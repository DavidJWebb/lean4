/-
Copyright (c) 2020 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura
-/
module

prelude
public import Lean.ScopedEnvExtension
public import Lean.Util.Recognizers
public import Lean.Meta.DiscrTree
public import Lean.Meta.Tactic.AuxLemma
public import Lean.DefEqAttrib
public import Lean.DocString
import Lean.Meta.AppBuilder
import Lean.Meta.Eqns

public section

/-!
This module contains types to manages simp theorems and sets theirof.

Overview of types in this module:

* `Origin`: Identifies where a simp theorem comes from (global declaration or local expression).
   Includes the direction of the theorem for global declarations.
* `SimpTheorem`: Represents a single simp theorem, including its origin and proof.
* `SimpEntry`: The effect of a simp attribute; either a `SimpTheorem` or information about a
   definition to unfold. This is stored in oleans.
* `SimpTheorems`: Main data structure to store the simp set for a given `simp` invocation, including
   discrimination trees, sets of erased theorem, declarations to unfold.
* `SimpExtension`: Environment extension to store the default simp set, or user-defined simp sets.
   Each simp extension maintains its own `SimpTheorems` within a module.
* `SimpTheoremsArray`: Array of `SimpTheorems`, to avoid the need for merging `SimpTheorems` when
   more than one simp extension is enabled.

-/


namespace Lean.Meta

register_builtin_option backward.dsimp.useDefEqAttr : Bool := {
  defValue := true
  descr    := "Use `defeq` attribute rather than checking theorem body to decide whether a theroem \
    can be used in `dsimp` or with `implicitDefEqProofs`."
}

register_builtin_option debug.tactic.simp.checkDefEqAttr : Bool := {
  defValue := false
  descr    := "If true, whenever `dsimp` fails to apply a rewrite rule because it is not marked as \
    `defeq`, check whether it would have been considered as a rfl theorem before the introduction \
    of the `defeq` attribute, and warn if it was. Note that this is a costly check."
}

/--
An `Origin` is an identifier for simp theorems which indicates roughly
what action the user took which lead to this theorem existing in the simp set.
-/
inductive Origin where
  /-- A global declaration in the environment. -/
  | decl (declName : Name) (post := true) (inv := false)
  /--
  A local hypothesis.
  When `contextual := true` is enabled, this fvar may exist in an extension
  of the current local context; it will not be used for rewriting by simp once
  it is out of scope but it may end up in the `usedSimps` trace.
  -/
  | fvar (fvarId : FVarId)
  /--
  A proof term provided directly to a call to `simp [ref, ...]` where `ref`
  is the provided simp argument (of kind `Parser.Tactic.simpLemma`).
  The `id` is a unique identifier for the call.
  -/
  | stx (id : Name) (ref : Syntax)
  /--
  Some other origin. `name` should not collide with the other types
  for erasure to work correctly, and simp trace will ignore this lemma.
  The other origins should be preferred if possible.
  -/
  | other (name : Name)
  deriving Inhabited, Repr

/-- A unique identifier corresponding to the origin. -/
def Origin.key : Origin → Name
  | .decl declName _ _ => declName
  | .fvar fvarId => fvarId.name
  | .stx id _ => id
  | .other name => name

/-- The origin corresponding to the converse direction (`← thm` vs. `thm`) -/
def Origin.converse : Origin → Option Origin
  | .decl declName phase inv => some (.decl declName phase (not inv))
  | _ => none

instance : BEq Origin where
  beq a b := match a, b with
    | .decl declName₁ _ inv₁, .decl declName₂ _ inv₂ =>
      /- Remark: we must distinguish `thm` from `←thm`. See issue #4290. -/
      declName₁ == declName₂ && inv₁ == inv₂
    | .decl .., _ => false
    | _, .decl .. => false
    | a, b => a.key == b.key

instance : Hashable Origin where
  hash a := match a with
   | .decl declName _ true => mixHash (hash declName) 11
   | .decl declName _ false => mixHash (hash declName) 13
   | a => hash a.key

def Origin.lt : Origin → Origin → Bool
  | .decl declName₁ _ inv₁, .decl declName₂ _ inv₂ =>
    Name.lt declName₁ declName₂ || (declName₁ == declName₂ && !inv₁ && inv₂)
  | .decl .., _ => false
  | _, .decl .. => true
  | a, b => Name.lt a.key b.key

instance : LT Origin where
  lt a b := a.lt b

instance (a b : Origin) : Decidable (a < b) :=
  inferInstanceAs (Decidable (a.lt b))

/-
Note: we want to use iota reduction when indexing instances. Otherwise,
we cannot use simp theorems such as
```
@[simp] theorem liftOn_mk (a : α) (f : α → γ) (h : ∀ a₁ a₂, r a₁ a₂ → f a₁ = f a₂) :
    Quot.liftOn (Quot.mk r a) f h = f a := rfl
```
If we use `iota`, then the lhs is reduced to `f a`.
See comment at `DiscrTree`.
-/

abbrev SimpTheoremKey := DiscrTree.Key

/--
  The fields `levelParams` and `proof` are used to encode the proof of the simp theorem.
  If the `proof` is a global declaration `c`, we store `Expr.const c []` at `proof` without the universe levels, and `levelParams` is set to `#[]`
  When using the lemma, we create fresh universe metavariables.
  Motivation: most simp theorems are global declarations, and this approach is faster and saves memory.

  The field `levelParams` is not empty only when we elaborate an expression provided by the user, and it contains universe metavariables.
  Then, we use `abstractMVars` to abstract the universe metavariables and create new fresh universe parameters that are stored at the field `levelParams`.
-/
structure SimpTheorem where
  keys        : Array SimpTheoremKey := #[]
  /--
    It stores universe parameter names for universe polymorphic proofs.
    Recall that it is non-empty only when we elaborate an expression provided by the user.
    When `proof` is just a constant, we can use the universe parameter names stored in the declaration.
   -/
  levelParams : Array Name := #[]
  proof       : Expr
  priority    : Nat  := eval_prio default
  post        : Bool := true
  /-- `perm` is true if lhs and rhs are identical modulo permutation of variables. -/
  perm        : Bool := false
  /--
    `origin` is mainly relevant for producing trace messages.
    It is also viewed an `id` used to "erase" `simp` theorems from `SimpTheorems`.
  -/
  origin      : Origin
  /--
  `rfl` is true if `proof` is by `Eq.refl`, `rfl` or a `@[defeq]` theorem.
  -/
  rfl         : Bool
  deriving Inhabited

mutual
  private partial def isRflProofCore (type : Expr) (proof : Expr) : CoreM Bool := do
    match type with
    | .forallE _ _ type _ =>
      if let .lam _ _ proof _ := proof then
        isRflProofCore type proof
      else
        return false
    | _ =>
      if type.isAppOfArity ``Eq 3 then
        if proof.isAppOfArity ``Eq.refl 2 || proof.isAppOfArity ``rfl 2 then
          return true
        else if proof.isAppOfArity ``Eq.symm 4 then
          -- `Eq.symm` of rfl theorem is a rfl theorem
          isRflProofCore type proof.appArg! -- small hack: we don't need to set the exact type
        else if proof.getAppFn.isConst then
          -- The application of a `rfl` theorem is a `rfl` theorem
          -- A constant which is a `rfl` theorem is a `rfl` theorem
          isRflTheoremCore proof.getAppFn.constName!
        else
          return false
      else
        return false

  private partial def isRflTheoremCore (declName : Name) : CoreM Bool := do
    if backward.dsimp.useDefEqAttr.get (← getOptions) then
      return defeqAttr.hasTag (← getEnv) declName
    else
      let { kind := .thm, constInfo, .. } ← getAsyncConstInfo declName | return false
      let .thmInfo info ← traceBlock "isRflTheorem theorem body" constInfo | return false
      isRflProofCore info.type info.value
end

def isRflTheorem (declName : Name) : CoreM Bool :=
  -- Make theorem body available if `declName` is from the current module; the body does not matter
  -- for the ultimate application of a rfl theorem, only that the theorem type's LHS and RHS are
  -- defeq.
  withoutExporting do
    isRflTheoremCore declName

def isRflProof (proof : Expr) : MetaM Bool := do
  -- Make theorem body available if `declName` is from the current module; the body does not matter
  -- for the ultimate application of a rfl theorem, only that the theorem type's LHS and RHS are
  -- defeq.
  withoutExporting do
    if let .const declName .. := proof then
      isRflTheoremCore declName
    else
      isRflProofCore (← inferType proof) proof

instance : ToFormat SimpTheorem where
  format s :=
    let perm := if s.perm then ":perm" else ""
    let name := format s.origin.key
    let prio := f!":{s.priority}"
    name ++ prio ++ perm

def ppOrigin [Monad m] [MonadEnv m] [MonadError m] : Origin → m MessageData
  | .decl n post inv => do
    let r := MessageData.ofConstName n
    match post, inv with
    | true,  true  => return m!"← {r}"
    | true,  false => return r
    | false, true  => return m!"↓ ← {r}"
    | false, false => return m!"↓ {r}"
  | .fvar n => return mkFVar n
  | .stx _ ref => return ref
  | .other n => return n

def ppSimpTheorem [Monad m] [MonadEnv m] [MonadError m] (s : SimpTheorem) : m MessageData := do
  let perm := if s.perm then ":perm" else ""
  let name ← ppOrigin s.origin
  let prio := m!":{s.priority}"
  return name ++ prio ++ perm

instance : BEq SimpTheorem where
  beq e₁ e₂ := e₁.proof == e₂.proof


/--
Configuration for `MetaM` used to process global simp theorems
-/
def simpGlobalConfig : ConfigWithKey :=
  { iota         := false
    proj         := .no
    zetaDelta    := false
    transparency := .reducible
  : Config }.toConfigWithKey

@[inline] def withSimpGlobalConfig : MetaM α → MetaM α :=
  withConfigWithKey simpGlobalConfig



private partial def isPerm : Expr → Expr → MetaM Bool
  | .app f₁ a₁, .app f₂ a₂ => isPerm f₁ f₂ <&&> isPerm a₁ a₂
  | .mdata _ s, t => isPerm s t
  | s, .mdata _ t => isPerm s t
  | s@(.mvar ..), t@(.mvar ..) => isDefEq s t
  | .forallE n₁ d₁ b₁ _, .forallE _ d₂ b₂ _ =>
    isPerm d₁ d₂ <&&> withLocalDeclD n₁ d₁ fun x => isPerm (b₁.instantiate1 x) (b₂.instantiate1 x)
  | .lam n₁ d₁ b₁ _, .lam _ d₂ b₂ _ =>
    isPerm d₁ d₂ <&&> withLocalDeclD n₁ d₁ fun x => isPerm (b₁.instantiate1 x) (b₂.instantiate1 x)
  | .letE n₁ t₁ v₁ b₁ _, .letE _  t₂ v₂ b₂ _ =>
    isPerm t₁ t₂ <&&> isPerm v₁ v₂ <&&> withLetDecl n₁ t₁ v₁ fun x => isPerm (b₁.instantiate1 x) (b₂.instantiate1 x)
  | .proj _ i₁ b₁, .proj _ i₂ b₂ => pure (i₁ == i₂) <&&> isPerm b₁ b₂
  | s, t => return s == t

private def checkBadRewrite (lhs rhs : Expr) : MetaM Unit := do
  let lhs ← withSimpGlobalConfig <| DiscrTree.reduceDT lhs (root := true)
  if lhs == rhs && lhs.isFVar then
    throwError "Invalid simp theorem: Equation is equivalent to{indentExpr (← mkEq lhs rhs)}"

private partial def shouldPreprocess (type : Expr) : MetaM Bool :=
  forallTelescopeReducing type fun _ result => do
    if let some (_, lhs, rhs) := result.eq? then
      checkBadRewrite lhs rhs
      return false
    else
      return true

private partial def preprocess (e type : Expr) (inv : Bool) (isGlobal : Bool) : MetaM (List (Expr × Expr)) :=
  go e type
where
  go (e type : Expr) : MetaM (List (Expr × Expr)) := do
  let type ← whnf type
  if type.isForall then
    forallTelescopeReducing type fun xs type => do
      let e := mkAppN e xs
      let ps ← go e type
      ps.mapM fun (e, type) =>
        return (← mkLambdaFVars xs e, ← mkForallFVars xs type)
  else if let some (_, lhs, rhs) := type.eq? then
    if isGlobal then
      checkBadRewrite lhs rhs
    if inv then
      let type ← mkEq rhs lhs
      let e    ← mkEqSymm e
      return [(e, type)]
    else
      return [(e, type)]
  else if let some (lhs, rhs) := type.iff? then
    if isGlobal then
      checkBadRewrite lhs rhs
    if inv then
      let type ← mkEq rhs lhs
      let e    ← mkEqSymm (← mkPropExt e)
      return [(e, type)]
    else
      let type ← mkEq lhs rhs
      let e    ← mkPropExt e
      return [(e, type)]
  else if let some (_, lhs, rhs) := type.ne? then
    if inv then
      throwError m!"Invalid `←` modifier: Cannot be applied to simp theorems of the form `a ≠ b`"
        ++ .note m!"This simp theorem will rewrite{inlineExpr (← mkEq lhs rhs)}to `{.ofConstName ``False}`, \
                    which should not be applied in the reverse direction"
    if rhs.isConstOf ``Bool.true then
      return [(← mkAppM ``Bool.of_not_eq_true #[e], ← mkEq lhs (mkConst ``Bool.false))]
    else if rhs.isConstOf ``Bool.false then
      return [(← mkAppM ``Bool.of_not_eq_false #[e], ← mkEq lhs (mkConst ``Bool.true))]
    let type ← mkEq (← mkEq lhs rhs) (mkConst ``False)
    let e    ← mkEqFalse e
    return [(e, type)]
  else if let some p := type.not? then
    if inv then
      throwError m!"Invalid `←` modifier: Cannot be applied to simp theorems of the form `¬ P`"
        ++ .note m!"This simp theorem will rewrite{inlineExpr p}to `{.ofConstName ``False}`, which should not \
                    be applied in the reverse direction"
    if let some (_, lhs, rhs) := p.eq? then
      if rhs.isConstOf ``Bool.true then
        return [(← mkAppM ``Bool.of_not_eq_true #[e], ← mkEq lhs (mkConst ``Bool.false))]
      else if rhs.isConstOf ``Bool.false then
        return [(← mkAppM ``Bool.of_not_eq_false #[e], ← mkEq lhs (mkConst ``Bool.true))]
    let type ← mkEq p (mkConst ``False)
    let e    ← mkEqFalse e
    return [(e, type)]
  else if let some (type₁, type₂) := type.and? then
    let e₁ := mkProj ``And 0 e
    let e₂ := mkProj ``And 1 e
    return (← go e₁ type₁) ++ (← go e₂ type₂)
  else
    if inv then
      throwError m!"Invalid `←` modifier: Cannot be applied to a rule that rewrites to `True`"
        ++ .note m!"This simp theorem will rewrite{inlineExpr type}to `True`, which should not be applied in the reverse direction"
    let type ← mkEq type (mkConst ``True)
    let e    ← mkEqTrue e
    return [(e, type)]

private def checkTypeIsProp (type : Expr) : MetaM Unit :=
  unless (← isProp type) do
    throwError "Invalid simp theorem: Expected a proposition, but found{indentExpr type}"

private def mkSimpTheoremCore (origin : Origin) (e : Expr) (levelParams : Array Name) (proof : Expr) (post : Bool) (prio : Nat) (noIndexAtArgs : Bool) : MetaM SimpTheorem := do
  assert! origin != .fvar ⟨.anonymous⟩
  let type ← instantiateMVars (← inferType e)
  withNewMCtxDepth do
    let (_, _, type) ← forallMetaTelescopeReducing type
    let type ← whnfR type
    let (keys, perm) ←
      match type.eq? with
      | some (_, lhs, rhs) => pure (← DiscrTree.mkPath lhs noIndexAtArgs, ← isPerm lhs rhs)
      | none => throwError "Unexpected kind of simp theorem{indentExpr type}"
    return { origin, keys, perm, post, levelParams, proof, priority := prio, rfl := (← isRflProof proof) }

/--
Creates a `SimpTheorem` from a global theorem.
Because some theorems lead to multiple `SimpTheorems` (in particular conjunctions), returns an array.
-/
def mkSimpTheoremFromConst (declName : Name) (post := true) (inv := false)
    (prio : Nat := eval_prio default) : MetaM (Array SimpTheorem) := do
  let cinfo ← getConstVal declName
  let us := cinfo.levelParams.map mkLevelParam
  let origin := .decl declName post inv
  let val := mkConst declName us
  withSimpGlobalConfig do
    let type ← inferType val
    checkTypeIsProp type
    if inv || (← shouldPreprocess type) then
      let mut r := #[]
      for (val, type) in (← preprocess val type inv (isGlobal := true)) do
        let auxName ← mkAuxLemma (kind? := `_simp) cinfo.levelParams type val (inferRfl := true)
        r := r.push <| (← withoutExporting do mkSimpTheoremCore origin (mkConst auxName us) #[] (mkConst auxName) post prio (noIndexAtArgs := false))
      return r
    else
      return #[← withoutExporting do mkSimpTheoremCore origin (mkConst declName us) #[] (mkConst declName) post prio (noIndexAtArgs := false)]

def SimpTheorem.getValue (simpThm : SimpTheorem) : MetaM Expr := do
  if simpThm.proof.isConst && simpThm.levelParams.isEmpty then
    let info ← getConstVal simpThm.proof.constName!
    if info.levelParams.isEmpty then
      return simpThm.proof
    else
      return simpThm.proof.updateConst! (← info.levelParams.mapM fun _ => mkFreshLevelMVar)
  else
    let us ← simpThm.levelParams.mapM fun _ => mkFreshLevelMVar
    return simpThm.proof.instantiateLevelParamsArray simpThm.levelParams us

private def preprocessProof (val : Expr) (inv : Bool) : MetaM (Array Expr) := do
  let type ← inferType val
  checkTypeIsProp type
  let ps ← preprocess val type inv (isGlobal := false)
  return ps.toArray.map fun (val, _) => val

def mkSimpTheoremFromExpr (id : Origin) (levelParams : Array Name) (proof : Expr) (inv := false)
    (post := true) (prio : Nat := eval_prio default) (config : ConfigWithKey := simpGlobalConfig) :
    MetaM (Array SimpTheorem) := do
  if proof.isConst then
    -- Recall that we use `simpGlobalConfig` for processing global declarations.
    mkSimpTheoremFromConst proof.constName! post inv prio
  else
    withConfigWithKey config do
      withReducible do
        (← preprocessProof proof inv).mapM fun val =>
          mkSimpTheoremCore id val levelParams val post prio (noIndexAtArgs := true)

/--
A simp theorem or information about a declaration to unfold by simp.
This is stored in the oleans to implement the `simp` attribute and user-defined simp sets.
-/
inductive SimpEntry where
  | thm      : SimpTheorem → SimpEntry
  | toUnfold : Name → SimpEntry
  | toUnfoldThms : Name → Array Name → SimpEntry
  deriving Inhabited

/--
Reducible functions and projection functions should always be put in `toUnfold`, instead
of trying to use equational theorems.

The simplifiers has special support for structure and class projections, and gets
confused when they suddenly rewrite, so ignore equations for them
-/
def Simp.ignoreEquations (declName : Name) : CoreM Bool := do
  return (← isProjectionFn declName) || (← isReducible declName)

/--
Even if a function has equation theorems,
we also store it in the `toUnfold` set in the following two cases:
1- It was defined by structural recursion and has a smart-unfolding associated declaration.
2- It is non-recursive.

Reason: `unfoldPartialApp := true` or conditional equations may not apply.

Remark: In the future, we are planning to disable this
behavior unless `unfoldPartialApp := true`.
Moreover, users will have to use `f.eq_def` if they want to force the definition to be
unfolded.
-/
def Simp.unfoldEvenWithEqns (declName : Name) : CoreM Bool := do
  if hasSmartUnfoldingDecl (← getEnv) declName then return true
  unless (← isRecursiveDefinition declName) do return true
  return false

/--
Given the name of a declaration to unfold, return the `SimpEntry` (or entries) that
implement this unfolding, using either the equational theorems, or `SimpEntry.toUnfold`, or both.
-/
def mkSimpEntryOfDeclToUnfold (declName : Name) : MetaM (Array SimpEntry) := do
  let mut entries : Array SimpEntry := #[]
  -- NOTE: the latter condition is only to preserve previous behavior where simp accepts even things
  -- that neither theorems nor unfoldable. This should likely be tightened up in the future.
  if !(← getConstInfo declName).isDefinition && getOriginalConstKind? (← getEnv) declName == some .defn then
    throwError "Invalid simp theorem `{.ofConstName declName}`: Expected a definition with an exposed body"
  if (← Simp.ignoreEquations declName) then
    entries := entries.push (.toUnfold declName)
  else if let some eqns ← getEqnsFor? declName then
    for h : i in *...eqns.size do
      let eqn := eqns[i]
      /-
      We assign priorities to the equational lemmas so that more specific ones
      are tried first before a possible catch-all with possible side-conditions.

      We assign very low priorities to match the simplifiers behavior when unfolding
      a definition, which happens in `simpLoop`’ `visitPreContinue` after applying
      rewrite rules.

      Definitions with more than 100 equational theorems will use priority 1 for all
      but the last (a heuristic, not perfect).
      -/
      let prio := if eqns.size > 100 then
        if i + 1 = eqns.size then 0 else 1
      else
        100 - i
      let thms ← mkSimpTheoremFromConst eqn (prio := prio)
      entries := entries ++ thms.map (.thm ·)
    if (← Simp.unfoldEvenWithEqns declName) then
      entries := entries.push (.toUnfold declName)
  else
    entries := entries.push (.toUnfold declName)
  return entries


abbrev SimpTheoremTree := DiscrTree SimpTheorem

/--
The theorems in a simp set.
-/
structure SimpTheorems where
  pre          : SimpTheoremTree := DiscrTree.empty
  post         : SimpTheoremTree := DiscrTree.empty
  lemmaNames   : PHashSet Origin := {}
  /--
  Constants (and let-declaration `FVarId`) to unfold.
  When `zetaDelta := false`, the simplifier will expand a let-declaration if it is in this set.
  -/
  toUnfold     : PHashSet Name := {}
  erased       : PHashSet Origin := {}
  toUnfoldThms : PHashMap Name (Array Name) := {}
  deriving Inhabited

partial def SimpTheorems.eraseCore (d : SimpTheorems) (thmId : Origin) : SimpTheorems :=
  let d := { d with erased := d.erased.insert thmId, lemmaNames := d.lemmaNames.erase thmId }
  if let .decl declName .. := thmId then
    let d := { d with toUnfold := d.toUnfold.erase declName }
    if let some thms := d.toUnfoldThms.find? declName then
      let dummy := true
      thms.foldl (init := d) (eraseCore · <| .decl · dummy (inv := false))
    else
      d
  else
    d

private def eraseIfExists (d : SimpTheorems) (thmId : Origin) : SimpTheorems :=
  if d.lemmaNames.contains thmId then
    d.eraseCore thmId
  else
    d

/--
If `e` is a backwards theorem `← thm`, we must ensure the forward theorem is erased
from `d`. See issue #4290
-/
private def eraseFwdIfBwd (d : SimpTheorems) (e : SimpTheorem) : SimpTheorems :=
  if let some converseOrigin := e.origin.converse then
    eraseIfExists d converseOrigin
  else
    d

def SimpTheorems.unerase (d : SimpTheorems) (thmId : Origin) : SimpTheorems :=
  { d with erased := d.erased.erase thmId }

def SimpTheorems.addSimpTheorem (d : SimpTheorems) (e : SimpTheorem) : SimpTheorems :=
  -- Erase the converse, if it exists
  let d := eraseFwdIfBwd d e
  if e.post then
    { d with post := d.post.insertCore e.keys e, lemmaNames := updateLemmaNames d.lemmaNames }
  else
    { d with pre := d.pre.insertCore e.keys e, lemmaNames := updateLemmaNames d.lemmaNames }
where
  updateLemmaNames (s : PHashSet Origin) : PHashSet Origin :=
    s.insert e.origin

@[deprecated SimpTheorems.addSimpTheorem (since := "2025-06-17")]
def addSimpTheoremEntry := SimpTheorems.addSimpTheorem

def SimpTheorems.addDeclToUnfoldCore (d : SimpTheorems) (declName : Name) : SimpTheorems :=
  { d with toUnfold := d.toUnfold.insert declName }

def SimpTheorems.addLetDeclToUnfold (d : SimpTheorems) (fvarId : FVarId) : SimpTheorems :=
  -- A small hack that relies on the fact that constants and `FVarId` names should be disjoint.
  { d with toUnfold := d.toUnfold.insert fvarId.name }

/-- Return `true` if `declName` is tagged to be unfolded using `unfoldDefinition?` (i.e., without using equational theorems). -/
def SimpTheorems.isDeclToUnfold (d : SimpTheorems) (declName : Name) : Bool :=
  d.toUnfold.contains declName

def SimpTheorems.isLetDeclToUnfold (d : SimpTheorems) (fvarId : FVarId) : Bool :=
  d.toUnfold.contains fvarId.name -- See comment at `addLetDeclToUnfold`

def SimpTheorems.isLemma (d : SimpTheorems) (thmId : Origin) : Bool :=
  d.lemmaNames.contains thmId

/-- Register the equational theorems for the given definition. -/
def SimpTheorems.registerDeclToUnfoldThms (d : SimpTheorems) (declName : Name) (eqThms : Array Name) : SimpTheorems :=
  { d with toUnfoldThms := d.toUnfoldThms.insert declName eqThms }

def SimpTheorems.erase [Monad m] [MonadLog m] [AddMessageContext m] [MonadOptions m]
    (d : SimpTheorems) (thmId : Origin) : m SimpTheorems := do
  if d.isLemma thmId ||
    match thmId with
    | .decl declName .. => d.isDeclToUnfold declName || d.toUnfoldThms.contains declName
    | _ => false
  then
    return d.eraseCore thmId

  -- `attribute [-simp] foo` should also undo `attribute [simp ←] foo`.
  if let some thmId' := thmId.converse then
    if d.isLemma thmId' then
      return d.eraseCore thmId'

  logWarning m!"`{thmId.key}` does not have the `[simp]` attribute"
  return d

def SimpTheorems.addSimpEntry (d : SimpTheorems) (e : SimpEntry) : SimpTheorems :=
  match e with
  | .thm e => d.addSimpTheorem e
  | .toUnfold n => d.addDeclToUnfoldCore n
  | .toUnfoldThms n thms => d.registerDeclToUnfoldThms n thms

/--
`simp [foo]` should undo a previous `attribute @[-simp] foo`.
(Note that `attribute @[simp] foo` does not undo a `attribute @[simp] foo`, see #5852)
-/
def SimpTheorems.uneraseSimpEntry (d : SimpTheorems) (e : SimpEntry) : SimpTheorems :=
  match e with
  | .thm e => d.unerase e.origin
  | _ => d

/-- Auxiliary method for adding a global declaration to a `SimpTheorems` datastructure. -/
def SimpTheorems.addConst (s : SimpTheorems) (declName : Name) (post := true) (inv := false) (prio : Nat := eval_prio default) : MetaM SimpTheorems := do
  let simpThms ← mkSimpTheoremFromConst declName post inv prio
  return simpThms.foldl SimpTheorems.addSimpTheorem s

/--
The environment extension that contains a simp set, returned by `Lean.Meta.registerSimpAttr`.

Use the simp set's attribute or `Lean.Meta.addSimpTheorem` to add theorems to the simp set. Use
`Lean.Meta.SimpExtension.getTheorems` to get the contents.
-/
abbrev SimpExtension := SimpleScopedEnvExtension SimpEntry SimpTheorems

def SimpExtension.getTheorems (ext : SimpExtension) : CoreM SimpTheorems :=
  return ext.getState (← getEnv)

/--
Adds a simp theorem to a simp extension
-/
def addSimpTheorem (ext : SimpExtension) (declName : Name) (post : Bool) (inv : Bool) (attrKind : AttributeKind) (prio : Nat) : MetaM Unit := do
  let simpThms ← withExporting (isExporting := !isPrivateName declName) do mkSimpTheoremFromConst declName post inv prio
  for simpThm in simpThms do
    ext.add (SimpEntry.thm simpThm) attrKind


def mkSimpExt (name : Name := by exact decl_name%) : IO SimpExtension :=
  registerSimpleScopedEnvExtension {
    name     := name
    initial  := {}
    addEntry := fun d e => d.addSimpEntry e
  }

abbrev SimpExtensionMap := Std.HashMap Name SimpExtension

builtin_initialize simpExtensionMapRef : IO.Ref SimpExtensionMap ← IO.mkRef {}

def getSimpExtension? (attrName : Name) : IO (Option SimpExtension) :=
  return (← simpExtensionMapRef.get)[attrName]?

def SimpTheorems.addDeclToUnfold (d : SimpTheorems) (declName : Name) : MetaM SimpTheorems := do
  let entries ← mkSimpEntryOfDeclToUnfold declName
  return entries.foldl (init := d) fun d e => d.addSimpEntry e

/-- Auxiliary method for adding a local simp theorem to a `SimpTheorems` datastructure. -/
def SimpTheorems.add (s : SimpTheorems) (id : Origin) (levelParams : Array Name) (proof : Expr)
        (inv := false) (post := true) (prio : Nat := eval_prio default)
        (config : ConfigWithKey := simpGlobalConfig) : MetaM SimpTheorems := do
  let simpThms ← mkSimpTheoremFromExpr id levelParams proof inv post prio config
  return simpThms.foldl SimpTheorems.addSimpTheorem s

/--
A `SimpTheoremsArray` is a collection of `SimpTheorems`. The first entry is the default simp set
and possible extensions as simp args (`simp [thm]`), further entries are custom simp sets added
a s simp arguments (`simp [my_simp_set]`). The array is scanned linear during rewriting.
This avoids the need for efficiently merging the `SimpTheorems` data structure.
-/
abbrev SimpTheoremsArray := Array SimpTheorems

def SimpTheoremsArray.addTheorem (thmsArray : SimpTheoremsArray) (id : Origin) (h : Expr) (config : ConfigWithKey := simpGlobalConfig) : MetaM SimpTheoremsArray :=
  if thmsArray.isEmpty then
    let thms : SimpTheorems := {}
    return #[ (← thms.add id #[] h (config := config)) ]
  else
    thmsArray.modifyM 0 fun thms => thms.add id #[] h (config := config)

def SimpTheoremsArray.eraseTheorem (thmsArray : SimpTheoremsArray) (thmId : Origin) : SimpTheoremsArray :=
  thmsArray.map fun thms => thms.eraseCore thmId

def SimpTheoremsArray.isErased (thmsArray : SimpTheoremsArray) (thmId : Origin) : Bool :=
  thmsArray.any fun thms => thms.erased.contains thmId

def SimpTheoremsArray.isDeclToUnfold (thmsArray : SimpTheoremsArray) (declName : Name) : Bool :=
  thmsArray.any fun thms => thms.isDeclToUnfold declName

def SimpTheoremsArray.isLetDeclToUnfold (thmsArray : SimpTheoremsArray) (fvarId : FVarId) : Bool :=
  thmsArray.any fun thms => thms.isLetDeclToUnfold fvarId

end Lean.Meta
