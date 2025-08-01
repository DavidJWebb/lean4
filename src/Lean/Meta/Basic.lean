/-
Copyright (c) 2019 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura
-/
module

prelude
public import Lean.Data.LOption
public import Lean.Environment
public import Lean.Class
public import Lean.ReducibilityAttrs
public import Lean.Util.ReplaceExpr
public import Lean.Util.MonadBacktrack
public import Lean.Compiler.InlineAttrs
public import Lean.Meta.TransparencyMode

public section

/-!
This module provides four (mutually dependent) goodies that are needed for building the elaborator and tactic frameworks.
1- Weak head normal form computation with support for metavariables and transparency modes.
2- Definitionally equality checking with support for metavariables (aka unification modulo definitional equality).
3- Type inference.
4- Type class resolution.

They are packed into the `MetaM` monad.
-/

namespace Lean.Meta

builtin_initialize isDefEqStuckExceptionId : InternalExceptionId ← registerInternalExceptionId `isDefEqStuck

def TransparencyMode.toUInt64 : TransparencyMode → UInt64
  | .all       => 0
  | .default   => 1
  | .reducible => 2
  | .instances => 3

def EtaStructMode.toUInt64 : EtaStructMode → UInt64
  | .all        => 0
  | .notClasses => 1
  | .none       => 2

/--
Configuration for projection reduction. See `whnfCore`.
-/
inductive ProjReductionKind where
  /-- Projections `s.i` are not reduced at `whnfCore`. -/
  | no
  /--
  Projections `s.i` are reduced at `whnfCore`, and `whnfCore` is used at `s` during the process.
  Recall that `whnfCore` does not perform `delta` reduction (i.e., it will not unfold constant declarations).
  -/
  | yes
  /--
  Projections `s.i` are reduced at `whnfCore`, and `whnf` is used at `s` during the process.
  Recall that `whnfCore` does not perform `delta` reduction (i.e., it will not unfold constant declarations), but `whnf` does.
  -/
  | yesWithDelta
  /--
  Projections `s.i` are reduced at `whnfCore`, and `whnfAtMostI` is used at `s` during the process.
  Recall that `whnfAtMostI` is like `whnf` but uses transparency at most `instances`.
  This option is stronger than `yes`, but weaker than `yesWithDelta`.
  We use this option to ensure we reduce projections to prevent expensive defeq checks when unifying TC operations.
  When unifying e.g. `(@Field.toNeg α inst1).1 =?= (@Field.toNeg α inst2).1`,
  we only want to unify negation (and not all other field operations as well).
  Unifying the field instances slowed down unification: https://github.com/leanprover/lean4/issues/1986
  -/
  | yesWithDeltaI
  deriving DecidableEq, Inhabited, Repr

def ProjReductionKind.toUInt64 : ProjReductionKind → UInt64
  | .no  => 0
  | .yes => 1
  | .yesWithDelta => 2
  | .yesWithDeltaI => 3

/--
Configuration flags for the `MetaM` monad.
Many of them are used to control the `isDefEq` function that checks whether two terms are definitionally equal or not.
Recall that when `isDefEq` is trying to check whether
`?m@C a₁ ... aₙ` and `t` are definitionally equal (`?m@C a₁ ... aₙ =?= t`), where
`?m@C` as a shorthand for `C |- ?m : t` where `t` is the type of `?m`.
We solve it using the assignment `?m := fun a₁ ... aₙ => t` if
1) `a₁ ... aₙ` are pairwise distinct free variables that are ​*not*​ let-variables.
2) `a₁ ... aₙ` are not in `C`
3) `t` only contains free variables in `C` and/or `{a₁, ..., aₙ}`
4) For every metavariable `?m'@C'` occurring in `t`, `C'` is a subprefix of `C`
5) `?m` does not occur in `t`
-/
structure Config where
  /--
    If `foApprox` is set to true, and some `aᵢ` is not a free variable,
    then we use first-order unification
    ```
      ?m a_1 ... a_i a_{i+1} ... a_{i+k} =?= f b_1 ... b_k
    ```
    reduces to
    ```
      ?m a_1 ... a_i =?= f
      a_{i+1}        =?= b_1
      ...
      a_{i+k}        =?= b_k
    ```
  -/
  foApprox           : Bool := false
  /--
    When `ctxApprox` is set to true, we relax condition 4, by creating an
    auxiliary metavariable `?n'` with a smaller context than `?m'`.
  -/
  ctxApprox          : Bool := false
  /--
    When `quasiPatternApprox` is set to true, we ignore condition 2.
  -/
  quasiPatternApprox : Bool := false
  /-- When `constApprox` is set to true,
     we solve `?m t =?= c` using
     `?m := fun _ => c`
     when `?m t` is not a higher-order pattern and `c` is not an application as -/
  constApprox        : Bool := false
  /--
    When the following flag is set,
    `isDefEq` throws the exception `Exception.isDefEqStuck`
    whenever it encounters a constraint `?m ... =?= t` where
    `?m` is read only.
    This feature is useful for type class resolution where
    we may want to notify the caller that the TC problem may be solvable
    later after it assigns `?m`. -/
  isDefEqStuckEx     : Bool := false
  /-- Enable/disable the unification hints feature. -/
  unificationHints   : Bool := true
  /-- Enables proof irrelevance at `isDefEq` -/
  proofIrrelevance   : Bool := true
  /-- By default synthetic opaque metavariables are not assigned by `isDefEq`. Motivation: we want to make
      sure typing constraints resolved during elaboration should not "fill" holes that are supposed to be filled using tactics.
      However, this restriction is too restrictive for tactics such as `exact t`. When elaborating `t`, we dot not fill
      named holes when solving typing constraints or TC resolution. But, we ignore the restriction when we try to unify
      the type of `t` with the goal target type. We claim this is not a hack and is defensible behavior because
      this last unification step is not really part of the term elaboration. -/
  assignSyntheticOpaque : Bool := false
  /-- Enable/Disable support for offset constraints such as `?x + 1 =?= e` -/
  offsetCnstrs          : Bool := true
  /--
    Controls which definitions and theorems can be unfolded by `isDefEq` and `whnf`.
   -/
  transparency       : TransparencyMode := TransparencyMode.default
  /-- Eta for structures configuration mode. -/
  etaStruct          : EtaStructMode := .all
  /--
  When `univApprox` is set to true,
  we use approximations when solving postponed universe constraints.
  Examples:
  - `max u ?v =?= u` is solved with `?v := u` and ignoring the solution `?v := 0`.
  - `max u w =?= max u ?v` is solved with `?v := w` ignoring the solution `?v := max u w`
  -/
  univApprox : Bool := true
  /-- If `true`, reduce recursor/matcher applications, e.g., `Nat.rec true (fun _ _ => false) Nat.zero` reduces to `true` -/
  iota : Bool := true
  /-- If `true`, reduce terms such as `(fun x => t[x]) a` into `t[a]` -/
  beta : Bool := true
  /-- Control projection reduction at `whnfCore`. -/
  proj : ProjReductionKind := .yesWithDelta
  /--
  Zeta reduction: `let x := v; e[x]` and `have x := v; e[x]` reduce to `e[v]`.
  We say a let-declaration `let x := v; e` is nondependent if it is equivalent to `(fun x => e) v`.
  Recall that
  ```
  fun x : BitVec 5 => let n := 5; fun y : BitVec n => x = y
  ```
  is type correct, but
  ```
  fun x : BitVec 5 => (fun n => fun y : BitVec n => x = y) 5
  ```
  is not.
  See also `zetaHave`, for disabling the reduction nondependent lets (`have` expressions).
  -/
  zeta : Bool := true
  /--
  Zeta-delta reduction: given a local context containing entry `x : t := e`, free variable `x` reduces to `e`.
  -/
  zetaDelta : Bool := true
  /--
  Zeta reduction for unused let-declarations: `let x := v; e` reduces to `e` when `x` does not occur
  in `e`.
  This option takes precedence over `zeta` and `zetaHave`.
  -/
  zetaUnused : Bool := true
  /--
  When `zeta := true`, then `zetaHave := false` disables zeta reduction of `have` expressions.
  -/
  zetaHave : Bool := true
  deriving Inhabited, Repr

/-- Convert `isDefEq` and `WHNF` relevant parts into a key for caching results -/
private def Config.toKey (c : Config) : UInt64 :=
  c.transparency.toUInt64 |||
  (c.foApprox.toUInt64 <<< 2) |||
  (c.ctxApprox.toUInt64 <<< 3) |||
  (c.quasiPatternApprox.toUInt64 <<< 4) |||
  (c.constApprox.toUInt64 <<< 5) |||
  (c.isDefEqStuckEx.toUInt64 <<< 6) |||
  (c.unificationHints.toUInt64 <<< 7) |||
  (c.proofIrrelevance.toUInt64 <<< 8) |||
  (c.assignSyntheticOpaque.toUInt64 <<< 9) |||
  (c.offsetCnstrs.toUInt64 <<< 10) |||
  (c.iota.toUInt64 <<< 11) |||
  (c.beta.toUInt64 <<< 12) |||
  (c.zeta.toUInt64 <<< 13) |||
  (c.zetaDelta.toUInt64 <<< 14) |||
  (c.univApprox.toUInt64 <<< 15) |||
  (c.etaStruct.toUInt64 <<< 16) |||
  (c.proj.toUInt64 <<< 18) |||
  (c.zetaHave.toUInt64 <<< 20)

/-- Configuration with key produced by `Config.toKey`. -/
structure ConfigWithKey where
  private mk ::
  config : Config := {}
  key    : UInt64 := private_decl% config.toKey

instance : Inhabited ConfigWithKey where  -- #9463
  default := private {}

def Config.toConfigWithKey (c : Config) : ConfigWithKey :=
  { config := c }

/--
Function parameter information cache.
-/
structure ParamInfo where
  /-- The binder annotation for the parameter. -/
  binderInfo     : BinderInfo := BinderInfo.default
  /-- `hasFwdDeps` is true if there is another parameter whose type depends on this one. -/
  hasFwdDeps     : Bool       := false
  /-- `backDeps` contains the backwards dependencies. That is, the (0-indexed) position of previous parameters that this one depends on. -/
  backDeps       : Array Nat  := #[]
  /-- `isProp` is true if the parameter type is always a proposition. -/
  isProp         : Bool       := false
  /--
    `isDecInst` is true if the parameter's type is of the form `Decidable ...`.
    This information affects the generation of congruence theorems.
  -/
  isDecInst      : Bool       := false
  /--
    `higherOrderOutParam` is true if this parameter is a higher-order output parameter
    of local instance.
    Example:
    ```
    getElem :
      {cont : Type u_1} → {idx : Type u_2} → {elem : Type u_3} →
      {dom : cont → idx → Prop} → [self : GetElem cont idx elem dom] →
      (xs : cont) → (i : idx) → dom xs i → elem
    ```
    This flag is true for the parameter `dom` because it is output parameter of
    `[self : GetElem cont idx elem dom]`
   -/
  higherOrderOutParam : Bool  := false
  /--
    `dependsOnHigherOrderOutParam` is true if the type of this parameter depends on
    the higher-order output parameter of a previous local instance.
    Example:
    ```
    getElem :
      {cont : Type u_1} → {idx : Type u_2} → {elem : Type u_3} →
      {dom : cont → idx → Prop} → [self : GetElem cont idx elem dom] →
      (xs : cont) → (i : idx) → dom xs i → elem
    ```
    This flag is true for the parameter with type `dom xs i` since `dom` is an output parameter
    of the instance `[self : GetElem cont idx elem dom]`
  -/
  dependsOnHigherOrderOutParam : Bool := false
  deriving Inhabited

def ParamInfo.isImplicit (p : ParamInfo) : Bool :=
  p.binderInfo == BinderInfo.implicit

def ParamInfo.isInstImplicit (p : ParamInfo) : Bool :=
  p.binderInfo == BinderInfo.instImplicit

def ParamInfo.isStrictImplicit (p : ParamInfo) : Bool :=
  p.binderInfo == BinderInfo.strictImplicit

def ParamInfo.isExplicit (p : ParamInfo) : Bool :=
  p.binderInfo == BinderInfo.default

/--
  Function information cache. See `ParamInfo`.
-/
structure FunInfo where
  /-- Parameter information cache. -/
  paramInfo  : Array ParamInfo := #[]
  /--
    `resultDeps` contains the function result type backwards dependencies.
    That is, the (0-indexed) position of parameters that the result type depends on.
  -/
  resultDeps : Array Nat       := #[]

/--
Key for the function information cache.
-/
structure InfoCacheKey where
  private mk ::
  /-- key produced using `Config.toKey`. -/
  configKey : UInt64
  /-- The function being cached information about. It is quite often an `Expr.const`. -/
  expr         : Expr
  /--
    `nargs? = some n` if the cached information was computed assuming the function has arity `n`.
    If `nargs? = none`, then the cache information consumed the arrow type as much as possible
    using the current transparency setting.
  X-/
  nargs?       : Option Nat
  deriving Inhabited, BEq

instance : Hashable InfoCacheKey where
  hash := private fun { configKey, expr, nargs? } => mixHash (hash configKey) <| mixHash (hash expr) (hash nargs?)

-- Remark: we don't need to store `Config.toKey` because typeclass resolution uses a fixed configuration.
structure SynthInstanceCacheKey where
  localInsts        : LocalInstances
  type              : Expr
  /--
  Value of `synthPendingDepth` when instance was synthesized or failed to be synthesized.
  See issue #2522.
  -/
  synthPendingDepth : Nat
  deriving Hashable, BEq

/-- Resulting type for `abstractMVars` -/
structure AbstractMVarsResult where
  paramNames : Array Name
  mvars      : Array Expr
  expr       : Expr
  deriving Inhabited, BEq

def AbstractMVarsResult.numMVars (r : AbstractMVarsResult) : Nat :=
  r.mvars.size

abbrev SynthInstanceCache := PersistentHashMap SynthInstanceCacheKey (Option AbstractMVarsResult)

-- Key for `InferType` and `WHNF` caches
structure ExprConfigCacheKey where
  private mk ::
  expr      : Expr
  configKey : UInt64
  deriving Inhabited

instance : BEq ExprConfigCacheKey where
  beq a b :=
    Expr.equal a.expr b.expr &&
    a.configKey == b.configKey

instance : Hashable ExprConfigCacheKey where
  hash := private fun { expr, configKey } => mixHash (hash expr) (hash configKey)

abbrev InferTypeCache := PersistentHashMap ExprConfigCacheKey Expr
abbrev FunInfoCache   := PersistentHashMap InfoCacheKey FunInfo
abbrev WhnfCache      := PersistentHashMap ExprConfigCacheKey Expr

structure DefEqCacheKey where
  private mk ::
  lhs       : Expr
  rhs       : Expr
  configKey : UInt64
  deriving Inhabited, BEq

instance : Hashable DefEqCacheKey where
  hash := private fun { lhs, rhs, configKey } => mixHash (hash lhs) <| mixHash (hash rhs) (hash configKey)

/--
A mapping `(s, t) ↦ isDefEq s t`.
TODO: consider more efficient representations (e.g., a proper set) and caching policies (e.g., imperfect cache).
We should also investigate the impact on memory consumption.
-/
abbrev DefEqCache := PersistentHashMap DefEqCacheKey Bool

/--
Cache datastructures for type inference, type class resolution, whnf, and definitional equality.
-/
structure Cache where
  inferType      : InferTypeCache := {}
  funInfo        : FunInfoCache := {}
  synthInstance  : SynthInstanceCache := {}
  whnf           : WhnfCache := {}
  defEqTrans     : DefEqCache := {} -- transient cache for terms containing mvars or using nonstandard configuration options, it is frequently reset.
  defEqPerm      : DefEqCache := {} -- permanent cache for terms not containing mvars and using standard configuration options
  deriving Inhabited

/--
 "Context" for a postponed universe constraint.
 `lhs` and `rhs` are the surrounding `isDefEq` call when the postponed constraint was created.
-/
structure DefEqContext where
  lhs            : Expr
  rhs            : Expr
  lctx           : LocalContext
  localInstances : LocalInstances

/--
  Auxiliary structure for representing postponed universe constraints.
  Remark: the fields `ref` and `rootDefEq?` are used for error message generation only.
  Remark: we may consider improving the error message generation in the future.
-/
structure PostponedEntry where
  /-- We save the `ref` at entry creation time. This is used for reporting errors back to the user. -/
  ref  : Syntax
  lhs  : Level
  rhs  : Level
  /-- Context for the surrounding `isDefEq` call when the entry was created. -/
  ctx? : Option DefEqContext
  deriving Inhabited

structure Diagnostics where
  /-- Number of times each declaration has been unfolded -/
  unfoldCounter : PHashMap Name Nat := {}
  /-- Number of times `f a =?= f b` heuristic has been used per function `f`. -/
  heuristicCounter : PHashMap Name Nat := {}
  /-- Number of times a TC instance is used. -/
  instanceCounter : PHashMap Name Nat := {}
  /-- Pending instances that were not synthesized because `maxSynthPendingDepth` has been reached. -/
  synthPendingFailures : PHashMap Expr MessageData := {}
  deriving Inhabited

/--
  `MetaM` monad state.
-/
structure State where
  mctx             : MetavarContext := {}
  cache            : Cache := {}
  /-- When `Context.trackZetaDelta == true`, then any let-decl free variable that is zetaDelta-expanded by `MetaM` is stored in `zetaDeltaFVarIds`. -/
  zetaDeltaFVarIds : FVarIdSet := {}
  /-- Array of postponed universe level constraints -/
  postponed        : PersistentArray PostponedEntry := {}
  diag             : Diagnostics := {}
  deriving Inhabited

/--
  Backtrackable state for the `MetaM` monad.
-/
structure SavedState where
  core        : Core.SavedState
  «meta»      : State
  deriving Nonempty

register_builtin_option maxSynthPendingDepth : Nat := {
  defValue := 1
  descr    := "maximum number of nested `synthPending` invocations. When resolving unification constraints, pending type class problems may need to be synthesized. These type class problems may create new unification constraints that again require solving new type class problems. This option puts a threshold on how many nested problems are created."
}

/--
  Contextual information for the `MetaM` monad.
-/
structure Context where
  keyedConfig : ConfigWithKey := default
  /--
  When `trackZetaDelta = true`, we track all free variables that have been zetaDelta-expanded.
  That is, suppose the local context contains
  the declaration `x : t := v`, and we reduce `x` to `v`, then we insert `x` into `State.zetaDeltaFVarIds`.
  We use `trackZetaDelta` to discover which let-declarations `let x := v; e` can be represented as `have x := v; e`.
  When we find these declarations we set their `nondep` flag with `true`.
  To find these let-declarations in a given term `s`, we
  1- Reset `State.zetaDeltaFVarIds`
  2- Set `trackZetaDelta := true`
  3- Type-check `s`.

  Note that, we do not include this field in the `Config` structure because this field is not
  taken into account while caching results. See also field `zetaDeltaSet`.
  -/
  trackZetaDelta     : Bool := false
  /--
  If `config.zetaDelta := false`, we may select specific local declarations to be unfolded using
  the field `zetaDeltaSet`. Note that, we do not include this field in the `Config` structure
  because this field is not taken into account while caching results.
  Moreover, we reset all caches whenever setting it.
  -/
  zetaDeltaSet : FVarIdSet := {}
  /-- Local context -/
  lctx              : LocalContext         := {}
  /-- Local instances in `lctx`. -/
  localInstances    : LocalInstances       := #[]
  /-- Not `none` when inside of an `isDefEq` test. See `PostponedEntry`. -/
  defEqCtx?         : Option DefEqContext  := none
  /--
    Track the number of nested `synthPending` invocations. Nested invocations can happen
    when the type class resolution invokes `synthPending`.

    Remark: `synthPending` fails if `synthPendingDepth > maxSynthPendingDepth`.
  -/
  synthPendingDepth : Nat                  := 0
  /--
    A predicate to control whether a constant can be unfolded or not at `whnf`.
    Note that we do not cache results at `whnf` when `canUnfold?` is not `none`. -/
  canUnfold?        : Option (Config → ConstantInfo → CoreM Bool) := none
  /--
  When `Config.univApprox := true`, this flag is set to `true` when there is no
  progress processing universe constraints.
  -/
  univApprox        : Bool := false
  /--
  `inTypeClassResolution := true` when `isDefEq` is invoked at `tryResolve` in the type class
   resolution module. We don't use `isDefEqProjDelta` when performing TC resolution due to performance issues.
   This is not a great solution, but a proper solution would require a more sophisticated caching mechanism.
  -/
  inTypeClassResolution : Bool := false
deriving Inhabited

def Context.config (c : Context) : Config := c.keyedConfig.config
def Context.configKey (c : Context) : UInt64 := c.keyedConfig.key

/--
The `MetaM` monad is a core component of Lean's metaprogramming framework, facilitating the
construction and manipulation of expressions (`Lean.Expr`) within Lean.

It builds on top of `CoreM` and additionally provides:
- A `LocalContext` for managing free variables.
- A `MetavarContext` for managing metavariables.
- A `Cache` for caching results of the key `MetaM` operations.

The key operations provided by `MetaM` are:
- `inferType`, which attempts to automatically infer the type of a given expression.
- `whnf`, which reduces an expression to the point where the outermost part is no longer reducible
  but the inside may still contain unreduced expression.
- `isDefEq`, which determines whether two expressions are definitionally equal, possibly assigning
  meta variables in the process.
- `forallTelescope` and `lambdaTelescope`, which make it possible to automatically move into
  (nested) binders while updating the local context.

The following is a small example that demonstrates how to obtain and manipulate the type of a
`Fin` expression:
```
public import Lean

open Lean Meta

def getFinBound (e : Expr) : MetaM (Option Expr) := do
  let type ← whnf (← inferType e)
  let_expr Fin bound := type | return none
  return bound

def a : Fin 100 := 42

run_meta
  match ← getFinBound (.const ``a []) with
  | some limit => IO.println (← ppExpr limit)
  | none => IO.println "no limit found"
```
-/
abbrev MetaM  := ReaderT Context $ StateRefT State CoreM

-- Make the compiler generate specialized `pure`/`bind` so we do not have to optimize through the
-- whole monad stack at every use site. May eventually be covered by `deriving`.
@[always_inline]
instance : Monad MetaM := let i := inferInstanceAs (Monad MetaM); { pure := i.pure, bind := i.bind }

instance : Inhabited (MetaM α) where
  default := fun _ _ => default

instance : MonadLCtx MetaM where
  getLCtx := return (← read).lctx

instance : MonadMCtx MetaM where
  getMCtx    := return (← get).mctx
  modifyMCtx f := modify fun s => { s with mctx := f s.mctx }

instance : MonadEnv MetaM where
  getEnv      := return (← getThe Core.State).env
  modifyEnv f := do modifyThe Core.State fun s => { s with env := f s.env, cache := {} }; modify fun s => { s with cache := {} }

instance : AddMessageContext MetaM where
  addMessageContext := addMessageContextFull

protected def saveState : MetaM SavedState :=
  return { core := (← Core.saveState), «meta» := (← get) }

/-- Restore backtrackable parts of the state. -/
def SavedState.restore (b : SavedState) : MetaM Unit := do
  b.core.restore
  modify fun s => { s with mctx := b.meta.mctx, zetaDeltaFVarIds := b.meta.zetaDeltaFVarIds, postponed := b.meta.postponed }

@[specialize, inherit_doc Core.withRestoreOrSaveFull]
def withRestoreOrSaveFull (reusableResult? : Option (α × SavedState)) (act : MetaM α) :
    MetaM (α × SavedState) := do
  if let some (_, state) := reusableResult? then
    set state.meta
  let reusableResult? := reusableResult?.map (fun (val, state) => (val, state.core))
  let (a, core) ← controlAt CoreM fun runInBase => do
    Core.withRestoreOrSaveFull reusableResult? <| runInBase act
  return (a, { core, «meta» := (← get) })

instance : MonadBacktrack SavedState MetaM where
  saveState      := Meta.saveState
  restoreState s := s.restore

@[inline] def MetaM.run (x : MetaM α) (ctx : Context := {}) (s : State := {}) : CoreM (α × State) :=
  x ctx |>.run s

@[inline] def MetaM.run' (x : MetaM α) (ctx : Context := {}) (s : State := {}) : CoreM α :=
  Prod.fst <$> x.run ctx s

@[inline] def MetaM.toIO (x : MetaM α) (ctxCore : Core.Context) (sCore : Core.State) (ctx : Context := {}) (s : State := {}) : IO (α × Core.State × State) := do
  let ((a, s), sCore) ← (x.run ctx s).toIO ctxCore sCore
  pure (a, sCore, s)

protected def throwIsDefEqStuck : MetaM α :=
  throw <| Exception.internal isDefEqStuckExceptionId

builtin_initialize
  registerTraceClass `Meta
  registerTraceClass `Meta.debug

export Core (instantiateTypeLevelParams instantiateValueLevelParams)

@[inline] def liftMetaM [MonadLiftT MetaM m] (x : MetaM α) : m α :=
  liftM x

@[inline] def mapMetaM [MonadControlT MetaM m] [Monad m] (f : forall {α}, MetaM α → MetaM α) {α} (x : m α) : m α :=
  controlAt MetaM fun runInBase => f <| runInBase x

@[inline] def map1MetaM [MonadControlT MetaM m] [Monad m] (f : forall {α}, (β → MetaM α) → MetaM α) {α} (k : β → m α) : m α :=
  controlAt MetaM fun runInBase => f fun b => runInBase <| k b

@[inline] def map2MetaM [MonadControlT MetaM m] [Monad m] (f : forall {α}, (β → γ → MetaM α) → MetaM α) {α} (k : β → γ → m α) : m α :=
  controlAt MetaM fun runInBase => f fun b c => runInBase <| k b c

@[inline] def map3MetaM [MonadControlT MetaM m] [Monad m] (f : forall {α}, (β → γ → δ → MetaM α) → MetaM α) {α} (k : β → γ → δ → m α) : m α :=
  controlAt MetaM fun runInBase => f fun b c d => runInBase <| k b c d

section Methods
variable [MonadControlT MetaM n] [Monad n]

@[inline] def modifyCache (f : Cache → Cache) : MetaM Unit :=
  modify fun { mctx, cache, zetaDeltaFVarIds, postponed, diag } => { mctx, cache := f cache, zetaDeltaFVarIds, postponed, diag }

def resetCache : MetaM Unit :=
  modifyCache fun _ => {}

@[inline] def modifyInferTypeCache (f : InferTypeCache → InferTypeCache) : MetaM Unit :=
  modifyCache fun ⟨ic, c1, c2, c3, c4, c5⟩ => ⟨f ic, c1, c2, c3, c4, c5⟩

@[inline] def modifyDefEqTransientCache (f : DefEqCache → DefEqCache) : MetaM Unit :=
  modifyCache fun ⟨c1, c2, c3, c4, defeqTrans, c5⟩ => ⟨c1, c2, c3, c4, f defeqTrans, c5⟩

@[inline] def modifyDefEqPermCache (f : DefEqCache → DefEqCache) : MetaM Unit :=
  modifyCache fun ⟨c1, c2, c3, c4, c5, defeqPerm⟩ => ⟨c1, c2, c3, c4, c5, f defeqPerm⟩

def mkExprConfigCacheKey (expr : Expr) : MetaM ExprConfigCacheKey :=
  return { expr, configKey := (← read).configKey }

def mkDefEqCacheKey (lhs rhs : Expr) : MetaM DefEqCacheKey := do
  let configKey := (← read).configKey
  if Expr.quickLt lhs rhs then
    return { lhs, rhs, configKey }
  else
    return { lhs := rhs, rhs := lhs, configKey }

def mkInfoCacheKey (expr : Expr) (nargs? : Option Nat) : MetaM InfoCacheKey :=
  return { expr, nargs?, configKey := (← read).configKey }

@[inline] def resetDefEqPermCaches : MetaM Unit :=
  modifyDefEqPermCache fun _ => {}

@[inline] def resetSynthInstanceCache : MetaM Unit :=
  modifyCache fun c => {c with synthInstance := {}}

@[inline] def modifyDiag (f : Diagnostics → Diagnostics) : MetaM Unit := do
  if (← isDiagnosticsEnabled) then
    modify fun { mctx, cache, zetaDeltaFVarIds, postponed, diag } => { mctx, cache, zetaDeltaFVarIds, postponed, diag := f diag }

/-- If diagnostics are enabled, record that `declName` has been unfolded. -/
def recordUnfold (declName : Name) : MetaM Unit := do
  modifyDiag fun { unfoldCounter, heuristicCounter, instanceCounter, synthPendingFailures } =>
    let newC := if let some c := unfoldCounter.find? declName then c + 1 else 1
    { unfoldCounter := unfoldCounter.insert declName newC, heuristicCounter, instanceCounter, synthPendingFailures }

/-- If diagnostics are enabled, record that heuristic for solving `f a =?= f b` has been used. -/
def recordDefEqHeuristic (declName : Name) : MetaM Unit := do
  modifyDiag fun { unfoldCounter, heuristicCounter, instanceCounter, synthPendingFailures } =>
    let newC := if let some c := heuristicCounter.find? declName then c + 1 else 1
    { unfoldCounter, heuristicCounter := heuristicCounter.insert declName newC, instanceCounter, synthPendingFailures }

/-- If diagnostics are enabled, record that instance `declName` was used during TC resolution. -/
def recordInstance (declName : Name) : MetaM Unit := do
  modifyDiag fun { unfoldCounter, heuristicCounter, instanceCounter, synthPendingFailures } =>
    let newC := if let some c := instanceCounter.find? declName then c + 1 else 1
    { unfoldCounter, heuristicCounter, instanceCounter := instanceCounter.insert declName newC, synthPendingFailures }

/-- If diagnostics are enabled, record that synth pending failures. -/
def recordSynthPendingFailure (type : Expr) : MetaM Unit := do
  if (← isDiagnosticsEnabled) then
    unless (← get).diag.synthPendingFailures.contains type do
      -- We need to save the full context since type class resolution uses multiple metavar contexts and different local contexts
      let msg ← addMessageContextFull m!"{type}"
      modifyDiag fun { unfoldCounter, heuristicCounter, instanceCounter, synthPendingFailures } =>
        { unfoldCounter, heuristicCounter, instanceCounter, synthPendingFailures := synthPendingFailures.insert type msg }

def getLocalInstances : MetaM LocalInstances :=
  return (← read).localInstances

def getConfig : MetaM Config :=
  return (← read).config

def getConfigWithKey : MetaM ConfigWithKey :=
  return (← getConfig).toConfigWithKey

/-- Return the array of postponed universe level constraints. -/
def getPostponed : MetaM (PersistentArray PostponedEntry) :=
  return (← get).postponed

/-- Set the array of postponed universe level constraints. -/
def setPostponed (postponed : PersistentArray PostponedEntry) : MetaM Unit :=
  modify fun s => { s with postponed := postponed }

/-- Modify the array of postponed universe level constraints. -/
@[inline] def modifyPostponed (f : PersistentArray PostponedEntry → PersistentArray PostponedEntry) : MetaM Unit :=
  modify fun s => { s with postponed := f s.postponed }

/--
  `useEtaStruct inductName` return `true` if we eta for structures is enabled for
  for the inductive datatype `inductName`.

  Recall we have three different settings: `.none` (never use it), `.all` (always use it), `.notClasses`
  (enabled only for structure-like inductive types that are not classes).

  The parameter `inductName` affects the result only if the current setting is `.notClasses`.
-/
def useEtaStruct (inductName : Name) : MetaM Bool := do
  match (← getConfig).etaStruct with
  | .none => return false
  | .all  => return true
  | .notClasses => return !isClass (← getEnv) inductName

/-!
WARNING: The following 4 constants are a hack for simulating forward declarations.
They are defined later using the `export` attribute. This is hackish because we
have to hard-code the true arity of these definitions here, and make sure the C names match.
We have used another hack based on `IO.Ref`s in the past, it was safer but less efficient.
-/

/--
Reduces an expression to its *weak head normal form*.
This is when the "head" of the top-level expression has been fully reduced.
The result may contain subexpressions that have not been reduced.

See `Lean.Meta.whnfImp` for the implementation.
-/
@[extern "lean_whnf"] opaque whnf : Expr → MetaM Expr
/--
Returns the inferred type of the given expression. Assumes the expression is type-correct.

The type inference algorithm does not do general type checking.
Type inference only looks at subterms that are necessary for determining an expression's type,
and as such if `inferType` succeeds it does *not* mean the term is type-correct.
If an expression is sufficiently ill-formed that it prevents `inferType` from computing a type,
then it will fail with a type error.

For typechecking during elaboration, see `Lean.Meta.check`.
(Note that we do not guarantee that the elaborator typechecker is as correct or as efficient as
the kernel typechecker. The kernel typechecker is invoked when a definition is added to the environment.)

Here are examples of type-incorrect terms for which `inferType` succeeds:
```lean
public import Lean

public section

open Lean Meta

/--
`@id.{1} Bool Nat.zero`.
In general, the type of `@id α x` is `α`.
-/
def e1 : Expr := mkApp2 (.const ``id [1]) (.const ``Bool []) (.const ``Nat.zero [])
#eval inferType e1
-- Lean.Expr.const `Bool []
#eval check e1
-- error: application type mismatch

/--
`let x : Int := Nat.zero; true`.
In general, the type of `let x := v; e`, if `e` does not reference `x`, is the type of `e`.
-/
def e2 : Expr := .letE `x (.const ``Int []) (.const ``Nat.zero []) (.const ``true []) false
#eval inferType e2
-- Lean.Expr.const `Bool []
#eval check e2
-- error: invalid let declaration
```
Here is an example of a type-incorrect term that makes `inferType` fail:
```lean
/--
`Nat.zero Nat.zero`
-/
def e3 : Expr := .app (.const ``Nat.zero []) (.const ``Nat.zero [])
#eval inferType e3
-- error: function expected
```

See `Lean.Meta.inferTypeImp` for the implementation of `inferType`.
-/
@[extern "lean_infer_type"] opaque inferType : Expr → MetaM Expr
@[extern "lean_is_expr_def_eq"] opaque isExprDefEqAux : Expr → Expr → MetaM Bool
@[extern "lean_is_level_def_eq"] opaque isLevelDefEqAux : Level → Level → MetaM Bool
@[extern "lean_synth_pending"] protected opaque synthPending : MVarId → MetaM Bool

def whnfForall (e : Expr) : MetaM Expr := do
  let e' ← whnf e
  if e'.isForall then pure e' else pure e

-- withIncRecDepth for a monad `n` such that `[MonadControlT MetaM n]`
protected def withIncRecDepth (x : n α) : n α :=
  mapMetaM (withIncRecDepth (m := MetaM)) x

private def mkFreshExprMVarAtCore
    (mvarId : MVarId) (lctx : LocalContext) (localInsts : LocalInstances) (type : Expr) (kind : MetavarKind) (userName : Name) (numScopeArgs : Nat) : MetaM Expr := do
  modifyMCtx fun mctx => mctx.addExprMVarDecl mvarId userName lctx localInsts type kind numScopeArgs;
  return mkMVar mvarId

def mkFreshExprMVarAt
    (lctx : LocalContext) (localInsts : LocalInstances) (type : Expr)
    (kind : MetavarKind := MetavarKind.natural) (userName : Name := Name.anonymous) (numScopeArgs : Nat := 0)
    : MetaM Expr := do
  mkFreshExprMVarAtCore (← mkFreshMVarId) lctx localInsts type kind userName numScopeArgs

def mkFreshLevelMVar : MetaM Level := do
  let mvarId ← mkFreshLMVarId
  modifyMCtx fun mctx => mctx.addLevelMVarDecl mvarId;
  return mkLevelMVar mvarId

private def mkFreshExprMVarCore (type : Expr) (kind : MetavarKind) (userName : Name) : MetaM Expr := do
  mkFreshExprMVarAt (← getLCtx) (← getLocalInstances) type kind userName

private def mkFreshExprMVarImpl (type? : Option Expr) (kind : MetavarKind) (userName : Name) : MetaM Expr :=
  match type? with
  | some type => mkFreshExprMVarCore type kind userName
  | none      => do
    let u ← mkFreshLevelMVar
    let type ← mkFreshExprMVarCore (mkSort u) MetavarKind.natural Name.anonymous
    mkFreshExprMVarCore type kind userName

def mkFreshExprMVar (type? : Option Expr) (kind := MetavarKind.natural) (userName := Name.anonymous) : MetaM Expr :=
  mkFreshExprMVarImpl type? kind userName

def mkFreshTypeMVar (kind := MetavarKind.natural) (userName := Name.anonymous) : MetaM Expr := do
  let u ← mkFreshLevelMVar
  mkFreshExprMVar (mkSort u) kind userName

/-- Low-level version of `MkFreshExprMVar` which allows users to create/reserve a `mvarId` using `mkFreshId`, and then later create
   the metavar using this method. -/
private def mkFreshExprMVarWithIdCore (mvarId : MVarId) (type : Expr)
    (kind : MetavarKind := MetavarKind.natural) (userName : Name := Name.anonymous) (numScopeArgs : Nat := 0)
    : MetaM Expr := do
  mkFreshExprMVarAtCore mvarId (← getLCtx) (← getLocalInstances) type kind userName numScopeArgs

def mkFreshExprMVarWithId (mvarId : MVarId) (type? : Option Expr := none) (kind : MetavarKind := MetavarKind.natural) (userName := Name.anonymous) : MetaM Expr :=
  match type? with
  | some type => mkFreshExprMVarWithIdCore mvarId type kind userName
  | none      => do
    let u ← mkFreshLevelMVar
    let type ← mkFreshExprMVar (mkSort u)
    mkFreshExprMVarWithIdCore mvarId type kind userName

def mkFreshLevelMVars (num : Nat) : MetaM (List Level) :=
  num.foldM (init := []) fun _ _ us =>
    return (← mkFreshLevelMVar)::us

def mkFreshLevelMVarsFor (info : ConstantInfo) : MetaM (List Level) :=
  mkFreshLevelMVars info.numLevelParams

/--
Create a constant with the given name and new universe metavariables.
Example: ``mkConstWithFreshMVarLevels `Monad`` returns `@Monad.{?u, ?v}`
-/
def mkConstWithFreshMVarLevels (declName : Name) : MetaM Expr := do
  let info ← getConstInfo declName
  return mkConst declName (← mkFreshLevelMVarsFor info)

/-- Return current transparency setting/mode. -/
def getTransparency : MetaM TransparencyMode :=
  return (← getConfig).transparency

def shouldReduceAll : MetaM Bool :=
  return (← getTransparency) == TransparencyMode.all

def shouldReduceReducibleOnly : MetaM Bool :=
  return (← getTransparency) == TransparencyMode.reducible

/--
Return `some mvarDecl` where `mvarDecl` is `mvarId` declaration in the current metavariable context.
Return `none` if `mvarId` has no declaration in the current metavariable context.
-/
def _root_.Lean.MVarId.findDecl? (mvarId : MVarId) : MetaM (Option MetavarDecl) :=
  return (← getMCtx).findDecl? mvarId

/--
Return `mvarId` declaration in the current metavariable context.
Throw an exception if `mvarId` is not declared in the current metavariable context.
-/
def _root_.Lean.MVarId.getDecl (mvarId : MVarId) : MetaM MetavarDecl := do
  match (← mvarId.findDecl?) with
  | some d => pure d
  | none   => throwError "unknown metavariable '?{mvarId.name}'"

/--
Return `mvarId` kind. Throw an exception if `mvarId` is not declared in the current metavariable context.
-/
def _root_.Lean.MVarId.getKind (mvarId : MVarId) : MetaM MetavarKind :=
  return (← mvarId.getDecl).kind

/-- Return `true` if `e` is a synthetic (or synthetic opaque) metavariable -/
def isSyntheticMVar (e : Expr) : MetaM Bool := do
  if e.isMVar then
     return (← e.mvarId!.getKind) matches .synthetic | .syntheticOpaque
  else
     return false

/--
Set `mvarId` kind in the current metavariable context.
-/
def _root_.Lean.MVarId.setKind (mvarId : MVarId) (kind : MetavarKind) : MetaM Unit :=
  modifyMCtx fun mctx => mctx.setMVarKind mvarId kind

/-- Update the type of the given metavariable. This function assumes the new type is
   definitionally equal to the current one -/
def _root_.Lean.MVarId.setType (mvarId : MVarId) (type : Expr) : MetaM Unit := do
  modifyMCtx fun mctx => mctx.setMVarType mvarId type

/--
Return true if the given metavariable is "read-only".
That is, its `depth` is different from the current metavariable context depth.
-/
def _root_.Lean.MVarId.isReadOnly (mvarId : MVarId) : MetaM Bool := do
  return (← mvarId.getDecl).depth != (← getMCtx).depth

/--
Returns true if `mvarId.isReadOnly` returns true or if `mvarId` is a synthetic opaque metavariable.

Recall `isDefEq` will not assign a value to `mvarId` if `mvarId.isReadOnlyOrSyntheticOpaque`.
-/
def _root_.Lean.MVarId.isReadOnlyOrSyntheticOpaque (mvarId : MVarId) : MetaM Bool := do
  let mvarDecl ← mvarId.getDecl
  if mvarDecl.depth != (← getMCtx).depth then
    return true
  else
    match mvarDecl.kind with
    | MetavarKind.syntheticOpaque => return !(← getConfig).assignSyntheticOpaque
    | _ => return false

/--
Return the level of the given universe level metavariable.
-/
def _root_.Lean.LMVarId.getLevel (mvarId : LMVarId) : MetaM Nat := do
  match (← getMCtx).findLevelDepth? mvarId with
  | some depth => return depth
  | _          => throwError "unknown universe metavariable '?{mvarId.name}'"

/--
Return true if the given universe metavariable is "read-only".
That is, its `depth` is different from the current metavariable context depth.
-/
def _root_.Lean.LMVarId.isReadOnly (mvarId : LMVarId) : MetaM Bool :=
  return (← mvarId.getLevel) < (← getMCtx).levelAssignDepth

/--
Set the user-facing name for the given metavariable.
-/
def _root_.Lean.MVarId.setUserName (mvarId : MVarId) (newUserName : Name) : MetaM Unit :=
  modifyMCtx fun mctx => mctx.setMVarUserName mvarId newUserName

/--
Throw an exception saying `fvarId` is not declared in the current local context.
-/
def _root_.Lean.FVarId.throwUnknown (fvarId : FVarId) : CoreM α :=
  throwError "unknown free variable '{mkFVar fvarId}'"

/--
Return `some decl` if `fvarId` is declared in the current local context.
-/
def _root_.Lean.FVarId.findDecl? (fvarId : FVarId) : MetaM (Option LocalDecl) :=
  return (← getLCtx).find? fvarId

/--
  Return the local declaration for the given free variable.
  Throw an exception if local declaration is not in the current local context.
-/
def _root_.Lean.FVarId.getDecl (fvarId : FVarId) : MetaM LocalDecl := do
  match (← getLCtx).find? fvarId with
  | some d => return d
  | none   => fvarId.throwUnknown

/-- Return the type of the given free variable. -/
def _root_.Lean.FVarId.getType (fvarId : FVarId) : MetaM Expr :=
  return (← fvarId.getDecl).type

/-- Return the binder information for the given free variable. -/
def _root_.Lean.FVarId.getBinderInfo (fvarId : FVarId) : MetaM BinderInfo :=
  return (← fvarId.getDecl).binderInfo

/--
Returns `some value` if the given free let-variable has a visible local definition in the current local context
(using `Lean.LocalDecl.value?`), and `none` otherwise.

Setting `allowNondep := true` allows access of the normally hidden value of a nondependent let declaration.
-/
def _root_.Lean.FVarId.getValue? (fvarId : FVarId) (allowNondep : Bool := false) : MetaM (Option Expr) :=
  return (← fvarId.getDecl).value? allowNondep

/-- Return the user-facing name for the given free variable. -/
def _root_.Lean.FVarId.getUserName (fvarId : FVarId) : MetaM Name :=
  return (← fvarId.getDecl).userName

/--
Returns `true` if the free variable is a let-variable with a visible local definition in the current local context
(using `Lean.LocalDecl.isLet`).

Setting `allowNondep := true` includes nondependent let declarations, whose values are normally hidden.
-/
def _root_.Lean.FVarId.isLetVar (fvarId : FVarId) (allowNondep : Bool := false) : MetaM Bool :=
  return (← fvarId.getDecl).isLet allowNondep

/-- Get the local declaration associated to the given `Expr` in the current local
context. Fails if the given expression is not a fvar or if no such declaration exists. -/
def getFVarLocalDecl (fvar : Expr) : MetaM LocalDecl :=
  fvar.fvarId!.getDecl

/--
Returns `true` if another local declaration in the local context depends on `fvarId`.
-/
def _root_.Lean.FVarId.hasForwardDeps (fvarId : FVarId) : MetaM Bool := do
  let decl ← fvarId.getDecl
  (← getLCtx).foldlM (init := false) (start := decl.index + 1) fun found other =>
    if found then
      return true
    else
      localDeclDependsOn other fvarId

/--
Given a user-facing name for a free variable, return its declaration in the current local context.
Throw an exception if free variable is not declared.
-/
def getLocalDeclFromUserName (userName : Name) : MetaM LocalDecl := do
  match (← getLCtx).findFromUserName? userName with
  | some d => pure d
  | none   => throwError "unknown local declaration '{userName}'"

/-- Given a user-facing name for a free variable, return the free variable or throw if not declared. -/
def getFVarFromUserName (userName : Name) : MetaM Expr := do
  let d ← getLocalDeclFromUserName userName
  return Expr.fvar d.fvarId

/--
Lift a `MkBindingM` monadic action `x` to `MetaM`.
-/
@[inline] def liftMkBindingM (x : MetavarContext.MkBindingM α) : MetaM α := do
  match x { lctx := (← getLCtx), mainModule := (← getEnv).mainModule } { mctx := (← getMCtx), ngen := (← getNGen), nextMacroScope := (← getThe Core.State).nextMacroScope } with
  | .ok e sNew => do
    setMCtx sNew.mctx
    modifyThe Core.State fun s => { s with ngen := sNew.ngen, nextMacroScope := sNew.nextMacroScope }
    pure e
  | .error (.revertFailure ..) sNew => do
    setMCtx sNew.mctx
    modifyThe Core.State fun s => { s with ngen := sNew.ngen, nextMacroScope := sNew.nextMacroScope }
    throwError "failed to create binder due to failure when reverting variable dependencies"

/--
Similar to `abstractM` but consider only the first `min n xs.size` entries in `xs`

It is also similar to `Expr.abstractRange`, but handles metavariables correctly.
It uses `elimMVarDeps` to ensure `e` and the type of the free variables `xs` do not
contain a metavariable `?m` s.t. local context of `?m` contains a free variable in `xs`.
-/
def _root_.Lean.Expr.abstractRangeM (e : Expr) (n : Nat) (xs : Array Expr) : MetaM Expr :=
  liftMkBindingM <| MetavarContext.abstractRange e n xs

/--
Replace free (or meta) variables `xs` with loose bound variables.
Similar to `Expr.abstract`, but handles metavariables correctly.
-/
def _root_.Lean.Expr.abstractM (e : Expr) (xs : Array Expr) : MetaM Expr :=
  e.abstractRangeM xs.size xs

/--
Collect forward dependencies for the free variables in `toRevert`.
Recall that when reverting free variables `xs`, we must also revert their forward dependencies.

When `generalizeNondepLet := true` (the default), then the values of nondependent lets are not considered
when computing forward dependencies.
-/
def collectForwardDeps (toRevert : Array Expr) (preserveOrder : Bool) (generalizeNondepLet := true) : MetaM (Array Expr) := do
  liftMkBindingM <| MetavarContext.collectForwardDeps toRevert preserveOrder generalizeNondepLet

/-- Takes an array `xs` of free variables or metavariables and a term `e` that may contain those variables, and abstracts and binds them as universal quantifiers.

- if `usedOnly = true` then only variables that the expression body depends on will appear.
- if `usedLetOnly = true` same as `usedOnly` except for let-bound variables. (That is, local constants which have been assigned a value.)
- if `generalizeNondepLet = true` then nondependent `ldecl`s become foralls too.
 -/
def mkForallFVars (xs : Array Expr) (e : Expr) (usedOnly : Bool := false) (usedLetOnly : Bool := true) (generalizeNondepLet := true) (binderInfoForMVars := BinderInfo.implicit) : MetaM Expr :=
  if xs.isEmpty then return e else liftMkBindingM <| MetavarContext.mkForall xs e usedOnly usedLetOnly generalizeNondepLet binderInfoForMVars

/-- Takes an array `xs` of free variables and metavariables and a
body term `e` and creates `fun ..xs => e`, suitably
abstracting `e` and the types in `xs`. -/
def mkLambdaFVars (xs : Array Expr) (e : Expr) (usedOnly : Bool := false) (usedLetOnly : Bool := true) (etaReduce : Bool := false) (generalizeNondepLet := true) (binderInfoForMVars := BinderInfo.implicit) : MetaM Expr :=
  if xs.isEmpty then return e else liftMkBindingM <| MetavarContext.mkLambda xs e usedOnly usedLetOnly etaReduce generalizeNondepLet binderInfoForMVars

def mkLetFVars (xs : Array Expr) (e : Expr) (usedLetOnly := true) (generalizeNondepLet := true) (binderInfoForMVars := BinderInfo.implicit) : MetaM Expr :=
  mkLambdaFVars xs e (usedLetOnly := usedLetOnly) (generalizeNondepLet := generalizeNondepLet) (binderInfoForMVars := binderInfoForMVars)

/-- `fun _ : Unit => a` -/
def mkFunUnit (a : Expr) : MetaM Expr :=
  return Lean.mkLambda (← mkFreshUserName `x) BinderInfo.default (mkConst ``Unit) a

def elimMVarDeps (xs : Array Expr) (e : Expr) (preserveOrder : Bool := false) : MetaM Expr :=
  if xs.isEmpty then pure e else liftMkBindingM <| MetavarContext.elimMVarDeps xs e preserveOrder

/-- `withConfig f x` executes `x` using the updated configuration object obtained by applying `f`. -/
@[inline] def withConfig (f : Config → Config) : n α → n α :=
  mapMetaM <| withReader fun ctx =>
    let config := f ctx.config
    { ctx with keyedConfig := { config } }

@[inline] def withConfigWithKey (c : ConfigWithKey) : n α → n α :=
  mapMetaM <| withReader fun ctx =>
    let config := c.config
    { ctx with keyedConfig := { config } }

@[inline] def withCanUnfoldPred (p : Config → ConstantInfo → CoreM Bool) : n α → n α :=
  mapMetaM <| withReader (fun ctx => { ctx with canUnfold? := p })

@[inline] def withIncSynthPending : n α → n α :=
  mapMetaM <| withReader (fun ctx => { ctx with synthPendingDepth := ctx.synthPendingDepth + 1 })

@[inline] def withInTypeClassResolution : n α → n α :=
  mapMetaM <| withReader (fun ctx => { ctx with inTypeClassResolution := true })

@[inline] def withFreshCache : n α → n α :=
  mapMetaM fun x => do
    let cacheSaved := (← get).cache
    modify fun s => { s with cache := {} }
    try
      x
    finally
      modify fun s => { s with cache := cacheSaved }

/--
If `s` is nonempty, then `withZetaDeltaSet s x` executes `x` with `zetaDeltaSet := s`.
The cache is temporarily reset while executing `x`.

If `s` is empty, then runs `x` without changing `zetaDeltaSet` or resetting the cache.

See also `withTrackingZetaDeltaSet` for tracking zeta-delta reductions.
-/
def withZetaDeltaSet (s : FVarIdSet) : n α → n α :=
  mapMetaM fun x =>
    if s.isEmpty then
      x
    else
      withFreshCache <| withReader (fun ctx => { ctx with zetaDeltaSet := s }) x

/--
Gets the current `zetaDeltaFVarIds` set.
If `Context.trackZetaDelta` is true, then `whnf` adds to this set
those local definitions that are unfolded ("zeta-delta reduced") .

See `withTrackingZetaDelta` and `withTrackingZetaDeltaSet`.
-/
def getZetaDeltaFVarIds : MetaM FVarIdSet :=
  return (← get).zetaDeltaFVarIds

/--
Inserts `fvarId` into the `zetaDeltaFVarIds` set.
-/
def addZetaDeltaFVarId (fvarId : FVarId) : MetaM Unit :=
  modify fun s => { s with zetaDeltaFVarIds := s.zetaDeltaFVarIds.insert fvarId }

/--
`withResetZetaDeltaFVarIds x` executes `x` in a context where the `zetaDeltaFVarIds` is temporarily cleared.

**Warning:** This does not reset the cache.
-/
@[inline] private def withResetZetaDeltaFVarIds : n α → n α :=
  mapMetaM fun x => do
    let zetaDeltaFVarIdsSaved ← modifyGet fun s => (s.zetaDeltaFVarIds, { s with zetaDeltaFVarIds := {} })
    try
      x
    finally
      modify fun s => { s with zetaDeltaFVarIds := zetaDeltaFVarIdsSaved }

/--
`withTrackingZetaDelta x` executes `x` while tracking zeta-delta reductions performed by `whnf`.
Furthermore, the `zetaDeltaFVarIds` set is temporarily cleared,
and also the cache is temporarily reset so that reductions are accurately tracked.

Any zeta-delta reductions recorded while executing `x` will *not* persist when leaving `withTrackingZetaDelta`.
-/
@[inline] def withTrackingZetaDelta : n α → n α :=
  mapMetaM fun x =>
    withFreshCache <| withReader (fun ctx => { ctx with trackZetaDelta := true }) <| withResetZetaDeltaFVarIds x

@[deprecated withTrackingZetaDelta (since := "2025-06-12")]
def resetZetaDeltaFVarIds : MetaM Unit :=
  modify fun s => { s with zetaDeltaFVarIds := {} }

/--
`withTrackingZetaDeltaSet s x` executes `x` in a context where `zetaDeltaFVarIds` has been temporarily cleared.
- If `s` is nonempty, zeta-delta tracking is enabled and `zetaDeltaSet := s`.
  Furthermore, the cache is temporarily reset so that zeta-delta tracking is accurate.
- If `s` is empty, then zeta-delta tracking is disabled. The `zetaDeltaSet` is *not* modified, and the cache is not cleared.

Any zeta-delta reductions recorded while executing `x` will *not* persist when leaving `withTrackingZetaDeltaSet`.

See also `withZetaDeltaSet`, which does not interact with zeta-delta tracking.
-/
def withTrackingZetaDeltaSet (s : FVarIdSet) : n α → n α :=
  mapMetaM fun x =>
    if s.isEmpty then
      withReader (fun ctx => { ctx with trackZetaDelta := false }) <| withResetZetaDeltaFVarIds x
    else
      withFreshCache <| withReader (fun ctx => { ctx with zetaDeltaSet := s, trackZetaDelta := true }) <| withResetZetaDeltaFVarIds x

@[inline] def withoutProofIrrelevance (x : n α) : n α :=
  withConfig (fun cfg => { cfg with proofIrrelevance := false }) x

@[inline] private def Context.setTransparency (ctx : Context) (transparency : TransparencyMode) : Context :=
  let config := { ctx.config with transparency }
  -- Recall that `transparency` is stored in the first 2 bits
  let key : UInt64 := ((ctx.configKey >>> (2 : UInt64)) <<< 2) ||| transparency.toUInt64
  { ctx with keyedConfig := { config, key } }

@[inline] def withTransparency (mode : TransparencyMode) : n α → n α :=
  -- We avoid `withConfig` for performance reasons.
  mapMetaM <| withReader (·.setTransparency mode)

/-- `withDefault x` executes `x` using the default transparency setting. -/
@[inline] def withDefault (x : n α) : n α :=
  withTransparency TransparencyMode.default x

/-- `withReducible x` executes `x` using the reducible transparency setting. In this setting only definitions tagged as `[reducible]` are unfolded. -/
@[inline] def withReducible (x : n α) : n α :=
  withTransparency TransparencyMode.reducible x

/--
`withReducibleAndInstances x` executes `x` using the `.instances` transparency setting. In this setting only definitions tagged as `[reducible]`
or type class instances are unfolded.
-/
@[inline] def withReducibleAndInstances (x : n α) : n α :=
  withTransparency TransparencyMode.instances x

/--
Execute `x` ensuring the transparency setting is at least `mode`.
Recall that `.all > .default > .instances > .reducible`.
-/
@[inline] def withAtLeastTransparency (mode : TransparencyMode) : n α → n α :=
  mapMetaM <| withReader fun ctx =>
    let modeOld := ctx.config.transparency
    ctx.setTransparency <| if modeOld.lt mode then mode else modeOld

/-- Execute `x` allowing `isDefEq` to assign synthetic opaque metavariables. -/
@[inline] def withAssignableSyntheticOpaque (x : n α) : n α :=
  withConfig (fun config => { config with assignSyntheticOpaque := true }) x

/-- Save cache, execute `x`, restore cache -/
@[inline] private def savingCacheImpl (x : MetaM α) : MetaM α := do
  let savedCache := (← get).cache
  try x finally modify fun s => { s with cache := savedCache }

@[inline] def savingCache : n α → n α :=
  mapMetaM savingCacheImpl

def getTheoremInfo (info : ConstantInfo) : MetaM (Option ConstantInfo) := do
  if (← shouldReduceAll) then
    return some info
  else
    return none

private def getDefInfoTemp (info : ConstantInfo) : MetaM (Option ConstantInfo) := do
  match (← getTransparency) with
  | .all => return some info
  | .default => return some info
  | _ =>
    if (← isReducible info.name) then
      return some info
    else
      return none

/-- Remark: we later define `getUnfoldableConst?` at `GetConst.lean` after we define `Instances.lean`.
   This method is only used to implement `isClassQuickConst?`.
   It is very similar to `getUnfoldableConst?`, but it returns none when `TransparencyMode.instances` and
   `constName` is an instance. This difference should be irrelevant for `isClassQuickConst?`. -/
private def getConstTemp? (constName : Name) : MetaM (Option ConstantInfo) := do
  match (← getEnv).find? constName with
  | some (info@(ConstantInfo.thmInfo _))  => getTheoremInfo info
  | some (info@(ConstantInfo.defnInfo _)) => getDefInfoTemp info
  | some info                             => pure (some info)
  | none                                  => throwUnknownConstantAt (← getRef) constName

private def isClassQuickConst? (constName : Name) : MetaM (LOption Name) := do
  if isClass (← getEnv) constName then
    return .some constName
  else
    match (← getConstTemp? constName) with
    | some (.defnInfo ..) => return .undef -- We may be able to unfold the definition
    | _ => return .none

private partial def isClassQuick? : Expr → MetaM (LOption Name)
  | .bvar ..         => return .none
  | .lit ..          => return .none
  | .fvar ..         => return .none
  | .sort ..         => return .none
  | .lam ..          => return .none
  | .letE ..         => return .undef
  | .proj ..         => return .undef
  | .forallE _ _ b _ => isClassQuick? b
  | .mdata _ e       => isClassQuick? e
  | .const n _       => isClassQuickConst? n
  | .mvar mvarId     => do
    let some val ← getExprMVarAssignment? mvarId | return .none
    isClassQuick? val
  | .app f _         => do
    match f.getAppFn with
    | .const n ..  => isClassQuickConst? n
    | .lam ..      => return .undef
    | .mvar mvarId =>
      let some val ← getExprMVarAssignment? mvarId | return .none
      match val.getAppFn with
      | .const n .. => isClassQuickConst? n
      | _ => return .undef
    | _            => return .none

private def withNewLocalInstanceImp (className : Name) (fvar : Expr) (k : MetaM α) : MetaM α := do
  let localDecl ← getFVarLocalDecl fvar
  if localDecl.isImplementationDetail then
    k
  else
    withReader (fun ctx => { ctx with localInstances := ctx.localInstances.push { className := className, fvar := fvar } }) k

/-- Add entry `{ className := className, fvar := fvar }` to localInstances,
    and then execute continuation `k`. -/
def withNewLocalInstance (className : Name) (fvar : Expr) : n α → n α :=
  mapMetaM <| withNewLocalInstanceImp className fvar

private def fvarsSizeLtMaxFVars (fvars : Array Expr) (maxFVars? : Option Nat) : Bool :=
  match maxFVars? with
  | some maxFVars => fvars.size < maxFVars
  | none          => true

mutual
  /--
    `withNewLocalInstances isClassExpensive fvars j k` updates the vector or local instances
    using free variables `fvars[j] ... fvars.back`, and execute `k`.

    - `isClassExpensive` is defined later.
    - `isClassExpensive` uses `whnf` which depends (indirectly) on the set of local instances. -/
  private partial def withNewLocalInstancesImp
      (fvars : Array Expr) (i : Nat) (k : MetaM α) : MetaM α := do
    if h : i < fvars.size then
      let fvar := fvars[i]
      let decl ← getFVarLocalDecl fvar
      match (← isClassQuick? decl.type) with
      | .none   => withNewLocalInstancesImp fvars (i+1) k
      | .undef  =>
        match (← isClassExpensive? decl.type) with
        | none   => withNewLocalInstancesImp fvars (i+1) k
        | some c => withNewLocalInstance c fvar <| withNewLocalInstancesImp fvars (i+1) k
      | .some c => withNewLocalInstance c fvar <| withNewLocalInstancesImp fvars (i+1) k
    else
      k

  /--
    `forallTelescopeAuxAux lctx fvars j type`
    Remarks:
    - `lctx` is the `MetaM` local context extended with declarations for `fvars`.
    - `type` is the type we are computing the telescope for. It contains only
      dangling bound variables in the range `[j, fvars.size)`
    - if `reducing? == true` and `type` is not `forallE`, we use `whnf`.
    - when `type` is not a `forallE` nor it can't be reduced to one, we
      execute the continuation `k`.

    Here is an example that demonstrates the `reducing?`.
    Suppose we have
    ```
    abbrev StateM s a := s -> Prod a s
    ```
    Now, assume we are trying to build the telescope for
    ```
    forall (x : Nat), StateM Int Bool
    ```
    if `reducing == true`, the function executes `k #[(x : Nat) (s : Int)] Bool`.
    if `reducing == false`, the function executes `k #[(x : Nat)] (StateM Int Bool)`

    if `maxFVars?` is `some max`, then we interrupt the telescope construction
    when `fvars.size == max`


    If `cleanupAnnotations` is `true`, we apply `Expr.cleanupAnnotations` to each type in the telescope.

    If `whnfIfReducing` is true, then in the `reducing == true` case, `k` is given the whnf of the type.
    This does not have any performance cost.
  -/
  private partial def forallTelescopeReducingAuxAux
      (reducing          : Bool) (maxFVars? : Option Nat)
      (type              : Expr)
      (k                 : Array Expr → Expr → MetaM α)
      (cleanupAnnotations : Bool) (whnfTypeIfReducing : Bool) : MetaM α := do
    let rec process (lctx : LocalContext) (fvars : Array Expr) (j : Nat) (type : Expr) : MetaM α := do
      match type with
      | .forallE n d b bi =>
        if fvarsSizeLtMaxFVars fvars maxFVars? then
          let d     := d.instantiateRevRange j fvars.size fvars
          let d     := if cleanupAnnotations then d.cleanupAnnotations else d
          let fvarId ← mkFreshFVarId
          let lctx  := lctx.mkLocalDecl fvarId n d bi
          let fvar  := mkFVar fvarId
          let fvars := fvars.push fvar
          process lctx fvars j b
        else
          let type := type.instantiateRevRange j fvars.size fvars;
          withReader (fun ctx => { ctx with lctx := lctx }) do
            withNewLocalInstancesImp fvars j do
              k fvars type
      | _ =>
        let type := type.instantiateRevRange j fvars.size fvars;
        withReader (fun ctx => { ctx with lctx := lctx }) do
          withNewLocalInstancesImp fvars j do
            if reducing && fvarsSizeLtMaxFVars fvars maxFVars? then
              let newType ← whnf type
              if newType.isForall then
                process lctx fvars fvars.size newType
              else if whnfTypeIfReducing then
                k fvars newType
              else
                k fvars type
            else
              k fvars type
    process (← getLCtx) #[] 0 type

  private partial def forallTelescopeReducingAux (type : Expr) (maxFVars? : Option Nat) (k : Array Expr → Expr → MetaM α) (cleanupAnnotations : Bool) (whnfType : Bool) : MetaM α := do
    match maxFVars? with
    | some 0 =>
      if whnfType then
        k #[] (← whnf type)
      else
        k #[] type
    | _ => do
      let newType ← whnf type
      if newType.isForall then
        forallTelescopeReducingAuxAux true maxFVars? newType k cleanupAnnotations whnfType
      else if whnfType then
        k #[] newType
      else
        k #[] type


  /--
  Helper method for `isClassExpensive?`. The type `type` is in WHNF.
  -/
  private partial def isClassApp? (type : Expr) : MetaM (Option Name) := do
    match type.getAppFn with
    | .const c _ =>
      let env ← getEnv
      if isClass env c then
        return some c
      else
        return none
    | _ => return none

  private partial def isClassExpensive? (type : Expr) : MetaM (Option Name) :=
    withReducible do -- when testing whether a type is a type class, we only unfold reducible constants.
      forallTelescopeReducingAux type none (cleanupAnnotations := false) (whnfType := true) fun _ type => isClassApp? type

  private partial def isClassImp? (type : Expr) : MetaM (Option Name) := do
    match (← isClassQuick? type) with
    | .none   => return none
    | .some c => return (some c)
    | .undef  => isClassExpensive? type

end

/--
  `isClass? type` return `some ClsName` if `type` is an instance of the class `ClsName`.
  Example:
  ```
  #eval do
    let x ← mkAppM ``Inhabited #[mkConst ``Nat]
    IO.println (← isClass? x)
    -- (some Inhabited)
  ```
-/
def isClass? (type : Expr) : MetaM (Option Name) :=
  try isClassImp? type catch _ => return none

private def withNewLocalInstancesImpAux (fvars : Array Expr) (j : Nat) : n α → n α :=
  mapMetaM <| withNewLocalInstancesImp fvars j

partial def withNewLocalInstances (fvars : Array Expr) (j : Nat) : n α → n α :=
  mapMetaM <| withNewLocalInstancesImpAux fvars j

@[inline] private def forallTelescopeImp (type : Expr) (k : Array Expr → Expr → MetaM α) (cleanupAnnotations : Bool) (whnfType : Bool) : MetaM α := do
  forallTelescopeReducingAuxAux (reducing := false) (maxFVars? := none) type k cleanupAnnotations whnfType

/--
  Given `type` of the form `forall xs, A`, execute `k xs A`.
  This combinator will declare local declarations, create free variables for them,
  execute `k` with updated local context, and make sure the cache is restored after executing `k`.

  If `cleanupAnnotations` is `true`, we apply `Expr.cleanupAnnotations` to each type in the telescope.
-/
def forallTelescope (type : Expr) (k : Array Expr → Expr → n α) (cleanupAnnotations := false) : n α :=
  map2MetaM (fun k => forallTelescopeImp type k cleanupAnnotations (whnfType := false)) k

/--
Given a monadic function `f` that takes a type and a term of that type and produces a new term,
lifts this to the monadic function that opens a `∀` telescope, applies `f` to the body,
and then builds the lambda telescope term for the new term.
-/
def mapForallTelescope' (f : Expr → Expr → MetaM Expr) (forallTerm : Expr) : MetaM Expr := do
  forallTelescope (← inferType forallTerm) fun xs ty => do
    mkLambdaFVars xs (← f ty (mkAppN forallTerm xs))

/--
Given a monadic function `f` that takes a term and produces a new term,
lifts this to the monadic function that opens a `∀` telescope, applies `f` to the body,
and then builds the lambda telescope term for the new term.
-/
def mapForallTelescope (f : Expr → MetaM Expr) (forallTerm : Expr) : MetaM Expr := do
  mapForallTelescope' (fun _ e => f e) forallTerm

private def forallTelescopeReducingImp (type : Expr) (k : Array Expr → Expr → MetaM α) (cleanupAnnotations : Bool) (whnfType : Bool) : MetaM α :=
  forallTelescopeReducingAux type (maxFVars? := none) k cleanupAnnotations (whnfType := whnfType)

/--
  Similar to `forallTelescope`, but given `type` of the form `forall xs, A`,
  it reduces `A` and continues building the telescope if it is a `forall`.

  If `cleanupAnnotations` is `true`, we apply `Expr.cleanupAnnotations` to each type in the telescope.

  If `whnfType` is `true`, we give `k` the `whnf` of the resulting type. This is a free operation.
-/
def forallTelescopeReducing (type : Expr) (k : Array Expr → Expr → n α) (cleanupAnnotations := false) (whnfType := false) : n α :=
  map2MetaM (fun k => forallTelescopeReducingImp type k cleanupAnnotations (whnfType := whnfType)) k

private def forallBoundedTelescopeImp (type : Expr) (maxFVars? : Option Nat) (k : Array Expr → Expr → MetaM α) (cleanupAnnotations : Bool) (whnfType : Bool) : MetaM α :=
  forallTelescopeReducingAux type maxFVars? k cleanupAnnotations (whnfType := whnfType)

/--
  Similar to `forallTelescopeReducing`, stops constructing the telescope when
  it reaches size `maxFVars`.

  If `cleanupAnnotations` is `true`, we apply `Expr.cleanupAnnotations` to each type in the telescope.

  If `whnfType` is `true`, we give `k` the `whnf` of the resulting type.
  This is a free operation unless `maxFVars? == some 0`, in which case it computes the `whnf`.
-/
def forallBoundedTelescope (type : Expr) (maxFVars? : Option Nat) (k : Array Expr → Expr → n α) (cleanupAnnotations := false) (whnfType := false) : n α :=
  map2MetaM (fun k => forallBoundedTelescopeImp type maxFVars? k cleanupAnnotations (whnfType := whnfType)) k

private partial def lambdaTelescopeImp (e : Expr) (consumeLambda : Bool) (consumeLet : Bool) (preserveNondepLet : Bool) (nondepLetOnly : Bool) (maxFVars? : Option Nat)
    (k : Array Expr → Expr → MetaM α) (cleanupAnnotations := false) : MetaM α := do
  process consumeLambda consumeLet (← getLCtx) #[] e
where
  process (consumeLambda : Bool) (consumeLet : Bool) (lctx : LocalContext) (fvars : Array Expr) (e : Expr) : MetaM α := do
    let finish (e : Expr) : MetaM α :=
      let e := e.instantiateRevRange 0 fvars.size fvars
      withReader (fun ctx => { ctx with lctx := lctx }) do
        withNewLocalInstancesImp fvars 0 do
          k fvars e
    match fvarsSizeLtMaxFVars fvars maxFVars?, consumeLambda, consumeLet, e with
    | true, true, _, .lam n d b bi =>
      let d := d.instantiateRevRange 0 fvars.size fvars
      let d := if cleanupAnnotations then d.cleanupAnnotations else d
      let fvarId ← mkFreshFVarId
      let lctx := lctx.mkLocalDecl fvarId n d bi
      let fvar := mkFVar fvarId
      process true consumeLet lctx (fvars.push fvar) b
    | true, _, true, .letE n t v b nondep => do
      if !nondep && nondepLetOnly then
        finish e
      else
        let t := t.instantiateRevRange 0 fvars.size fvars
        let t := if cleanupAnnotations then t.cleanupAnnotations else t
        let v := v.instantiateRevRange 0 fvars.size fvars
        let fvarId ← mkFreshFVarId
        let lctx := lctx.mkLetDecl fvarId n t v (nondep && preserveNondepLet)
        let fvar := mkFVar fvarId
        process consumeLambda true lctx (fvars.push fvar) b
    | _, _, _, e =>
      finish e

/--
Similar to `lambdaTelescope` but for lambda and let expressions.

- If `cleanupAnnotations` is `true`, we apply `Expr.cleanupAnnotations` to each type in the telescope.
- If `preserveNondep` is `false`, all `have`s are converted to `let`s.

See also `mapLambdaLetTelescope` for entering and rebuilding the telescope.
-/
def lambdaLetTelescope (e : Expr) (k : Array Expr → Expr → n α) (cleanupAnnotations := false) (preserveNondepLet := true) : n α :=
  map2MetaM (fun k => lambdaTelescopeImp e true true preserveNondepLet false .none k (cleanupAnnotations := cleanupAnnotations)) k

/--
  Given `e` of the form `fun ..xs => A`, execute `k xs A`.
  This combinator will declare local declarations, create free variables for them,
  execute `k` with updated local context, and make sure the cache is restored after executing `k`.

  If `cleanupAnnotations` is `true`, we apply `Expr.cleanupAnnotations` to each type in the telescope.
-/
def lambdaTelescope (e : Expr) (k : Array Expr → Expr → n α) (cleanupAnnotations := false) : n α :=
  map2MetaM (fun k => lambdaTelescopeImp e true false true false none k (cleanupAnnotations := cleanupAnnotations)) k

/--
  Given `e` of the form `fun ..xs ..ys => A`, execute `k xs (fun ..ys => A)` where
  `xs.size ≤ maxFVars`.
  This combinator will declare local declarations, create free variables for them,
  execute `k` with updated local context, and make sure the cache is restored after executing `k`.

  If `cleanupAnnotations` is `true`, we apply `Expr.cleanupAnnotations` to each type in the telescope.
-/
def lambdaBoundedTelescope (e : Expr) (maxFVars : Nat) (k : Array Expr → Expr → n α) (cleanupAnnotations := false) : n α :=
  map2MetaM (fun k => lambdaTelescopeImp e true false true false (.some maxFVars) k (cleanupAnnotations := cleanupAnnotations)) k

/--
Given `e` of the form `let x₁ := v₁; ...; let xₙ := vₙ; A`, executes `k xs A`,
where `xs` is an array of free variables for the binders.
The `let`s can also be `have`s.

- If `cleanupAnnotations` is `true`, applies `Expr.cleanupAnnotations` to each type in the telescope.
- If `preserveNondep` is `false`, all `have`s are converted to `let`s.
- If `nondepLetOnly` is `true`, then only `have`s are consumed (it stops at the first dependent `let`).

See also `mapLetTelescope` for entering and rebuilding the telescope.
-/
def letTelescope (e : Expr) (k : Array Expr → Expr → n α) (cleanupAnnotations := false) (preserveNondepLet := true) (nondepLetOnly := false) : n α :=
  map2MetaM (fun k => lambdaTelescopeImp e false true preserveNondepLet nondepLetOnly none k (cleanupAnnotations := cleanupAnnotations)) k

/--
Like `letTelescope`, but limits the number of `let`/`have`s consumed to `maxFVars?`.
If `maxFVars?` is none, then this is the same as `letTelescope`.
-/
def letBoundedTelescope (e : Expr) (maxFVars? : Option Nat) (k : Array Expr → Expr → n α) (cleanupAnnotations := false) (preserveNondepLet := true) (nondepLetOnly := false) : n α :=
  map2MetaM (fun k => lambdaTelescopeImp e false true preserveNondepLet nondepLetOnly maxFVars? k (cleanupAnnotations := cleanupAnnotations)) k

/--
Evaluates `k` from within a `lambdaLetTelescope`, then uses `mkLetFVars` to rebuild the telescope.
-/
def mapLambdaLetTelescope [MonadLiftT MetaM n] (e : Expr) (k : Array Expr → Expr → n Expr) (cleanupAnnotations := false) (preserveNondepLet := true) (usedLetOnly := true) : n Expr :=
  lambdaLetTelescope e (cleanupAnnotations := cleanupAnnotations) (preserveNondepLet := preserveNondepLet) fun xs b => do
    mkLambdaFVars (usedLetOnly := usedLetOnly) (generalizeNondepLet := false) xs (← k xs b)

/--
Evaluates `k` from within a `letTelescope`, then uses `mkLetFVars` to rebuild the telescope.
-/
def mapLetTelescope [MonadLiftT MetaM n] (e : Expr) (k : Array Expr → Expr → n Expr) (cleanupAnnotations := false) (preserveNondepLet := true) (nondepLetOnly := false) (usedLetOnly := true) : n Expr :=
  letTelescope e (cleanupAnnotations := cleanupAnnotations) (preserveNondepLet := preserveNondepLet) (nondepLetOnly := nondepLetOnly) fun xs b => do
    mkLetFVars (usedLetOnly := usedLetOnly) (generalizeNondepLet := false) xs (← k xs b)

/-- Return the parameter names for the given global declaration. -/
def getParamNames (declName : Name) : MetaM (Array Name) := do
  forallTelescopeReducing (← getConstInfo declName).type fun xs _ => do
    xs.mapM fun x => do
      let localDecl ← x.fvarId!.getDecl
      return localDecl.userName

-- `kind` specifies the metavariable kind for metavariables not corresponding to instance implicit `[ ... ]` arguments.
private partial def forallMetaTelescopeReducingAux
    (e : Expr) (reducing : Bool) (maxMVars? : Option Nat) (kind : MetavarKind) : MetaM (Array Expr × Array BinderInfo × Expr) :=
  process #[] #[] 0 e
where
  process (mvars : Array Expr) (bis : Array BinderInfo) (j : Nat) (type : Expr) : MetaM (Array Expr × Array BinderInfo × Expr) := do
    if maxMVars?.isEqSome mvars.size then
      let type := type.instantiateRevRange j mvars.size mvars;
      return (mvars, bis, type)
    else
      match type with
      | .forallE n d b bi =>
        let d  := d.instantiateRevRange j mvars.size mvars
        let k  := if bi.isInstImplicit then  MetavarKind.synthetic else kind
        let mvar ← mkFreshExprMVar d k n
        let mvars := mvars.push mvar
        let bis   := bis.push bi
        process mvars bis j b
      | _ =>
        let type := type.instantiateRevRange j mvars.size mvars;
        if reducing then do
          let newType ← whnf type;
          if newType.isForall then
            process mvars bis mvars.size newType
          else
            return (mvars, bis, type)
        else
          return (mvars, bis, type)

/-- Given `e` of the form `forall ..xs, A`, this combinator will create a new
  metavariable for each `x` in `xs` and instantiate `A` with these.
  Returns a product containing
  - the new metavariables
  - the binder info for the `xs`
  - the instantiated `A`
  -/
def forallMetaTelescope (e : Expr) (kind := MetavarKind.natural) : MetaM (Array Expr × Array BinderInfo × Expr) :=
  forallMetaTelescopeReducingAux e (reducing := false) (maxMVars? := none) kind

/-- Similar to `forallMetaTelescope`, but if `e = forall ..xs, A`
it will reduce `A` to construct further mvars.  -/
def forallMetaTelescopeReducing (e : Expr) (maxMVars? : Option Nat := none) (kind := MetavarKind.natural) : MetaM (Array Expr × Array BinderInfo × Expr) :=
  forallMetaTelescopeReducingAux e (reducing := true) maxMVars? kind

/-- Similar to `forallMetaTelescopeReducing`, stops
constructing the telescope when it reaches size `maxMVars`. -/
def forallMetaBoundedTelescope (e : Expr) (maxMVars : Nat) (kind : MetavarKind := MetavarKind.natural) : MetaM (Array Expr × Array BinderInfo × Expr) :=
  forallMetaTelescopeReducingAux e (reducing := true) (maxMVars? := some maxMVars) (kind := kind)

/-- Similar to `forallMetaTelescopeReducingAux` but for lambda expressions. -/
partial def lambdaMetaTelescope (e : Expr) (maxMVars? : Option Nat := none) : MetaM (Array Expr × Array BinderInfo × Expr) :=
  process #[] #[] 0 e
where
  process (mvars : Array Expr) (bis : Array BinderInfo) (j : Nat) (type : Expr) : MetaM (Array Expr × Array BinderInfo × Expr) := do
    let finalize : Unit → MetaM (Array Expr × Array BinderInfo × Expr) := fun _ => do
      let type := type.instantiateRevRange j mvars.size mvars
      return (mvars, bis, type)
    if maxMVars?.isEqSome mvars.size then
      finalize ()
    else
      match type with
      | .lam _ d b bi =>
        let d     := d.instantiateRevRange j mvars.size mvars
        let mvar ← mkFreshExprMVar d
        let mvars := mvars.push mvar
        let bis   := bis.push bi
        process mvars bis j b
      | _ => finalize ()

private def withNewFVar (fvar fvarType : Expr) (k : Expr → MetaM α) : MetaM α := do
  if let some c ← isClass? fvarType then
    withNewLocalInstance c fvar <| k fvar
  else
    k fvar

private def withLocalDeclImp (n : Name) (bi : BinderInfo) (type : Expr) (k : Expr → MetaM α) (kind : LocalDeclKind) : MetaM α := do
  let fvarId ← mkFreshFVarId
  let ctx ← read
  let lctx := ctx.lctx.mkLocalDecl fvarId n type bi kind
  let fvar := mkFVar fvarId
  withReader (fun ctx => { ctx with lctx := lctx }) do
    withNewFVar fvar type k

/-- Create a free variable `x` with name, binderInfo and type, add it to the context and run in `k`.
Then revert the context. -/
def withLocalDecl (name : Name) (bi : BinderInfo) (type : Expr) (k : Expr → n α) (kind : LocalDeclKind := .default) : n α :=
  map1MetaM (fun k => withLocalDeclImp name bi type k kind) k

def withLocalDeclD (name : Name) (type : Expr) (k : Expr → n α) : n α :=
  withLocalDecl name BinderInfo.default type k

/--
Similar to `withLocalDecl`, but it does **not** check whether the new variable is a local instance or not.
-/
def withLocalDeclNoLocalInstanceUpdate (name : Name) (bi : BinderInfo) (type : Expr) (x : Expr → MetaM α) : MetaM α := do
  let fvarId ← mkFreshFVarId
  withReader (fun ctx => { ctx with lctx := ctx.lctx.mkLocalDecl fvarId name type bi }) do
    x (mkFVar fvarId)

/-- Append an array of free variables `xs` to the local context and execute `k xs`.
`declInfos` takes the form of an array consisting of:
- the name of the variable
- the binder info of the variable
- a type constructor for the variable, where the array consists of all of the free variables
  defined prior to this one. This is needed because the type of the variable may depend on prior variables.

See `withLocalDeclsD` and `withLocalDeclsDND` for simpler variants.
-/
partial def withLocalDecls
    [Inhabited α]
    (declInfos : Array (Name × BinderInfo × (Array Expr → n Expr)))
    (k : (xs : Array Expr) → n α)
    : n α :=
  loop #[]
where
  loop [Inhabited α] (acc : Array Expr) : n α := do
    if acc.size < declInfos.size then
      let (name, bi, typeCtor) := declInfos[acc.size]!
      withLocalDecl name bi (←typeCtor acc) fun x => loop (acc.push x)
    else
      k acc

/--
Variant of `withLocalDecls` using `BinderInfo.default`
-/
def withLocalDeclsD [Inhabited α] (declInfos : Array (Name × (Array Expr → n Expr))) (k : (xs : Array Expr) → n α) : n α :=
  withLocalDecls
    (declInfos.map (fun (name, typeCtor) => (name, BinderInfo.default, typeCtor))) k

/--
Simpler variant of `withLocalDeclsD` for bringing variables into scope whose types do not depend
on each other.
-/
def withLocalDeclsDND [Inhabited α] (declInfos : Array (Name × Expr)) (k : (xs : Array Expr) → n α) : n α :=
  withLocalDeclsD
    (declInfos.map (fun (name, typeCtor) => (name, fun _ => pure typeCtor))) k

private def withAuxDeclImp (shortDeclName : Name) (type : Expr) (declName : Name) (k : Expr → MetaM α) : MetaM α := do
  let fvarId ← mkFreshFVarId
  let ctx ← read
  let lctx := ctx.lctx.mkAuxDecl fvarId shortDeclName type declName
  let fvar := mkFVar fvarId
  withReader (fun ctx => { ctx with lctx := lctx }) do
    withNewFVar fvar type k

/--
  Declare an auxiliary local declaration `shortDeclName : type` for elaborating recursive
  declaration `declName`, update the mapping `auxDeclToFullName`, and then execute `k`.
-/
def withAuxDecl (shortDeclName : Name) (type : Expr) (declName : Name) (k : Expr → n α) : n α :=
  map1MetaM (fun k => withAuxDeclImp shortDeclName type declName k) k

private def withNewBinderInfosImp (bs : Array (FVarId × BinderInfo)) (k : MetaM α) : MetaM α := do
  let lctx := bs.foldl (init := (← getLCtx)) fun lctx (fvarId, bi) =>
      lctx.setBinderInfo fvarId bi
  withReader (fun ctx => { ctx with lctx := lctx }) k

def withNewBinderInfos (bs : Array (FVarId × BinderInfo)) (k : n α) : n α :=
  mapMetaM (fun k => withNewBinderInfosImp bs k) k

/--
 Execute `k` using a local context where any `x` in `xs` that is tagged as
 instance implicit is treated as a regular implicit. -/
def withInstImplicitAsImplicit (xs : Array Expr) (k : MetaM α) : MetaM α := do
  let newBinderInfos ← xs.filterMapM fun x => do
    let bi ← x.fvarId!.getBinderInfo
    if bi == .instImplicit then
      return some (x.fvarId!, .implicit)
    else
      return none
  withNewBinderInfos newBinderInfos k

private def withLetDeclImp (n : Name) (type : Expr) (val : Expr) (k : Expr → MetaM α) (nondep : Bool) (kind : LocalDeclKind) : MetaM α := do
  let fvarId ← mkFreshFVarId
  let ctx ← read
  let lctx := ctx.lctx.mkLetDecl fvarId n type val nondep kind
  let fvar := mkFVar fvarId
  withReader (fun ctx => { ctx with lctx := lctx }) do
    withNewFVar fvar type k

/--
  Add the local declaration `<name> : <type> := <val>` to the local context and execute `k x`, where `x` is a new
  free variable corresponding to the `let`-declaration. After executing `k x`, the local context is restored.
-/
def withLetDecl (name : Name) (type : Expr) (val : Expr) (k : Expr → n α) (nondep : Bool := false) (kind : LocalDeclKind := .default) : n α :=
  map1MetaM (fun k => withLetDeclImp name type val k nondep kind) k

/--
Runs `k x` with the local declaration `<name> : <type> := <val>` added to the local context, where `x` is the new free variable.
Afterwards, the result is wrapped in the given `let`/`have` expression (according to the value of `nondep`).
- If `usedLetOnly := true` (the default) then the the `let`/`have` is not created if the variable is unused.
-/
def mapLetDecl [MonadLiftT MetaM n] (name : Name) (type : Expr) (val : Expr) (k : Expr → n Expr) (nondep : Bool := false) (kind : LocalDeclKind := .default) (usedLetOnly : Bool := true) : n Expr :=
  withLetDecl name type val (nondep := nondep) (kind := kind) fun x => do
    mkLetFVars (usedLetOnly := usedLetOnly) (generalizeNondepLet := false) #[x] (← k x)

def withLocalInstancesImp (decls : List LocalDecl) (k : MetaM α) : MetaM α := do
  let mut localInsts := (← read).localInstances
  let size := localInsts.size
  for decl in decls do
    unless decl.isImplementationDetail do
      if let some className ← isClass? decl.type then
        -- Ensure we don't add the same local instance multiple times.
        unless localInsts.any fun localInst => localInst.fvar.fvarId! == decl.fvarId do
          localInsts := localInsts.push { className, fvar := decl.toExpr }
  if localInsts.size == size then
    k
  else
    withReader (fun ctx => { ctx with localInstances := localInsts }) k

/-- Register any local instance in `decls` -/
def withLocalInstances (decls : List LocalDecl) : n α → n α :=
  mapMetaM <| withLocalInstancesImp decls

private def withExistingLocalDeclsImp (decls : List LocalDecl) (k : MetaM α) : MetaM α := do
  let ctx ← read
  let lctx := decls.foldl (fun (lctx : LocalContext) decl => lctx.addDecl decl) ctx.lctx
  withReader (fun ctx => { ctx with lctx := lctx }) do
    withLocalInstancesImp decls k

/--
  `withExistingLocalDecls decls k`, adds the given local declarations to the local context,
  and then executes `k`. This method assumes declarations in `decls` have valid `FVarId`s.
  After executing `k`, the local context is restored.

  Remark: this method is used, for example, to implement the `match`-compiler.
  Each `match`-alternative comes with a local declarations (corresponding to pattern variables),
  and we use `withExistingLocalDecls` to add them to the local context before we process
  them.
-/
def withExistingLocalDecls (decls : List LocalDecl) : n α → n α :=
  mapMetaM <| withExistingLocalDeclsImp decls

private def withNewMCtxDepthImp (allowLevelAssignments : Bool) (x : MetaM α) : MetaM α := do
  let saved ← get
  modify fun s => { s with mctx := s.mctx.incDepth allowLevelAssignments, postponed := {} }
  try
    x
  finally
    modify fun s => { s with mctx := saved.mctx, postponed := saved.postponed }

/--
Removes `fvarId` from the local context, and replaces occurrences of it with `e`.
It is the responsibility of the caller to ensure that `e` is well-typed in the context
of any occurrence of `fvarId`.
-/
def withReplaceFVarId {α} (fvarId : FVarId) (e : Expr) : MetaM α → MetaM α :=
  withReader fun ctx => { ctx with
    lctx := ctx.lctx.replaceFVarId fvarId e
    localInstances := ctx.localInstances.erase fvarId }

/--
`withNewMCtxDepth k` executes `k` with a higher metavariable context depth,
where metavariables created outside the `withNewMCtxDepth` (with a lower depth) cannot be assigned.
If `allowLevelAssignments` is set to true, then the level metavariable depth
is not increased, and level metavariables from the outer scope can be
assigned.  (This is used by TC synthesis.)
-/
def withNewMCtxDepth (k : n α) (allowLevelAssignments := false) : n α :=
  mapMetaM (withNewMCtxDepthImp allowLevelAssignments) k

private def withLocalContextImp (lctx : LocalContext) (localInsts : LocalInstances) (x : MetaM α) : MetaM α := do
  withReader (fun ctx => { ctx with lctx := lctx, localInstances := localInsts }) do
    x

/--
`withLCtx lctx localInsts k` replaces the local context and local instances, and then executes `k`.
The local context and instances are restored after executing `k`.
This method assumes that the local instances in `localInsts` are in the local context `lctx`.
-/
def withLCtx (lctx : LocalContext) (localInsts : LocalInstances) : n α → n α :=
  mapMetaM <| withLocalContextImp lctx localInsts

/--
Simpler version of `withLCtx` which just updates the local context. It is the responsibility of the
caller ensure the local instances are also properly updated.
-/
def withLCtx' (lctx : LocalContext) : n α → n α :=
  mapMetaM <| withReader (fun ctx => { ctx with lctx })

/--
Runs `k` in a local environment with the `fvarIds` erased.
-/
def withErasedFVars [MonadLCtx n] [MonadLiftT MetaM n] (fvarIds : Array FVarId) (k : n α) : n α := do
  let lctx ← getLCtx
  let localInsts ← getLocalInstances
  let lctx' := fvarIds.foldl (·.erase ·) lctx
  let localInsts' := localInsts.filter (!fvarIds.contains ·.fvar.fvarId!)
  withLCtx lctx' localInsts' k

private def withMVarContextImp (mvarId : MVarId) (x : MetaM α) : MetaM α := do
  let mvarDecl ← mvarId.getDecl
  withLocalContextImp mvarDecl.lctx mvarDecl.localInstances x

/--
Executes `x` using the given metavariable `LocalContext` and `LocalInstances`.
The type class resolution cache is flushed when executing `x` if its `LocalInstances` are
different from the current ones. -/
def _root_.Lean.MVarId.withContext (mvarId : MVarId) : n α → n α :=
  mapMetaM <| withMVarContextImp mvarId

private def withMCtxImp (mctx : MetavarContext) (x : MetaM α) : MetaM α := do
  let mctx' ← getMCtx
  setMCtx mctx
  try x finally setMCtx mctx'

/--
`withMCtx mctx k` replaces the metavariable context and then executes `k`.
The metavariable context is restored after executing `k`.

This method is used to implement the type class resolution procedure. -/
def withMCtx (mctx : MetavarContext) : n α → n α :=
  mapMetaM <| withMCtxImp mctx

/--
`withoutModifyingMCtx k` executes `k` and then restores the metavariable context.
-/
def withoutModifyingMCtx : n α → n α :=
  mapMetaM fun x => do
    let mctx ← getMCtx
    let cache := (← get).cache
    try
      x
    finally
      modify fun s => { s with cache, mctx }

@[inline] private def approxDefEqImp (x : MetaM α) : MetaM α :=
  withConfig (fun config => { config with foApprox := true, ctxApprox := true, quasiPatternApprox := true}) x

/-- Execute `x` using approximate unification: `foApprox`, `ctxApprox` and `quasiPatternApprox`.  -/
@[inline] def approxDefEq : n α → n α :=
  mapMetaM approxDefEqImp

@[inline] private def fullApproxDefEqImp (x : MetaM α) : MetaM α :=
  withConfig (fun config => { config with foApprox := true, ctxApprox := true, quasiPatternApprox := true, constApprox := true }) x

/--
  Similar to `approxDefEq`, but uses all available approximations.
  We don't use `constApprox` by default at `approxDefEq` because it often produces undesirable solution for monadic code.
  For example, suppose we have `pure (x > 0)` which has type `?m Prop`. We also have the goal `[Pure ?m]`.
  Now, assume the expected type is `IO Bool`. Then, the unification constraint `?m Prop =?= IO Bool` could be solved
  as `?m := fun _ => IO Bool` using `constApprox`, but this spurious solution would generate a failure when we try to
  solve `[Pure (fun _ => IO Bool)]` -/
@[inline] def fullApproxDefEq : n α → n α :=
  mapMetaM fullApproxDefEqImp

/-- Instantiate assigned universe metavariables in `u`, and then normalize it. -/
def normalizeLevel (u : Level) : MetaM Level := do
  let u ← instantiateLevelMVars u
  pure u.normalize

/-- `whnf` with reducible transparency.-/
def whnfR (e : Expr) : MetaM Expr :=
  withTransparency TransparencyMode.reducible <| whnf e

/-- `whnf` with default transparency.-/
def whnfD (e : Expr) : MetaM Expr :=
  withTransparency TransparencyMode.default <| whnf e

/-- `whnf` with instances transparency.-/
def whnfI (e : Expr) : MetaM Expr :=
  withTransparency TransparencyMode.instances <| whnf e

/-- `whnf` with at most instances transparency. -/
def whnfAtMostI (e : Expr) : MetaM Expr := do
  match (← getTransparency) with
  | .all | .default => withTransparency TransparencyMode.instances <| whnf e
  | _ => whnf e

/--
  Mark declaration `declName` with the attribute `[inline]`.
  This method does not check whether the given declaration is a definition.

  Recall that this attribute can only be set in the same module where `declName` has been declared.
-/
def setInlineAttribute (declName : Name) (kind := Compiler.InlineAttributeKind.inline): MetaM Unit := do
  let env ← getEnv
  match Compiler.setInlineAttribute env declName kind with
  | .ok env    => setEnv env
  | .error msg => throwError msg

private partial def instantiateForallAux (ps : Array Expr) (i : Nat) (e : Expr) : MetaM Expr := do
  if h : i < ps.size then
    let p := ps[i]
    match (← whnf e) with
    | .forallE _ _ b _ => instantiateForallAux ps (i+1) (b.instantiate1 p)
    | _                => throwError "invalid instantiateForall, too many parameters"
  else
    return e

/-- Given `e` of the form `forall (a_1 : A_1) ... (a_n : A_n), B[a_1, ..., a_n]` and `p_1 : A_1, ... p_n : A_n`, return `B[p_1, ..., p_n]`. -/
def instantiateForall (e : Expr) (ps : Array Expr) : MetaM Expr :=
  instantiateForallAux ps 0 e

private partial def instantiateLambdaAux (ps : Array Expr) (i : Nat) (e : Expr) : MetaM Expr := do
  if h : i < ps.size then
    let p := ps[i]
    match (← whnf e) with
    | .lam _ _ b _ => instantiateLambdaAux ps (i+1) (b.instantiate1 p)
    | _            => throwError "invalid instantiateLambda, too many parameters"
  else
    return e

/-- Given `e` of the form `fun (a_1 : A_1) ... (a_n : A_n) => t[a_1, ..., a_n]` and `p_1 : A_1, ... p_n : A_n`, return `t[p_1, ..., p_n]`.
   It uses `whnf` to reduce `e` if it is not a lambda -/
def instantiateLambda (e : Expr) (ps : Array Expr) : MetaM Expr :=
  instantiateLambdaAux ps 0 e

/--
A simpler version of `ParamInfo` for information about the parameter of a forall or lambda.
-/
structure ExprParamInfo where
  /-- The name of the parameter. -/
  name : Name
  /-- The type of the parameter. -/
  type : Expr
  /-- The binder annotation for the parameter. -/
  binderInfo : BinderInfo := BinderInfo.default
  deriving Inhabited

/--
Given `e` of the form `∀ (p₁ : P₁) … (p₁ : P₁), B[p_1,…,p_n]` and `arg₁ : P₁, …, argₙ : Pₙ`, returns
* the names `p₁, …, pₙ`,
* the binder infos,
* the binder types `P₁, P₂[arg₁], …, P[arg₁,…,argₙ₋₁]`, and
* the type `B[arg₁,…,argₙ]`.

It uses `whnf` to reduce `e` if it is not a forall.

See also `Lean.Meta.instantiateForall`.
-/
def instantiateForallWithParamInfos (e : Expr) (args : Array Expr) (cleanupAnnotations : Bool := false) :
    MetaM (Array ExprParamInfo × Expr) := do
  let mut e := e
  let mut res := Array.mkEmpty args.size
  let mut j := 0
  for i in *...args.size do
    unless e.isForall do
      e ← whnf (e.instantiateRevRange j i args)
      j := i
    match e with
    | .forallE name type e' binderInfo =>
      let type := type.instantiateRevRange j i args
      let type := if cleanupAnnotations then type.cleanupAnnotations else type
      res := res.push { name, type, binderInfo }
      e := e'
    | _ => throwError "invalid `instantiateForallWithParams`, too many parameters{indentExpr e}"
  return (res, e)

/--
Given `e` of the form `fun (p₁ : P₁) … (p₁ : P₁) => t[p_1,…,p_n]` and `arg₁ : P₁, …, argₙ : Pₙ`, returns
* the names `p₁, …, pₙ`,
* the binder infos,
* the binder types `P₁, P₂[arg₁], …, P[arg₁,…,argₙ₋₁]`, and
* the term `t[arg₁,…,argₙ]`.

It uses `whnf` to reduce `e` if it is not a lambda.

See also `Lean.Meta.instantiateLambda`.
-/
def instantiateLambdaWithParamInfos (e : Expr) (args : Array Expr) (cleanupAnnotations : Bool := false) :
    MetaM (Array ExprParamInfo × Expr) := do
  let mut e := e
  let mut res := Array.mkEmpty args.size
  let mut j := 0
  for i in *...args.size do
    unless e.isLambda do
      e ← whnf (e.instantiateRevRange j i args)
      j := i
    match e with
    | .forallE name type e' binderInfo =>
      let type := type.instantiateRevRange j i args
      let type := if cleanupAnnotations then type.cleanupAnnotations else type
      res := res.push { name, type, binderInfo }
      e := e'
    | _ => throwError "invalid `instantiateForallWithParams`, too many parameters{indentExpr e}"
  return (res, e)

/-- Pretty-print the given expression. -/
def ppExprWithInfos (e : Expr) : MetaM FormatWithInfos := do
  let ctxCore  ← readThe Core.Context
  Lean.ppExprWithInfos { env := (← getEnv), mctx := (← getMCtx), lctx := (← getLCtx), opts := (← getOptions), currNamespace := ctxCore.currNamespace, openDecls := ctxCore.openDecls } e

/-- Pretty-print the given expression. -/
def ppExpr (e : Expr) : MetaM Format := (·.fmt) <$> ppExprWithInfos e

@[inline] protected def orElse (x : MetaM α) (y : Unit → MetaM α) : MetaM α := do
  let s ← saveState
  try x catch _ => s.restore; y ()

instance : OrElse (MetaM α) := ⟨Meta.orElse⟩

instance : Alternative MetaM where
  failure := fun {_} => throwError "failed"
  orElse  := Meta.orElse

@[inline] private def orelseMergeErrorsImp (x y : MetaM α)
    (mergeRef : Syntax → Syntax → Syntax := fun r₁ _ => r₁)
    (mergeMsg : MessageData → MessageData → MessageData := fun m₁ m₂ => m₁ ++ Format.line ++ m₂) : MetaM α := do
  let env  ← getEnv
  let mctx ← getMCtx
  try
    x
  catch ex =>
    setEnv env
    setMCtx mctx
    match ex with
    | Exception.error ref₁ m₁ =>
      try
        y
      catch
        | Exception.error ref₂ m₂ => throw <| Exception.error (mergeRef ref₁ ref₂) (mergeMsg m₁ m₂)
        | ex => throw ex
    | ex => throw ex

/--
  Similar to `orelse`, but merge errors. Note that internal errors are not caught.
  The default `mergeRef` uses the `ref` (position information) for the first message.
  The default `mergeMsg` combines error messages using `Format.line ++ Format.line` as a separator. -/
@[inline] def orelseMergeErrors [MonadControlT MetaM m] [Monad m] (x y : m α)
    (mergeRef : Syntax → Syntax → Syntax := fun r₁ _ => r₁)
    (mergeMsg : MessageData → MessageData → MessageData := fun m₁ m₂ => m₁ ++ Format.line ++ Format.line ++ m₂) : m α := do
  controlAt MetaM fun runInBase => orelseMergeErrorsImp (runInBase x) (runInBase y) mergeRef mergeMsg

def mapErrorImp (x : MetaM α) (f : MessageData → MessageData) : MetaM α := do
  try
    x
  catch
    | Exception.error ref msg =>
      let msg' := f msg
      let msg' ← addMessageContext msg'
      throw <| Exception.error ref msg'
    | ex => throw ex

/-- Execute `x`, and apply `f` to the produced error message -/
@[inline] def mapError [MonadControlT MetaM m] [Monad m] (x : m α) (f : MessageData → MessageData) : m α :=
  controlAt MetaM fun runInBase => mapErrorImp (runInBase x) f

/-- Execute `x`. If it throws an error, indent and prepend `msg` to it.  -/
@[inline] def prependError [MonadControlT MetaM m] [Monad m] (msg : MessageData) (x : m α) : m α := do
  mapError x fun e => m!"{msg}{indentD e}"

/--
  Sort free variables using an order `x < y` iff `x` was defined before `y`.
  If a free variable is not in the local context, we use their id. -/
def sortFVarIds (fvarIds : Array FVarId) : MetaM (Array FVarId) := do
  let lctx ← getLCtx
  return fvarIds.qsort fun fvarId₁ fvarId₂ =>
    match lctx.find? fvarId₁, lctx.find? fvarId₂ with
    | some d₁, some d₂ => d₁.index < d₂.index
    | some _,  none    => false
    | none,    some _  => true
    | none,    none    => Name.quickLt fvarId₁.name fvarId₂.name

end Methods

/--
Return `some info` if `declName` is an inductive predicate where `info : InductiveVal`.
That is, `inductive` type in `Prop`.
-/
def isInductivePredicate? (declName : Name) : MetaM (Option InductiveVal) := do
  match (← getEnv).find? declName with
  | some (.inductInfo info) =>
    forallTelescopeReducing info.type fun _ type => do
      match (← whnfD type) with
      | .sort u .. => if u == levelZero then return some info else return none
      | _ => return none
  | _ => return none

/-- Return `true` if `declName` is an inductive predicate. That is, `inductive` type in `Prop`. -/
def isInductivePredicate (declName : Name) : MetaM Bool := do
  return (← isInductivePredicate? declName).isSome

def isListLevelDefEqAux : List Level → List Level → MetaM Bool
  | [],    []    => return true
  | u::us, v::vs => isLevelDefEqAux u v <&&> isListLevelDefEqAux us vs
  | _,     _     => return false

def getNumPostponed : MetaM Nat := do
  return (← getPostponed).size

def getResetPostponed : MetaM (PersistentArray PostponedEntry) := do
  let ps ← getPostponed
  setPostponed {}
  return ps

/-- Annotate any constant and sort in `e` that satisfies `p` with `pp.universes true` -/
private def exposeRelevantUniverses (e : Expr) (p : Level → Bool) : Expr :=
  e.replace fun e =>
    match e with
    | .const _ us => if us.any p then some (e.setPPUniverses true) else none
    | .sort u     => if p u then some (e.setPPUniverses true) else none
    | _           => none

private def mkLevelErrorMessageCore (header : String) (entry : PostponedEntry) : MetaM MessageData := do
  match entry.ctx? with
  | none =>
    return m!"{header}{indentD m!"{entry.lhs} =?= {entry.rhs}"}"
  | some ctx =>
    withLCtx ctx.lctx ctx.localInstances do
      let s   := entry.lhs.collectMVars entry.rhs.collectMVars
      /- `p u` is true if it contains a universe metavariable in `s` -/
      let p (u : Level) := u.any fun | .mvar m => s.contains m | _ => false
      let lhs := exposeRelevantUniverses (← instantiateMVars ctx.lhs) p
      let rhs := exposeRelevantUniverses (← instantiateMVars ctx.rhs) p
      try
        addMessageContext m!"{header}{indentD m!"{entry.lhs} =?= {entry.rhs}"}\nwhile trying to unify{indentD m!"{lhs} : {← inferType lhs}"}\nwith{indentD m!"{rhs} : {← inferType rhs}"}"
      catch _ =>
        addMessageContext m!"{header}{indentD m!"{entry.lhs} =?= {entry.rhs}"}\nwhile trying to unify{indentD lhs}\nwith{indentD rhs}"

def mkLevelStuckErrorMessage (entry : PostponedEntry) : MetaM MessageData := do
  mkLevelErrorMessageCore "stuck at solving universe constraint" entry

def mkLevelErrorMessage (entry : PostponedEntry) : MetaM MessageData := do
  mkLevelErrorMessageCore "failed to solve universe constraint" entry

private def processPostponedStep (exceptionOnFailure : Bool) : MetaM Bool := do
  let ps ← getResetPostponed
  for p in ps do
    unless (← withReader (fun ctx => { ctx with defEqCtx? := p.ctx? }) <| isLevelDefEqAux p.lhs p.rhs) do
      if exceptionOnFailure then
        withRef p.ref do
          throwError (← mkLevelErrorMessage p)
      else
        return false
  return true

partial def processPostponed (mayPostpone : Bool := true) (exceptionOnFailure := false) : MetaM Bool := do
  if (← getNumPostponed) == 0 then
    return true
  else
    let numPostponedBegin ← getNumPostponed
    withTraceNode `Meta.isLevelDefEq.postponed
        (fun _ => return m!"processing #{numPostponedBegin} postponed is-def-eq level constraints") do
      let rec loop : MetaM Bool := do
        let numPostponed ← getNumPostponed
        if numPostponed == 0 then
          return true
        else
          if !(← processPostponedStep exceptionOnFailure) then
            return false
          else
            let numPostponed' ← getNumPostponed
            if numPostponed' == 0 then
              return true
            else if numPostponed' < numPostponed then
              loop
            -- If we cannot postpone anymore, `Config.univApprox := true`, but we haven't tried universe approximations yet,
            -- then try approximations before failing.
            else if !mayPostpone && (← getConfig).univApprox && !(← read).univApprox then
              withReader (fun ctx => { ctx with univApprox := true }) loop
            else
              trace[Meta.isLevelDefEq.postponed] "no progress solving pending is-def-eq level constraints"
              return mayPostpone
      loop

/--
  `checkpointDefEq x` executes `x` and process all postponed universe level constraints produced by `x`.
  We keep the modifications only if `processPostponed` return true and `x` returned `true`.

  If `mayPostpone == false`, all new postponed universe level constraints must be solved before returning.
  We currently try to postpone universe constraints as much as possible, even when by postponing them we
  are not sure whether `x` really succeeded or not.
-/
@[specialize] def checkpointDefEq (x : MetaM Bool) (mayPostpone : Bool := true) : MetaM Bool := do
  let s ← saveState
  /-
    It is not safe to use the `isDefEq` cache between different `isDefEq` calls.
    Reason: different configuration settings, and result depends on the state of the `MetavarContext`
    We have tried in the past to track when the result was independent of the `MetavarContext` state
    but it was not effective. It is more important to cache aggressively inside of a single `isDefEq`
    call because some of the heuristics create many similar subproblems.
    See issue #1102 for an example that triggers an exponential blowup if we don't use this more
    aggressive form of caching.
  -/
  modifyDefEqTransientCache fun _ => {}
  let postponed ← getResetPostponed
  try
    if (← x) then
      if (← processPostponed mayPostpone) then
        let newPostponed ← getPostponed
        setPostponed (postponed ++ newPostponed)
        return true
      else
        s.restore
        return false
    else
      s.restore
      return false
  catch ex =>
    s.restore
    throw ex

/--
  Determines whether two universe level expressions are definitionally equal to each other.
-/
def isLevelDefEq (u v : Level) : MetaM Bool :=
  checkpointDefEq (mayPostpone := true) <| Meta.isLevelDefEqAux u v

/-- See `isDefEq`. -/
def isExprDefEq (t s : Expr) : MetaM Bool :=
  withReader (fun ctx => { ctx with defEqCtx? := some { lhs := t, rhs := s, lctx := ctx.lctx, localInstances := ctx.localInstances } }) do
    /-
    The following `resetDefEqPermCaches` is a workaround. Without it the test suite fails, and we probably cannot compile complex libraries such as Mathlib.
    TODO: investigate why we need this reset.
    Some conjectures:
    - It is not enough to check whether `t` and `s` do not contain metavariables. We would need to check the type
      of all local variables `t` and `s` depend on. If the local variables contain metavariables, the result of `isDefEq` may change if these
      variables are instantiated.
    - Related to the previous one: the operation
      ```lean
      _root_.Lean.MVarId.replaceLocalDeclDefEq (mvarId : MVarId) (fvarId : FVarId) (typeNew : Expr)
      ```
      is probably being misused. We are probably using it to replace a `type` with `typeNew` where these two types
      are definitionally equal IFF we can assign the metavariables in `type`.

    Possible fix: always generate new `FVarId`s when update the type of local variables.
    Drawback: this operation can be quite expensive, and we must evaluate whether it is worth doing to remove the following `reset`.

    Remark: the kernel does *not* update the type of variables in the local context.
    -/
    resetDefEqPermCaches
    checkpointDefEq (mayPostpone := true) <| Meta.isExprDefEqAux t s

/--
  Determines whether two expressions are definitionally equal to each other.

  To control how metavariables are assigned and unified, metavariables and their context have a "depth".
  Given a metavariable `?m` and a `MetavarContext` `mctx`, `?m` is not assigned if `?m.depth != mctx.depth`.
  The combinator `withNewMCtxDepth x` will bump the depth while executing `x`.
  So, `withNewMCtxDepth (isDefEq a b)` is `isDefEq` without any mvar assignment happening
  whereas `isDefEq a b` will assign any metavariables of the current depth in `a` and `b` to unify them.

  For matching (where only mvars in `b` should be assigned), we create the term inside the `withNewMCtxDepth`.
  For an example, see [Lean.Meta.Simp.tryTheoremWithExtraArgs?](https://github.com/leanprover/lean4/blob/master/src/Lean/Meta/Tactic/Simp/Rewrite.lean#L100-L106)
 -/
abbrev isDefEq (t s : Expr) : MetaM Bool :=
  isExprDefEq t s

def isExprDefEqGuarded (a b : Expr) : MetaM Bool := do
  try isExprDefEq a b catch _ => return false

/-- Similar to `isDefEq`, but returns `false` if an exception has been thrown. -/
abbrev isDefEqGuarded (t s : Expr) : MetaM Bool :=
  isExprDefEqGuarded t s

def isDefEqNoConstantApprox (t s : Expr) : MetaM Bool :=
  approxDefEq <| isDefEq t s

/--
Returns `true` if `mvarId := val` was successfully assigned.
This method uses the same assignment validation performed by `isDefEq`, but it does not check whether the types match.
-/
-- Remark: this method is implemented at `ExprDefEq`
@[extern "lean_checked_assign"]
opaque _root_.Lean.MVarId.checkedAssign (mvarId : MVarId) (val : Expr) : MetaM Bool

/--
  Eta expand the given expression.
  Example:
  ```
  etaExpand (mkConst ``Nat.add)
  ```
  produces `fun x y => Nat.add x y`
-/
def etaExpand (e : Expr) : MetaM Expr :=
  withDefault do forallTelescopeReducing (← inferType e) fun xs _ => mkLambdaFVars xs (mkAppN e xs)

/--
If `e` is of the form `?m ...` instantiate metavars
-/
def instantiateMVarsIfMVarApp (e : Expr) : MetaM Expr := do
  if e.getAppFn.isMVar then
    instantiateMVars e
  else
    return e

def instantiateMVarsProfiling (e : Expr) : MetaM Expr := do
  profileitM Exception s!"instantiate metavars" (← getOptions) do
  withTraceNode `Meta.instantiateMVars (fun _ => pure e) do
    instantiateMVars e

private partial def setAllDiagRanges (snap : Language.SnapshotTree) (pos endPos : Position) :
    BaseIO Language.SnapshotTree := do
  let msgLog := snap.element.diagnostics.msgLog
  let msgLog := { msgLog with unreported := msgLog.unreported.map fun diag =>
      { diag with pos, endPos } }
  return {
    element.diagnostics := (← Language.Snapshot.Diagnostics.ofMessageLog msgLog)
    children := (← snap.children.mapM fun task => return { task with
      stx? := none
      task := (← BaseIO.mapTask (t := task.task) (setAllDiagRanges · pos endPos)) })
  }

open Language

private structure RealizeConstantResult where
  snap       : SnapshotTree
  error? : Option Exception
deriving TypeName

/--
Makes the helper constant `constName` that is derived from `forConst` available in the environment.
`enableRealizationsForConst forConst` must have been called first on this environment branch. If
this is the first environment branch requesting `constName` to be realized (atomically), `realize`
is called with the environment and options at the time of calling `enableRealizationsForConst` if
`forConst` is from the current module and the state just after importing  otherwise, thus helping
achieve deterministic results despite the non-deterministic choice of which thread is tasked with
realization. In other words, the state after calling `realizeConst` is *as if* `realize` had been
called immediately after `enableRealizationsForConst forConst`, though the effects of this call are
visible only after calling `realizeConst`. See below for more details on the replayed effects.

`realizeConst` cannot check what other data is captured in the `realize` closure,
so it is best practice to extract it into a separate function and pay close attention to the passed
arguments, if any. `realize` must return with `constName` added to the environment,
at which point all callers of `realizeConst` with this `constName` will be unblocked
and have access to an updated version of their own environment containing any new constants
`realize` added, including recursively realized constants. Traces, diagnostics, and raw std stream
output are reported at all callers via `Core.logSnapshotTask` (so that the location of generated
diagnostics is deterministic). Note that, as `realize` is run using the options at declaration time
of `forConst`, trace options must be set prior to that (or, for imported constants, on the cmdline)
in order to be active. The environment extension state at the end of `realize` is available to each
caller via `EnvExtension.findStateAsync` for `constName`. If `realize` throws an exception or fails
to add `constName` to the environment, an appropriate diagnostic is reported to all callers but no
constants are added to the environment.
-/
def realizeConst (forConst : Name) (constName : Name) (realize : MetaM Unit) :
    MetaM Unit := do
  let env ← getEnv
  -- If `constName` is already known on this branch, avoid the trace node. We should not use
  -- `contains` as it could block as well as find realizations on other branches, which would lack
  -- the relevant local environment extension state when accessed on this branch.
  if env.containsOnBranch constName then
    return
  withTraceNode `Meta.realizeConst (fun _ => return constName) do
    let coreCtx ← readThe Core.Context
    let coreCtx := {
      -- these fields should be invariant throughout the file
      fileName := coreCtx.fileName, fileMap := coreCtx.fileMap
      -- heartbeat limits inside `realizeAndReport` should be measured from this point on
      initHeartbeats := (← IO.getNumHeartbeats)
    }
    let (env, exTask, dyn) ← env.realizeConst forConst constName (realizeAndReport coreCtx)
    -- Realizations cannot be cancelled as their result is shared across elaboration runs
    let exAct ← Core.wrapAsyncAsSnapshot (cancelTk? := none) fun
      | none => return
      | some ex => do
        logError <| ex.toMessageData (← getOptions)
    Core.logSnapshotTask {
      stx? := none
      task := (← BaseIO.mapTask (t := exTask) exAct)
      cancelTk? := none
    }
    if let some res := dyn.get? RealizeConstantResult then
      let mut snap := res.snap
      -- localize diagnostics
      if let some range := (← getRef).getRange? then
        let fileMap ← getFileMap
        snap ← setAllDiagRanges snap (fileMap.toPosition range.start) (fileMap.toPosition range.stop)
      Core.logSnapshotTask <| .finished (stx? := none) snap
      if let some e := res.error? then
        throw e
    setEnv env
where
  -- similar to `wrapAsyncAsSnapshot` but not sufficiently so to share code
  realizeAndReport (coreCtx : Core.Context) env opts := do
    let coreCtx := { coreCtx with options := opts }
    let act :=
      IO.FS.withIsolatedStreams (isolateStderr := Core.stderrAsMessages.get opts) (do
        -- catch all exceptions
        let _ : MonadExceptOf _ MetaM := MonadAlwaysExcept.except
        observing do
          realize
          -- Meta code working on a non-exported declaration should usually do so inside
          -- `withoutExporting` but we're lenient here in case this call is the only one that needs
          -- the setting.
          if !((← getEnv).setExporting false).contains constName then
            throwError "Lean.Meta.realizeConst: {constName} was not added to the environment")
        <* addTraceAsMessages
    let res? ← act |>.run' |>.run coreCtx { env } |>.toBaseIO
    match res? with
    | .ok ((output, err?), st) => pure (st.env, .mk {
      snap := (← Core.mkSnapshot output coreCtx st)
      error? := match err? with
        | .ok ()   => none
        | .error e => some e
      : RealizeConstantResult
    })
    | _ =>
      let _ : Inhabited (Environment × Dynamic) := ⟨env, .mk {
        snap := (← Core.mkSnapshot "" coreCtx { env })
        error? := none
        : RealizeConstantResult
      }⟩
      unreachable!

end Meta

open Meta

namespace PPContext

def runCoreM {α : Type} (ppCtx : PPContext) (x : CoreM α) : IO α :=
  Prod.fst <$> x.toIO { options := ppCtx.opts, currNamespace := ppCtx.currNamespace
                        openDecls := ppCtx.openDecls
                        fileName := "<PrettyPrinter>", fileMap := default
                        diag     := getDiag ppCtx.opts }
                      { env := ppCtx.env, ngen := { namePrefix := `_pp_uniq } }

def runMetaM {α : Type} (ppCtx : PPContext) (x : MetaM α) : IO α :=
  ppCtx.runCoreM <| x.run' { lctx := ppCtx.lctx } { mctx := ppCtx.mctx }

end PPContext

/--
Turns a `MetaM MessageData` into a `MessageData.lazy` which will run the monadic value.
The optional array of expressions is used to set the `hasSyntheticSorry` fields, and should
comprise the expressions that are included in the message data.
-/
def MessageData.ofLazyM (f : MetaM MessageData) (es : Array Expr := #[]) : MessageData :=
  .lazy
    (f := fun ppctxt => do
      match (← ppctxt.runMetaM f |>.toBaseIO) with
      | .ok fmt => return fmt
      | .error ex => return m!"[Error pretty printing: {ex}]"
      )
    (hasSyntheticSorry := fun mvarctxt => es.any (fun a =>
        instantiateMVarsCore mvarctxt a |>.1.hasSyntheticSorry
    ))

builtin_initialize
  registerTraceClass `Meta.isLevelDefEq.postponed
  registerTraceClass `Meta.realizeConst

export Meta (MetaM)

end Lean
