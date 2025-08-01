/-
Copyright (c) 2018 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura
-/
module

prelude
public import Init.Data.Hashable
public import Init.Data.Int
public import Lean.Data.KVMap
public import Lean.Data.SMap
public import Lean.Level
public import Std.Data.HashSet.Basic
public import Std.Data.TreeSet.Basic

public section

namespace Lean

/-- Literal values for `Expr`. -/
inductive Literal where
  /-- Natural number literal -/
  | natVal (val : Nat)
  /-- String literal -/
  | strVal (val : String)
  deriving Inhabited, BEq, Repr

protected def Literal.hash : Literal → UInt64
  | .natVal v => hash v
  | .strVal v => hash v

instance : Hashable Literal := ⟨Literal.hash⟩

/--
Total order on `Expr` literal values.
Natural number values are smaller than string literal values.
-/
def Literal.lt : Literal → Literal → Bool
  | .natVal _,  .strVal _  => true
  | .natVal v₁, .natVal v₂ => v₁ < v₂
  | .strVal v₁, .strVal v₂ => v₁ < v₂
  | _,                 _   => false

instance : LT Literal := ⟨fun a b => a.lt b⟩

instance (a b : Literal) : Decidable (a < b) :=
  inferInstanceAs (Decidable (a.lt b))

/--
Arguments in forallE binders can be labelled as implicit or explicit.

Each `lam` or `forallE` binder comes with a `binderInfo` argument (stored in ExprData).
This can be set to
- `default` -- `(x : α)`
- `implicit` --  `{x : α}`
- `strict_implicit` -- `⦃x : α⦄`
- `inst_implicit` -- `[x : α]`.
- `aux_decl` -- Auxiliary definitions are helper methods that
  Lean generates. `aux_decl` is used for `_match`, `_fun_match`,
  `_let_match` and the self reference that appears in recursive pattern matching.

The difference between implicit `{}` and strict-implicit `⦃⦄` is how
implicit arguments are treated that are *not* followed by explicit arguments.
`{}` arguments are applied eagerly, while `⦃⦄` arguments are left partially applied:
```
def foo {x : Nat} : Nat := x
def bar ⦃x : Nat⦄ : Nat := x
#check foo -- foo : Nat
#check bar -- bar : ⦃x : Nat⦄ → Nat
```

See also [the Lean manual](https://lean-lang.org/lean4/doc/expressions.html#implicit-arguments).
-/
inductive BinderInfo where
  /-- Default binder annotation, e.g. `(x : α)` -/
  | default
  /-- Implicit binder annotation, e.g., `{x : α}` -/
  | implicit
  /-- Strict implicit binder annotation, e.g., `{{ x : α }}` -/
  | strictImplicit
  /-- Local instance binder annotation, e.g., `[Decidable α]` -/
  | instImplicit
  deriving Inhabited, BEq, Repr

def BinderInfo.hash : BinderInfo → UInt64
  | .default        => 947
  | .implicit       => 1019
  | .strictImplicit => 1087
  | .instImplicit   => 1153

/--
Return `true` if the given `BinderInfo` does not correspond to an implicit binder annotation
(i.e., `implicit`, `strictImplicit`, or `instImplicit`).
-/
def BinderInfo.isExplicit : BinderInfo → Bool
  | .implicit       => false
  | .strictImplicit => false
  | .instImplicit   => false
  | _               => true

instance : Hashable BinderInfo := ⟨BinderInfo.hash⟩

/-- Return `true` if the given `BinderInfo` is an instance implicit annotation (e.g., `[Decidable α]`) -/
def BinderInfo.isInstImplicit : BinderInfo → Bool
  | BinderInfo.instImplicit => true
  | _                       => false

/-- Return `true` if the given `BinderInfo` is a regular implicit annotation (e.g., `{α : Type u}`) -/
def BinderInfo.isImplicit : BinderInfo → Bool
  | BinderInfo.implicit => true
  | _                   => false

/-- Return `true` if the given `BinderInfo` is a strict implicit annotation (e.g., `{{α : Type u}}`) -/
def BinderInfo.isStrictImplicit : BinderInfo → Bool
  | BinderInfo.strictImplicit => true
  | _                         => false

/-- Expression metadata. Used with the `Expr.mdata` constructor. -/
abbrev MData := KVMap
abbrev MData.empty : MData := {}

/--
Cached hash code, cached results, and other data for `Expr`.
-  hash           : 32-bits
-  approxDepth    : 8-bits -- the approximate depth is used to minimize the number of hash collisions
-  hasFVar        : 1-bit -- does it contain free variables?
-  hasExprMVar    : 1-bit -- does it contain metavariables?
-  hasLevelMVar   : 1-bit -- does it contain level metavariables?
-  hasLevelParam  : 1-bit -- does it contain level parameters?
-  looseBVarRange : 20-bits

Remark: this is mostly an internal datastructure used to implement `Expr`,
most will never have to use it.
-/
@[expose] def Expr.Data := UInt64

instance: Inhabited Expr.Data :=
  inferInstanceAs (Inhabited UInt64)

def Expr.Data.hash (c : Expr.Data) : UInt64 :=
  c.toUInt32.toUInt64

instance : BEq Expr.Data where
  beq (a b : UInt64) := a == b

def Expr.Data.approxDepth (c : Expr.Data) : UInt8 :=
  ((c.shiftRight 32).land 255).toUInt8

def Expr.Data.looseBVarRange (c : Expr.Data) : UInt32 :=
  (c.shiftRight 44).toUInt32

def Expr.Data.hasFVar (c : Expr.Data) : Bool :=
  ((c.shiftRight 40).land 1) == 1

def Expr.Data.hasExprMVar (c : Expr.Data) : Bool :=
  ((c.shiftRight 41).land 1) == 1

def Expr.Data.hasLevelMVar (c : Expr.Data) : Bool :=
  ((c.shiftRight 42).land 1) == 1

def Expr.Data.hasLevelParam (c : Expr.Data) : Bool :=
  ((c.shiftRight 43).land 1) == 1

-- NOTE: the `extern` clause of `BinderInfo.toUInt64` is ABI sensitive.
-- It exploits the fact that a small enum compiles to `uint8`.
@[extern "lean_uint8_to_uint64"]
def BinderInfo.toUInt64 : BinderInfo → UInt64
  | .default        => 0
  | .implicit       => 1
  | .strictImplicit => 2
  | .instImplicit   => 3

@[extern "lean_expr_mk_data"]
opaque Expr.mkData (h : UInt64) (looseBVarRange : Nat := 0) (approxDepth : UInt32 := 0)
    (hasFVar hasExprMVar hasLevelMVar hasLevelParam : Bool := false) : Expr.Data

/-- Optimized version of `Expr.mkData` for applications. -/
@[extern "lean_expr_mk_app_data"]
opaque Expr.mkAppData (fData : Data) (aData : Data) : Data

@[inline] def Expr.mkDataForBinder (h : UInt64) (looseBVarRange : Nat) (approxDepth : UInt32) (hasFVar hasExprMVar hasLevelMVar hasLevelParam : Bool) : Expr.Data :=
  Expr.mkData h looseBVarRange approxDepth hasFVar hasExprMVar hasLevelMVar hasLevelParam

@[inline] def Expr.mkDataForLet (h : UInt64) (looseBVarRange : Nat) (approxDepth : UInt32) (hasFVar hasExprMVar hasLevelMVar hasLevelParam : Bool) : Expr.Data :=
  Expr.mkData h looseBVarRange approxDepth hasFVar hasExprMVar hasLevelMVar hasLevelParam

instance : Repr Expr.Data where
  reprPrec v prec := Id.run do
    let mut r := "Expr.mkData " ++ toString v.hash
    if v.looseBVarRange != 0 then
      r := r ++ " (looseBVarRange := " ++ toString v.looseBVarRange ++ ")"
    if v.approxDepth != 0 then
      r := r ++ " (approxDepth := " ++ toString v.approxDepth ++ ")"
    if v.hasFVar then
      r := r ++ " (hasFVar := " ++ toString v.hasFVar ++ ")"
    if v.hasExprMVar then
      r := r ++ " (hasExprMVar := " ++ toString v.hasExprMVar ++ ")"
    if v.hasLevelMVar then
      r := r ++ " (hasLevelMVar := " ++ toString v.hasLevelMVar ++ ")"
    Repr.addAppParen r prec

open Expr

/--
The unique free variable identifier. It is just a hierarchical name,
but we wrap it in `FVarId` to make sure they don't get mixed up with `MVarId`.

This is not the user-facing name for a free variable. This information is stored
in the local context (`LocalContext`). The unique identifiers are generated using
a `NameGenerator`.
-/
structure FVarId where
  name : Name
  deriving Inhabited, BEq, Hashable

instance : Repr FVarId where
  reprPrec n p := reprPrec n.name p

/--
A set of unique free variable identifiers.
This is a persistent data structure implemented using `Std.TreeSet`. -/
@[expose] def FVarIdSet := Std.TreeSet FVarId (Name.quickCmp ·.name ·.name)
  deriving Inhabited, EmptyCollection

instance : ForIn m FVarIdSet FVarId := inferInstanceAs (ForIn _ (Std.TreeSet _ _) ..)

def FVarIdSet.insert (s : FVarIdSet) (fvarId : FVarId) : FVarIdSet :=
  Std.TreeSet.insert s fvarId

def FVarIdSet.union (vs₁ vs₂ : FVarIdSet) : FVarIdSet :=
  vs₁.foldl (init := vs₂) (·.insert ·)

def FVarIdSet.ofList (l : List FVarId) : FVarIdSet :=
  Std.TreeSet.ofList l _

def FVarIdSet.ofArray (l : Array FVarId) : FVarIdSet :=
  Std.TreeSet.ofArray l _

/--
A set of unique free variable identifiers implemented using hashtables.
Hashtables are faster than red-black trees if they are used linearly.
They are not persistent data-structures. -/
@[expose] def FVarIdHashSet := Std.HashSet FVarId
  deriving Inhabited, EmptyCollection

/--
A mapping from free variable identifiers to values of type `α`.
This is a persistent data structure implemented using `Std.TreeMap`. -/
@[expose] def FVarIdMap (α : Type) := Std.TreeMap FVarId α (Name.quickCmp ·.name ·.name)

def FVarIdMap.insert (s : FVarIdMap α) (fvarId : FVarId) (a : α) : FVarIdMap α :=
  Std.TreeMap.insert s fvarId a

instance : EmptyCollection (FVarIdMap α) := inferInstanceAs (EmptyCollection (Std.TreeMap _ _ _))

instance : Inhabited (FVarIdMap α) where
  default := {}

/-- Universe metavariable Id   -/
structure MVarId where
  name : Name
  deriving Inhabited, BEq, Hashable

instance : Repr MVarId where
  reprPrec n p := reprPrec n.name p

@[expose] def MVarIdSet := Std.TreeSet MVarId (Name.quickCmp ·.name ·.name)
  deriving Inhabited, EmptyCollection

def MVarIdSet.insert (s : MVarIdSet) (mvarId : MVarId) : MVarIdSet :=
  Std.TreeSet.insert s mvarId

def MVarIdSet.ofList (l : List MVarId) : MVarIdSet :=
  Std.TreeSet.ofList l _

def MVarIdSet.ofArray (l : Array MVarId) : MVarIdSet :=
  Std.TreeSet.ofArray l _

instance : ForIn m MVarIdSet MVarId := inferInstanceAs (ForIn _ (Std.TreeSet _ _) ..)

@[expose] def MVarIdMap (α : Type) := Std.TreeMap MVarId α (Name.quickCmp ·.name ·.name)

def MVarIdMap.insert (s : MVarIdMap α) (mvarId : MVarId) (a : α) : MVarIdMap α :=
  Std.TreeMap.insert s mvarId a

instance : EmptyCollection (MVarIdMap α) := inferInstanceAs (EmptyCollection (Std.TreeMap _ _ _))

instance : ForIn m (MVarIdMap α) (MVarId × α) := inferInstanceAs (ForIn _ (Std.TreeMap _ _ _) ..)

instance : Inhabited (MVarIdMap α) where
  default := {}

/--
Lean expressions. This data structure is used in the kernel and
elaborator. However, expressions sent to the kernel should not
contain metavariables.

Remark: we use the `E` suffix (short for `Expr`) to avoid collision with keywords.
We considered using «...», but it is too inconvenient to use.
-/
inductive Expr where
  /--
  The `bvar` constructor represents bound variables, i.e. occurrences
  of a variable in the expression where there is a variable binder
  above it (i.e. introduced by a `lam`, `forallE`, or `letE`).

  The `deBruijnIndex` parameter is the *de-Bruijn* index for the bound
  variable. See [the Wikipedia page on de-Bruijn indices](https://en.wikipedia.org/wiki/De_Bruijn_index)
  for additional information.

  For example, consider the expression `fun x : Nat => forall y : Nat, x = y`.
  The `x` and `y` variables in the equality expression are constructed
  using `bvar` and bound to the binders introduced by the earlier
  `lam` and `forallE` constructors. Here is the corresponding `Expr` representation
  for the same expression:
  ```lean
  .lam `x (.const `Nat [])
    (.forallE `y (.const `Nat [])
      (.app (.app (.app (.const `Eq [.succ .zero]) (.const `Nat [])) (.bvar 1)) (.bvar 0))
      .default)
    .default
  ```
  -/
  | bvar (deBruijnIndex : Nat)

  /--
  The `fvar` constructor represent free variables. These *free* variable
  occurrences are not bound by an earlier `lam`, `forallE`, or `letE`
  constructor and its binder exists in a local context only.

  Note that Lean uses the *locally nameless approach*. See [McBride and McKinna](https://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.365.2479&rep=rep1&type=pdf)
  for additional details.

  When "visiting" the body of a binding expression (i.e. `lam`, `forallE`, or `letE`),
  bound variables are converted into free variables using a unique identifier,
  and their user-facing name, type, value (for `LetE`), and binder annotation
  are stored in the `LocalContext`.
  -/
  | fvar (fvarId : FVarId)

  /--
  Metavariables are used to represent "holes" in expressions, and goals in the
  tactic framework. Metavariable declarations are stored in the `MetavarContext`.
  Metavariables are used during elaboration, and are not allowed in the kernel,
  or in the code generator.
  -/
  | mvar (mvarId : MVarId)

  /--
  Used for `Type u`, `Sort u`, and `Prop`:
  - `Prop` is represented as `.sort .zero`,
  - `Sort u` as ``.sort (.param `u)``, and
  - `Type u` as ``.sort (.succ (.param `u))``
  -/
  | sort (u : Level)

  /--
  A (universe polymorphic) constant that has been defined earlier in the module or
  by another imported module. For example, `@Eq.{1}` is represented
  as ``Expr.const `Eq [.succ .zero]``, and `@Array.map.{0, 0}` is represented
  as ``Expr.const `Array.map [.zero, .zero]``.
  -/
  | const (declName : Name) (us : List Level)

  /--
  A function application.

  For example, the natural number one, i.e. `Nat.succ Nat.zero` is represented as
  ``Expr.app (.const `Nat.succ []) (.const .zero [])``.
  Note that multiple arguments are represented using partial application.

  For example, the two argument application `f x y` is represented as
  `Expr.app (.app f x) y`.
  -/
  | app (fn : Expr) (arg : Expr)

  /--
  A lambda abstraction (aka anonymous functions). It introduces a new binder for
  variable `x` in scope for the lambda body.

  For example, the expression `fun x : Nat => x` is represented as
  ```
  Expr.lam `x (.const `Nat []) (.bvar 0) .default
  ```
  -/
  | lam (binderName : Name) (binderType : Expr) (body : Expr) (binderInfo : BinderInfo)

  /--
  A dependent arrow `(a : α) → β)` (aka forall-expression) where `β` may dependent
  on `a`. Note that this constructor is also used to represent non-dependent arrows
  where `β` does not depend on `a`.

  For example:
  - `forall x : Prop, x ∧ x`:
    ```lean
    Expr.forallE `x (.sort .zero)
      (.app (.app (.const `And []) (.bvar 0)) (.bvar 0)) .default
    ```
  - `Nat → Bool`:
    ```lean
    Expr.forallE `a (.const `Nat [])
      (.const `Bool []) .default
    ```
  -/
  | forallE (binderName : Name) (binderType : Expr) (body : Expr) (binderInfo : BinderInfo)

  /--
  Let-expressions.

  The let-expression `let x : Nat := 2; Nat.succ x` is represented as
  ```
  Expr.letE `x (.const `Nat []) (.lit (.natVal 2)) (.app (.const `Nat.succ []) (.bvar 0)) true
  ```

  If the `nondep` flag is `true`, then the elaborator treats this as a *non-dependent `let`* (known as a *`have` expression*).
  Given an environment, a metavariable context, and a local context,
  we say a let-expression `let x : t := v; e` is non-dependent when it is equivalent
  to `(fun x : t => e) v`. In contrast, the dependent let-expression
  `let n : Nat := 2; fun (a : Array Nat n) (b : Array Nat 2) => a = b` is type correct,
  but `(fun (n : Nat) (a : Array Nat n) (b : Array Nat 2) => a = b) 2` is not.

  The kernel does not verify `nondep` when type checking. This is an elaborator feature.
  -/
  | letE (declName : Name) (type : Expr) (value : Expr) (body : Expr) (nondep : Bool)

  /--
  Natural number and string literal values.

  They are not really needed, but provide a more compact representation in memory
  for these two kinds of literals, and are used to implement efficient reduction
  in the elaborator and kernel. The "raw" natural number `2` can be represented
  as `Expr.lit (.natVal 2)`. Note that, it is definitionally equal to:
  ```lean
  Expr.app (.const `Nat.succ []) (.app (.const `Nat.succ []) (.const `Nat.zero []))
  ```
  -/
  | lit : Literal → Expr

  /--
  Metadata (aka annotations).

  We use annotations to provide hints to the pretty-printer,
  store references to `Syntax` nodes, position information, and save information for
  elaboration procedures (e.g., we use the `inaccessible` annotation during elaboration to
  mark `Expr`s that correspond to inaccessible patterns).

  Note that `Expr.mdata data e` is definitionally equal to `e`.
  -/
  | mdata (data : MData) (expr : Expr)

  /--
  Projection-expressions. They are redundant, but are used to create more compact
  terms, speedup reduction, and implement eta for structures.
  The type of `struct` must be an structure-like inductive type. That is, it has only one
  constructor, is not recursive, and it is not an inductive predicate. The kernel and elaborators
  check whether the `typeName` matches the type of `struct`, and whether the (zero-based) index
  is valid (i.e., it is smaller than the number of constructor fields).
  When exporting Lean developments to other systems, `proj` can be replaced with `typeName`.`rec`
  applications.

  Example, given `a : Nat × Bool`, `a.1` is represented as
  ```
  .proj `Prod 0 a
  ```
  -/
  | proj (typeName : Name) (idx : Nat) (struct : Expr)
with
  @[computed_field, extern "lean_expr_data"]
  data : @& Expr → Data
    | .const n lvls => mkData (mixHash 5 <| mixHash (hash n) (hash lvls)) 0 0 false false (lvls.any Level.hasMVar) (lvls.any Level.hasParam)
    | .bvar idx => mkData (mixHash 7 <| hash idx) (idx+1)
    | .sort lvl => mkData (mixHash 11 <| hash lvl) 0 0 false false lvl.hasMVar lvl.hasParam
    | .fvar fvarId => mkData (mixHash 13 <| hash fvarId) 0 0 true
    | .mvar fvarId => mkData (mixHash 17 <| hash fvarId) 0 0 false true
    | .mdata _m e =>
      let d := e.data.approxDepth.toUInt32+1
      mkData (mixHash d.toUInt64 <| e.data.hash) e.data.looseBVarRange.toNat d e.data.hasFVar e.data.hasExprMVar e.data.hasLevelMVar e.data.hasLevelParam
    | .proj s i e =>
      let d := e.data.approxDepth.toUInt32+1
      mkData (mixHash d.toUInt64 <| mixHash (hash s) <| mixHash (hash i) e.data.hash)
          e.data.looseBVarRange.toNat d e.data.hasFVar e.data.hasExprMVar e.data.hasLevelMVar e.data.hasLevelParam
    | .app f a => mkAppData f.data a.data
    | .lam _ t b _ =>
      let d := (max t.data.approxDepth.toUInt32 b.data.approxDepth.toUInt32) + 1
      mkDataForBinder (mixHash d.toUInt64 <| mixHash t.data.hash b.data.hash)
        (max t.data.looseBVarRange.toNat (b.data.looseBVarRange.toNat - 1))
        d
        (t.data.hasFVar || b.data.hasFVar)
        (t.data.hasExprMVar || b.data.hasExprMVar)
        (t.data.hasLevelMVar || b.data.hasLevelMVar)
        (t.data.hasLevelParam || b.data.hasLevelParam)
    | .forallE _ t b _ =>
      let d := (max t.data.approxDepth.toUInt32 b.data.approxDepth.toUInt32) + 1
      mkDataForBinder (mixHash d.toUInt64 <| mixHash t.data.hash b.data.hash)
        (max t.data.looseBVarRange.toNat (b.data.looseBVarRange.toNat - 1))
        d
        (t.data.hasFVar || b.data.hasFVar)
        (t.data.hasExprMVar || b.data.hasExprMVar)
        (t.data.hasLevelMVar || b.data.hasLevelMVar)
        (t.data.hasLevelParam || b.data.hasLevelParam)
    | .letE _ t v b _ =>
      let d := (max (max t.data.approxDepth.toUInt32 v.data.approxDepth.toUInt32) b.data.approxDepth.toUInt32) + 1
      mkDataForLet (mixHash d.toUInt64 <| mixHash t.data.hash <| mixHash v.data.hash b.data.hash)
        (max (max t.data.looseBVarRange.toNat v.data.looseBVarRange.toNat) (b.data.looseBVarRange.toNat - 1))
        d
        (t.data.hasFVar || v.data.hasFVar || b.data.hasFVar)
        (t.data.hasExprMVar || v.data.hasExprMVar || b.data.hasExprMVar)
        (t.data.hasLevelMVar || v.data.hasLevelMVar || b.data.hasLevelMVar)
        (t.data.hasLevelParam || v.data.hasLevelParam || b.data.hasLevelParam)
    | .lit l => mkData (mixHash 3 (hash l))
deriving Repr

instance : Inhabited Expr where
  -- use a distinctive name to aid debugging
  default := .const `_inhabitedExprDummy []

namespace Expr

/-- The constructor name for the given expression. This is used for debugging purposes. -/
def ctorName : Expr → String
  | bvar ..    => "bvar"
  | fvar ..    => "fvar"
  | mvar ..    => "mvar"
  | sort ..    => "sort"
  | const ..   => "const"
  | app ..     => "app"
  | lam ..     => "lam"
  | forallE .. => "forallE"
  | letE ..    => "letE"
  | lit ..     => "lit"
  | mdata ..   => "mdata"
  | proj ..    => "proj"

protected def hash (e : Expr) : UInt64 :=
  e.data.hash

instance : Hashable Expr := ⟨Expr.hash⟩

/--
Return `true` if `e` contains free variables.
This is a constant time operation.
-/
def hasFVar (e : Expr) : Bool :=
  e.data.hasFVar

/--
Return `true` if `e` contains expression metavariables.
This is a constant time operation.
-/
def hasExprMVar (e : Expr) : Bool :=
  e.data.hasExprMVar

/--
Return `true` if `e` contains universe (aka `Level`) metavariables.
This is a constant time operation.
-/
def hasLevelMVar (e : Expr) : Bool :=
  e.data.hasLevelMVar

/--
Does the expression contain level (aka universe) or expression metavariables?
This is a constant time operation.
-/
def hasMVar (e : Expr) : Bool :=
  let d := e.data
  d.hasExprMVar || d.hasLevelMVar

/--
Return true if `e` contains universe level parameters.
This is a constant time operation.
-/
def hasLevelParam (e : Expr) : Bool :=
  e.data.hasLevelParam

/--
Return the approximated depth of an expression. This information is used to compute
the expression hash code, and speedup comparisons.
This is a constant time operation. We say it is approximate because it maxes out at `255`.
-/
def approxDepth (e : Expr) : UInt32 :=
  e.data.approxDepth.toUInt32

/--
The range of de-Bruijn variables that are loose.
That is, bvars that are not bound by a binder.
For example, `bvar i` has range `i + 1` and
an expression with no loose bvars has range `0`.
-/
def looseBVarRange (e : Expr) : Nat :=
  e.data.looseBVarRange.toNat

/--
Return the binder information if `e` is a lambda or forall expression, and `.default` otherwise.
-/
def binderInfo (e : Expr) : BinderInfo :=
  match e with
  | .forallE _ _ _ bi => bi
  | .lam _ _ _ bi => bi
  | _ => .default

/-!
Export functions.
-/
@[export lean_expr_hash] def hashEx : Expr → UInt64 := hash
@[export lean_expr_has_fvar] def hasFVarEx : Expr → Bool := hasFVar
@[export lean_expr_has_expr_mvar] def hasExprMVarEx : Expr → Bool := hasExprMVar
@[export lean_expr_has_level_mvar] def hasLevelMVarEx : Expr → Bool := hasLevelMVar
@[export lean_expr_has_mvar] def hasMVarEx : Expr → Bool := hasMVar
@[export lean_expr_has_level_param] def hasLevelParamEx : Expr → Bool := hasLevelParam
@[export lean_expr_loose_bvar_range] def looseBVarRangeEx (e : Expr) : UInt32 := e.data.looseBVarRange
@[export lean_expr_binder_info] def binderInfoEx : Expr → BinderInfo := binderInfo

end Expr

/-- `mkConst declName us` return `.const declName us`. -/
def mkConst (declName : Name) (us : List Level := []) : Expr :=
  .const declName us

/-- Return the type of a literal value. -/
def Literal.type : Literal → Expr
  | .natVal _ => mkConst `Nat
  | .strVal _ => mkConst `String

@[export lean_lit_type]
def Literal.typeEx : Literal → Expr := Literal.type

/-- `.bvar idx` is now the preferred form. -/
def mkBVar (idx : Nat) : Expr :=
  .bvar idx

/-- `.sort u` is now the preferred form. -/
def mkSort (u : Level) : Expr :=
  .sort u

/--
`.fvar fvarId` is now the preferred form.
This function is seldom used, free variables are often automatically created using the
telescope functions (e.g., `forallTelescope` and `lambdaTelescope`) at `MetaM`.
-/
def mkFVar (fvarId : FVarId) : Expr :=
  .fvar fvarId

/--
`.mvar mvarId` is now the preferred form.
This function is seldom used, metavariables are often created using functions such
as `mkFreshExprMVar` at `MetaM`.
-/
def mkMVar (mvarId : MVarId) : Expr :=
  .mvar mvarId

/--
`.mdata m e` is now the preferred form.
-/
def mkMData (m : MData) (e : Expr) : Expr :=
  .mdata m e

/--
`.proj structName idx struct` is now the preferred form.
-/
def mkProj (structName : Name) (idx : Nat) (struct : Expr) : Expr :=
  .proj structName idx struct

/--
`.app f a` is now the preferred form.
-/
@[match_pattern, expose] def mkApp (f a : Expr) : Expr :=
  .app f a

/--
`.lam x t b bi` is now the preferred form.
-/
def mkLambda (x : Name) (bi : BinderInfo) (t : Expr) (b : Expr) : Expr :=
  .lam x t b bi

/--
`.forallE x t b bi` is now the preferred form.
-/
def mkForall (x : Name) (bi : BinderInfo) (t : Expr) (b : Expr) : Expr :=
  .forallE x t b bi

/-- Return `Unit -> type`. Do not confuse with `Thunk type` -/
def mkSimpleThunkType (type : Expr) : Expr :=
  mkForall Name.anonymous .default (mkConst `Unit) type

/-- Return `fun (_ : Unit), e` -/
def mkSimpleThunk (type : Expr) : Expr :=
  mkLambda `_ BinderInfo.default (mkConst `Unit) type

/-- Returns `let x : t := v; b`, a `let` expression. If `nondep := true`, then returns a `have`. -/
@[inline] def mkLet (x : Name) (t : Expr) (v : Expr) (b : Expr) (nondep : Bool := false) : Expr :=
  .letE x t v b nondep

/-- Returns `have x : t := v; b`, a non-dependent `let` expression. -/
@[inline] def mkHave (x : Name) (t : Expr) (v : Expr) (b : Expr) : Expr :=
  .letE x t v b true

@[match_pattern, expose] def mkAppB (f a b : Expr) := mkApp (mkApp f a) b
@[match_pattern, expose] def mkApp2 (f a b : Expr) := mkAppB f a b
@[match_pattern, expose] def mkApp3 (f a b c : Expr) := mkApp (mkAppB f a b) c
@[match_pattern, expose] def mkApp4 (f a b c d : Expr) := mkAppB (mkAppB f a b) c d
@[match_pattern, expose] def mkApp5 (f a b c d e : Expr) := mkApp (mkApp4 f a b c d) e
@[match_pattern, expose] def mkApp6 (f a b c d e₁ e₂ : Expr) := mkAppB (mkApp4 f a b c d) e₁ e₂
@[match_pattern, expose] def mkApp7 (f a b c d e₁ e₂ e₃ : Expr) := mkApp3 (mkApp4 f a b c d) e₁ e₂ e₃
@[match_pattern, expose] def mkApp8 (f a b c d e₁ e₂ e₃ e₄ : Expr) := mkApp4 (mkApp4 f a b c d) e₁ e₂ e₃ e₄
@[match_pattern, expose] def mkApp9 (f a b c d e₁ e₂ e₃ e₄ e₅ : Expr) := mkApp5 (mkApp4 f a b c d) e₁ e₂ e₃ e₄ e₅
@[match_pattern, expose] def mkApp10 (f a b c d e₁ e₂ e₃ e₄ e₅ e₆ : Expr) := mkApp6 (mkApp4 f a b c d) e₁ e₂ e₃ e₄ e₅ e₆

/--
`.lit l` is now the preferred form.
-/
def mkLit (l : Literal) : Expr :=
  .lit l

/--
Return the "raw" natural number `.lit (.natVal n)`.
This is not the default representation used by the Lean frontend.
See `mkNatLit`.
-/
def mkRawNatLit (n : Nat) : Expr :=
  mkLit (.natVal n)

/--
Return a natural number literal used in the frontend. It is a `OfNat.ofNat` application.
Recall that all theorems and definitions containing numeric literals are encoded using
`OfNat.ofNat` applications in the frontend.
-/
def mkNatLit (n : Nat) : Expr :=
  let r := mkRawNatLit n
  mkApp3 (mkConst ``OfNat.ofNat [levelZero]) (mkConst ``Nat) r (mkApp (mkConst ``instOfNatNat) r)

/-- Return the string literal `.lit (.strVal s)` -/
def mkStrLit (s : String) : Expr :=
  mkLit (.strVal s)

@[export lean_expr_mk_bvar] def mkBVarEx : Nat → Expr := mkBVar
@[export lean_expr_mk_fvar] def mkFVarEx : FVarId → Expr := mkFVar
@[export lean_expr_mk_mvar] def mkMVarEx : MVarId → Expr := mkMVar
@[export lean_expr_mk_sort] def mkSortEx : Level → Expr := mkSort
@[export lean_expr_mk_const] def mkConstEx (c : Name) (lvls : List Level) : Expr := mkConst c lvls
@[export lean_expr_mk_app] def mkAppEx : Expr → Expr → Expr := mkApp
@[export lean_expr_mk_lambda] def mkLambdaEx (n : Name) (d b : Expr) (bi : BinderInfo) : Expr := mkLambda n bi d b
@[export lean_expr_mk_forall] def mkForallEx (n : Name) (d b : Expr) (bi : BinderInfo) : Expr := mkForall n bi d b
@[export lean_expr_mk_let] def mkLetEx (n : Name) (t v b : Expr) (nondep : Bool) : Expr := mkLet n t v b nondep
@[export lean_expr_mk_lit] def mkLitEx : Literal → Expr := mkLit
@[export lean_expr_mk_mdata] def mkMDataEx : MData → Expr → Expr := mkMData
@[export lean_expr_mk_proj] def mkProjEx : Name → Nat → Expr → Expr := mkProj

/--
`mkAppN f #[a₀, ..., aₙ]` constructs the application `f a₀ a₁ ... aₙ`.
-/
def mkAppN (f : Expr) (args : Array Expr) : Expr :=
  args.foldl mkApp f

private def mkAppRangeAux (n : Nat) (args : Array Expr) (i : Nat) (e : Expr) : Expr :=
  if i < n then mkAppRangeAux n args (i+1) (mkApp e args[i]!) else e

/-- `mkAppRange f i j #[a_1, ..., a_i, ..., a_j, ... ]` ==> the expression `f a_i ... a_{j-1}` -/
def mkAppRange (f : Expr) (i j : Nat) (args : Array Expr) : Expr :=
  mkAppRangeAux j args i f

/-- Same as `mkApp f args` but reversing `args`. -/
def mkAppRev (fn : Expr) (revArgs : Array Expr) : Expr :=
  revArgs.foldr (fun a r => mkApp r a) fn

namespace Expr
-- TODO: implement it in Lean
@[extern "lean_expr_dbg_to_string"]
opaque dbgToString (e : @& Expr) : String

/-- A total order for expressions. We say it is quick because it first compares the hashcodes. -/
@[extern "lean_expr_quick_lt"]
opaque quickLt (a : @& Expr) (b : @& Expr) : Bool

/-- A total order for expressions that takes the structure into account (e.g., variable names). -/
@[extern "lean_expr_lt"]
opaque lt (a : @& Expr) (b : @& Expr) : Bool

def quickComp (a b : Expr) : Ordering :=
  if quickLt a b then .lt
  else if quickLt b a then .gt
  else .eq

/--
Return true iff `a` and `b` are alpha equivalent.
Binder annotations are ignored.
-/
@[extern "lean_expr_eqv"]
opaque eqv (a : @& Expr) (b : @& Expr) : Bool

instance : BEq Expr where
  beq := Expr.eqv

/--
Return `true` iff `a` and `b` are equal.
Binder names and annotations are taken into account.
-/
@[extern "lean_expr_equal"]
opaque equal (a : @& Expr) (b : @& Expr) : Bool

/-- Return `true` if the given expression is a `.sort ..` -/
def isSort : Expr → Bool
  | sort .. => true
  | _       => false

/-- Return `true` if the given expression is of the form `.sort (.succ ..)`. -/
def isType : Expr → Bool
  | sort (.succ ..) => true
  | _ => false

/-- Return `true` if the given expression is of the form `.sort (.succ .zero)`. -/
def isType0 : Expr → Bool
  | sort (.succ .zero) => true
  | _ => false

/-- Return `true` if the given expression is `.sort .zero` -/
def isProp : Expr → Bool
  | sort .zero => true
  | _ => false

/-- Return `true` if the given expression is a bound variable. -/
def isBVar : Expr → Bool
  | bvar .. => true
  | _       => false

/-- Return `true` if the given expression is a metavariable. -/
def isMVar : Expr → Bool
  | mvar .. => true
  | _       => false

/-- Return `true` if the given expression is a free variable. -/
def isFVar : Expr → Bool
  | fvar .. => true
  | _       => false

/-- Return `true` if the given expression is an application. -/
def isApp : Expr → Bool
  | app .. => true
  | _      => false

/-- Return `true` if the given expression is a projection `.proj ..` -/
def isProj : Expr → Bool
  | proj ..  => true
  | _        => false

/-- Return `true` if the given expression is a constant. -/
def isConst : Expr → Bool
  | const .. => true
  | _        => false

/--
Return `true` if the given expression is a constant of the given name.
Examples:
- `` (.const `Nat []).isConstOf `Nat `` is `true`
- `` (.const `Nat []).isConstOf `False `` is `false`
-/
def isConstOf : Expr → Name → Bool
  | const n .., m => n == m
  | _,          _ => false

/--
Return `true` if the given expression is a free variable with the given id.
Examples:
- `isFVarOf (.fvar id) id` is `true`
- ``isFVarOf (.fvar id) id'`` is `false`
- ``isFVarOf (.sort levelZero) id`` is `false`
-/
def isFVarOf : Expr → FVarId → Bool
  | .fvar fvarId, fvarId' => fvarId == fvarId'
  | _, _ => false

/-- Return `true` if the given expression is a forall-expression aka (dependent) arrow. -/
@[expose] def isForall : Expr → Bool
  | forallE .. => true
  | _          => false

/-- Return `true` if the given expression is a lambda abstraction aka anonymous function. -/
def isLambda : Expr → Bool
  | lam .. => true
  | _      => false

/-- Return `true` if the given expression is a forall or lambda expression. -/
def isBinding : Expr → Bool
  | lam ..     => true
  | forallE .. => true
  | _          => false

/-- Return `true` if the given expression is a let-expression or a have-expression. -/
def isLet : Expr → Bool
  | letE .. => true
  | _       => false

/-- Return `true` if the given expression is a non-dependent let-expression (a have-expression). -/
def isHave : Expr → Bool
  | letE (nondep := nondep) .. => nondep
  | _       => false

@[export lean_expr_is_have] def isHaveEx : Expr → Bool := isHave

/-- Return `true` if the given expression is a metadata. -/
def isMData : Expr → Bool
  | mdata .. => true
  | _        => false

/-- Return `true` if the given expression is a literal value. -/
def isLit : Expr → Bool
  | lit .. => true
  | _      => false

def appFn! : Expr → Expr
  | app f _ => f
  | _       => panic! "application expected"

def appArg! : Expr → Expr
  | app _ a => a
  | _       => panic! "application expected"

def appFn!' : Expr → Expr
  | mdata _ b => appFn!' b
  | app f _   => f
  | _         => panic! "application expected"

def appArg!' : Expr → Expr
  | mdata _ b => appArg!' b
  | app _ a   => a
  | _         => panic! "application expected"

def appArg (e : Expr) (h : e.isApp) : Expr :=
  match e, h with
  | .app _ a, _ => a

def appFn (e : Expr) (h : e.isApp) : Expr :=
  match e, h with
  | .app f _, _ => f

def sortLevel! : Expr → Level
  | sort u => u
  | _      => panic! "sort expected"

def litValue! : Expr → Literal
  | lit v => v
  | _     => panic! "literal expected"

def isRawNatLit : Expr → Bool
  | lit (Literal.natVal _) => true
  | _                      => false

def rawNatLit? : Expr → Option Nat
  | lit (Literal.natVal v) => v
  | _                      => none

def isStringLit : Expr → Bool
  | lit (Literal.strVal _) => true
  | _                      => false

def isCharLit : Expr → Bool
  | app (const c _) a => c == ``Char.ofNat && a.isRawNatLit
  | _                 => false

def constName! : Expr → Name
  | const n _ => n
  | _         => panic! "constant expected"

def constName? : Expr → Option Name
  | const n _ => some n
  | _         => none

/-- If the expression is a constant, return that name. Otherwise return `Name.anonymous`. -/
def constName (e : Expr) : Name :=
  e.constName?.getD Name.anonymous

def constLevels! : Expr → List Level
  | const _ ls => ls
  | _          => panic! "constant expected"

def bvarIdx! : Expr → Nat
  | bvar idx => idx
  | _        => panic! "bvar expected"

def fvarId! : Expr → FVarId
  | fvar n => n
  | _      => panic! "fvar expected"

def fvarId? : Expr → Option FVarId
  | fvar n => some n
  | _      => none

def mvarId! : Expr → MVarId
  | mvar n => n
  | _      => panic! "mvar expected"

def bindingName! : Expr → Name
  | forallE n _ _ _ => n
  | lam n _ _ _     => n
  | _               => panic! "binding expected"

def bindingDomain! : Expr → Expr
  | forallE _ d _ _ => d
  | lam _ d _ _     => d
  | _               => panic! "binding expected"

def bindingBody! : Expr → Expr
  | forallE _ _ b _ => b
  | lam _ _ b _     => b
  | _               => panic! "binding expected"

def bindingInfo! : Expr → BinderInfo
  | forallE _ _ _ bi => bi
  | lam _ _ _ bi     => bi
  | _                => panic! "binding expected"

def forallName : (a : Expr) → a.isForall → Name
  | forallE n _ _ _, _  => n

def forallDomain : (a : Expr) → a.isForall → Expr
  | forallE _ d _ _, _  => d

def forallBody : (a : Expr) → a.isForall → Expr
  | forallE _ _ b _, _  => b

def forallInfo : (a : Expr) → a.isForall → BinderInfo
  | forallE _ _ _ i, _  => i

def letName! : Expr → Name
  | letE n .. => n
  | _         => panic! "let expression expected"

def letType! : Expr → Expr
  | letE _ t .. => t
  | _           => panic! "let expression expected"

def letValue! : Expr → Expr
  | letE _ _ v .. => v
  | _             => panic! "let expression expected"

def letBody! : Expr → Expr
  | letE _ _ _ b .. => b
  | _               => panic! "let expression expected"

def letNondep! : Expr → Bool
  | letE _ _ _ _ nondep => nondep
  | _                   => panic! "let expression expected"

def consumeMData : Expr → Expr
  | mdata _ e => consumeMData e
  | e         => e

def mdataExpr! : Expr → Expr
  | mdata _ e => e
  | _         => panic! "mdata expression expected"

def projExpr! : Expr → Expr
  | proj _ _ e => e
  | _          => panic! "proj expression expected"

def projIdx! : Expr → Nat
  | proj _ i _ => i
  | _          => panic! "proj expression expected"

/--
Return the "body" of a forall expression.
Example: let `e` be the representation for `forall (p : Prop) (q : Prop), p ∧ q`, then
`getForallBody e` returns ``.app (.app (.const `And []) (.bvar 1)) (.bvar 0)``
-/
def getForallBody : Expr → Expr
  | forallE _ _ b .. => getForallBody b
  | e                => e

def getForallBodyMaxDepth : (maxDepth : Nat) → Expr → Expr
  | (n+1), forallE _ _ b _ => getForallBodyMaxDepth n b
  | 0, e => e
  | _, e => e

/-- Given a sequence of nested foralls `(a₁ : α₁) → ... → (aₙ : αₙ) → _`,
returns the names `[a₁, ... aₙ]`. -/
def getForallBinderNames : Expr → List Name
  | forallE n _ b _ => n :: getForallBinderNames b
  | _ => []

/--
Returns the number of leading `∀` binders of an expression. Ignores metadata.
-/
def getNumHeadForalls : Expr → Nat
  | mdata _ b => getNumHeadForalls b
  | forallE _ _ body _ => getNumHeadForalls body + 1
  | _ => 0

/--
If the given expression is a sequence of
function applications `f a₁ .. aₙ`, return `f`.
Otherwise return the input expression.
-/
def getAppFn : Expr → Expr
  | app f _ => getAppFn f
  | e         => e

/--
Similar to `getAppFn`, but skips `mdata`
-/
def getAppFn' : Expr → Expr
  | app f _   => getAppFn' f
  | mdata _ a => getAppFn' a
  | e         => e

/-- Given `f a₀ a₁ ... aₙ`, returns true if `f` is a constant with name `n`. -/
def isAppOf (e : Expr) (n : Name) : Bool :=
  match e.getAppFn with
  | const c _ => c == n
  | _           => false

/--
Given `f a₁ ... aᵢ`, returns true if `f` is a constant
with name `n` and has the correct number of arguments.
-/
def isAppOfArity : Expr → Name → Nat → Bool
  | const c _, n, 0   => c == n
  | app f _,   n, a+1 => isAppOfArity f n a
  | _,         _, _   => false

/-- Similar to `isAppOfArity` but skips `Expr.mdata`. -/
def isAppOfArity' : Expr → Name → Nat → Bool
  | mdata _ b , n, a   => isAppOfArity' b n a
  | const c _,  n, 0   => c == n
  | app f _,    n, a+1 => isAppOfArity' f n a
  | _,          _,  _   => false

private def getAppNumArgsAux : Expr → Nat → Nat
  | app f _, n => getAppNumArgsAux f (n+1)
  | _,       n => n

/-- Counts the number `n` of arguments for an expression `f a₁ .. aₙ`. -/
def getAppNumArgs (e : Expr) : Nat :=
  getAppNumArgsAux e 0

/-- Like `getAppNumArgs` but ignores metadata. -/
def getAppNumArgs' (e : Expr) : Nat :=
  go e 0
where
  /-- Auxiliary definition for `getAppNumArgs'`. -/
  go : Expr → Nat → Nat
    | mdata _ b, n => go b n
    | app f _  , n => go f (n + 1)
    | _        , n => n

/--
Like `Lean.Expr.getAppFn` but assumes the application has up to `maxArgs` arguments.
If there are any more arguments than this, then they are returned by `getAppFn` as part of the function.

In particular, if the given expression is a sequence of function applications `f a₁ .. aₙ`,
returns `f a₁ .. aₖ` where `k` is minimal such that `n - k ≤ maxArgs`.
-/
def getBoundedAppFn : (maxArgs : Nat) → Expr → Expr
  | maxArgs' + 1, .app f _ => getBoundedAppFn maxArgs' f
  | _, e => e

private def getAppArgsAux : Expr → Array Expr → Nat → Array Expr
  | app f a, as, i => getAppArgsAux f (as.set! i a) (i-1)
  | _,       as, _ => as

/-- Given `f a₁ a₂ ... aₙ`, returns `#[a₁, ..., aₙ]` -/
@[inline] def getAppArgs (e : Expr) : Array Expr :=
  let dummy := mkSort levelZero
  let nargs := e.getAppNumArgs
  getAppArgsAux e (.replicate nargs dummy) (nargs-1)

private def getBoundedAppArgsAux : Expr → Array Expr → Nat → Array Expr
  | app f a, as, i + 1 => getBoundedAppArgsAux f (as.set! i a) i
  | _,       as, _     => as

/--
Like `Lean.Expr.getAppArgs` but returns up to `maxArgs` arguments.

In particular, given `f a₁ a₂ ... aₙ`, returns `#[aₖ₊₁, ..., aₙ]`
where `k` is minimal such that the size of this array is at most `maxArgs`.
-/
@[inline] def getBoundedAppArgs (maxArgs : Nat) (e : Expr) : Array Expr :=
  let dummy := mkSort levelZero
  let nargs := min maxArgs e.getAppNumArgs
  getBoundedAppArgsAux e (.replicate nargs dummy) nargs

private def getAppRevArgsAux : Expr → Array Expr → Array Expr
  | app f a, as => getAppRevArgsAux f (as.push a)
  | _,       as => as

/-- Same as `getAppArgs` but reverse the output array. -/
@[inline] def getAppRevArgs (e : Expr) : Array Expr :=
  getAppRevArgsAux e (Array.mkEmpty e.getAppNumArgs)

@[specialize] def withAppAux (k : Expr → Array Expr → α) : Expr → Array Expr → Nat → α
  | app f a, as, i => withAppAux k f (as.set! i a) (i-1)
  | f,       as, _ => k f as

/-- Given `e = f a₁ a₂ ... aₙ`, returns `k f #[a₁, ..., aₙ]`. -/
@[inline] def withApp (e : Expr) (k : Expr → Array Expr → α) : α :=
  let dummy := mkSort levelZero
  let nargs := e.getAppNumArgs
  withAppAux k e (.replicate nargs dummy) (nargs-1)

/-- Return the function (name) and arguments of an application. -/
def getAppFnArgs (e : Expr) : Name × Array Expr :=
  withApp e λ e a => (e.constName, a)

/--
Given `f a_1 ... a_n`, returns `#[a_1, ..., a_n]`.
Note that `f` may be an application.
The resulting array has size `n` even if `f.getAppNumArgs < n`.
-/
@[inline] def getAppArgsN (e : Expr) (n : Nat) : Array Expr :=
  let dummy := mkSort levelZero
  loop n e (.replicate n dummy)
where
  loop : Nat → Expr → Array Expr → Array Expr
    | 0,   _,        as => as
    | i+1, .app f a, as => loop i f (as.set! i a)
    | _,   _,        _  => panic! "too few arguments at"

/--
Given `e` of the form `f a_1 ... a_n`, return `f`.
If `n` is greater than the number of arguments, then return `e.getAppFn`.
-/
def stripArgsN (e : Expr) (n : Nat) : Expr :=
  match n, e with
  | 0,   _        => e
  | n+1, .app f _ => stripArgsN f n
  | _,   _        => e

/--
Given `e` of the form `f a_1 ... a_n ... a_m`, return `f a_1 ... a_n`.
If `n` is greater than the arity, then return `e`.
-/
def getAppPrefix (e : Expr) (n : Nat) : Expr :=
  e.stripArgsN (e.getAppNumArgs - n)

/-- Given `e = fn a₁ ... aₙ`, runs `f` on `fn` and each of the arguments `aᵢ` and
makes a new function application with the results. -/
def traverseApp {M} [Monad M]
  (f : Expr → M Expr) (e : Expr) : M Expr :=
  e.withApp fun fn args => mkAppN <$> f fn <*> args.mapM f

@[specialize] private def withAppRevAux (k : Expr → Array Expr → α) : Expr → Array Expr → α
  | app f a, as => withAppRevAux k f (as.push a)
  | f,       as => k f as

/-- Same as `withApp` but with arguments reversed. -/
@[inline] def withAppRev (e : Expr) (k : Expr → Array Expr → α) : α :=
  withAppRevAux k e (Array.mkEmpty e.getAppNumArgs)

def getRevArgD : Expr → Nat → Expr → Expr
  | app _ a, 0,   _ => a
  | app f _, i+1, v => getRevArgD f i v
  | _,       _,   v => v

def getRevArg! : Expr → Nat → Expr
  | app _ a, 0   => a
  | app f _, i+1 => getRevArg! f i
  | _,       _   => panic! "invalid index"

/-- Similar to `getRevArg!` but skips `mdata` -/
def getRevArg!' : Expr → Nat → Expr
  | mdata _ a, i => getRevArg!' a i
  | app _ a, 0   => a
  | app f _, i+1 => getRevArg!' f i
  | _,       _   => panic! "invalid index"

/-- Given `f a₀ a₁ ... aₙ`, returns the `i`th argument or panics if out of bounds. -/
@[inline] def getArg! (e : Expr) (i : Nat) (n := e.getAppNumArgs) : Expr :=
  getRevArg! e (n - i - 1)

/-- Similar to `getArg!`, but skips mdata -/
@[inline] def getArg!' (e : Expr) (i : Nat) (n := e.getAppNumArgs) : Expr :=
  getRevArg!' e (n - i - 1)

/-- Given `f a₀ a₁ ... aₙ`, returns the `i`th argument or returns `v₀` if out of bounds. -/
@[inline] def getArgD (e : Expr) (i : Nat) (v₀ : Expr) (n := e.getAppNumArgs) : Expr :=
  getRevArgD e (n - i - 1) v₀

/-- Return `true` if `e` contains any loose bound variables.

This is a constant time operation. -/
def hasLooseBVars (e : Expr) : Bool :=
  e.looseBVarRange > 0

/--
Return `true` if `e` is a non-dependent arrow.
Remark: the following function assumes `e` does not have loose bound variables.
-/
def isArrow (e : Expr) : Bool :=
  match e with
  | forallE _ _ b _ => !b.hasLooseBVars
  | _ => false

/--
Return `true` if `e` contains the specified loose bound variable with index `bvarIdx`.

This operation traverses the expression tree.
-/
@[extern "lean_expr_has_loose_bvar"]
opaque hasLooseBVar (e : @& Expr) (bvarIdx : @& Nat) : Bool

/--
Returns true if `e` contains the loose bound variable `bvarIdx` in an explicit parameter,
or in the range if `considerRange == true`.
Additionally, if the bound variable appears in an implicit parameter,
it transitively looks for that implicit parameter.
-/
-- This should be kept in sync with `lean::has_loose_bvars_in_domain`
def hasLooseBVarInExplicitDomain (e : Expr) (bvarIdx : Nat) (considerRange : Bool) : Bool :=
  match e with
  | Expr.forallE _ d b bi =>
    (hasLooseBVar d bvarIdx
      && (bi.isExplicit
          -- "Transitivity": bvar occurs in current implicit argument,
          -- so we search for the current argument in the body.
          || hasLooseBVarInExplicitDomain b 0 considerRange))
    || hasLooseBVarInExplicitDomain b (bvarIdx+1) considerRange
  | e => considerRange && hasLooseBVar e bvarIdx

/--
Lower the loose bound variables `>= s` in `e` by `d`.
That is, a loose bound variable `bvar i` with `i >= s` is mapped to `bvar (i-d)`.

Remark: if `s < d`, then the result is `e`.
-/
@[extern "lean_expr_lower_loose_bvars"]
opaque lowerLooseBVars (e : @& Expr) (s d : @& Nat) : Expr

/--
  Lift loose bound variables `>= s` in `e` by `d`. -/
@[extern "lean_expr_lift_loose_bvars"]
opaque liftLooseBVars (e : @& Expr) (s d : @& Nat) : Expr

/--
`inferImplicit e numParams considerRange` updates the first `numParams` parameter binder annotations of the `e` forall type.
It marks any parameter with an explicit binder annotation if there is another explicit arguments that depends on it or
the resulting type if `considerRange == true`.

Remark: we use this function to infer the binder annotations of structure projections.
-/
-- This should be kept in synch with `lean::infer_implicit`
def inferImplicit (e : Expr) (numParams : Nat) (considerRange : Bool) : Expr :=
  match e, numParams with
  | Expr.forallE n d b bi, i + 1 =>
    let b       := inferImplicit b i considerRange
    let newInfo := if bi.isExplicit && hasLooseBVarInExplicitDomain b 0 considerRange then BinderInfo.implicit else bi
    mkForall n newInfo d b
  | e, _ => e

/--
Uses `newBinderInfos` to update the binder infos of the first `numParams` foralls.
-/
def updateForallBinderInfos (e : Expr) (binderInfos? : List (Option BinderInfo)) : Expr :=
  match e, binderInfos? with
  | Expr.forallE n d b bi, newBi? :: binderInfos? =>
    let b  := updateForallBinderInfos b binderInfos?
    let bi := newBi?.getD bi
    Expr.forallE n d b bi
  | e, _ => e

/--
Instantiates the loose bound variables in `e` using the `subst` array,
where a loose `Expr.bvar i` at "binding depth" `d` is instantiated with `subst[i - d]` if `0 <= i - d < subst.size`,
and otherwise it is replaced with `Expr.bvar (i - subst.size)`; non-loose bound variables are not touched.

If we imagine all expressions as being able to refer to the infinite list of loose bound variables ..., 3, 2, 1, 0 in that order,
then conceptually `instantiate` is instantiating the last `n` of these and reindexing the remaining ones.
Warning: `instantiate` uses the de Bruijn indexing to index the `subst` array, which might be the reverse order from what you might expect.
See also `Lean.Expr.instantiateRev`.

**Terminology.** The "binding depth" of a subexpression is the number of bound variables available to that subexpression
by virtue of being in the bodies of `Expr.forallE`, `Expr.lam`, and `Expr.letE` expressions.
A bound variable `Expr.bvar i` is "loose" if its de Bruijn index `i` is not less than its binding depth.)

**About instantiation.** Instantiation isn't mere substitution.
When an expression from `subst` is being instantiated, its internal loose bound variables have their de Bruijn indices incremented
by the binding depth of the replaced loose bound variable.
This is necessary for the substituted expression to still refer to the correct binders after instantiation.
Similarly, the reason loose bound variables not instantiated using `subst` have their de Bruijn indices decremented like `Expr.bvar (i - subst.size)`
is that `instantiate` can be used to eliminate binding expressions internal to a larger expression,
and this adjustment keeps these bound variables referring to the same binders.
-/
@[extern "lean_expr_instantiate"]
opaque instantiate (e : @& Expr) (subst : @& Array Expr) : Expr

/--
Instantiates loose bound variable `0` in `e` using the expression `subst`,
where in particular a loose `Expr.bvar i` at binding depth `d` is instantiated with `subst` if `i = d`,
and otherwise it is replaced with `Expr.bvar (i - 1)`; non-loose bound variables are not touched.

If we imagine all expressions as being able to refer to the infinite list of loose bound variables ..., 3, 2, 1, 0 in that order,
then conceptually `instantiate1` is instantiating the last one of these and reindexing the remaining ones.

This function is equivalent to `instantiate e #[subst]`, but it avoids allocating an array.

See the documentation for `Lean.Expr.instantiate` for a description of instantiation.
In short, during instantiation the loose bound variables in `subst` have their own de Bruijn indices updated to account
for the binding depth of the replaced loose bound variable.
-/
@[extern "lean_expr_instantiate1"]
opaque instantiate1 (e : @& Expr) (subst : @& Expr) : Expr

/--
Instantiates the loose bound variables in `e` using the `subst` array.
This is equivalent to `Lean.Expr.instantiate e subst.reverse`, but it avoids reversing the array.
In particular, rather than instantiating `Expr.bvar i` with `subst[i - d]` it instantiates with `subst[subst.size - 1 - (i - d)]`,
where `d` is the binding depth.

This function instantiates with the "forwards" indexing scheme.
For example, if `e` represents the expression `fun x y => x + y`,
then `instantiateRev e.bindingBody!.bindingBody! #[a, b]` yields `a + b`.
The `instantiate` function on the other hand would yield `b + a`, since de Bruijn indices count outwards.
 -/
@[extern "lean_expr_instantiate_rev"]
opaque instantiateRev (e : @& Expr) (subst : @& Array Expr) : Expr

/--
Similar to `Lean.Expr.instantiate`, but considers only the substitutions `subst` in the range `[beginIdx, endIdx)`.
Function panics if `beginIdx <= endIdx <= subst.size` does not hold.

This function is equivalent to `instantiate e (subst.extract beginIdx endIdx)`, but it does not allocate a new array.

This instantiates with the "backwards" indexing scheme.
See also `Lean.Expr.instantiateRevRange`, which instantiates with the "forwards" indexing scheme.
-/
@[extern "lean_expr_instantiate_range"]
opaque instantiateRange (e : @& Expr) (beginIdx endIdx : @& Nat) (subst : @& Array Expr) : Expr

/--
Similar to `Lean.Expr.instantiateRev`, but considers only the substitutions `subst` in the range `[beginIdx, endIdx)`.
Function panics if `beginIdx <= endIdx <= subst.size` does not hold.

This function is equivalent to `instantiateRev e (subst.extract beginIdx endIdx)`, but it does not allocate a new array.

This instantiates with the "forwards" indexing scheme (see the docstring for `Lean.Expr.instantiateRev` for an example).
See also `Lean.Expr.instantiateRange`, which instantiates with the "backwards" indexing scheme.
-/
@[extern "lean_expr_instantiate_rev_range"]
opaque instantiateRevRange (e : @& Expr) (beginIdx endIdx : @& Nat) (subst : @& Array Expr) : Expr

/-- Replace free (or meta) variables `xs` with loose bound variables,
with `xs` ordered from outermost to innermost de Bruijn index.

For example, `e := f x y` with `xs := #[x, y]` goes to `f #1 #0`,
whereas `e := f x y` with `xs := #[y, x]` goes to `f #0 #1`. -/
@[extern "lean_expr_abstract"]
opaque abstract (e : @& Expr) (xs : @& Array Expr) : Expr

/-- Similar to `abstract`, but consider only the first `min n xs.size` entries in `xs`. -/
@[extern "lean_expr_abstract_range"]
opaque abstractRange (e : @& Expr) (n : @& Nat) (xs : @& Array Expr) : Expr

/-- Replace occurrences of the free variable `fvar` in `e` with `v` -/
def replaceFVar (e : Expr) (fvar : Expr) (v : Expr) : Expr :=
  (e.abstract #[fvar]).instantiate1 v

/-- Replace occurrences of the free variable `fvarId` in `e` with `v` -/
def replaceFVarId (e : Expr) (fvarId : FVarId) (v : Expr) : Expr :=
  replaceFVar e (mkFVar fvarId) v

/-- Replace occurrences of the free variables `fvars` in `e` with `vs` -/
def replaceFVars (e : Expr) (fvars : Array Expr) (vs : Array Expr) : Expr :=
  (e.abstract fvars).instantiateRev vs

instance : ToString Expr where
  toString := Expr.dbgToString

/-- Returns true when the expression does not have any sub-expressions. -/
def isAtomic : Expr → Bool
  | Expr.const .. => true
  | Expr.sort ..  => true
  | Expr.bvar ..  => true
  | Expr.lit ..   => true
  | Expr.mvar ..  => true
  | Expr.fvar ..  => true
  | _             => false

end Expr

def mkDecIsTrue (pred proof : Expr) :=
  mkAppB (mkConst `Decidable.isTrue) pred proof

def mkDecIsFalse (pred proof : Expr) :=
  mkAppB (mkConst `Decidable.isFalse) pred proof

abbrev ExprMap (α : Type)  := Std.HashMap Expr α
abbrev PersistentExprMap (α : Type) := PHashMap Expr α
abbrev SExprMap (α : Type)  := SMap Expr α

abbrev ExprSet := Std.HashSet Expr
abbrev PersistentExprSet := PHashSet Expr
abbrev PExprSet := PersistentExprSet

/-- Auxiliary type for forcing `==` to be structural equality for `Expr` -/
structure ExprStructEq where
  val : Expr
  deriving Inhabited

instance : Coe Expr ExprStructEq := ⟨ExprStructEq.mk⟩

namespace ExprStructEq

protected def beq : ExprStructEq → ExprStructEq → Bool
  | ⟨e₁⟩, ⟨e₂⟩ => Expr.equal e₁ e₂

protected def hash : ExprStructEq → UInt64
  | ⟨e⟩ => e.hash

instance : BEq ExprStructEq := ⟨ExprStructEq.beq⟩
instance : Hashable ExprStructEq := ⟨ExprStructEq.hash⟩
instance : ToString ExprStructEq := ⟨fun e => toString e.val⟩

end ExprStructEq

abbrev ExprStructMap (α : Type) := Std.HashMap ExprStructEq α
abbrev PersistentExprStructMap (α : Type) := PHashMap ExprStructEq α

namespace Expr

private def mkAppRevRangeAux (revArgs : Array Expr) (start : Nat) (b : Expr) (i : Nat) : Expr :=
  if i ≤ start then b
  else
    let i := i - 1
    mkAppRevRangeAux revArgs start (mkApp b revArgs[i]!) i

/-- `mkAppRevRange f b e args == mkAppRev f (revArgs.extract b e)` -/
def mkAppRevRange (f : Expr) (beginIdx endIdx : Nat) (revArgs : Array Expr) : Expr :=
  mkAppRevRangeAux revArgs beginIdx f endIdx

/--
If `f` is a lambda expression, than "beta-reduce" it using `revArgs`.
This function is often used with `getAppRev` or `withAppRev`.
Examples:
- `betaRev (fun x y => t x y) #[]` ==> `fun x y => t x y`
- `betaRev (fun x y => t x y) #[a]` ==> `fun y => t a y`
- `betaRev (fun x y => t x y) #[a, b]` ==> `t b a`
- `betaRev (fun x y => t x y) #[a, b, c, d]` ==> `t d c b a`
Suppose `t` is `(fun x y => t x y) a b c d`, then
`args := t.getAppRev` is `#[d, c, b, a]`,
and `betaRev (fun x y => t x y) #[d, c, b, a]` is `t a b c d`.

If `useZeta` is true, the function also performs zeta-reduction (reduction of let binders) to create further
opportunities for beta reduction.
-/
partial def betaRev (f : Expr) (revArgs : Array Expr) (useZeta := false) (preserveMData := false) : Expr :=
  if revArgs.size == 0 then f
  else
    let sz := revArgs.size
    let rec go (e : Expr) (i : Nat) : Expr :=
      let done (_ : Unit) : Expr :=
        let n := sz - i
        mkAppRevRange (e.instantiateRange n sz revArgs) 0 n revArgs
      match e with
      | .lam _ _ b _ =>
        if i + 1 < sz then
          go b (i+1)
        else
          b.instantiate revArgs
      | .letE _ _ v b _ =>
        if useZeta && i < sz then
          go (b.instantiate1 v) i
        else
          done ()
      | .mdata _ b =>
        if preserveMData then
          done ()
        else
          go b i
      | _ => done ()
    go f 0

/--
Apply the given arguments to `f`, beta-reducing if `f` is a
lambda expression. See docstring for `betaRev` for examples.
-/
def beta (f : Expr) (args : Array Expr) : Expr :=
  betaRev f args.reverse

/--
Count the number of lambdas at the head of the given expression.
-/
def getNumHeadLambdas : Expr → Nat
  | .lam _ _ b _ => getNumHeadLambdas b + 1
  | .mdata _ b => getNumHeadLambdas b
  | _ => 0

/--
Return true if the given expression is the function of an expression that is target for (head) beta reduction.
If `useZeta = true`, then `let`-expressions are visited. That is, it assumes
that zeta-reduction (aka let-expansion) is going to be used.

See `isHeadBetaTarget`.
-/
def isHeadBetaTargetFn (useZeta : Bool) : Expr → Bool
  | Expr.lam ..         => true
  | Expr.letE _ _ _ b _ => useZeta && isHeadBetaTargetFn useZeta b
  | Expr.mdata _ b      => isHeadBetaTargetFn useZeta b
  | _                   => false

/-- `(fun x => e) a` ==> `e[x/a]`. -/
def headBeta (e : Expr) : Expr :=
  let f := e.getAppFn
  if f.isHeadBetaTargetFn false then betaRev f e.getAppRevArgs else e

/--
Return true if the given expression is a target for (head) beta reduction.
If `useZeta = true`, then `let`-expressions are visited. That is, it assumes
that zeta-reduction (aka let-expansion) is going to be used.
-/
def isHeadBetaTarget (e : Expr) (useZeta := false) : Bool :=
  e.isApp && e.getAppFn.isHeadBetaTargetFn useZeta

private def etaExpandedBody : Expr → Nat → Nat → Option Expr
  | app f (bvar j), n+1, i => if j == i then etaExpandedBody f n (i+1) else none
  | _,              _+1, _ => none
  | f,              0,   _ => if f.hasLooseBVars then none else some f

private def etaExpandedAux : Expr → Nat → Option Expr
  | lam _ _ b _, n => etaExpandedAux b (n+1)
  | e,           n => etaExpandedBody e n 0

/--
If `e` is of the form `(fun x₁ ... xₙ => f x₁ ... xₙ)` and `f` does not contain `x₁`, ..., `xₙ`,
then return `some f`. Otherwise, return `none`.

It assumes `e` does not have loose bound variables.

Remark: `ₙ` may be 0
-/
def etaExpanded? (e : Expr) : Option Expr :=
  etaExpandedAux e 0

/-- Similar to `etaExpanded?`, but only succeeds if `ₙ ≥ 1`. -/
def etaExpandedStrict? : Expr → Option Expr
  | lam _ _ b _ => etaExpandedAux b 1
  | _           => none

/-- Return `some e'` if `e` is of the form `optParam _ e'` -/
def getOptParamDefault? (e : Expr) : Option Expr :=
  if e.isAppOfArity ``optParam 2 then
    some e.appArg!
  else
    none

/-- Return `some e'` if `e` is of the form `autoParam _ e'` -/
def getAutoParamTactic? (e : Expr) : Option Expr :=
  if e.isAppOfArity ``autoParam 2 then
    some e.appArg!
  else
    none

/-- Return `true` if `e` is of the form `outParam _` -/
@[export lean_is_out_param]
def isOutParam (e : Expr) : Bool :=
  e.isAppOfArity ``outParam 1

/-- Return `true` if `e` is of the form `semiOutParam _` -/
def isSemiOutParam (e : Expr) : Bool :=
  e.isAppOfArity ``semiOutParam 1

/-- Return `true` if `e` is of the form `optParam _ _` -/
def isOptParam (e : Expr) : Bool :=
  e.isAppOfArity ``optParam 2

/-- Return `true` if `e` is of the form `autoParam _ _` -/
def isAutoParam (e : Expr) : Bool :=
  e.isAppOfArity ``autoParam 2

/-- Returns `true` if `e` is an application of one of the type annotation gadgets. This does not check that the application has the correct arity. -/
def isTypeAnnotation (e : Expr) : Bool :=
  if let .const c _ := e.getAppFn then
    c == ``outParam || c == ``semiOutParam || c == ``optParam || c == ``autoParam
  else
    false

/--
Remove `outParam`, `optParam`, and `autoParam` applications/annotations from `e`.
Note that it does not remove nested annotations.
Examples:
- Given `e` of the form `outParam (optParam Nat b)`, `consumeTypeAnnotations e = b`.
- Given `e` of the form `Nat → outParam (optParam Nat b)`, `consumeTypeAnnotations e = e`.
-/
@[export lean_expr_consume_type_annotations]
partial def consumeTypeAnnotations (e : Expr) : Expr :=
  if e.isOptParam || e.isAutoParam then
    consumeTypeAnnotations e.appFn!.appArg!
  else if e.isOutParam || e.isSemiOutParam then
    consumeTypeAnnotations e.appArg!
  else
    e

/--
Remove metadata annotations and `outParam`, `optParam`, and `autoParam` applications/annotations from `e`.
Note that it does not remove nested annotations.
Examples:
- Given `e` of the form `outParam (optParam Nat b)`, `cleanupAnnotations e = b`.
- Given `e` of the form `Nat → outParam (optParam Nat b)`, `cleanupAnnotations e = e`.
-/
partial def cleanupAnnotations (e : Expr) : Expr :=
  let e' := e.consumeMData.consumeTypeAnnotations
  if e' == e then e else cleanupAnnotations e'

/--
Similar to `appFn`, but also applies `cleanupAnnotations` to resulting function.
This function is used compile the `match_expr` term.
-/
def appFnCleanup (e : Expr) (h : e.isApp) : Expr :=
  match e, h with
  | .app f _, _ => f.cleanupAnnotations

def isFalse (e : Expr) : Bool :=
  e.cleanupAnnotations.isConstOf ``False

def isTrue (e : Expr) : Bool :=
  e.cleanupAnnotations.isConstOf ``True

/--
`getForallArity type` returns the arity of a `forall`-type. This function consumes nested annotations,
and performs pending beta reductions. It does **not** use whnf.
Examples:
- If `a` is `Nat`, `getForallArity a` returns `0`
- If `a` is `Nat → Bool`, `getForallArity a` returns `1`
-/
partial def getForallArity : Expr → Nat
  | .mdata _ b       => getForallArity b
  | .forallE _ _ b _ => getForallArity b + 1
  | e                =>
    if e.isHeadBetaTarget then
      getForallArity e.headBeta
    else
      let e' := e.cleanupAnnotations
      if e != e' then getForallArity e' else 0

/--
Checks if an expression is a "natural number numeral in normal form",
i.e. of type `Nat`, and explicitly of the form `OfNat.ofNat n`
where `n` matches `.lit (.natVal n)` for some literal natural number `n`.
and if so returns `n`.
-/
-- Note that `Expr.lit (.natVal n)` is not considered in normal form!
def nat? (e : Expr) : Option Nat := do
  let_expr OfNat.ofNat _ n _ := e | failure
  let lit (.natVal n) := n | failure
  n

/--
Checks if an expression is an "integer numeral in normal form",
i.e. of type `Nat` or `Int`, and either a natural number numeral in normal form (as specified by `nat?`),
or the negation of a positive natural number numeral in normal form,
and if so returns the integer.
-/
def int? (e : Expr) : Option Int :=
  let_expr Neg.neg _ _ a := e | e.nat?
  match a.nat? with
  | none => none
  | some 0 => none
  | some n => some (-n)

/-- Return true iff `e` contains a free variable which satisfies `p`. -/
@[inline] def hasAnyFVar (e : Expr) (p : FVarId → Bool) : Bool :=
  let rec @[specialize] visit (e : Expr) := if !e.hasFVar then false else
    match e with
    | Expr.forallE _ d b _   => visit d || visit b
    | Expr.lam _ d b _       => visit d || visit b
    | Expr.mdata _ e         => visit e
    | Expr.letE _ t v b _    => visit t || visit v || visit b
    | Expr.app f a           => visit f || visit a
    | Expr.proj _ _ e        => visit e
    | Expr.fvar fvarId       => p fvarId
    | _                      => false
  visit e

/-- Return `true` if `e` contains the given free variable. -/
def containsFVar (e : Expr) (fvarId : FVarId) : Bool :=
  e.hasAnyFVar (· == fvarId)

/-!
The update functions try to avoid allocating new values using pointer equality.
Note that if the `update*!` functions are used under a match-expression,
the compiler will eliminate the double-match.
-/

@[inline] private unsafe def updateApp!Impl (e : Expr) (newFn : Expr) (newArg : Expr) : Expr :=
  match e with
  | app fn arg => if ptrEq fn newFn && ptrEq arg newArg then e else mkApp newFn newArg
  | _          => panic! "application expected"

@[implemented_by updateApp!Impl]
def updateApp! (e : Expr) (newFn : Expr) (newArg : Expr) : Expr :=
  match e with
  | app _ _ => mkApp newFn newArg
  | _       => panic! "application expected"

@[inline] def updateFVar! (e : Expr) (fvarIdNew : FVarId) : Expr :=
  match e with
  | .fvar fvarId => if fvarId == fvarIdNew then e else .fvar fvarIdNew
  | _            => panic! "fvar expected"

@[inline] private unsafe def updateConst!Impl (e : Expr) (newLevels : List Level) : Expr :=
  match e with
  | const n ls => if ptrEqList ls newLevels then e else mkConst n newLevels
  | _          => panic! "constant expected"

@[implemented_by updateConst!Impl]
def updateConst! (e : Expr) (newLevels : List Level) : Expr :=
  match e with
  | const n _ => mkConst n newLevels
  | _         => panic! "constant expected"

@[inline] private unsafe def updateSort!Impl (e : Expr) (u' : Level) : Expr :=
  match e with
  | sort u => if ptrEq u u' then e else mkSort u'
  | _      => panic! "level expected"

@[implemented_by updateSort!Impl]
def updateSort! (e : Expr) (newLevel : Level) : Expr :=
  match e with
  | sort _ => mkSort newLevel
  | _      => panic! "level expected"

@[inline] private unsafe def updateMData!Impl (e : Expr) (newExpr : Expr) : Expr :=
  match e with
  | mdata d a => if ptrEq a newExpr then e else mkMData d newExpr
  | _         => panic! "mdata expected"

@[implemented_by updateMData!Impl]
def updateMData! (e : Expr) (newExpr : Expr) : Expr :=
  match e with
  | mdata d _ => mkMData d newExpr
  | _         => panic! "mdata expected"

@[inline] private unsafe def updateProj!Impl (e : Expr) (newExpr : Expr) : Expr :=
  match e with
  | proj s i a => if ptrEq a newExpr then e else mkProj s i newExpr
  | _          => panic! "proj expected"

@[implemented_by updateProj!Impl]
def updateProj! (e : Expr) (newExpr : Expr) : Expr :=
  match e with
  | proj s i _ => mkProj s i newExpr
  | _          => panic! "proj expected"

@[inline] private unsafe def updateForall!Impl (e : Expr) (newBinfo : BinderInfo) (newDomain : Expr) (newBody : Expr) : Expr :=
  match e with
  | forallE n d b bi =>
    if ptrEq d newDomain && ptrEq b newBody && bi == newBinfo then
      e
    else
      mkForall n newBinfo newDomain newBody
  | _               => panic! "forall expected"

@[implemented_by updateForall!Impl]
def updateForall! (e : Expr) (newBinfo : BinderInfo) (newDomain : Expr) (newBody : Expr) : Expr :=
  match e with
  | forallE n _ _ _ => mkForall n newBinfo newDomain newBody
  | _               => panic! "forall expected"

@[inline] def updateForallE! (e : Expr) (newDomain : Expr) (newBody : Expr) : Expr :=
  match e with
  | forallE n d b bi => updateForall! (forallE n d b bi) bi newDomain newBody
  | _                => panic! "forall expected"

@[inline] private unsafe def updateLambda!Impl (e : Expr) (newBinfo : BinderInfo) (newDomain : Expr) (newBody : Expr) : Expr :=
  match e with
  | lam n d b bi =>
    if ptrEq d newDomain && ptrEq b newBody && bi == newBinfo then
      e
    else
      mkLambda n newBinfo newDomain newBody
  | _           => panic! "lambda expected"

@[implemented_by updateLambda!Impl]
def updateLambda! (e : Expr) (newBinfo : BinderInfo) (newDomain : Expr) (newBody : Expr) : Expr :=
  match e with
  | lam n _ _ _ => mkLambda n newBinfo newDomain newBody
  | _           => panic! "lambda expected"

@[inline] def updateLambdaE! (e : Expr) (newDomain : Expr) (newBody : Expr) : Expr :=
  match e with
  | lam n d b bi => updateLambda! (lam n d b bi) bi newDomain newBody
  | _            => panic! "lambda expected"

@[inline] private unsafe def updateLet!Impl (e : Expr) (newType : Expr) (newVal : Expr) (newBody : Expr) (newNondep : Bool) : Expr :=
  match e with
  | letE n t v b nondep =>
    if ptrEq t newType && ptrEq v newVal && ptrEq b newBody && nondep == newNondep then
      e
    else
      letE n newType newVal newBody newNondep
  | _              => panic! "let expression expected"

@[implemented_by updateLet!Impl]
def updateLet! (e : Expr) (newType : Expr) (newVal : Expr) (newBody : Expr) (newNondep : Bool) : Expr :=
  match e with
  | letE n _ _ _ _ => letE n newType newVal newBody newNondep
  | _              => panic! "let expression expected"

/-- Like `Expr.updateLet!` but preserves the `nondep` flag. -/
@[inline]
def updateLetE! (e : Expr) (newType : Expr) (newVal : Expr) (newBody : Expr) : Expr :=
  match e with
  | letE n t v b nondep => updateLet! (letE n t v b nondep) newType newVal newBody nondep
  | _                   => panic! "let expression expected"

def updateFn : Expr → Expr → Expr
  | e@(app f a), g => e.updateApp! (updateFn f g) a
  | _,           g => g

/--
Eta reduction. If `e` is of the form `(fun x => f x)`, then return `f`.
-/
def eta (e : Expr) : Expr :=
  match e with
  | Expr.lam _ d b _ =>
    let b' := b.eta
    match b' with
    | .app f (.bvar 0) =>
      if !f.hasLooseBVar 0 then
        f.lowerLooseBVars 1 1
      else
        e.updateLambdaE! d b'
    | _ => e.updateLambdaE! d b'
  | _ => e

/--
Annotate `e` with the given option.
The information is stored using metadata around `e`.
-/
def setOption (e : Expr) (optionName : Name) [KVMap.Value α] (val : α) : Expr :=
  mkMData (MData.empty.set optionName val) e

/--
Annotate `e` with `pp.explicit := flag`
The delaborator uses `pp` options.
-/
def setPPExplicit (e : Expr) (flag : Bool) :=
  e.setOption `pp.explicit flag

/--
Annotate `e` with `pp.universes := flag`
The delaborator uses `pp` options.
-/
def setPPUniverses (e : Expr) (flag : Bool) :=
  e.setOption `pp.universes flag

/--
Annotate `e` with `pp.piBinderTypes := flag`
The delaborator uses `pp` options.
-/
def setPPPiBinderTypes (e : Expr) (flag : Bool) :=
  e.setOption `pp.piBinderTypes flag

/--
Annotate `e` with `pp.funBinderTypes := flag`
The delaborator uses `pp` options.
-/
def setPPFunBinderTypes (e : Expr) (flag : Bool) :=
  e.setOption `pp.funBinderTypes flag

/--
Annotate `e` with `pp.numericTypes := flag`
The delaborator uses `pp` options.
-/
def setPPNumericTypes (e : Expr) (flag : Bool) :=
  e.setOption `pp.numericTypes flag

/--
If `e` is an application `f a_1 ... a_n` annotate `f`, `a_1` ... `a_n` with `pp.explicit := false`,
and annotate `e` with `pp.explicit := true`.
-/
def setAppPPExplicit (e : Expr) : Expr :=
  match e with
  | app .. =>
    let f    := e.getAppFn.setPPExplicit false
    let args := e.getAppArgs.map (·.setPPExplicit false)
    mkAppN f args |>.setPPExplicit true
  | _      => e

/--
Similar for `setAppPPExplicit`, but only annotate children with `pp.explicit := false` if
`e` does not contain metavariables.
-/
def setAppPPExplicitForExposingMVars (e : Expr) : Expr :=
  match e with
  | app .. =>
    let f    := e.getAppFn.setPPExplicit false
    let args := e.getAppArgs.map fun arg => if arg.hasMVar then arg else arg.setPPExplicit false
    mkAppN f args |>.setPPExplicit true
  | _      => e

/--
Returns true if `e` is an expression of the form `letFun v f`.
Ideally `f` is a lambda, but we do not require that here.
Warning: if the `let_fun` is applied to additional arguments (such as in `(let_fun f := id; id) 1`), this function returns `false`.
-/
@[deprecated Expr.isHave (since := "2025-06-29")]
def isLetFun (e : Expr) : Bool := e.isAppOfArity ``letFun 4

/--
Recognizes a `let_fun` expression.
For `let_fun n : t := v; b`, returns `some (n, t, v, b)`, which are the first four arguments to `Lean.Expr.letE`.
Warning: if the `let_fun` is applied to additional arguments (such as in `(let_fun f := id; id) 1`), this function returns `none`.

`let_fun` expressions are encoded as `letFun v (fun (n : t) => b)`.
They can be created using `Lean.Meta.mkLetFun`.

If in the encoding of `let_fun` the last argument to `letFun` is eta reduced, this returns `Name.anonymous` for the binder name.
-/
@[deprecated Expr.isHave (since := "2025-06-29")]
def letFun? (e : Expr) : Option (Name × Expr × Expr × Expr) :=
  match e with
  | .app (.app (.app (.app (.const ``letFun _) t) _β) v) f =>
    match f with
    | .lam n _ b _ => some (n, t, v, b)
    | _ => some (.anonymous, t, v, .app (f.liftLooseBVars 0 1) (.bvar 0))
  | _ => none

/--
Like `Lean.Expr.letFun?`, but handles the case when the `let_fun` expression is possibly applied to additional arguments.
Returns those arguments in addition to the values returned by `letFun?`.
-/
@[deprecated Expr.isHave (since := "2025-06-29")]
def letFunAppArgs? (e : Expr) : Option (Array Expr × Name × Expr × Expr × Expr) := do
  guard <| 4 ≤ e.getAppNumArgs
  guard <| e.isAppOf ``letFun
  let args := e.getAppArgs
  let t := args[0]!
  let v := args[2]!
  let f := args[3]!
  let rest := args.extract 4 args.size
  match f with
  | .lam n _ b _ => some (rest, n, t, v, b)
  | _ => some (rest, .anonymous, t, v, .app (f.liftLooseBVars 0 1) (.bvar 0))

/-- Maps `f` on each immediate child of the given expression. -/
@[specialize]
def traverseChildren [Applicative M] (f : Expr → M Expr) : Expr → M Expr
  | e@(forallE _ d b _) => pure e.updateForallE! <*> f d <*> f b
  | e@(lam _ d b _)     => pure e.updateLambdaE! <*> f d <*> f b
  | e@(mdata _ b)       => e.updateMData! <$> f b
  | e@(letE _ t v b _)  => pure e.updateLetE! <*> f t <*> f v <*> f b
  | e@(app l r)         => pure e.updateApp! <*> f l <*> f r
  | e@(proj _ _ b)      => e.updateProj! <$> f b
  | e                   => pure e

/-- `e.foldlM f a` folds the monadic function `f` over the subterms of the expression `e`,
with initial value `a`. -/
def foldlM {α : Type} {m} [Monad m] (f : α → Expr → m α) (init : α) (e : Expr) : m α :=
  Prod.snd <$> StateT.run (e.traverseChildren (fun e' => fun a => Prod.mk e' <$> f a e')) init

/--
Returns the size of `e` as a tree, i.e. nodes reachable via multiple paths are counted multiple
times.

This is a naive implementation that visits shared subterms multiple times instead of caching their
sizes. It is primarily meant for debugging.
-/
def sizeWithoutSharing : (e : Expr) → Nat
  | .forallE _ d b _ => 1 + d.sizeWithoutSharing + b.sizeWithoutSharing
  | .lam _ d b _     => 1 + d.sizeWithoutSharing + b.sizeWithoutSharing
  | .mdata _ e       => 1 + e.sizeWithoutSharing
  | .letE _ t v b _  => 1 + t.sizeWithoutSharing + v.sizeWithoutSharing + b.sizeWithoutSharing
  | .app f a         => 1 + f.sizeWithoutSharing + a.sizeWithoutSharing
  | .proj _ _ e      => 1 + e.sizeWithoutSharing
  | .lit .. | .const .. | .sort .. | .mvar .. | .fvar .. | .bvar .. => 1

end Expr

/--
Annotate `e` with the given annotation name `kind`.
It uses metadata to store the annotation.
-/
def mkAnnotation (kind : Name) (e : Expr) : Expr :=
  mkMData (KVMap.empty.insert kind (DataValue.ofBool true)) e

/--
Return `some e'` if `e = mkAnnotation kind e'`
-/
def annotation? (kind : Name) (e : Expr) : Option Expr :=
  match e with
  | .mdata d b => if d.size == 1 && d.getBool kind false then some b else none
  | _          => none

/--
Auxiliary annotation used to mark terms marked with the "inaccessible" annotation `.(t)` and
`_` in patterns.
-/
def mkInaccessible (e : Expr) : Expr :=
  mkAnnotation `_inaccessible e

/-- Return `some e'` if `e = mkInaccessible e'`. -/
def inaccessible? (e : Expr) : Option Expr :=
  annotation? `_inaccessible e

private def patternRefAnnotationKey := `_patWithRef

/--
During elaboration expressions corresponding to pattern matching terms
are annotated with `Syntax` objects. This function returns `some (stx, p')` if
`p` is the pattern `p'` annotated with `stx`
-/
def patternWithRef? (p : Expr) : Option (Syntax × Expr) :=
  match p with
  | .mdata d _ =>
    match d.find patternRefAnnotationKey with
    | some (DataValue.ofSyntax stx) => some (stx, p.mdataExpr!)
    | _ => none
  | _ => none

def isPatternWithRef (p : Expr) : Bool :=
  patternWithRef? p |>.isSome

/--
Annotate the pattern `p` with `stx`. This is an auxiliary annotation
for producing better hover information.
-/
def mkPatternWithRef (p : Expr) (stx : Syntax) : Expr :=
  if patternWithRef? p |>.isSome then
    p
  else
    mkMData (KVMap.empty.insert patternRefAnnotationKey (DataValue.ofSyntax stx)) p

/-- Return `some p` if `e` is an annotated pattern (`inaccessible?` or `patternWithRef?`) -/
def patternAnnotation? (e : Expr) : Option Expr :=
  if let some e := inaccessible? e then
    some e
  else if let some (_, e) := patternWithRef? e then
    some e
  else
    none

/--
Annotate `e` with the LHS annotation. The delaborator displays
expressions of the form `lhs = rhs` as `lhs` when they have this annotation.
This is used to implement the infoview for the `conv` mode.

This version of `mkLHSGoal` does not check that the argument is an equality.
-/
def mkLHSGoalRaw (e : Expr) : Expr :=
  mkAnnotation `_lhsGoal e

/-- Return `some lhs` if `e = mkLHSGoal e'`, where `e'` is of the form `lhs = rhs`. -/
def isLHSGoal? (e : Expr) : Option Expr :=
  match annotation? `_lhsGoal e with
  | none => none
  | some e =>
    if e.isAppOfArity `Eq 3 then
      some e.appFn!.appArg!
    else
      none

/--
Polymorphic operation for generating unique/fresh free variable identifiers.
It is available in any monad `m` that implements the interface `MonadNameGenerator`.
-/
def mkFreshFVarId [Monad m] [MonadNameGenerator m] : m FVarId :=
  return { name := (← mkFreshId) }

/--
Polymorphic operation for generating unique/fresh metavariable identifiers.
It is available in any monad `m` that implements the interface `MonadNameGenerator`.
-/
def mkFreshMVarId [Monad m] [MonadNameGenerator m] : m MVarId :=
  return { name := (← mkFreshId) }

/--
Polymorphic operation for generating unique/fresh universe metavariable identifiers.
It is available in any monad `m` that implements the interface `MonadNameGenerator`.
-/
def mkFreshLMVarId [Monad m] [MonadNameGenerator m] : m LMVarId :=
  return { name := (← mkFreshId) }

/-- Return `Not p` -/
def mkNot (p : Expr) : Expr := mkApp (mkConst ``Not) p
/-- Return `p ∨ q` -/
def mkOr (p q : Expr) : Expr := mkApp2 (mkConst ``Or) p q
/-- Return `p ∧ q` -/
def mkAnd (p q : Expr) : Expr := mkApp2 (mkConst ``And) p q
/-- Make an n-ary `And` application. `mkAndN []` returns `True`. -/
def mkAndN : List Expr → Expr
  | [] => mkConst ``True
  | [p] => p
  | p :: ps => mkAnd p (mkAndN ps)
/-- Return `Classical.em p` -/
def mkEM (p : Expr) : Expr := mkApp (mkConst ``Classical.em) p
/-- Return `p ↔ q` -/
def mkIff (p q : Expr) : Expr := mkApp2 (mkConst ``Iff) p q

/-! Constants for Nat typeclasses. -/
namespace Nat

protected def mkType : Expr := mkConst ``Nat

def mkInstAdd : Expr := mkConst ``instAddNat
def mkInstHAdd : Expr := mkApp2 (mkConst ``instHAdd [levelZero]) Nat.mkType mkInstAdd

def mkInstSub : Expr := mkConst ``instSubNat
def mkInstHSub : Expr := mkApp2 (mkConst ``instHSub [levelZero]) Nat.mkType mkInstSub

def mkInstMul : Expr := mkConst ``instMulNat
def mkInstHMul : Expr := mkApp2 (mkConst ``instHMul [levelZero]) Nat.mkType mkInstMul

def mkInstDiv : Expr := mkConst ``Nat.instDiv
def mkInstHDiv : Expr := mkApp2 (mkConst ``instHDiv [levelZero]) Nat.mkType mkInstDiv

def mkInstMod : Expr := mkConst ``Nat.instMod
def mkInstHMod : Expr := mkApp2 (mkConst ``instHMod [levelZero]) Nat.mkType mkInstMod

def mkInstNatPow : Expr := mkConst ``instNatPowNat
def mkInstPow  : Expr := mkApp2 (mkConst ``instPowNat [levelZero]) Nat.mkType mkInstNatPow
def mkInstHPow : Expr := mkApp3 (mkConst ``instHPow [levelZero, levelZero]) Nat.mkType Nat.mkType mkInstPow

def mkInstLT : Expr := mkConst ``instLTNat
def mkInstLE : Expr := mkConst ``instLENat

end Nat

private def natAddFn : Expr :=
  mkApp4 (mkConst ``HAdd.hAdd [0, 0, 0]) Nat.mkType Nat.mkType Nat.mkType Nat.mkInstHAdd

private def natSubFn : Expr :=
  mkApp4 (mkConst ``HSub.hSub [0, 0, 0]) Nat.mkType Nat.mkType Nat.mkType Nat.mkInstHSub

private def natMulFn : Expr :=
  mkApp4 (mkConst ``HMul.hMul [0, 0, 0]) Nat.mkType Nat.mkType Nat.mkType Nat.mkInstHMul

private def natPowFn : Expr :=
  mkApp4 (mkConst ``HPow.hPow [0, 0, 0]) Nat.mkType Nat.mkType Nat.mkType Nat.mkInstHPow

/-- Given `a : Nat`, returns `Nat.succ a` -/
def mkNatSucc (a : Expr) : Expr :=
  mkApp (mkConst ``Nat.succ) a

/-- Given `a b : Nat`, returns `a + b` -/
def mkNatAdd (a b : Expr) : Expr :=
  mkApp2 natAddFn a b

/-- Given `a b : Nat`, returns `a - b` -/
def mkNatSub (a b : Expr) : Expr :=
  mkApp2 natSubFn a b

/-- Given `a b : Nat`, returns `a * b` -/
def mkNatMul (a b : Expr) : Expr :=
  mkApp2 natMulFn a b

/-- Given `a b : Nat`, returns `a ^ b` -/
def mkNatPow (a b : Expr) : Expr :=
  mkApp2 natPowFn a b

private def natLEPred : Expr :=
  mkApp2 (mkConst ``LE.le [0]) Nat.mkType Nat.mkInstLE

/-- Given `a b : Nat`, return `a ≤ b` -/
def mkNatLE (a b : Expr) : Expr :=
  mkApp2 natLEPred a b

private def natEqPred : Expr :=
  mkApp (mkConst ``Eq [1]) Nat.mkType

/-- Given `a b : Nat`, return `a = b` -/
def mkNatEq (a b : Expr) : Expr :=
  mkApp2 natEqPred a b

/-- Given `a b : Prop`, return `a = b` -/
def mkPropEq (a b : Expr) : Expr :=
  mkApp3 (mkConst ``Eq [levelOne]) (mkSort levelZero) a b

/-! Constants for Int typeclasses. -/
namespace Int

protected def mkType : Expr := mkConst ``Int

def mkInstNeg : Expr := mkConst ``Int.instNegInt

def mkInstAdd : Expr := mkConst ``Int.instAdd
def mkInstHAdd : Expr := mkApp2 (mkConst ``instHAdd [levelZero]) Int.mkType mkInstAdd

def mkInstSub : Expr := mkConst ``Int.instSub
def mkInstHSub : Expr := mkApp2 (mkConst ``instHSub [levelZero]) Int.mkType mkInstSub

def mkInstMul : Expr := mkConst ``Int.instMul
def mkInstHMul : Expr := mkApp2 (mkConst ``instHMul [levelZero]) Int.mkType mkInstMul

def mkInstDiv : Expr := mkConst ``Int.instDiv
def mkInstHDiv : Expr := mkApp2 (mkConst ``instHDiv [levelZero]) Int.mkType mkInstDiv

def mkInstMod : Expr := mkConst ``Int.instMod
def mkInstHMod : Expr := mkApp2 (mkConst ``instHMod [levelZero]) Int.mkType mkInstMod

def mkInstPow : Expr := mkConst ``Int.instNatPow
def mkInstPowNat  : Expr := mkApp2 (mkConst ``instPowNat [levelZero]) Int.mkType mkInstPow
def mkInstHPow : Expr := mkApp3 (mkConst ``instHPow [levelZero, levelZero]) Int.mkType Nat.mkType mkInstPowNat

def mkInstLT : Expr := mkConst ``Int.instLTInt
def mkInstLE : Expr := mkConst ``Int.instLEInt

def mkInstNatCast : Expr := mkConst ``instNatCastInt

end Int

private def intNegFn : Expr :=
  mkApp2 (mkConst ``Neg.neg [0]) Int.mkType Int.mkInstNeg

private def intAddFn : Expr :=
  mkApp4 (mkConst ``HAdd.hAdd [0, 0, 0]) Int.mkType Int.mkType Int.mkType Int.mkInstHAdd

private def intSubFn : Expr :=
  mkApp4 (mkConst ``HSub.hSub [0, 0, 0]) Int.mkType Int.mkType Int.mkType Int.mkInstHSub

private def intMulFn : Expr :=
  mkApp4 (mkConst ``HMul.hMul [0, 0, 0]) Int.mkType Int.mkType Int.mkType Int.mkInstHMul

private def intDivFn : Expr :=
  mkApp4 (mkConst ``HDiv.hDiv [0, 0, 0]) Int.mkType Int.mkType Int.mkType Int.mkInstHDiv

private def intModFn : Expr :=
  mkApp4 (mkConst ``HMod.hMod [0, 0, 0]) Int.mkType Int.mkType Int.mkType Int.mkInstHMod

private def intPowNatFn : Expr :=
  mkApp4 (mkConst ``HPow.hPow [0, 0, 0]) Int.mkType Nat.mkType Int.mkType Int.mkInstHPow

private def intNatCastFn : Expr :=
  mkApp2 (mkConst ``NatCast.natCast [0]) Int.mkType Int.mkInstNatCast

/-- Given `a : Int`, returns `- a` -/
def mkIntNeg (a : Expr) : Expr :=
  mkApp intNegFn a

/-- Given `a b : Int`, returns `a + b` -/
def mkIntAdd (a b : Expr) : Expr :=
  mkApp2 intAddFn a b

/-- Given `a b : Int`, returns `a - b` -/
def mkIntSub (a b : Expr) : Expr :=
  mkApp2 intSubFn a b

/-- Given `a b : Int`, returns `a * b` -/
def mkIntMul (a b : Expr) : Expr :=
  mkApp2 intMulFn a b

/-- Given `a b : Int`, returns `a / b` -/
def mkIntDiv (a b : Expr) : Expr :=
  mkApp2 intDivFn a b

/-- Given `a b : Int`, returns `a % b` -/
def mkIntMod (a b : Expr) : Expr :=
  mkApp2 intModFn a b

/-- Given `a : Nat`, returns `NatCast.natCast (R := Int) a` -/
def mkIntNatCast (a : Expr) : Expr :=
  mkApp intNatCastFn a

/-- Given `a b : Int`, returns `a ^ b` -/
def mkIntPowNat (a b : Expr) : Expr :=
  mkApp2 intPowNatFn a b

private def intLEPred : Expr :=
  mkApp2 (mkConst ``LE.le [0]) Int.mkType Int.mkInstLE

/-- Given `a b : Int`, returns `a ≤ b` -/
def mkIntLE (a b : Expr) : Expr :=
  mkApp2 intLEPred a b

private def intEqPred : Expr :=
  mkApp (mkConst ``Eq [1]) Int.mkType

/-- Given `a b : Int`, returns `a = b` -/
def mkIntEq (a b : Expr) : Expr :=
  mkApp2 intEqPred a b

/-- Given `a b : Int`, returns `a ∣ b` -/
def mkIntDvd (a b : Expr) : Expr :=
  mkApp4 (mkConst ``Dvd.dvd [0]) Int.mkType (mkConst ``Int.instDvd) a b

def mkIntLit (n : Int) : Expr :=
  let r := mkRawNatLit n.natAbs
  let r := mkApp3 (mkConst ``OfNat.ofNat [levelZero]) Int.mkType r (mkApp (mkConst ``instOfNat) r)
  if n < 0 then
    mkIntNeg r
  else
    r

def reflBoolTrue : Expr :=
  mkApp2 (mkConst ``Eq.refl [levelOne]) (mkConst ``Bool) (mkConst ``Bool.true)

end Lean
