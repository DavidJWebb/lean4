/-
Copyright (c) 2020 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura
-/
module

prelude
public import Lean.Util.RecDepth
public import Lean.Util.Trace
public import Lean.Log
public import Lean.ResolveName
public import Lean.Elab.InfoTree.Types
public import Lean.MonadEnv
public import Lean.Elab.Exception
public import Lean.Language.Basic

public section

namespace Lean
register_builtin_option diagnostics : Bool := {
  defValue := false
  group    := "diagnostics"
  descr    := "collect diagnostic information"
}

register_builtin_option diagnostics.threshold : Nat := {
  defValue := 20
  group    := "diagnostics"
  descr    := "only diagnostic counters above this threshold are reported by the definitional equality"
}

register_builtin_option maxHeartbeats : Nat := {
  defValue := 200000
  descr := "maximum amount of heartbeats per command. A heartbeat is number of (small) memory allocations (in thousands), 0 means no limit"
}

register_builtin_option Elab.async : Bool := {
  defValue := false
  descr := "perform elaboration using multiple threads where possible\
    \n\
    \nThis option defaults to `false` but (when not explicitly set) is overridden to `true` in \
      the Lean language server and cmdline. \
      Metaprogramming users driving elaboration directly via e.g. \
      `Lean.Elab.Command.elabCommandTopLevel` can opt into asynchronous elaboration by setting \
      this option but then are responsible for processing messages and other data not only in the \
      resulting command state but also from async tasks in `Lean.Command.Context.snap?` and \
      `Lean.Command.State.snapshotTasks`."
}

register_builtin_option Elab.inServer : Bool := {
  defValue := false
  descr := "true if elaboration is being run inside the Lean language server\
    \n\
    \nThis option is set by the file worker and should not be modified otherwise."
}

/-- Performance option used by cmdline driver. -/
register_builtin_option internal.cmdlineSnapshots : Bool := {
  defValue := false
  descr    := "reduce information stored in snapshots to the minimum necessary \
    for the cmdline driver: diagnostics per command and final full snapshot"
}

/--
If the `diagnostics` option is not already set, gives a message explaining this option.
Begins with a `\n\n`, so an error message can look like `m!"some error occurred{useDiagnosticMsg}"`.
The double newline gives better visual separation from the main error message
-/
def useDiagnosticMsg : MessageData :=
  MessageData.lazy fun ctx =>
    if diagnostics.get ctx.opts then
      pure ""
    else
      pure <| .hint' s!"Additional diagnostic information may be available using the `set_option {diagnostics.name} true` command."

/-- Name generator that creates user-accessible names. -/
structure DeclNameGenerator where
  namePrefix : Name := .anonymous
  -- We use a non-nil list instead of changing `namePrefix` as we want to distinguish between
  -- numeric components in the original name (e.g. from macro scopes) and ones added by `mkChild`.
  idx        : Nat := 1
  parentIdxs : List Nat := .nil
  deriving Inhabited

namespace DeclNameGenerator

def ofPrefix (namePrefix : Name) : DeclNameGenerator :=
  { namePrefix }

private def idxs (g : DeclNameGenerator) : List Nat :=
  g.idx :: g.parentIdxs

def next (g : DeclNameGenerator) : DeclNameGenerator :=
  { g with idx := g.idx + 1 }

/--
Creates a user-accessible unique name of the following structure:
```
<name prefix>.<infix>_<numeric components>_...
```
Uniqueness is guaranteed for the current branch of elaboration. When entering parallelism and other
branching elaboration steps, `mkChild` must be used (automatically done in `wrapAsync*`).
-/
partial def mkUniqueName (env : Environment) (g : DeclNameGenerator) («infix» : Name) :
    (Name × DeclNameGenerator) := Id.run do
  -- `Name.append` does not allow macro scopes on both operands; as the result of this function is
  -- unlikely to be referenced in a macro; the choice doesn't really matter.
  let «infix» := if g.namePrefix.hasMacroScopes && infix.hasMacroScopes then infix.eraseMacroScopes else «infix»
  let base := g.namePrefix ++ «infix»
  let mut g := g
  while isConflict (curr g base) do
    g := g.next
  return (curr g base, g)
where
  -- Check whether the name conflicts with an existing one. Conflicts ignore privacy.
  -- NOTE: We only check the current branch and rely on the documented invariant instead because we
  -- do not want to block here and because it would not solve the issue for completely separated
  -- threads of elaboration such as in Aesop's backtracking search.
  isConflict (n : Name) : Bool :=
    (env.setExporting false).containsOnBranch n ||
    isPrivateName n && (env.setExporting false).containsOnBranch (privateToUserName n) ||
    !isPrivateName n && (env.setExporting false).containsOnBranch (mkPrivateName env n)
  curr (g : DeclNameGenerator) (base : Name) : Name := Id.run do
    let mut n := g.idxs.foldr (fun i n => n.appendIndexAfter i) base
    if env.header.isModule && !env.isExporting && !isPrivateName n then
      n := mkPrivateName env n
    return n

def mkChild (g : DeclNameGenerator) : DeclNameGenerator × DeclNameGenerator :=
  ({ g with parentIdxs := g.idx :: g.parentIdxs, idx := 1 },
   { g with idx := g.idx + 1 })

end DeclNameGenerator

class MonadDeclNameGenerator (m : Type → Type) where
  getDeclNGen : m DeclNameGenerator
  setDeclNGen : DeclNameGenerator → m Unit

export MonadDeclNameGenerator (getDeclNGen setDeclNGen)

instance [MonadLift m n] [MonadDeclNameGenerator m] : MonadDeclNameGenerator n where
  getDeclNGen := liftM (getDeclNGen : m _)
  setDeclNGen := fun ngen => liftM (setDeclNGen ngen : m _)

/--
Creates a new name for use as an auxiliary declaration that can be assumed to be globally unique.

Uniqueness is guaranteed for the current branch of elaboration. When entering parallelism and other
branching elaboration steps, `mkChild` must be used (automatically done in `wrapAsync*`).
-/
def mkAuxDeclName [Monad m] [MonadEnv m] [MonadDeclNameGenerator m] (kind : Name := `_aux) : m Name := do
  let ngen ← getDeclNGen
  let (n, ngen) := ngen.mkUniqueName (← getEnv) («infix» := kind)
  setDeclNGen ngen
  return n

/--
Adjusts the `namePrefix` of `getDeclNGen` to the given name and resets the nested counter.
-/
def withDeclNameForAuxNaming [Monad m] [MonadFinally m] [MonadDeclNameGenerator m]
    (name : Name) (x : m α) : m α := do
  let ngen ← getDeclNGen
  -- do not reset index if prefix unchanged
  if ngen.namePrefix != name then
    try
      setDeclNGen { namePrefix := name }
      x
    finally
      setDeclNGen ngen
  else
    x

namespace Core

builtin_initialize registerTraceClass `Kernel

def getMaxHeartbeats (opts : Options) : Nat :=
  maxHeartbeats.get opts * 1000

abbrev InstantiateLevelCache := PersistentHashMap Name (List Level × Expr)

/-- Cache for the `CoreM` monad -/
structure Cache where
  instLevelType  : InstantiateLevelCache := {}
  instLevelValue : InstantiateLevelCache := {}
  deriving Inhabited

/-- State for the CoreM monad. -/
structure State where
  /-- Current environment. -/
  env             : Environment
  /-- Next macro scope. We use macro scopes to avoid accidental name capture. -/
  nextMacroScope  : MacroScope     := firstFrontendMacroScope + 1
  /-- Name generator for producing unique `FVarId`s, `MVarId`s, and `LMVarId`s -/
  ngen            : NameGenerator  := {}
  /--
  Name generator for creating persistent auxiliary declarations. Separate from `ngen` to keep
  numbers smaller and create user-accessible names.
  -/
  auxDeclNGen     : DeclNameGenerator := {}
  /-- Trace messages -/
  traceState      : TraceState     := {}
  /-- Cache for instantiating universe polymorphic declarations. -/
  cache           : Cache          := {}
  /-- Message log. -/
  messages        : MessageLog     := {}
  /-- Info tree. We have the info tree here because we want to update it while adding attributes. -/
  infoState       : Elab.InfoState := {}
  /--
  Snapshot trees of asynchronous subtasks. As these are untyped and reported only at the end of the
  command's main elaboration thread, they are only useful for basic message log reporting; for
  incremental reporting and reuse within a long-running elaboration thread, types rooted in
  `CommandParsedSnapshot` need to be adjusted.
  -/
  snapshotTasks : Array (Language.SnapshotTask Language.SnapshotTree) := #[]
  deriving Nonempty

/-- Context for the CoreM monad. -/
structure Context where
  /-- Name of the file being compiled. -/
  fileName       : String
  /-- Auxiliary datastructure for converting `String.Pos` into Line/Column number. -/
  fileMap        : FileMap
  options        : Options := {}
  currRecDepth   : Nat := 0
  maxRecDepth    : Nat := 1000
  ref            : Syntax := Syntax.missing
  currNamespace  : Name := Name.anonymous
  openDecls      : List OpenDecl := []
  initHeartbeats : Nat := 0
  maxHeartbeats  : Nat := getMaxHeartbeats options
  currMacroScope : MacroScope := firstFrontendMacroScope
  /--
  If `diag := true`, different parts of the system collect diagnostics.
  Use the `set_option diag true` to set it to true.
  -/
  diag           : Bool := false
  /-- If set, used to cancel elaboration from outside when results are not needed anymore. -/
  cancelTk?      : Option IO.CancelToken := none
  /--
  If set (when `showPartialSyntaxErrors` is not set and parsing failed), suppresses most elaboration
  errors; see also `logMessage` below.
  -/
  suppressElabErrors : Bool := false
  /-- Cache of `Lean.inheritedTraceOptions`. -/
  inheritedTraceOptions : Std.HashSet Name := {}
  deriving Nonempty

/-- CoreM is a monad for manipulating the Lean environment.
It is the base monad for `MetaM`.
The main features it provides are:
- name generator state
- environment state
- Lean options context
- the current open namespace
-/
abbrev CoreM := ReaderT Context <| StateRefT State (EIO Exception)

-- Make the compiler generate specialized `pure`/`bind` so we do not have to optimize through the
-- whole monad stack at every use site. May eventually be covered by `deriving`.
@[always_inline]
instance : Monad CoreM := let i := inferInstanceAs (Monad CoreM); { pure := i.pure, bind := i.bind }

instance : Inhabited (CoreM α) where
  default := fun _ _ => throw default

instance : MonadRef CoreM where
  getRef := return (← read).ref
  withRef ref x := withReader (fun ctx => { ctx with ref := ref }) x

instance : MonadEnv CoreM where
  getEnv := return (← get).env
  modifyEnv f := modify fun s => { s with env := f s.env, cache := {} }

instance : MonadOptions CoreM where
  getOptions := return (← read).options

instance : MonadWithOptions CoreM where
  withOptions f x := do
    let options := f (← read).options
    let diag := diagnostics.get options
    if Kernel.isDiagnosticsEnabled (← getEnv) != diag then
      modifyEnv fun env => Kernel.enableDiag env diag
    withReader
      (fun ctx =>
        { ctx with
          options
          diag
          maxRecDepth := maxRecDepth.get options })
      x

-- Helper function for ensuring fields derived from e.g. options have the correct value.
@[inline] private def withConsistentCtx (x : CoreM α) : CoreM α := do
  let inheritedTraceOptions ← inheritedTraceOptions.get
  withReader (fun ctx => { ctx with inheritedTraceOptions }) do
    withOptions id x

instance : AddMessageContext CoreM where
  addMessageContext := addMessageContextPartial

instance : MonadNameGenerator CoreM where
  getNGen := return (← get).ngen
  setNGen ngen := modify fun s => { s with ngen := ngen }

instance : MonadDeclNameGenerator CoreM where
  getDeclNGen := return (← get).auxDeclNGen
  setDeclNGen ngen := modify fun s => { s with auxDeclNGen := ngen }

instance : MonadRecDepth CoreM where
  withRecDepth d x := withReader (fun ctx => { ctx with currRecDepth := d }) x
  getRecDepth := return (← read).currRecDepth
  getMaxRecDepth := return (← read).maxRecDepth

instance : MonadResolveName CoreM where
  getCurrNamespace := return (← read).currNamespace
  getOpenDecls := return (← read).openDecls

protected def withFreshMacroScope (x : CoreM α) : CoreM α := do
  let fresh ← modifyGetThe Core.State (fun st => (st.nextMacroScope, { st with nextMacroScope := st.nextMacroScope + 1 }))
  withReader (fun ctx => { ctx with currMacroScope := fresh }) x

instance : MonadQuotation CoreM where
  getCurrMacroScope   := return (← read).currMacroScope
  getMainModule       := return (← getEnv).mainModule
  withFreshMacroScope := Core.withFreshMacroScope

instance : Elab.MonadInfoTree CoreM where
  getInfoState      := return (← get).infoState
  modifyInfoState f := modify fun s => { s with infoState := f s.infoState }

@[inline] def modifyCache (f : Cache → Cache) : CoreM Unit :=
  modify fun ⟨env, next, ngen, auxDeclNGen, trace, cache, messages, infoState, snaps⟩ =>
   ⟨env, next, ngen, auxDeclNGen, trace, f cache, messages, infoState, snaps⟩

@[inline] def modifyInstLevelTypeCache (f : InstantiateLevelCache → InstantiateLevelCache) : CoreM Unit :=
  modifyCache fun ⟨c₁, c₂⟩ => ⟨f c₁, c₂⟩

@[inline] def modifyInstLevelValueCache (f : InstantiateLevelCache → InstantiateLevelCache) : CoreM Unit :=
  modifyCache fun ⟨c₁, c₂⟩ => ⟨c₁, f c₂⟩

def instantiateTypeLevelParams (c : ConstantVal) (us : List Level) : CoreM Expr := do
  if let some (us', r) := (← get).cache.instLevelType.find? c.name then
    if us == us' then
      return r
  let r := c.instantiateTypeLevelParams us
  modifyInstLevelTypeCache fun s => s.insert c.name (us, r)
  return r

def instantiateValueLevelParams (c : ConstantInfo) (us : List Level) : CoreM Expr := do
  if let some (us', r) := (← get).cache.instLevelValue.find? c.name then
    if us == us' then
      return r
  unless c.hasValue do
    throwError "Not a definition or theorem: {c.name}"
  let r := c.instantiateValueLevelParams! us
  modifyInstLevelValueCache fun s => s.insert c.name (us, r)
  return r

@[inline] def liftIOCore (x : IO α) : CoreM α := do
  let ref ← getRef
  IO.toEIO (fun (err : IO.Error) => Exception.error ref (toString err)) x

instance : MonadLift IO CoreM where
  monadLift := liftIOCore

instance : MonadTrace CoreM where
  getTraceState := return (← get).traceState
  modifyTraceState f := modify fun s => { s with traceState := f s.traceState }
  getInheritedTraceOptions := return (← read).inheritedTraceOptions

structure SavedState extends State where
  /-- Number of heartbeats passed inside `withRestoreOrSaveFull`, not used otherwise. -/
  passedHeartbeats : Nat
deriving Nonempty

def saveState : CoreM SavedState := do
  let s ← get
  return { toState := s, passedHeartbeats := 0 }

/--
Incremental reuse primitive: if `reusableResult?` is `none`, runs `act` and returns its result
together with the saved monadic state after `act` including the heartbeats used by it. If
`reusableResult?` on the other hand is `some (a, state)`, restores full `state` including heartbeats
used and returns `(a, state)`.

The intention is for steps that support incremental reuse to initially pass `none` as
`reusableResult?` and store the result and state in a snapshot. In a further run, if reuse is
possible, `reusableResult?` should be set to the previous result and state, ensuring that the state
after running `withRestoreOrSaveFull` is identical in both runs. Note however that necessarily this
is only an approximation in the case of heartbeats as heartbeats used by `withRestoreOrSaveFull`
itself after calling `act` as well as by reuse-handling code such as the one supplying
`reusableResult?` are not accounted for.
-/
@[specialize] def withRestoreOrSaveFull (reusableResult? : Option (α × SavedState))
    (act : CoreM α) : CoreM (α × SavedState) := do
  if let some (val, state) := reusableResult? then
    set state.toState
    IO.addHeartbeats state.passedHeartbeats
    return (val, state)

  let startHeartbeats ← IO.getNumHeartbeats
  let a ← act
  let s ← get
  let stopHeartbeats ← IO.getNumHeartbeats
  return (a, { toState := s, passedHeartbeats := stopHeartbeats - startHeartbeats })

/-- Restore backtrackable parts of the state. -/
def SavedState.restore (b : SavedState) : CoreM Unit :=
  modify fun s => { s with env := b.env, messages := b.messages, infoState := b.infoState }

private def mkFreshNameImp (n : Name) : CoreM Name := do
  let fresh ← modifyGet fun s => (s.nextMacroScope, { s with nextMacroScope := s.nextMacroScope + 1 })
  return addMacroScope (← getEnv).mainModule n fresh

/--
Creates a name from `n` that is guaranteed to be unique.
This is intended to be used for creating inaccessible user names for free variables and constants.

It works by adding a fresh macro scope to `n`.
Applying `Lean.Name.eraseMacroScopes` to the resulting name yields `n`.

See also `Lean.LocalContext.getUnusedName` (for creating a new accessible user name that is
unused in the local context) and `Lean.Meta.mkFreshBinderNameForTactic` (for creating names
that are conditionally inaccessible, depending on the current value of the `tactic.hygiene` option).
-/
def mkFreshUserName (n : Name) : CoreM Name :=
  mkFreshNameImp n

@[inline] def CoreM.run (x : CoreM α) (ctx : Context) (s : State) : EIO Exception (α × State) :=
  ((withConsistentCtx x) ctx).run s

@[inline] def CoreM.run' (x : CoreM α) (ctx : Context) (s : State) : EIO Exception α :=
  Prod.fst <$> x.run ctx s

@[inline] def CoreM.toIO (x : CoreM α) (ctx : Context) (s : State) : IO (α × State) := do
  match (← (x.run { ctx with initHeartbeats := (← IO.getNumHeartbeats) } s).toIO') with
  | Except.error (Exception.error _ msg)   => throw <| IO.userError (← msg.toString)
  | Except.error (Exception.internal id _) => throw <| IO.userError <| "internal exception #" ++ toString id.idx
  | Except.ok a                            => return a

-- withIncRecDepth for a monad `m` such that `[MonadControlT CoreM n]`
protected def withIncRecDepth [Monad m] [MonadControlT CoreM m] (x : m α) : m α :=
  controlAt CoreM fun runInBase => withIncRecDepth (runInBase x)

/--
Throws an internal interrupt exception if cancellation has been requested. The exception is not
caught by `try catch` but is intended to be caught by `Command.withLoggingExceptions` at the top
level of elaboration. In particular, we want to skip producing further incremental snapshots after
the exception has been thrown.
 -/
@[inline] def checkInterrupted : CoreM Unit := do
  if let some tk := (← read).cancelTk? then
    if (← tk.isSet) then
      throwInterruptException

register_builtin_option debug.moduleNameAtTimeout : Bool := {
  defValue := true
  group    := "debug"
  descr    := "include module name in deterministic timeout error messages.\nRemark: we set this option to false to increase the stability of our test suite"
}

def throwMaxHeartbeat (moduleName : Name) (optionName : Name) (max : Nat) : CoreM Unit := do
  let includeModuleName := debug.moduleNameAtTimeout.get (← getOptions)
  let atModuleName := if includeModuleName then s!" at `{moduleName}`" else ""
  throw <| Exception.error (← getRef) <| .tagged `runtime.maxHeartbeats m!"\
    (deterministic) timeout{atModuleName}, maximum number of heartbeats ({max/1000}) has been reached\
    {.note m!"Use `set_option {optionName} <num>` to set the limit."}\
    {useDiagnosticMsg}"

def checkMaxHeartbeatsCore (moduleName : String) (optionName : Name) (max : Nat) : CoreM Unit := do
  unless max == 0 do
    let numHeartbeats ← IO.getNumHeartbeats
    if numHeartbeats - (← read).initHeartbeats > max then
      throwMaxHeartbeat (.mkSimple moduleName) optionName max

def checkMaxHeartbeats (moduleName : String) : CoreM Unit := do
  checkMaxHeartbeatsCore moduleName `maxHeartbeats (← read).maxHeartbeats

def checkSystem (moduleName : String) : CoreM Unit := do
  -- TODO: bring back more checks from the C++ implementation
  checkInterrupted
  checkMaxHeartbeats moduleName

private def withCurrHeartbeatsImp (x : CoreM α) : CoreM α := do
  let heartbeats ← IO.getNumHeartbeats
  withReader (fun ctx => { ctx with initHeartbeats := heartbeats }) x

def withCurrHeartbeats [Monad m] [MonadControlT CoreM m] (x : m α) : m α :=
  controlAt CoreM fun runInBase => withCurrHeartbeatsImp (runInBase x)

def setMessageLog (messages : MessageLog) : CoreM Unit :=
  modify fun s => { s with messages := messages }

def resetMessageLog : CoreM Unit :=
  setMessageLog {}

def getMessageLog : CoreM MessageLog :=
  return (← get).messages

/--
Returns the current log and then resets its messages while adjusting `MessageLog.hadErrors`. Used
for incremental reporting during elaboration of a single command.
-/
def getAndEmptyMessageLog : CoreM MessageLog :=
  modifyGet fun s => (s.messages, { s with messages := s.messages.markAllReported })

/--
Returns the current set of tasks added by `logSnapshotTask` and then resets it. When
saving/restoring state of an action that may have logged such tasks during incremental reuse, this
function must be used to store them in the corresponding snapshot tree; otherwise, they will leak
outside and may be cancelled by a later step, potentially leading to inconsistent state being
reused.
-/
def getAndEmptySnapshotTasks : CoreM (Array (Language.SnapshotTask Language.SnapshotTree)) :=
  modifyGet fun s => (s.snapshotTasks, { s with snapshotTasks := #[] })

instance : MonadLog CoreM where
  getRef      := getRef
  getFileMap  := return (← read).fileMap
  getFileName := return (← read).fileName
  hasErrors   := return (← get).messages.hasErrors
  logMessage msg := do
    if (← read).suppressElabErrors then
      -- discard elaboration errors, except for a few important and unlikely misleading ones, on
      -- parse error
      unless msg.data.hasTag (· matches `Elab.synthPlaceholder | `Tactic.unsolvedGoals | `trace) do
        return

    let ctx ← read
    let msg := { msg with data := MessageData.withNamingContext { currNamespace := ctx.currNamespace, openDecls := ctx.openDecls } msg.data };
    modify fun s => { s with messages := s.messages.add msg }

/--
Includes a given task (such as from `wrapAsyncAsSnapshot`) in the overall snapshot tree for this
command's elaboration, making its result available to reporting and the language server. The
reporter will not know about this snapshot tree node until the main elaboration thread for this
command has finished so this function is not useful for incremental reporting within a longer
elaboration thread but only for tasks that outlive it such as background kernel checking or proof
elaboration.
-/
def logSnapshotTask (task : Language.SnapshotTask Language.SnapshotTree) : CoreM Unit :=
  modify fun s => { s with snapshotTasks := s.snapshotTasks.push task }

/-- Wraps the given action for use in `EIO.asTask` etc., discarding its final monadic state. -/
def wrapAsync {α : Type} (act : α → CoreM β) (cancelTk? : Option IO.CancelToken) :
    CoreM (α → EIO Exception β) := do
  let (childNGen, parentNGen) := (← getDeclNGen).mkChild
  setDeclNGen parentNGen
  let st ← get
  let st := { st with auxDeclNGen := childNGen }
  let ctx ← read
  let ctx := { ctx with cancelTk? }
  let heartbeats := (← IO.getNumHeartbeats) - ctx.initHeartbeats
  return fun a => withCurrHeartbeats (do
      -- include heartbeats since start of elaboration in new thread as well such that forking off
      -- an action doesn't suddenly allow it to succeed from a lower heartbeat count
      IO.addHeartbeats heartbeats
      act a : CoreM _)
    |>.run' ctx st

/-- Option for capturing output to stderr during elaboration. -/
register_builtin_option stderrAsMessages : Bool := {
  defValue := true
  group    := "server"
  descr    := "(server) capture output to the Lean stderr channel (such as from `dbg_trace`) during elaboration of a command as a diagnostic message"
}

/--
Creates snapshot reporting given `withIsolatedStreams` output and diagnostics and traces from the
given state.
-/
def mkSnapshot (output : String) (ctx : Context) (st : State)
    (desc : String := by exact decl_name%.toString) : BaseIO Language.SnapshotTree := do
  let mut msgs := st.messages
  if !output.isEmpty then
    msgs := msgs.add {
      fileName := ctx.fileName
      severity := MessageSeverity.information
      pos      := ctx.fileMap.toPosition <| ctx.ref.getPos?.getD 0
      data     := output
    }
  return .mk {
    desc
    diagnostics := (← Language.Snapshot.Diagnostics.ofMessageLog msgs)
    traces := st.traceState
  } st.snapshotTasks

open Language in
/--
Wraps the given action for use in `BaseIO.asTask` etc., discarding its final state except for
`logSnapshotTask` tasks, which are reported as part of the returned tree. The given cancellation
token, if any, should be stored in a `SnapshotTask` for the server to trigger it when the result is
no longer needed.
-/
def wrapAsyncAsSnapshot {α : Type} (act : α → CoreM Unit) (cancelTk? : Option IO.CancelToken)
    (desc : String := by exact decl_name%.toString) : CoreM (α → BaseIO SnapshotTree) := do
  let f ← wrapAsync (cancelTk? := cancelTk?) fun a => do
    IO.FS.withIsolatedStreams (isolateStderr := stderrAsMessages.get (← getOptions)) do
      let tid ← IO.getTID
      -- reset trace/info state and message log so as not to report them twice
      modify fun st => { st with
        messages := st.messages.markAllReported
        traceState := { tid }
        snapshotTasks := #[]
        infoState := {}
      }
      try
        withTraceNode `Elab.async (fun _ => return desc) do
          act a
      catch e =>
        unless e.isInterrupt do
          logError e.toMessageData
      finally
        addTraceAsMessages
      get
  let ctx ← readThe Core.Context
  return fun a => do
    match (← (f a).toBaseIO) with
    | .ok (output, st) => mkSnapshot output ctx st desc
    -- interrupt or abort exception as `try catch` above should have caught any others
    | .error _ => default

end Core

export Core (CoreM mkFreshUserName checkSystem withCurrHeartbeats)

@[inline] def withAtLeastMaxRecDepth [MonadFunctorT CoreM m] (max : Nat) : m α → m α :=
  monadMap (m := CoreM) <| withReader (fun ctx => { ctx with maxRecDepth := Nat.max max ctx.maxRecDepth })

@[inline] def catchInternalId [Monad m] [MonadExcept Exception m] (id : InternalExceptionId) (x : m α) (h : Exception → m α) : m α := do
  try
    x
  catch ex => match ex with
    | .error ..       => throw ex
    | .internal id' _ => if id == id' then h ex else throw ex

@[inline] def catchInternalIds [Monad m] [MonadExcept Exception m] (ids : List InternalExceptionId) (x : m α) (h : Exception → m α) : m α := do
  try
    x
  catch ex => match ex with
    | .error ..      => throw ex
    | .internal id _ => if ids.contains id then h ex else throw ex

/--
  Return true if `ex` was generated by `throwMaxHeartbeat`.
  This function is a bit hackish. The heartbeat exception should probably be an internal exception.
  We used a similar hack at `Exception.isMaxRecDepth` -/
def Exception.isMaxHeartbeat (ex : Exception) : Bool :=
  ex matches Exception.error _ (.tagged `runtime.maxHeartbeats _)

/-- Creates the expression `d → b` -/
def mkArrow (d b : Expr) : CoreM Expr :=
  return Lean.mkForall (← mkFreshUserName `x) BinderInfo.default d b

/-- Iterated `mkArrow`, creates the expression `a₁ → a₂ → … → aₙ → b`. Also see `arrowDomainsN`. -/
def mkArrowN (ds : Array Expr) (e : Expr) : CoreM Expr := ds.foldrM mkArrow e

private def supportedRecursors :=
  #[``Empty.rec, ``False.rec, ``Eq.ndrec, ``Eq.rec, ``Eq.recOn, ``Eq.casesOn, ``False.casesOn, ``Empty.casesOn, ``And.rec, ``And.casesOn]

/-- This is a temporary workaround for generating better error messages for the compiler. It can be deleted after we
   rewrite the remaining parts of the compiler in Lean.  -/
private def checkUnsupported [Monad m] [MonadEnv m] [MonadError m] (decl : Declaration) : m Unit := do
  let env ← getEnv
  decl.forExprM fun e =>
    let unsupportedRecursor? := e.find? fun
      | Expr.const declName .. =>
        ((isAuxRecursor env declName && !isCasesOnRecursor env declName) || isRecCore env declName)
        && !supportedRecursors.contains declName
      | _ => false
    match unsupportedRecursor? with
    | some (Expr.const declName ..) => throwError "code generator does not support recursor '{declName}' yet, consider using 'match ... with' and/or structural recursion"
    | _ => pure ()

/--
If `t` has not finished yet, waits for it under an `Elab.block` trace node. Returns `t`'s result.
-/
def traceBlock (tag : String) (t : Task α) : CoreM α := do
  if (← IO.hasFinished t) then
    return t.get
  withTraceNode `Elab.block (tag := tag) (fun _ => pure tag) do
    profileitM Exception "blocked" (← getOptions) do
      IO.wait t

-- Forward declaration
@[extern "lean_lcnf_compile_decls"]
opaque compileDeclsImpl (declNames : Array Name) : CoreM Unit

-- `ref?` is used for error reporting if available
partial def compileDecls (decls : Array Name) (logErrors := true) : CoreM Unit := do
  -- When inside `realizeConst`, do compilation synchronously so that `_cstage*` constants are found
  -- by the replay code
  if !Elab.async.get (← getOptions) || (← getEnv).isRealizing then
    let _ ← traceBlock "compiler env" (← getEnv).checked
    doCompile
    return
  let env ← getEnv
  let res ← env.promiseChecked
  setEnv res.mainEnv
  let cancelTk ← IO.CancelToken.new
  let checkAct ← Core.wrapAsyncAsSnapshot (cancelTk? := cancelTk) fun _ => do
    setEnv res.asyncEnv
    try
      doCompile
    finally
      res.commitChecked (← getEnv)
  let t ← BaseIO.mapTask checkAct env.checked
  let endRange? := (← getRef).getTailPos?.map fun pos => ⟨pos, pos⟩
  Core.logSnapshotTask { stx? := none, reportingRange? := endRange?, task := t, cancelTk? := cancelTk }
where doCompile := do
  -- don't compile if kernel errored; should be converted into a task dependency when compilation
  -- is made async as well
  if !decls.all (← getEnv).constants.contains then
    return
  withoutExporting do
    let state ← Core.saveState
    try
      compileDeclsImpl decls
    catch e =>
      state.restore
      if logErrors then
        throw e

def compileDecl (decl : Declaration) (logErrors := true) : CoreM Unit := do
  compileDecls (Compiler.getDeclNamesForCodeGen decl) logErrors

def getDiag (opts : Options) : Bool :=
  diagnostics.get opts

/-- Return `true` if diagnostic information collection is enabled. -/
def isDiagnosticsEnabled : CoreM Bool :=
  return (← read).diag

def ImportM.runCoreM (x : CoreM α) : ImportM α := do
  let ctx ← read
  let (a, _) ← (withOptions (fun _ => ctx.opts) x).toIO { fileName := "<ImportM>", fileMap := default } { env := ctx.env }
  return a

/-- Return `true` if the exception was generated by one of our resource limits. -/
def Exception.isRuntime (ex : Exception) : Bool :=
  ex.isMaxHeartbeat || ex.isMaxRecDepth

/--
Custom `try-catch` for all monads based on `CoreM`. We usually don't want to catch "runtime
exceptions" these monads, but on `CommandElabM` or, in specific cases, using `tryCatchRuntimeEx`.
See issues #2775 and #2744 as well as `MonadAlwaysExcept`. Also, we never want to catch interrupt
exceptions inside the elaborator.
-/
@[inline] protected def Core.tryCatch (x : CoreM α) (h : Exception → CoreM α) : CoreM α := do
  try
    x
  catch ex =>
    if ex.isInterrupt || ex.isRuntime then
      throw ex
    else
      h ex

/--
A variant of `tryCatch` that also catches runtime exception (see also `tryCatch` documentation).
Like `tryCatch`, this function does not catch interrupt exceptions, which are not considered runtime
exceptions.
-/
@[inline] protected def Core.tryCatchRuntimeEx (x : CoreM α) (h : Exception → CoreM α) : CoreM α := do
  try
    x
  catch ex =>
    if ex.isInterrupt then
      throw ex
    h ex

instance : MonadExceptOf Exception CoreM where
  throw    := throw
  tryCatch := Core.tryCatch

class MonadRuntimeException (m : Type → Type) where
  tryCatchRuntimeEx (body : m α) (handler : Exception → m α) : m α

export MonadRuntimeException (tryCatchRuntimeEx)

instance : MonadRuntimeException CoreM where
  tryCatchRuntimeEx := Core.tryCatchRuntimeEx

@[inline] instance [MonadRuntimeException m] : MonadRuntimeException (ReaderT ρ m) where
  tryCatchRuntimeEx := fun x c r => tryCatchRuntimeEx (x r) (fun e => (c e) r)

@[inline] instance [MonadRuntimeException m] : MonadRuntimeException (StateRefT' ω σ m) where
  tryCatchRuntimeEx := fun x c s => tryCatchRuntimeEx (x s) (fun e => c e s)

@[inline] def mapCoreM [MonadControlT CoreM m] [Monad m] (f : forall {α}, CoreM α → CoreM α) {α} (x : m α) : m α :=
  controlAt CoreM fun runInBase => f <| runInBase x

/--
Returns `true` if the given message kind has not been reported in the message log,
and then mark it as logged. Otherwise, returns `false`.
We use this API to ensure we don't log the same kind of warning multiple times.
-/
def logMessageKind (kind : Name) : CoreM Bool := do
  if (← get).messages.loggedKinds.contains kind then
    return false
  else
    modify fun s => { s with messages.loggedKinds := s.messages.loggedKinds.insert kind }
    return true

@[inherit_doc Environment.enableRealizationsForConst]
def enableRealizationsForConst (n : Name) : CoreM Unit := do
  let env ← (← getEnv).enableRealizationsForConst (← getOptions) n
  setEnv env

builtin_initialize
  registerTraceClass `Elab.async
  registerTraceClass `Elab.block

end Lean
