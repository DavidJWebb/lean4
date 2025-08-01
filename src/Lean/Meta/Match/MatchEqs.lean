/-
Copyright (c) 2021 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura
-/
module

prelude
public import Lean.Meta.CtorRecognizer
public import Lean.Meta.Match.Match
public import Lean.Meta.Match.MatchEqsExt
public import Lean.Meta.Tactic.Apply
public import Lean.Meta.Tactic.Refl
public import Lean.Meta.Tactic.Delta
public import Lean.Meta.Tactic.Injection
public import Lean.Meta.Tactic.Contradiction
import Lean.Meta.Tactic.SplitIf

public section

namespace Lean.Meta

/--
A custom, approximated, and quick `contradiction` tactic.
It only finds contradictions of the form `(h₁ : p)` and `(h₂ : ¬ p)` where
`p`s are structurally equal. The procedure is not quadratic like `contradiction`.

We use it to improve the performance of `proveSubgoalLoop` at `mkSplitterProof`.
We will eventually have to write more efficient proof automation for this module.
The new proof automation should exploit the structure of the generated goals and avoid general purpose tactics
such as `contradiction`.
-/
private def _root_.Lean.MVarId.contradictionQuick (mvarId : MVarId) : MetaM Bool := do
  mvarId.withContext do
    let mut posMap : Std.HashMap Expr FVarId := {}
    let mut negMap : Std.HashMap Expr FVarId := {}
    for localDecl in (← getLCtx) do
      unless localDecl.isImplementationDetail do
        if let some p ← matchNot? localDecl.type then
          if let some pFVarId := posMap[p]? then
            mvarId.assign (← mkAbsurd (← mvarId.getType) (mkFVar pFVarId) localDecl.toExpr)
            return true
          negMap := negMap.insert p localDecl.fvarId
        if (← isProp localDecl.type) then
          if let some nFVarId := negMap[localDecl.type]? then
            mvarId.assign (← mkAbsurd (← mvarId.getType) localDecl.toExpr (mkFVar nFVarId))
            return true
          posMap := posMap.insert localDecl.type localDecl.fvarId
      pure ()
    return false

/--
  Helper method for `proveCondEqThm`. Given a goal of the form `C.rec ... xMajor = rhs`,
  apply `cases xMajor`. -/
partial def casesOnStuckLHS (mvarId : MVarId) : MetaM (Array MVarId) := do
  let target ← mvarId.getType
  if let some (_, lhs, _) ← matchEq? target then
    if let some fvarId ← findFVar? lhs then
      return (←  mvarId.cases fvarId).map fun s => s.mvarId
  throwError "'casesOnStuckLHS' failed"
where
  findFVar? (e : Expr) : MetaM (Option FVarId) := do
    match e.getAppFn with
    | Expr.proj _ _ e => findFVar? e
    | f =>
      if !f.isConst then
        return none
      else
        let declName := f.constName!
        let args := e.getAppArgs
        match (← getProjectionFnInfo? declName) with
        | some projInfo =>
          if projInfo.numParams < args.size then
            findFVar? args[projInfo.numParams]!
          else
            return none
        | none =>
          matchConstRec f (fun _ => return none) fun recVal _ => do
            if recVal.getMajorIdx >= args.size then
              return none
            let major := args[recVal.getMajorIdx]!.consumeMData
            if major.isFVar then
              return some major.fvarId!
            else
              return none

def casesOnStuckLHS? (mvarId : MVarId) : MetaM (Option (Array MVarId)) := do
  try casesOnStuckLHS mvarId catch _ => return none

namespace Match

def unfoldNamedPattern (e : Expr) : MetaM Expr := do
  let visit (e : Expr) : MetaM TransformStep := do
    if let some e := isNamedPattern? e then
      if let some eNew ← unfoldDefinition? e then
        return TransformStep.visit eNew
    return .continue
  Meta.transform e (pre := visit)

/--
  Similar to `forallTelescopeReducing`, but

  1. Eliminates arguments for named parameters and the associated equation proofs.

  2. Instantiate the `Unit` parameter of an otherwise argumentless alternative.

  It does not handle the equality parameters associated with the `h : discr` notation.

  The continuation `k` takes four arguments `ys args mask type`.
  - `ys` are variables for the hypotheses that have not been eliminated.
  - `args` are the arguments for the alternative `alt` that has type `altType`. `ys.size <= args.size`
  - `mask[i]` is true if the hypotheses has not been eliminated. `mask.size == args.size`.
  - `type` is the resulting type for `altType`.

  We use the `mask` to build the splitter proof. See `mkSplitterProof`.

  This can be used to use the alternative of a match expression in its splitter.
-/
partial def forallAltVarsTelescope (altType : Expr) (altNumParams numDiscrEqs : Nat)
  (k : (patVars : Array Expr) → (args : Array Expr) → (mask : Array Bool) → (type : Expr) → MetaM α) : MetaM α := do
  go #[] #[] #[] 0 altType
where
  go (ys : Array Expr) (args : Array Expr) (mask : Array Bool) (i : Nat) (type : Expr) : MetaM α := do
    let type ← whnfForall type
    if i < altNumParams - numDiscrEqs then
      let Expr.forallE n d b .. := type
        | throwError "expecting {altNumParams} parameters, excluding {numDiscrEqs} equalities, but found type{indentExpr altType}"

      -- Handle the special case of `Unit` parameters.
      if i = 0 && altNumParams - numDiscrEqs = 1 && d.isConstOf ``Unit && !b.hasLooseBVars then
        return ← k #[] #[mkConst ``Unit.unit] #[false] b

      let d ← Match.unfoldNamedPattern d
      withLocalDeclD n d fun y => do
        let typeNew := b.instantiate1 y
        if let some (_, lhs, rhs) ← matchEq? d then
          if lhs.isFVar && ys.contains lhs && args.contains lhs && isNamedPatternProof typeNew y then
              let some j  := ys.finIdxOf? lhs | unreachable!
              let ys      := ys.eraseIdx j
              let some k  := args.idxOf? lhs | unreachable!
              let mask    := mask.set! k false
              let args    := args.map fun arg => if arg == lhs then rhs else arg
              let arg     ← mkEqRefl rhs
              let typeNew := typeNew.replaceFVar lhs rhs
              return ← withReplaceFVarId lhs.fvarId! rhs do
              withReplaceFVarId y.fvarId! arg do
                go ys (args.push arg) (mask.push false) (i+1) typeNew
        go (ys.push y) (args.push y) (mask.push true) (i+1) typeNew
    else
      let type ← Match.unfoldNamedPattern type
      k ys args mask type

  isNamedPatternProof (type : Expr) (h : Expr) : Bool :=
    Option.isSome <| type.find? fun e =>
      if let some e := Match.isNamedPattern? e then
        e.appArg! == h
      else
        false


/--
  Extension of `forallAltTelescope` that continues further:

  Equality parameters associated with the `h : discr` notation are replaced with `rfl` proofs.
  Recall that this kind of parameter always occurs after the parameters corresponding to pattern
  variables.

  The continuation `k` takes four arguments `ys args mask type`.
  - `ys` are variables for the hypotheses that have not been eliminated.
  - `eqs` are variables for equality hypotheses associated with discriminants annotated with `h : discr`.
  - `args` are the arguments for the alternative `alt` that has type `altType`. `ys.size <= args.size`
  - `mask[i]` is true if the hypotheses has not been eliminated. `mask.size == args.size`.
  - `type` is the resulting type for `altType`.

  We use the `mask` to build the splitter proof. See `mkSplitterProof`.

  This can be used to use the alternative of a match expression in its splitter.
-/
partial def forallAltTelescope (altType : Expr) (altNumParams numDiscrEqs : Nat)
    (k : (ys : Array Expr) → (eqs : Array Expr) → (args : Array Expr) → (mask : Array Bool) → (type : Expr) → MetaM α)
    : MetaM α := do
  forallAltVarsTelescope altType altNumParams numDiscrEqs fun ys args mask altType => do
    go ys #[] args mask 0 altType
where
  go (ys : Array Expr) (eqs : Array Expr) (args : Array Expr) (mask : Array Bool) (i : Nat) (type : Expr) : MetaM α := do
    let type ← whnfForall type
    if i < numDiscrEqs then
      let Expr.forallE n d b .. := type
        | throwError "expecting {altNumParams} parameters, including {numDiscrEqs} equalities, but found type{indentExpr altType}"
      let arg ← if let some (_, _, rhs) ← matchEq? d then
        mkEqRefl rhs
      else if let some (_, _, _, rhs) ← matchHEq? d then
        mkHEqRefl rhs
      else
        throwError "unexpected match alternative type{indentExpr altType}"
      withLocalDeclD n d fun eq => do
        let typeNew := b.instantiate1 eq
        go ys (eqs.push eq) (args.push arg) (mask.push false) (i+1) typeNew
    else
      let type ← unfoldNamedPattern type
      k ys eqs args mask type

/--
Given an application of an matcher arm `alt` that is expecting the `numDiscrEqs`, and
an array of `discr = pattern` equalities (one for each discriminant), apply those that
are expected by the alternative.
-/
partial def mkAppDiscrEqs (alt : Expr) (heqs : Array Expr) (numDiscrEqs : Nat) : MetaM Expr := do
  go alt (← inferType alt) 0
where
  go e ty i := do
    if i < numDiscrEqs then
      let Expr.forallE n d b .. := ty
        | throwError "expecting {numDiscrEqs} equalities, but found type{indentExpr alt}"
      for heq in heqs do
        if (← isDefEq (← inferType heq) d) then
          return ← go (mkApp e heq) (b.instantiate1 heq) (i+1)
      throwError "Could not find equation {n} : {d} among {heqs}"
    else
      return e

namespace SimpH

/--
  State for the equational theorem hypothesis simplifier.

  Recall that each equation contains additional hypotheses to ensure the associated case does not taken by previous cases.
  We have one hypothesis for each previous case.

  Each hypothesis is of the form `forall xs, eqs → False`

  We use tactics to minimize code duplication.
-/
structure State where
  mvarId : MVarId            -- Goal representing the hypothesis
  xs  : List FVarId          -- Pattern variables for a previous case
  eqs : List FVarId          -- Equations to be processed
  eqsNew : List FVarId := [] -- Simplified (already processed) equations

abbrev M := StateRefT State MetaM

/--
  Apply the given substitution to `fvarIds`.
  This is an auxiliary method for `substRHS`.
-/
private def applySubst (s : FVarSubst) (fvarIds : List FVarId) : List FVarId :=
  fvarIds.filterMap fun fvarId => match s.apply (mkFVar fvarId) with
    | Expr.fvar fvarId .. => some fvarId
    | _ => none

/--
  Given an equation of the form `lhs = rhs` where `rhs` is variable in `xs`,
  replace it everywhere with `lhs`.
-/
private def substRHS (eq : FVarId) (rhs : FVarId) : M Unit := do
  assert! (← get).xs.contains rhs
  let (subst, mvarId) ← substCore (← get).mvarId eq (symm := true)
  modify fun s => { s with
    mvarId,
    xs  := applySubst subst (s.xs.erase rhs)
    eqs := applySubst subst s.eqs
    eqsNew := applySubst subst s.eqsNew
  }

private def isDone : M Bool :=
  return (← get).eqs.isEmpty

/-- Customized `contradiction` tactic for `simpH?` -/
private def contradiction (mvarId : MVarId) : MetaM Bool :=
   mvarId.contradictionCore { genDiseq := false, emptyType := false }

/--
  Auxiliary tactic that tries to replace as many variables as possible and then apply `contradiction`.
  We use it to discard redundant hypotheses.
-/
partial def trySubstVarsAndContradiction (mvarId : MVarId) (forbidden : FVarIdSet := {}) : MetaM Bool :=
  commitWhen do
    let mvarId ← substVars mvarId
    match (← injections mvarId (forbidden := forbidden)) with
    | .solved => return true -- closed goal
    | .subgoal mvarId' _ forbidden =>
      if mvarId' == mvarId then
        contradiction mvarId
      else
        trySubstVarsAndContradiction mvarId' forbidden

private def processNextEq : M Bool := do
  let s ← get
  s.mvarId.withContext do
    -- If the goal is contradictory, the hypothesis is redundant.
    if (← contradiction s.mvarId) then
      return false
    if let eq :: eqs := s.eqs then
      modify fun s => { s with eqs }
      let eqType ← inferType (mkFVar eq)
      -- See `substRHS`. Recall that if `rhs` is a variable then if must be in `s.xs`
      if let some (_, lhs, rhs) ← matchEq? eqType then
        if (← isDefEq lhs rhs) then
          return true
        if rhs.isFVar && s.xs.contains rhs.fvarId! then
          substRHS eq rhs.fvarId!
          return true
      if let some (α, lhs, β, rhs) ← matchHEq? eqType then
        -- Try to convert `HEq` into `Eq`
        if (← isDefEq α β) then
          let (eqNew, mvarId) ← heqToEq s.mvarId eq (tryToClear := true)
          modify fun s => { s with mvarId, eqs := eqNew :: s.eqs }
          return true
        -- If it is not possible, we try to show the hypothesis is redundant by substituting even variables that are not at `s.xs`, and then use contradiction.
        else
          match (← isConstructorApp? lhs), (← isConstructorApp? rhs) with
          | some lhsCtor, some rhsCtor =>
            if lhsCtor.name != rhsCtor.name then
              return false -- If the constructors are different, we can discard the hypothesis even if it a heterogeneous equality
            else if (← trySubstVarsAndContradiction s.mvarId) then
              return false
          | _, _ =>
            if (← trySubstVarsAndContradiction s.mvarId) then
              return false
      try
        -- Try to simplify equation using `injection` tactic.
        match (← injection s.mvarId eq) with
        | InjectionResult.solved => return false
        | InjectionResult.subgoal mvarId eqNews .. =>
          modify fun s => { s with mvarId, eqs := eqNews.toList ++ s.eqs }
      catch _ =>
        modify fun s => { s with eqsNew := eq :: s.eqsNew }
    return true

partial def go : M Bool := do
  if (← isDone) then
    return true
  else if (← processNextEq) then
    go
  else
    return false

end SimpH

/--
  Auxiliary method for simplifying equational theorem hypotheses.

  Recall that each equation contains additional hypotheses to ensure the associated case was not taken by previous cases.
  We have one hypothesis for each previous case.
-/
private partial def simpH? (h : Expr) (numEqs : Nat) : MetaM (Option Expr) := withDefault do
  let numVars ← forallTelescope h fun ys _ => pure (ys.size - numEqs)
  let mvarId := (← mkFreshExprSyntheticOpaqueMVar h).mvarId!
  let (xs, mvarId) ← mvarId.introN numVars
  let (eqs, mvarId) ← mvarId.introN numEqs
  let (r, s) ← SimpH.go |>.run { mvarId, xs := xs.toList, eqs := eqs.toList }
  if r then
    s.mvarId.withContext do
      let eqs := s.eqsNew.reverse.toArray.map mkFVar
      let mut r ← mkForallFVars eqs (mkConst ``False)
      /- We only include variables in `xs` if there is a dependency. -/
      for x in s.xs.reverse do
        if (← dependsOn r x) then
          r ← mkForallFVars #[mkFVar x] r
      trace[Meta.Match.matchEqs] "simplified hypothesis{indentExpr r}"
      check r
      return some r
  else
    return none

private def substSomeVar (mvarId : MVarId) : MetaM (Array MVarId) := mvarId.withContext do
  for localDecl in (← getLCtx) do
    if let some (_, lhs, rhs) ← matchEq? localDecl.type then
      if lhs.isFVar then
        if !(← dependsOn rhs lhs.fvarId!) then
          match (← subst? mvarId lhs.fvarId!) with
          | some mvarId => return #[mvarId]
          | none => pure ()
  throwError "substSomeVar failed"

private def unfoldElimOffset (mvarId : MVarId) : MetaM MVarId := do
  if Option.isNone <| (← mvarId.getType).find? fun e => e.isConstOf ``Nat.elimOffset then
    throwError "goal's target does not contain `Nat.elimOffset`"
  mvarId.deltaTarget (· == ``Nat.elimOffset)

/--
Helper method for proving a conditional equational theorem associated with an alternative of
the `match`-eliminator `matchDeclName`. `type` contains the type of the theorem.

The `heqPos`/`heqNum` arguments indicate that these hypotheses are `Eq`/`HEq` hypotheses
to substitute first; this is used for the generalized match equations.
-/
partial def proveCondEqThm (matchDeclName : Name) (type : Expr)
  (heqPos : Nat := 0) (heqNum : Nat := 0) : MetaM Expr := withLCtx {} {} do
  let type ← instantiateMVars type
  let mvar0  ← mkFreshExprSyntheticOpaqueMVar type
  trace[Meta.Match.matchEqs] "proveCondEqThm {mvar0.mvarId!}"
  let mut mvarId := mvar0.mvarId!
  if heqNum > 0 then
    mvarId := (← mvarId.introN heqPos).2
    for _ in *...heqNum do
      let (h, mvarId') ← mvarId.intro1
      mvarId ← subst mvarId' h
    trace[Meta.Match.matchEqs] "proveCondEqThm after subst{mvarId}"
  mvarId := (← mvarId.intros).2
  mvarId ← mvarId.deltaTarget (· == matchDeclName)
  mvarId ← mvarId.heqOfEq
  go mvarId 0
  instantiateMVars mvar0
where
  go (mvarId : MVarId) (depth : Nat) : MetaM Unit := withIncRecDepth do
    trace[Meta.Match.matchEqs] "proveCondEqThm.go {mvarId}"
    let mvarId ← mvarId.modifyTargetEqLHS whnfCore
    let subgoals ←
      (do mvarId.refl; return #[])
      <|>
      (do mvarId.contradiction { genDiseq := true }; return #[])
      <|>
      (do let mvarId ← unfoldElimOffset mvarId; return #[mvarId])
      <|>
      (casesOnStuckLHS mvarId)
      <|>
      (do let mvarId' ← simpIfTarget mvarId (useDecide := true) (useNewSemantics := true)
          if mvarId' == mvarId then throwError "simpIf failed"
          return #[mvarId'])
      <|>
      (do if let some (s₁, s₂) ← splitIfTarget? mvarId (useNewSemantics := true) then
            let mvarId₁ ← trySubst s₁.mvarId s₁.fvarId
            return #[mvarId₁, s₂.mvarId]
          else
            throwError "spliIf failed")
      <|>
      (substSomeVar mvarId)
      <|>
      (throwError "failed to generate equality theorems for `match` expression `{matchDeclName}`\n{MessageData.ofGoal mvarId}")
    subgoals.forM (go · (depth+1))


/-- Construct new local declarations `xs` with types `altTypes`, and then execute `f xs`  -/
private partial def withSplitterAlts (altTypes : Array Expr) (f : Array Expr → MetaM α) : MetaM α := do
  let rec go (i : Nat) (xs : Array Expr) : MetaM α := do
    if h : i < altTypes.size then
      let hName := (`h).appendIndexAfter (i+1)
      withLocalDeclD hName altTypes[i] fun x =>
        go (i+1) (xs.push x)
    else
      f xs
  go 0 #[]

inductive InjectionAnyResult where
  | solved
  | failed
  /-- `fvarId` refers to the local declaration selected for the application of the `injection` tactic. -/
  | subgoal (fvarId : FVarId) (mvarId : MVarId)

private def injectionAnyCandidate? (type : Expr) : MetaM (Option (Expr × Expr)) := do
  if let some (_, lhs, rhs) ← matchEq? type then
    return some (lhs, rhs)
  else if let some (α, lhs, β, rhs) ← matchHEq? type then
    if (← isDefEq α β) then
      return some (lhs, rhs)
  return none

/--
Try applying `injection` to a local declaration that is not in `forbidden`.

We use `forbidden` because the `injection` tactic might fail to clear the variable if there are forward dependencies.
See `proveSubgoalLoop` for additional details.
-/
private def injectionAny (mvarId : MVarId) (forbidden : FVarIdSet := {}) : MetaM InjectionAnyResult := do
  mvarId.withContext do
    for localDecl in (← getLCtx) do
      unless forbidden.contains localDecl.fvarId do
        if let some (lhs, rhs) ← injectionAnyCandidate? localDecl.type then
          unless (← isDefEq lhs rhs) do
            let lhs ← whnf lhs
            let rhs ← whnf rhs
            unless lhs.isRawNatLit && rhs.isRawNatLit do
              try
                match (← injection mvarId localDecl.fvarId) with
                | InjectionResult.solved  => return InjectionAnyResult.solved
                | InjectionResult.subgoal mvarId .. => return InjectionAnyResult.subgoal localDecl.fvarId mvarId
              catch ex =>
                trace[Meta.Match.matchEqs] "injectionAnyFailed at {localDecl.userName}, error\n{ex.toMessageData}"
                pure ()
    return InjectionAnyResult.failed


private abbrev ConvertM := ReaderT (FVarIdMap (Expr × Nat × Array Bool)) $ StateRefT (Array MVarId) MetaM

/--
  Construct a proof for the splitter generated by `mkEquationsFor`.
  The proof uses the definition of the `match`-declaration as a template (argument `template`).
  - `alts` are free variables corresponding to alternatives of the `match` auxiliary declaration being processed.
  - `altNews` are the new free variables which contains additional hypotheses that ensure they are only used
     when the previous overlapping alternatives are not applicable. -/
private partial def mkSplitterProof (matchDeclName : Name) (template : Expr) (alts altsNew : Array Expr)
    (altsNewNumParams : Array Nat)
    (altArgMasks : Array (Array Bool)) : MetaM Expr := do
  trace[Meta.Match.matchEqs] "proof template: {template}"
  let map := mkMap
  let (proof, mvarIds) ← convertTemplate template |>.run map |>.run #[]
  trace[Meta.Match.matchEqs] "splitter proof: {proof}"
  for mvarId in mvarIds do
    proveSubgoal mvarId
  instantiateMVars proof
where
  mkMap : FVarIdMap (Expr × Nat × Array Bool) := Id.run do
    let mut m := {}
    for alt in alts, altNew in altsNew, numParams in altsNewNumParams, argMask in altArgMasks do
      m := m.insert alt.fvarId! (altNew, numParams, argMask)
    return m

  trimFalseTrail (argMask : Array Bool) : Array Bool :=
    if argMask.isEmpty then
      argMask
    else if !argMask.back! then
      trimFalseTrail argMask.pop
    else
      argMask

  /--
    Auxiliary function used at `convertTemplate` to decide whether to use `convertCastEqRec`.
    See `convertCastEqRec`.  -/
  isCastEqRec (e : Expr) : ConvertM Bool := do
    -- TODO: we do not handle `Eq.rec` since we never found an example that needed it.
    -- If we find one we must extend `convertCastEqRec`.
    unless e.isAppOf ``Eq.ndrec do return false
    unless e.getAppNumArgs > 6 do return false
    for arg in e.getAppArgs[6...*] do
      if arg.isFVar && (← read).contains arg.fvarId! then
        return true
    return true

  /--
    Auxiliary function used at `convertTemplate`. It is needed when the auxiliary `match` declaration had to refine the type of its
    minor premises during dependent pattern match. For an example, consider
    ```
    inductive Foo : Nat → Type _
    | nil             : Foo 0
    | cons  (t: Foo l): Foo l

    def Foo.bar (t₁: Foo l₁): Foo l₂ → Bool
    | cons s₁ => t₁.bar s₁
    | _ => false
    attribute [simp] Foo.bar
    ```
    The auxiliary `Foo.bar.match_1` is of the form
    ```
    def Foo.bar.match_1.{u_1} : {l₂ : Nat} →
      (t₂ : Foo l₂) →
        (motive : Foo l₂ → Sort u_1) →
          (t₂ : Foo l₂) → ((s₁ : Foo l₂) → motive (Foo.cons s₁)) → ((x : Foo l₂) → motive x) → motive t₂ :=
    fun {l₂} t₂ motive t₂_1 h_1 h_2 =>
      (fun t₂_2 =>
          Foo.casesOn (motive := fun a x => l₂ = a → t₂_1 ≍ x → motive t₂_1) t₂_2
            (fun h =>
              Eq.ndrec (motive := fun {l₂} =>
                (t₂ t₂ : Foo l₂) →
                  (motive : Foo l₂ → Sort u_1) →
                    ((s₁ : Foo l₂) → motive (Foo.cons s₁)) → ((x : Foo l₂) → motive x) → t₂ ≍ Foo.nil → motive t₂)
                (fun t₂ t₂ motive h_1 h_2 h => Eq.symm (eq_of_heq h) ▸ h_2 Foo.nil) (Eq.symm h) t₂ t₂_1 motive h_1 h_2) --- HERE
            fun {l} t h =>
            Eq.ndrec (motive := fun {l} => (t : Foo l) → t₂_1 ≍ Foo.cons t → motive t₂_1)
              (fun t h => Eq.symm (eq_of_heq h) ▸ h_1 t) h t)
        t₂_1 (Eq.refl l₂) (HEq.refl t₂_1)
    ```
    The `HERE` comment marks the place where the type of `Foo.bar.match_1` minor premises `h_1` and `h_2` is being "refined"
    using `Eq.ndrec`.

    This function will adjust the motive and minor premise of the `Eq.ndrec` to reflect the new minor premises used in the
    corresponding splitter theorem.

    We may have to extend this function to handle `Eq.rec` too.

    This function was added to address issue #1179
  -/
  convertCastEqRec (e : Expr) : ConvertM Expr := do
    assert! (← isCastEqRec e)
    e.withApp fun f args => do
      let mut argsNew := args
      let mut isAlt := #[]
      for i in 6...args.size do
        let arg := argsNew[i]!
        if arg.isFVar then
          match (← read).get? arg.fvarId! with
          | some (altNew, _, _) =>
            argsNew := argsNew.set! i altNew
            trace[Meta.Match.matchEqs] "arg: {arg} : {← inferType arg}, altNew: {altNew} : {← inferType altNew}"
            isAlt := isAlt.push true
          | none =>
            argsNew := argsNew.set! i (← convertTemplate arg)
            isAlt := isAlt.push false
        else
          argsNew := argsNew.set! i (← convertTemplate arg)
          isAlt := isAlt.push false
      assert! isAlt.size == args.size - 6
      let rhs := args[4]!
      let motive := args[2]!
      -- Construct new motive using the splitter theorem minor premise types.
      let motiveNew ← lambdaTelescope motive fun motiveArgs body => do
        unless motiveArgs.size == 1 do
          throwError "unexpected `Eq.ndrec` motive while creating splitter/eliminator theorem for `{matchDeclName}`, expected lambda with 1 binder{indentExpr motive}"
        let x := motiveArgs[0]!
        forallTelescopeReducing body fun motiveTypeArgs resultType => do
          unless motiveTypeArgs.size >= isAlt.size do
            throwError "unexpected `Eq.ndrec` motive while creating splitter/eliminator theorem for `{matchDeclName}`, expected arrow with at least #{isAlt.size} binders{indentExpr body}"
          let rec go (i : Nat) (motiveTypeArgsNew : Array Expr) : ConvertM Expr := do
            assert! motiveTypeArgsNew.size == i
            if h : i < motiveTypeArgs.size then
              let motiveTypeArg := motiveTypeArgs[i]
              if i < isAlt.size && isAlt[i]! then
                let altNew := argsNew[6+i]! -- Recall that `Eq.ndrec` has 6 arguments
                let altTypeNew ← inferType altNew
                trace[Meta.Match.matchEqs] "altNew: {altNew} : {altTypeNew}"
                -- Replace `rhs` with `x` (the lambda binder in the motive)
                let mut altTypeNewAbst := (← kabstract altTypeNew rhs).instantiate1 x
                -- Replace args[6...(6+i)] with `motiveTypeArgsNew`
                for j in *...i do
                  altTypeNewAbst := (← kabstract altTypeNewAbst argsNew[6+j]!).instantiate1 motiveTypeArgsNew[j]!
                let localDecl ← motiveTypeArg.fvarId!.getDecl
                withLocalDecl localDecl.userName localDecl.binderInfo altTypeNewAbst fun motiveTypeArgNew =>
                  go (i+1) (motiveTypeArgsNew.push motiveTypeArgNew)
              else
                go (i+1) (motiveTypeArgsNew.push motiveTypeArg)
            else
              mkLambdaFVars motiveArgs (← mkForallFVars motiveTypeArgsNew resultType)
          go 0 #[]
      trace[Meta.Match.matchEqs] "new motive: {motiveNew}"
      unless (← isTypeCorrect motiveNew) do
        throwError "failed to construct new type correct motive for `Eq.ndrec` while creating splitter/eliminator theorem for `{matchDeclName}`{indentExpr motiveNew}"
      argsNew := argsNew.set! 2 motiveNew
      -- Construct the new minor premise for the `Eq.ndrec` application.
      -- First, we use `eqRecNewPrefix` to infer the new minor premise binders for `Eq.ndrec`
      let eqRecNewPrefix := mkAppN f argsNew[*...3] -- `Eq.ndrec` minor premise is the fourth argument.
      let .forallE _ minorTypeNew .. ← whnf (← inferType eqRecNewPrefix) | unreachable!
      trace[Meta.Match.matchEqs] "new minor type: {minorTypeNew}"
      let minor := args[3]!
      let minorNew ← forallBoundedTelescope minorTypeNew isAlt.size fun minorArgsNew _ => do
        let mut minorBodyNew := minor
        -- We have to extend the mapping to make sure `convertTemplate` can "fix" occurrences of the refined minor premises
        let mut m ← read
        for h : i in *...isAlt.size do
          if isAlt[i] then
            -- `convertTemplate` will correct occurrences of the alternative
            let alt := args[6+i]! -- Recall that `Eq.ndrec` has 6 arguments
            let some (_, numParams, argMask) := m.get? alt.fvarId! | unreachable!
            -- We add a new entry to `m` to make sure `convertTemplate` will correct the occurrences of the alternative
            m := m.insert minorArgsNew[i]!.fvarId! (minorArgsNew[i]!, numParams, argMask)
          unless minorBodyNew.isLambda do
            throwError "unexpected `Eq.ndrec` minor premise while creating splitter/eliminator theorem for `{matchDeclName}`, expected lambda with at least #{isAlt.size} binders{indentExpr minor}"
          minorBodyNew := minorBodyNew.bindingBody!
        minorBodyNew := minorBodyNew.instantiateRev minorArgsNew
        trace[Meta.Match.matchEqs] "minor premise new body before convertTemplate:{indentExpr minorBodyNew}"
        minorBodyNew ← withReader (fun _ => m) <| convertTemplate minorBodyNew
        trace[Meta.Match.matchEqs] "minor premise new body after convertTemplate:{indentExpr minorBodyNew}"
        mkLambdaFVars minorArgsNew minorBodyNew
      unless (← isTypeCorrect minorNew) do
        throwError "failed to construct new type correct minor premise for `Eq.ndrec` while creating splitter/eliminator theorem for `{matchDeclName}`{indentExpr minorNew}"
      argsNew := argsNew.set! 3 minorNew
      -- trace[Meta.Match.matchEqs] "argsNew: {argsNew}"
      trace[Meta.Match.matchEqs] "found cast target {e}"
      return mkAppN f argsNew

  convertTemplate (e : Expr) : ConvertM Expr :=
    transform e fun e => do
      if (← isCastEqRec e) then
        return .done (← convertCastEqRec e)
      else
        let Expr.fvar fvarId .. := e.getAppFn | return .continue
        let some (altNew, numParams, argMask) := (← read).get? fvarId | return .continue
        trace[Meta.Match.matchEqs] ">> argMask: {argMask}, e: {e}, {altNew}"
        let mut newArgs := #[]
        let argMask := trimFalseTrail argMask
        unless e.getAppNumArgs ≥ argMask.size do
          throwError "unexpected occurrence of `match`-expression alternative (aka minor premise) while creating splitter/eliminator theorem for `{matchDeclName}`, minor premise is partially applied{indentExpr e}\npossible solution if you are matching on inductive families: add its indices as additional discriminants"
        for arg in e.getAppArgs, includeArg in argMask do
          if includeArg then
            newArgs := newArgs.push arg
        let eNew := mkAppN altNew newArgs
        /- Recall that `numParams` does not include the equalities associated with discriminants of the form `h : discr`. -/
        let (mvars, _, _) ← forallMetaBoundedTelescope (← inferType eNew) (numParams - newArgs.size) (kind := MetavarKind.syntheticOpaque)
        modify fun s => s ++ (mvars.map (·.mvarId!))
        let eNew := mkAppN eNew mvars
        return TransformStep.done eNew

  /-
  `forbidden` tracks variables that we have already applied `injection`.
  Recall that the `injection` tactic may not be able to eliminate them when
  they have forward dependencies.
  -/
  proveSubgoalLoop (mvarId : MVarId) (forbidden : FVarIdSet) : MetaM Unit := do
    trace[Meta.Match.matchEqs] "proveSubgoalLoop\n{mvarId}"
    if (← mvarId.contradictionQuick) then
      return ()
    match (← injectionAny mvarId forbidden) with
    | .solved => return ()
    | .failed =>
      let mvarId' ← substVars mvarId
      if mvarId' == mvarId then
        if (← mvarId.contradictionCore {}) then
          return ()
        throwError "failed to generate splitter for match auxiliary declaration '{matchDeclName}', unsolved subgoal:\n{MessageData.ofGoal mvarId}"
      else
        proveSubgoalLoop mvarId' forbidden
    | .subgoal fvarId mvarId => proveSubgoalLoop mvarId (forbidden.insert fvarId)

  proveSubgoal (mvarId : MVarId) : MetaM Unit := do
    trace[Meta.Match.matchEqs] "subgoal {mkMVar mvarId}, {repr (← mvarId.getDecl).kind}, {← mvarId.isAssigned}\n{MessageData.ofGoal mvarId}"
    let (_, mvarId) ← mvarId.intros
    let mvarId ← mvarId.tryClearMany (alts.map (·.fvarId!))
    proveSubgoalLoop mvarId {}

/--
  Create new alternatives (aka minor premises) by replacing `discrs` with `patterns` at `alts`.
  Recall that `alts` depends on `discrs` when `numDiscrEqs > 0`, where `numDiscrEqs` is the number of discriminants
  annotated with `h : discr`.
-/
private partial def withNewAlts (numDiscrEqs : Nat) (discrs : Array Expr) (patterns : Array Expr) (alts : Array Expr) (k : Array Expr → MetaM α) : MetaM α :=
  if numDiscrEqs == 0 then
    k alts
  else
    go 0 #[]
where
  go (i : Nat) (altsNew : Array Expr) : MetaM α := do
   if h : i < alts.size then
     let altLocalDecl ← getFVarLocalDecl alts[i]
     let typeNew := altLocalDecl.type.replaceFVars discrs patterns
     withLocalDecl altLocalDecl.userName altLocalDecl.binderInfo typeNew fun altNew =>
       go (i+1) (altsNew.push altNew)
   else
     k altsNew

/-
Creates conditional equations and splitter for the given match auxiliary declaration.

See also `getEquationsFor`.
-/
@[export lean_get_match_equations_for]
def getEquationsForImpl (matchDeclName : Name) : MetaM MatchEqns := do
  /-
  Remark: users have requested the `split` tactic to be available for writing code.
  Thus, the `splitter` declaration must be a definition instead of a theorem.
  Moreover, the `splitter` is generated on demand, and we currently
  can't import the same definition from different modules. Thus, we must
  keep `splitter` as a private declaration to prevent import failures.
  -/
  let baseName := mkPrivateName (← getEnv) matchDeclName
  let splitterName := baseName ++ `splitter
  -- NOTE: `go` will generate both splitter and equations but we use the splitter as the "key" for
  -- `realizeConst` as well as for looking up the resultant environment extension state via
  -- `findStateAsync`.
  realizeConst matchDeclName splitterName (go baseName splitterName)
  return matchEqnsExt.findStateAsync (← getEnv) splitterName |>.map.find! matchDeclName
where go baseName splitterName := withConfig (fun c => { c with etaStruct := .none }) do
  let constInfo ← getConstInfo matchDeclName
  let us := constInfo.levelParams.map mkLevelParam
  let some matchInfo ← getMatcherInfo? matchDeclName | throwError "'{matchDeclName}' is not a matcher function"
  let numDiscrEqs := getNumEqsFromDiscrInfos matchInfo.discrInfos
  forallTelescopeReducing constInfo.type fun xs matchResultType => do
    let mut eqnNames := #[]
    let params := xs[*...matchInfo.numParams]
    let motive := xs[matchInfo.getMotivePos]!
    let alts   := xs[(xs.size - matchInfo.numAlts)...*]
    let firstDiscrIdx := matchInfo.numParams + 1
    let discrs := xs[firstDiscrIdx...(firstDiscrIdx + matchInfo.numDiscrs)]
    let mut notAlts := #[]
    let mut idx := 1
    let mut splitterAltTypes := #[]
    let mut splitterAltNumParams := #[]
    let mut altArgMasks := #[] -- masks produced by `forallAltTelescope`
    for i in *...alts.size do
      let altNumParams := matchInfo.altNumParams[i]!
      let thmName := Name.str baseName eqnThmSuffixBase |>.appendIndexAfter idx
      eqnNames := eqnNames.push thmName
      let (notAlt, splitterAltType, splitterAltNumParam, argMask) ←
          forallAltTelescope (← inferType alts[i]!) altNumParams numDiscrEqs
          fun ys eqs rhsArgs argMask altResultType => do
        let patterns := altResultType.getAppArgs
        let mut hs := #[]
        for notAlt in notAlts do
          let h ← instantiateForall notAlt patterns
          if let some h ← simpH? h patterns.size then
            hs := hs.push h
        trace[Meta.Match.matchEqs] "hs: {hs}"
        let splitterAltType ← mkForallFVars ys (← hs.foldrM (init := (← mkForallFVars eqs altResultType)) (mkArrow · ·))
        let splitterAltType ← unfoldNamedPattern splitterAltType
        let splitterAltNumParam := hs.size + ys.size
        -- Create a proposition for representing terms that do not match `patterns`
        let mut notAlt := mkConst ``False
        for discr in discrs.toArray.reverse, pattern in patterns.reverse do
          notAlt ← mkArrow (← mkEqHEq discr pattern) notAlt
        notAlt ← mkForallFVars (discrs ++ ys) notAlt
        /- Recall that when we use the `h : discr`, the alternative type depends on the discriminant.
           Thus, we need to create new `alts`. -/
        withNewAlts numDiscrEqs discrs patterns alts fun alts => do
          let alt := alts[i]!
          let lhs := mkAppN (mkConst constInfo.name us) (params ++ #[motive] ++ patterns ++ alts)
          let rhs := mkAppN alt rhsArgs
          let thmType ← mkEq lhs rhs
          let thmType ← hs.foldrM (init := thmType) (mkArrow · ·)
          let thmType ← mkForallFVars (params ++ #[motive] ++ ys ++ alts) thmType
          let thmType ← unfoldNamedPattern thmType
          let thmVal ← proveCondEqThm matchDeclName thmType
          addDecl <| Declaration.thmDecl {
            name        := thmName
            levelParams := constInfo.levelParams
            type        := thmType
            value       := thmVal
          }
          return (notAlt, splitterAltType, splitterAltNumParam, argMask)
      notAlts := notAlts.push notAlt
      splitterAltTypes := splitterAltTypes.push splitterAltType
      splitterAltNumParams := splitterAltNumParams.push splitterAltNumParam
      altArgMasks := altArgMasks.push argMask
      trace[Meta.Match.matchEqs] "splitterAltType: {splitterAltType}"
      idx := idx + 1
    -- Define splitter with conditional/refined alternatives
    withSplitterAlts splitterAltTypes fun altsNew => do
      let splitterParams := params.toArray ++ #[motive] ++ discrs.toArray ++ altsNew
      let splitterType ← mkForallFVars splitterParams matchResultType
      trace[Meta.Match.matchEqs] "splitterType: {splitterType}"
      let template := mkAppN (mkConst constInfo.name us) (params ++ #[motive] ++ discrs ++ alts)
      let template ← deltaExpand template (· == constInfo.name)
      let template := template.headBeta
      let splitterVal ← mkLambdaFVars splitterParams (← mkSplitterProof matchDeclName template alts altsNew splitterAltNumParams altArgMasks)
      addAndCompile <| Declaration.defnDecl {
        name        := splitterName
        levelParams := constInfo.levelParams
        type        := splitterType
        value       := splitterVal
        hints       := .abbrev
        safety      := .safe
      }
      setInlineAttribute splitterName
      let result := { eqnNames, splitterName, splitterAltNumParams }
      registerMatchEqns matchDeclName result

def congrEqnThmSuffixBase := "congr_eq"
def congrEqnThmSuffixBasePrefix := congrEqnThmSuffixBase ++ "_"
def congrEqn1ThmSuffix := congrEqnThmSuffixBasePrefix ++ "1"
example : congrEqn1ThmSuffix = "congr_eq_1" := rfl

/-- Returns `true` if `s` is of the form `congr_eq_<idx>` -/
def isCongrEqnReservedNameSuffix (s : String) : Bool :=
  congrEqnThmSuffixBasePrefix.isPrefixOf s && (s.drop congrEqnThmSuffixBasePrefix.length).isNat

/- We generate the equations and splitter on demand, and do not save them on .olean files. -/
builtin_initialize matchCongrEqnsExt : EnvExtension (PHashMap Name (Array Name)) ←
  -- Using `local` allows us to use the extension in `realizeConst` without specifying `replay?`.
  -- The resulting state can still be accessed on the generated declarations using `findStateAsync`;
  -- see below
  registerEnvExtension (pure {}) (asyncMode := .local)

def registerMatchCongrEqns (matchDeclName : Name) (eqnNames : Array Name) : CoreM Unit := do
  modifyEnv fun env => matchCongrEqnsExt.modifyState env fun map =>
    map.insert matchDeclName eqnNames

/--
Generate the congruence equations for the given match auxiliary declaration.
The congruence equations have a completely unrestricted left-hand side (arbitrary discriminants),
and take propositional equations relating the discriminants to the patterns as arguments. In this
sense they combine a congruence lemma with the regular equation lemma.
Since the motive depends on the discriminants, they are `HEq` equations.

The code duplicates a fair bit of the logic above, and has to repeat the calculation of the
`notAlts`. One could avoid that and generate the generalized equations eagerly above, but they are
not always needed, so for now we live with the code duplication.
-/
def genMatchCongrEqns (matchDeclName : Name) : MetaM (Array Name) := do
  let baseName := mkPrivateName (← getEnv) matchDeclName
  let firstEqnName := .str baseName congrEqn1ThmSuffix
  realizeConst matchDeclName firstEqnName (go baseName)
  return matchCongrEqnsExt.findStateAsync (← getEnv) firstEqnName |>.find! matchDeclName
where go baseName := withConfig (fun c => { c with etaStruct := .none }) do
  withConfig (fun c => { c with etaStruct := .none }) do
  let constInfo ← getConstInfo matchDeclName
  let us := constInfo.levelParams.map mkLevelParam
  let some matchInfo ← getMatcherInfo? matchDeclName | throwError "'{matchDeclName}' is not a matcher function"
  let numDiscrEqs := matchInfo.getNumDiscrEqs
  forallTelescopeReducing constInfo.type fun xs _matchResultType => do
    let mut eqnNames := #[]
    let params := xs[*...matchInfo.numParams]
    let motive := xs[matchInfo.getMotivePos]!
    let alts   := xs[(xs.size - matchInfo.numAlts)...*]
    let firstDiscrIdx := matchInfo.numParams + 1
    let discrs := xs[firstDiscrIdx...(firstDiscrIdx + matchInfo.numDiscrs)]
    let mut notAlts := #[]
    let mut idx := 1
    for i in *...alts.size do
      let altNumParams := matchInfo.altNumParams[i]!
      let thmName := (Name.str baseName congrEqnThmSuffixBase).appendIndexAfter idx
      eqnNames := eqnNames.push thmName
      let notAlt ← do
        let alt := alts[i]!
        Match.forallAltVarsTelescope (← inferType alt) altNumParams numDiscrEqs fun altVars args _mask altResultType => do
        let patterns ← forallTelescope altResultType fun _ t => pure t.getAppArgs
        let mut heqsTypes := #[]
        assert! patterns.size == discrs.size
        for discr in discrs, pattern in patterns do
          let heqType ← mkEqHEq discr pattern
          heqsTypes := heqsTypes.push ((`heq).appendIndexAfter (heqsTypes.size + 1), heqType)
        withLocalDeclsDND heqsTypes fun heqs => do
          let rhs ← Match.mkAppDiscrEqs (mkAppN alt args) heqs numDiscrEqs
          let mut hs := #[]
          for notAlt in notAlts do
            let h ← instantiateForall notAlt patterns
            if let some h ← Match.simpH? h patterns.size then
              hs := hs.push h
          trace[Meta.Match.matchEqs] "hs: {hs}"
          let mut notAlt := mkConst ``False
          for discr in discrs.toArray.reverse, pattern in patterns.reverse do
            notAlt ← mkArrow (← mkEqHEq discr pattern) notAlt
          notAlt ← mkForallFVars (discrs ++ altVars) notAlt
          let lhs := mkAppN (mkConst constInfo.name us) (params ++ #[motive] ++ discrs ++ alts)
          let thmType ← mkHEq lhs rhs
          let thmType ← hs.foldrM (init := thmType) (mkArrow · ·)
          let thmType ← mkForallFVars (params ++ #[motive] ++ discrs ++ alts ++ altVars ++ heqs) thmType
          let thmType ← Match.unfoldNamedPattern thmType
          -- Here we prove the theorem from scratch. One could likely also use the (non-generalized)
          -- match equation theorem after subst'ing the `heqs`.
          let thmVal ← Match.proveCondEqThm matchDeclName thmType
            (heqPos := params.size + 1 + discrs.size + alts.size + altVars.size) (heqNum := heqs.size)
          unless (← getEnv).contains thmName do
            addDecl <| Declaration.thmDecl {
              name        := thmName
              levelParams := constInfo.levelParams
              type        := thmType
              value       := thmVal
            }
          return notAlt
      notAlts := notAlts.push notAlt
      idx := idx + 1
    registerMatchCongrEqns matchDeclName eqnNames

builtin_initialize registerTraceClass `Meta.Match.matchEqs

private def isMatchEqName? (env : Environment) (n : Name) : Option (Name × Bool) := do
  let .str p s := n | failure
  guard <| isEqnReservedNameSuffix s || s == "splitter" || isCongrEqnReservedNameSuffix s
  let p ← privateToUserName? p
  guard <| isMatcherCore env p
  return (p, isCongrEqnReservedNameSuffix s)

builtin_initialize registerReservedNamePredicate (isMatchEqName? · · |>.isSome)

builtin_initialize registerReservedNameAction fun name => do
  let some (p, isGenEq) := isMatchEqName? (← getEnv) name |
    return false
  if isGenEq then
    let _ ← MetaM.run' <| genMatchCongrEqns p
  else
    let _ ← MetaM.run' <| getEquationsFor p
  return true

end Lean.Meta.Match
