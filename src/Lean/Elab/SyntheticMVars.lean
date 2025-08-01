/-
Copyright (c) 2020 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura, Sebastian Ullrich
-/
module

prelude
public import Lean.Meta.Tactic.Util
public import Lean.Util.NumObjs
public import Lean.Util.ForEachExpr
public import Lean.Util.OccursCheck
public import Lean.Elab.Tactic.Basic
public import Lean.Meta.AbstractNestedProofs

public section

namespace Lean.Elab.Term
open Tactic (TacticM evalTactic getUnsolvedGoals withTacticInfoContext)
open Meta

/-- Auxiliary function used to implement `synthesizeSyntheticMVars`. -/
private def resumeElabTerm (stx : Syntax) (expectedType? : Option Expr) (errToSorry := true) : TermElabM Expr :=
  -- Remark: if `ctx.errToSorry` is already false, then we don't enable it. Recall tactics disable `errToSorry`
  withReader (fun ctx => { ctx with errToSorry := ctx.errToSorry && errToSorry }) do
    elabTerm stx expectedType? false

/--
  Try to elaborate `stx` that was postponed by an elaboration method using `Exception.postpone`.
  It returns `true` if it succeeded, and `false` otherwise.
  It is used to implement `synthesizeSyntheticMVars`. -/
private def resumePostponed (savedContext : SavedContext) (stx : Syntax) (mvarId : MVarId) (postponeOnError : Bool) : TermElabM Bool :=
  withRef stx <| mvarId.withContext do
    let s ← saveState
    try
      withSavedContext savedContext do
        let mvarDecl     ← getMVarDecl mvarId
        let expectedType ← instantiateMVars mvarDecl.type
        withInfoHole mvarId do
          let result ← resumeElabTerm stx expectedType (!postponeOnError)
          /- We must ensure `result` has the expected type because it is the one expected by the method that postponed stx.
            That is, the method does not have an opportunity to check whether `result` has the expected type or not. -/
          let result ← withRef stx <| ensureHasType expectedType result
          /- We must perform `occursCheck` here since `result` may contain `mvarId` when it has synthetic `sorry`s. -/
          if (← occursCheck mvarId result) then
            mvarId.assign result
            return true
          else
            return false
    catch
     | ex@(.internal id _) =>
       if id == postponeExceptionId then
         s.restore (restoreInfo := true)
         return false
       else
         throw ex
     | ex@(.error ..) =>
       if postponeOnError then
         s.restore (restoreInfo := true)
         return false
       else
         logException ex
         return true

/--
  Similar to `synthesizeInstMVarCore`, but makes sure that `instMVar` local context and instances
  are used. It also logs any error message produced. -/
private def synthesizePendingInstMVar (instMVar : MVarId) (extraErrorMsg? : Option MessageData := none): TermElabM Bool :=
  instMVar.withContext do
    try
      synthesizeInstMVarCore instMVar (extraErrorMsg? := extraErrorMsg?)
    catch
      | ex@(.error ..) => logException ex; return true
      | _              => unreachable!

/--
  Try to synthesize `mvarId` by starting using a default instance with the given priority.
  This method succeeds only if the metavariable of fully synthesized.

  Remark: In the past, we would return a list of pending TC problems, but this was problematic since
  a default instance may create subproblems that cannot be solved.

  Remark: The new approach also has limitations because other pending metavariables are not taken into account
  while backtracking. That is, we fail to synthesize `mvarId` because we reach subproblems that are stuck,
  but we could "unstuck" them if we tried to solve other pending metavariables. Considering all pending metavariables
  into a single backtracking search seems to be too expensive, and potentially generate incomprehensible error messages.
  This is particularly true if we consider pending metavariables for "postponed" elaboration steps.
  Here is an example that demonstrate this issue. The example considers we are using the old `binrel%` elaborator which was
  disconnected from `binop%`.
  ```
  example (a : Int) (b c : Nat) : a = ↑b - ↑c := sorry
  ```
  We have two pending coercions for the `↑` and `HSub ?m.220 ?m.221 ?m.222`.
  When we did not use a backtracking search here, then the homogeneous default instance for `HSub`.
  ```
  instance [Sub α] : HSub α α α where
  ```
  would be applied first, and would propagate the expected type `Int` to the pending coercions which would now be unblocked.

  Instead of performing a backtracking search that considers all pending metavariables, we improved the `binrel%` elaborator.
-/
private partial def synthesizeUsingDefaultPrio (mvarId : MVarId) (prio : Nat) : TermElabM Bool :=
  mvarId.withContext do
    let mvarType ← mvarId.getType
    match (← isClass? mvarType) with
    | none => return false
    | some className =>
      match (← getDefaultInstances className) with
      | [] => return false
      | defaultInstances =>
        for (defaultInstance, instPrio) in defaultInstances do
          if instPrio == prio then
            if (← synthesizeUsingDefaultInstance mvarId defaultInstance) then
              return true
        return false
where
  synthesizeUsingDefault (mvarId : MVarId) : TermElabM Bool := do
    for prio in (← getDefaultInstancesPriorities) do
      if (← synthesizeUsingDefaultPrio mvarId prio) then
        return true
    return false

  synthesizePendingInstMVar' (mvarId : MVarId) : TermElabM Bool :=
    commitWhen <| mvarId.withContext do
      try
        synthesizeInstMVarCore mvarId
      catch _ =>
        return false

  synthesizeUsingInstancesStep (mvarIds : List MVarId) : TermElabM (List MVarId) :=
    mvarIds.filterM fun mvarId => do
      if (← synthesizePendingInstMVar' mvarId) then
        return false
      else
        return true

  synthesizeUsingInstances (mvarIds : List MVarId) : TermElabM (List MVarId) := do
    let mvarIds' ← synthesizeUsingInstancesStep mvarIds
    if mvarIds'.length < mvarIds.length then
      synthesizeUsingInstances mvarIds'
    else
      return mvarIds'

  synthesizeUsingDefaultInstance (mvarId : MVarId) (defaultInstance : Name) : TermElabM Bool :=
    commitWhen do
      let candidate ← mkConstWithFreshMVarLevels defaultInstance
      let (mvars, bis, _) ← forallMetaTelescopeReducing (← inferType candidate)
      let candidate := mkAppN candidate mvars
      trace[Elab.defaultInstance] "{toString (mkMVar mvarId)}, {mkMVar mvarId} : {← inferType (mkMVar mvarId)} =?= {candidate} : {← inferType candidate}"
      /- The `coeAtOutParam` feature may mark output parameters of local instances as `syntheticOpaque`.
         This kind of parameter is not assignable by default. We use `withAssignableSyntheticOpaque` to workaround this behavior
         when processing default instances. TODO: try to avoid `withAssignableSyntheticOpaque`. -/
      if (← withAssignableSyntheticOpaque <| isDefEqGuarded (mkMVar mvarId) candidate) then
        -- Succeeded. Collect new TC problems
        trace[Elab.defaultInstance] "isDefEq worked {mkMVar mvarId} : {← inferType (mkMVar mvarId)} =?= {candidate} : {← inferType candidate}"
        let mut pending := []
        for h : i in *...bis.size do
          if bis[i] == BinderInfo.instImplicit then
            pending := mvars[i]!.mvarId! :: pending
        synthesizePending pending
      else
        return false

  synthesizeSomeUsingDefault? (mvarIds : List MVarId) : TermElabM (Option (List MVarId)) := do
    match mvarIds with
    | [] => return none
    | mvarId :: mvarIds =>
      if (← synthesizeUsingDefault mvarId) then
        return mvarIds
      else if let some mvarIds' ← synthesizeSomeUsingDefault? mvarIds then
        return mvarId :: mvarIds'
      else
        return none

  synthesizePending (mvarIds : List MVarId) : TermElabM Bool := do
    let mvarIds ← synthesizeUsingInstances mvarIds
    if mvarIds.isEmpty then return true
    let some mvarIds ← synthesizeSomeUsingDefault? mvarIds | return false
    synthesizePending mvarIds

/-- Used to implement `synthesizeUsingDefault`. This method only consider default instances with the given priority. -/
private def synthesizeSomeUsingDefaultPrio (prio : Nat) : TermElabM Bool := do
  let rec visit (pendingMVars : List MVarId) (pendingMVarsNew : List MVarId) : TermElabM Bool := do
    match pendingMVars with
    | [] => return false
    | mvarId :: pendingMVars =>
      let some mvarDecl ← getSyntheticMVarDecl? mvarId | visit pendingMVars (mvarId :: pendingMVarsNew)
      match mvarDecl.kind with
      | .typeClass .. => -- TODO: use `errorMsg?` in `typeClass`.
        if (← withRef mvarDecl.stx <| synthesizeUsingDefaultPrio mvarId prio) then
          modify fun s => { s with pendingMVars := pendingMVars.reverse ++ pendingMVarsNew }
          return true
        else
          visit pendingMVars (mvarId :: pendingMVarsNew)
      | _ => visit pendingMVars (mvarId :: pendingMVarsNew)
  /- Recall that s.pendingMVars is essentially a stack. The first metavariable was the last one created.
     We want to apply the default instance in reverse creation order. Otherwise,
     `toString 0` will produce a `OfNat String _` cannot be synthesized error. -/
  visit (← get).pendingMVars.reverse []

/--
  Apply default value to any pending synthetic metavariable of kind `SyntheticMVarKind.withDefault`
  Return true if something was synthesized. -/
private def synthesizeUsingDefault : TermElabM Bool := do
  let prioSet ← getDefaultInstancesPriorities
  /- Recall that `prioSet` is stored in descending order -/
  for prio in prioSet do
    if (← synthesizeSomeUsingDefaultPrio prio) then
      return true
  return false

/--
We use this method to report typeclass (and coercion) resolution problems that are "stuck".
That is, there is nothing else to do, and we don't have enough information to synthesize them using TC resolution.
-/
def reportStuckSyntheticMVar (mvarId : MVarId) (ignoreStuckTC := false) : TermElabM Unit := do
  let some mvarSyntheticDecl ← getSyntheticMVarDecl? mvarId | return ()
  withRef mvarSyntheticDecl.stx do
    match mvarSyntheticDecl.kind with
    | .typeClass extraErrorMsg? =>
      let extraErrorMsg := extraMsgToMsg extraErrorMsg?
      unless ignoreStuckTC do
        mvarId.withContext do
          let mvarDecl ← getMVarDecl mvarId
          unless (← MonadLog.hasErrors) do
            throwError "typeclass instance problem is stuck, it is often due to metavariables{indentExpr mvarDecl.type}{extraErrorMsg}"
    | .coe header expectedType e f? mkErrorMsg? =>
      mvarId.withContext do
        if let some mkErrorMsg := mkErrorMsg? then
          throwError (← mkErrorMsg mvarId expectedType e)
        else
          throwTypeMismatchError header expectedType (← inferType e) e f?
            m!"failed to create type class instance for{indentExpr (← getMVarDecl mvarId).type}"
    | .tactic (ctx := savedContext) (delayOnMVars := true) .. =>
      withSavedContext savedContext do
        mvarId.withContext do
          let mvarDecl ← getMVarDecl mvarId
          throwError "tactic execution is stuck, goal contains metavariables{indentExpr mvarDecl.type}"
    | _ => unreachable! -- TODO handle other cases.

/--
  Report an error for each synthetic metavariable that could not be resolved.
  Remark: we set `ignoreStuckTC := true` when elaborating `simp` arguments.
-/
private def reportStuckSyntheticMVars (ignoreStuckTC := false) : TermElabM Unit := do
  let pendingMVars ← modifyGet fun s => (s.pendingMVars, { s with pendingMVars := [] })
  for mvarId in pendingMVars do
    reportStuckSyntheticMVar mvarId ignoreStuckTC

private def getSomeSyntheticMVarsRef : TermElabM Syntax := do
  for mvarId in (← get).pendingMVars do
    if let some decl ← getSyntheticMVarDecl? mvarId then
      if decl.stx.getPos?.isSome then
        return decl.stx
  return .missing

/--
  Generate an nicer error message for stuck universe constraints.
-/
private def throwStuckAtUniverseCnstr : TermElabM Unit := do
  -- This code assumes `entries` is not empty. Note that `processPostponed` uses `exceptionOnFailure` to guarantee this property
  let entries ← getPostponed
  let mut found : Std.HashSet (Level × Level) := {}
  let mut uniqueEntries := #[]
  for entry in entries do
    let mut lhs := entry.lhs
    let mut rhs := entry.rhs
    if Level.normLt rhs lhs then
      (lhs, rhs) := (rhs, lhs)
    unless found.contains (lhs, rhs) do
      found := found.insert (lhs, rhs)
      uniqueEntries := uniqueEntries.push entry
  for h : i in 1...uniqueEntries.size do
    logErrorAt uniqueEntries[i].ref (← mkLevelStuckErrorMessage uniqueEntries[i]!)
  throwErrorAt uniqueEntries[0]!.ref (← mkLevelStuckErrorMessage uniqueEntries[0]!)

/--
  Try to solve postponed universe constraints, and throws an exception if there are stuck constraints.

  Remark: in previous versions, each `isDefEq u v` invocation would fail if there
  were pending universe level constraints. With this old approach, we were not able
  to process
  ```
  Functor.map Prod.fst (x s)
  ```
  because after elaborating `Prod.fst` and trying to ensure its type
  match the expected one, we would be stuck at the universe constraint:
  ```
  u =?= max u ?v
  ```
  Another benefit of using `withoutPostponingUniverseConstraints` is better error messages. Instead
  of getting a mysterious type mismatch constraint, we get a list of
  universe constraints the system is stuck at.
-/
private def processPostponedUniverseConstraints : TermElabM Unit := do
  unless (← processPostponed (mayPostpone := false) (exceptionOnFailure := true)) do
    throwStuckAtUniverseCnstr

/--
  Remove `mvarId` from the `syntheticMVars` table. We use this method after
  the metavariable has been synthesized.
-/
private def markAsResolved (mvarId : MVarId) : TermElabM Unit :=
  modify fun s => { s with syntheticMVars := s.syntheticMVars.erase mvarId }

/--
Auxiliary type for `synthesizeSyntheticMVars`. It specifies
whether pending synthetic metavariables can be postponed or not.
-/
inductive PostponeBehavior where
  /--
  Any kind of pending synthetic metavariable can be postponed.
  Universe constrains may also be postponed.
  -/
  | yes
  /--
  Pending synthetic metavariables cannot be postponed.
  -/
  | no
  /--
  Synthetic metavariables associated with type class resolution can be postponed.
  Motivation: this kind of metavariable are not synthetic opaque, and can be assigned by `isDefEq`.
  Universe constraints can also be postponed.
  -/
  | «partial»
  deriving Inhabited, Repr, BEq

def PostponeBehavior.ofBool : Bool → PostponeBehavior
  | true  => .yes
  | false => .no

private def TacticMVarKind.logError (tacticCode : Syntax) (kind : TacticMVarKind) : TermElabM Unit := do
  match kind with
  | term => pure ()
  | autoParam argName => logErrorAt tacticCode m!"could not synthesize default value for parameter '{argName}' using tactics"
  | fieldAutoParam fieldName structName => logErrorAt tacticCode m!"could not synthesize default value for field '{fieldName}' of '{structName}' using tactics"

private def TacticMVarKind.maybeWithoutRecovery (kind : TacticMVarKind) (m : TacticM α) : TacticM α := do
  if kind matches .autoParam .. | .fieldAutoParam .. then
    withoutErrToSorry <| Tactic.withoutRecover <| m
  else
    m

mutual

  /--
  Try to synthesize a term `val` using the tactic code `tacticCode`, and then assign `mvarId := val`.

  The `tacticCode` syntax comprises the whole `by ...` expression.

  If `report := false`, then `runTactic` will not capture exceptions nor will report unsolved goals. Unsolved goals become exceptions.
  -/
  partial def runTactic (mvarId : MVarId) (tacticCode : Syntax) (kind : TacticMVarKind) (report := true) : TermElabM Unit := withoutAutoBoundImplicit do
    let wasExporting := (← getEnv).isExporting
    -- exit exporting context if entering proof
    let isNoLongerExporting ← pure wasExporting <&&> do
      mvarId.withContext do
        isProp (← mvarId.getType)
    instantiateMVarDeclMVars mvarId
    -- When exiting exporting context, use fresh mvar for running tactics and abstract it into an
    -- aux theorem in the end so that we cannot leak references to private decls into the exporting
    -- context.
    let mut mvarId' := mvarId
    if isNoLongerExporting then
      let mvarDecl ← getMVarDecl mvarId
      mvarId' := (← mkFreshExprMVarAt mvarDecl.lctx mvarDecl.localInstances mvarDecl.type mvarDecl.kind).mvarId!
    withExporting (isExporting := wasExporting && !isNoLongerExporting) do
    /-
    TODO: consider using `runPendingTacticsAt` at `mvarId` local context and target type.
    Issue #1380 demonstrates that the goal may still contain pending metavariables.
    It happens in the following scenario we have a term `foo A (by tac)` where `A` has been postponed
    and contains nested `by ...` terms. The pending metavar list contains two metavariables: ?m1 (for `A`) and
    `?m2` (for `by tac`). When `A` is resumed, it creates a new metavariable `?m3` for the nested `by ...` term in `A`.
    `?m3` is after `?m2` in the to-do list. Then, we execute `by tac` for synthesizing `?m2`, but its type depends on
    `?m3`. We have considered putting `?m3` at `?m2` place in the to-do list, but this is not super robust.
    The ideal solution is to make sure a tactic "resolves" all pending metavariables nested in their local context and target type
    before starting tactic execution. The procedure would be a generalization of `runPendingTacticsAt`. We can try to combine
    it with `instantiateMVarDeclMVars` to make sure we do not perform two traversals.
    Regarding issue #1380, we addressed the issue by avoiding the elaboration postponement step. However, the same issue can happen
    in more complicated scenarios.
    -/
    tryCatchRuntimeEx
      (do let remainingGoals ← withInfoHole mvarId <| Tactic.run mvarId' <| kind.maybeWithoutRecovery do
            withTacticInfoContext tacticCode do
              -- also put an info node on the `by` keyword specifically -- the token may be `canonical` and thus shown in the info
              -- view even though it is synthetic while a node like `tacticCode` never is (#1990)
              withTacticInfoContext tacticCode[0] do
                withNarrowedArgTacticReuse (argIdx := 1) (evalTactic ·) tacticCode
            -- Pending tactic mvars may escape from `evalTactic` to here (#4436), so make sure
            -- incrementality is disabled so they cannot be confused for top-level tactic blocks
            withoutTacticIncrementality true do
              synthesizeSyntheticMVars (postpone := .no)
          unless remainingGoals.isEmpty do
            if report then
              kind.logError tacticCode
              reportUnsolvedGoals remainingGoals
            else
              throwError "unsolved goals\n{goalsToMessageData remainingGoals}"
          if isNoLongerExporting then
            let mut e ← instantiateExprMVars (.mvar mvarId')
            if !e.isFVar then
              e ← mvarId'.withContext do
                withExporting (isExporting := wasExporting) do
                  abstractProof e
            mvarId.assign e)
      fun ex => do
        if report then
          kind.logError tacticCode
        if report && (← read).errToSorry then
          for mvarId in (← getMVars (mkMVar mvarId')) do
            mvarId.admit
          logException ex
        else
          throw ex

  /-- Try to synthesize the given pending synthetic metavariable. -/
  private partial def synthesizeSyntheticMVar (mvarId : MVarId) (postponeOnError : Bool) (runTactics : Bool) : TermElabM Bool := do
    let some mvarSyntheticDecl ← getSyntheticMVarDecl? mvarId | return true -- The metavariable has already been synthesized
    withRef mvarSyntheticDecl.stx do
    match mvarSyntheticDecl.kind with
    | .typeClass extraErrorMsg? => synthesizePendingInstMVar mvarId extraErrorMsg?
    | .coe _header? expectedType e _f? _ => mvarId.withContext do
      if (← withDefault do isDefEq (← inferType e) expectedType) then
        -- Types may be defeq now due to mvar assignments, type class
        -- defaulting, etc.
        if (← occursCheck mvarId e) then
          mvarId.assign e
          return true
      if let .some coerced ← coerce? e expectedType then
        if (← occursCheck mvarId coerced) then
          mvarId.assign coerced
          return true
      return false
    -- NOTE: actual processing at `synthesizeSyntheticMVarsAux`
    | .postponed savedContext => resumePostponed savedContext mvarSyntheticDecl.stx mvarId postponeOnError
    | .tactic tacticCode savedContext kind delayOnMVars =>
      withSavedContext savedContext do
        if runTactics && !(delayOnMVars && (← mvarId.getType >>= instantiateExprMVars).hasExprMVar) then
          runTactic mvarId tacticCode kind
          return true
        else
          return false
  /--
    Try to synthesize the current list of pending synthetic metavariables.
    Return `true` if at least one of them was synthesized. -/
  private partial def synthesizeSyntheticMVarsStep (postponeOnError : Bool) (runTactics : Bool) : TermElabM Bool := do
    let ctx ← read
    traceAtCmdPos `Elab.resuming fun _ =>
      m!"resuming synthetic metavariables, mayPostpone: {ctx.mayPostpone}, postponeOnError: {postponeOnError}"
    let pendingMVars    := (← get).pendingMVars
    let numSyntheticMVars := pendingMVars.length
    -- We reset `pendingMVars` because new synthetic metavariables may be created by `synthesizeSyntheticMVar`.
    modify fun s => { s with pendingMVars := [] }
    -- Recall that `pendingMVars` is a list where head is the most recent pending synthetic metavariable.
    -- We use `filterRevM` instead of `filterM` to make sure we process the synthetic metavariables using the order they were created.
    -- It would not be incorrect to use `filterM`.
    let remainingPendingMVars ← pendingMVars.filterRevM fun mvarId => do
       -- We use `traceM` because we want to make sure the metavar local context is used to trace the message
       traceM `Elab.postpone (mvarId.withContext do addMessageContext m!"resuming {mkMVar mvarId}")
       let succeeded ← synthesizeSyntheticMVar mvarId postponeOnError runTactics
       if succeeded then markAsResolved mvarId
       trace[Elab.postpone] if succeeded then format "succeeded" else format "not ready yet"
       pure !succeeded
    -- Merge new synthetic metavariables with `remainingPendingMVars`, i.e., metavariables that still couldn't be synthesized
    modify fun s => { s with pendingMVars := s.pendingMVars ++ remainingPendingMVars }
    return numSyntheticMVars != remainingPendingMVars.length

  /--
    Try to process pending synthetic metavariables.

    If `postpone == .no`,then `pendingMVars` is `[]` after executing this method.
    If `postpone == .partial`, then `pendingMVars` contains only `.tc` and `.coe` kinds.

    It keeps executing `synthesizeSyntheticMVarsStep` while progress is being made.
    If `postpone != .yes`, then it applies default instances to `SyntheticMVarKind.typeClass` (if available)
    metavariables that are still unresolved, and then tries to resolve metavariables
    with `postponeOnError == false`. That is, we force them to produce error messages and/or commit to
    a "best option". If, after that, we still haven't made progress, we report "stuck" errors If `postpone == .no`.

    Remark: we set `ignoreStuckTC := true` when elaborating `simp` arguments. Then,
    pending TC problems become implicit parameters for the simp theorem.
  -/
  partial def synthesizeSyntheticMVars (postpone := PostponeBehavior.yes) (ignoreStuckTC := false) : TermElabM Unit := do
    let rec loop (_ : Unit) : TermElabM Unit := do
      withRef (← getSomeSyntheticMVarsRef) <| withIncRecDepth do
        unless (← get).pendingMVars.isEmpty do
          if ← synthesizeSyntheticMVarsStep (postponeOnError := false) (runTactics := false) then
            loop ()
          else if postpone != .yes then
            /- Resume pending metavariables with "elaboration postponement" disabled.
               We postpone elaboration errors in this step by setting `postponeOnError := true`.
               Example:
               ```
               #check let x := ⟨1, 2⟩; Prod.fst x
               ```
               The term `⟨1, 2⟩` can't be elaborated because the expected type is not know.
               The `x` at `Prod.fst x` is not elaborated because the type of `x` is not known.
               When we execute the following step with "elaboration postponement" disabled,
               the elaborator fails at `⟨1, 2⟩` and postpones it, and succeeds at `x` and learns
               that its type must be of the form `Prod ?α ?β`.

               Recall that we postponed `x` at `Prod.fst x` because its type it is not known.
               We the type of `x` may learn later its type and it may contain implicit and/or auto arguments.
               By disabling postponement, we are essentially giving up the opportunity of learning `x`s type
               and assume it does not have implicit and/or auto arguments. -/
            if ← withoutPostponing <| synthesizeSyntheticMVarsStep (postponeOnError := true) (runTactics := false) then
              loop ()
            else if ← synthesizeUsingDefault then
              loop ()
            else if ← withoutPostponing <| synthesizeSyntheticMVarsStep (postponeOnError := false) (runTactics := false) then
              loop ()
            else if ← synthesizeSyntheticMVarsStep (postponeOnError := false) (runTactics := true) then
              loop ()
            else if postpone == .no then
              reportStuckSyntheticMVars ignoreStuckTC
    loop ()
    if postpone == .no then
     processPostponedUniverseConstraints
end

def synthesizeSyntheticMVarsNoPostponing (ignoreStuckTC := false) : TermElabM Unit :=
  synthesizeSyntheticMVars (postpone := .no) (ignoreStuckTC := ignoreStuckTC)

/-- Keep invoking `synthesizeUsingDefault` until it returns false. -/
private partial def synthesizeUsingDefaultLoop : TermElabM Unit := do
  if (← synthesizeUsingDefault) then
    synthesizeSyntheticMVars (postpone := .yes)
    synthesizeUsingDefaultLoop

def synthesizeSyntheticMVarsUsingDefault : TermElabM Unit := do
  synthesizeSyntheticMVars (postpone := .yes)
  synthesizeUsingDefaultLoop

private partial def withSynthesizeImp (k : TermElabM α) (postpone : PostponeBehavior) : TermElabM α := do
   let pendingMVarsSaved := (← get).pendingMVars
   modify fun s => { s with pendingMVars := [] }
   try
     let a ← k
     synthesizeSyntheticMVars (postpone := postpone)
     if postpone == .yes then
       synthesizeUsingDefaultLoop
     return a
   finally
     modify fun s => { s with pendingMVars := s.pendingMVars ++ pendingMVarsSaved }

/--
  Execute `k`, and synthesize pending synthetic metavariables created while executing `k` are solved.
  If `mayPostpone == false`, then all of them must be synthesized.
  Remark: even if `mayPostpone == true`, the method still uses `synthesizeUsingDefault` -/
@[inline] def withSynthesize [MonadFunctorT TermElabM m] (k : m α) (postpone := PostponeBehavior.no) : m α :=
  monadMap (m := TermElabM) (withSynthesizeImp · postpone) k

private partial def withSynthesizeLightImp (k : TermElabM α) : TermElabM α := do
  let pendingMVarsSaved := (← get).pendingMVars
  modify fun s => { s with pendingMVars := [] }
  try
    let a ← k
    synthesizeSyntheticMVars (postpone := .yes)
    return a
  finally
    modify fun s => { s with pendingMVars := s.pendingMVars ++ pendingMVarsSaved }

/-- Similar to `withSynthesize`, but uses `postpone := .true`, does not use `synthesizeUsingDefault` -/
@[inline] def withSynthesizeLight [MonadFunctorT TermElabM m] (k : m α) : m α :=
  monadMap (m := TermElabM) (withSynthesizeLightImp ·) k

/-- Elaborate `stx`, and make sure all pending synthetic metavariables created while elaborating `stx` are solved. -/
def elabTermAndSynthesize (stx : Syntax) (expectedType? : Option Expr) : TermElabM Expr :=
  withRef stx do
    instantiateMVars (← withSynthesize <| elabTerm stx expectedType?)

/--
Collect unassigned metavariables at `e` that have associated tactic blocks, and then execute them using `runTactic`.
We use this method at the `match .. with` elaborator when it cannot be postponed anymore, but it is still waiting
the result of a tactic block.
-/
def runPendingTacticsAt (e : Expr) : TermElabM Unit := do
  for mvarId in (← getMVars e) do
    let mvarId ← getDelayedMVarRoot mvarId
    if let some { kind := .tactic tacticCode savedContext kind, .. } ← getSyntheticMVarDecl? mvarId then
      withSavedContext savedContext do
        runTactic mvarId tacticCode kind
        markAsResolved mvarId

builtin_initialize
  registerTraceClass `Elab.resume

end Lean.Elab.Term
