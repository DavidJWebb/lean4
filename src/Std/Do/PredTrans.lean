/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sebastian Graf
-/
module

prelude
public import Init.Control.Lawful
public import Std.Do.PostCond

@[expose] public section

/-!
# Predicate transformers for arbitrary postcondition shapes

This module defines the type `PredTrans ps` of *predicate transformers* for a given `ps :
PostShape`.
`PredTrans` forms the semantic domain of the weakest precondition interpretation
`WP` in which we interpret monadic programs.

A predicate transformer `x : PredTrans ps α` is a function that takes a postcondition
`Q : PostCond α ps` and returns a precondition `x.apply Q : Assertion ps`, with the additional
monotonicity property that the precondition is stronger the stronger the postcondition is:
`Q₁ ⊢ₚ Q₂ → x.apply Q₁ ⊢ₛ x.apply Q₂`.

Since `PredTrans` itself forms a monad, we can interpret monadic programs by writing
a monad morphism into `PredTrans`; this is exactly what `WP` encodes.
This module defines interpretations of common monadic operations, such as `get`, `throw`,
`liftM`, etc.
-/

namespace Std.Do

universe u
variable {ps : PostShape.{u}} {α : Type u}

/-- The stronger the postcondition, the stronger the transformed precondition. -/
def PredTrans.Monotonic (t : PostCond α ps → Assertion ps) : Prop :=
  ∀ Q₁ Q₂, (Q₁ ⊢ₚ Q₂) → (t Q₁) ⊢ₛ (t Q₂)

/-- Transforming a conjunction of postconditions is the same as the conjunction of transformed
postconditions. -/
def PredTrans.Conjunctive (t : PostCond α ps → Assertion ps) : Prop :=
  ∀ Q₁ Q₂, t (Q₁ ∧ₚ Q₂) ⊣⊢ₛ t Q₁ ∧ t Q₂

/-- Any predicate transformer that is conjunctive is also monotonic. -/
def PredTrans.Conjunctive.mono (t : PostCond α ps → Assertion ps) (h : PredTrans.Conjunctive t) : PredTrans.Monotonic t := by
  intro Q₁ Q₂ hq
  replace hq : Q₁ = (Q₁ ∧ₚ Q₂) := PostCond.and_eq_left hq
  rw [hq, (h Q₁ Q₂).to_eq]
  exact SPred.and_elim_r

/--
  The type of predicate transformers for a given `ps : PostShape` and return type `α : Type`.
  A predicate transformer `x : PredTrans ps α` is a function that takes a postcondition
  `Q : PostCond α ps` and returns a precondition `x.apply Q : Assertion ps`, with the additional
  monotonicity property that the precondition is stronger the stronger the postcondition is:
  `Q₁ ⊢ₚ Q₂ → x.apply Q₁ ⊢ₛ x.apply Q₂`.
 -/
@[ext]
structure PredTrans (ps : PostShape) (α : Type u) : Type u where
  apply : PostCond α ps → Assertion ps
  conjunctive : PredTrans.Conjunctive apply

namespace PredTrans

theorem mono (t : PredTrans ps α) : Monotonic t.apply :=
  Conjunctive.mono t.apply t.conjunctive

/--
  Given a fixed postcondition, the *stronger* predicate transformer will yield a
  *weaker* precondition.
-/
def le (x y : PredTrans ps α) : Prop :=
  ∀ Q, y.apply Q ⊢ₛ x.apply Q -- the weaker the precondition, the smaller the PredTrans
instance : LE (PredTrans ps α) := ⟨le⟩

def pure (a : α) : PredTrans ps α :=
  { apply := fun Q => Q.1 a, conjunctive := by intro _ _; simp }

def bind (x : PredTrans ps α) (f : α → PredTrans ps β) : PredTrans ps β :=
  { apply := fun Q => x.apply (fun a => (f a).apply Q, Q.2),
    conjunctive := by
      intro Q₁ Q₂
      apply SPred.bientails.of_eq
      dsimp
      conv => rhs; rw [← (x.conjunctive _ _).to_eq]
      conv in (f _).apply _ => rw [((f _).conjunctive _ _).to_eq]
  }

def const (p : Assertion ps) : PredTrans ps α :=
  { apply := fun Q => p, conjunctive := by intro _ _; simp [SPred.and_self.to_eq] }

instance : Monad (PredTrans ps) where
  pure := pure
  bind := bind

@[simp]
theorem pure_apply (a : α) (Q : PostCond α ps) :
  (PredTrans.pure a : PredTrans ps α).apply Q = Q.1 a := by rfl

@[simp]
theorem Pure_pure_apply (a : α) (Q : PostCond α ps) :
  (Pure.pure a : PredTrans ps α).apply Q = Q.1 a := by rfl

@[simp]
theorem map_apply (f : α → β) (x : PredTrans ps α) (Q : PostCond β ps) :
  (f <$> x).apply Q = x.apply (fun a => Q.1 (f a), Q.2) := by rfl

@[simp]
theorem bind_apply (x : PredTrans ps α) (f : α → PredTrans ps β) (Q : PostCond β ps) :
  (x >>= f).apply Q = x.apply (fun a => (f a).apply Q, Q.2) := by rfl

@[simp]
theorem seq_apply (f : PredTrans ps (α → β)) (x : PredTrans ps α) (Q : PostCond β ps) :
  (f <*> x).apply Q = f.apply (fun g => x.apply (fun a => Q.1 (g a), Q.2), Q.2) := by rfl

theorem bind_mono {x y : PredTrans ps α} {f : α → PredTrans ps β}
  (h : x ≤ y) : x >>= f ≤ y >>= f := by intro Q; exact (h (_, Q.2))

instance instLawfulMonad : LawfulMonad (PredTrans ps) :=
  LawfulMonad.mk' (PredTrans ps)
    (id_map := by simp +unfoldPartialApp [Functor.map, bind, pure])
    (pure_bind := by simp +unfoldPartialApp [Bind.bind, bind, Pure.pure, pure])
    (bind_assoc := by simp +unfoldPartialApp [Bind.bind, bind])

-- The interpretation of `StateT σ (PredTrans ps) α` into `PredTrans (.arg σ ps) α`.
-- Think: modifyGetM
def pushArg {σ : Type u} (x : StateT σ (PredTrans ps) α) : PredTrans (.arg σ ps) α :=
  { apply := fun Q s => (x s).apply (fun (a, s) => Q.1 a s, Q.2),
    conjunctive := by
      intro Q₁ Q₂
      apply SPred.bientails.of_eq
      ext s
      dsimp
      rw [← ((x s).conjunctive _ _).to_eq]
  }

-- The interpretation of `ExceptT ε (PredTrans ps) α` into `PredTrans (.except ε ps) α`
def pushExcept {ps : PostShape} {α ε} (x : ExceptT ε (PredTrans ps) α) : PredTrans (.except ε ps) α :=
  { apply Q := x.apply (fun | .ok a => Q.1 a | .error e => Q.2.1 e, Q.2.2),
    conjunctive := by
      intro Q₁ Q₂
      apply SPred.bientails.of_eq
      dsimp
      rw[← (x.conjunctive _ _).to_eq]
      congr
      ext x
      cases x <;> simp
  }

@[simp]
def pushArg_apply {ps} {α σ : Type u} {Q : PostCond α (.arg σ ps)} (f : σ → PredTrans ps (α × σ)) :
  (pushArg f).apply Q = fun s => (f s).apply (fun ⟨a, s⟩ => Q.1 a s, Q.2) := rfl

@[simp]
def pushExcept_apply {ps} {α ε : Type u} {Q : PostCond α (.except ε ps)} (x : PredTrans ps (Except ε α)) :
  (pushExcept x).apply Q = x.apply (fun | .ok a => Q.1 a | .error e => Q.2.1 e, Q.2.2) := rfl

def dite_apply {ps} {Q : PostCond α ps} (c : Prop) [Decidable c] (t : c → PredTrans ps α) (e : ¬ c → PredTrans ps α) :
  (if h : c then t h else e h).apply Q = if h : c then (t h).apply Q else (e h).apply Q := by split <;> rfl

def ite_apply {ps} {Q : PostCond α ps} (c : Prop) [Decidable c] (t : PredTrans ps α) (e : PredTrans ps α) :
  (if c then t else e).apply Q = if c then t.apply Q else e.apply Q := by split <;> rfl
