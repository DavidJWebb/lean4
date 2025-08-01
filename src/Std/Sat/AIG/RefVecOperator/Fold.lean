/-
Copyright (c) 2024 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Henrik Böving
-/
module

prelude
public import Std.Sat.AIG.RefVec
public import Std.Sat.AIG.LawfulVecOperator

@[expose] public section

namespace Std
namespace Sat

namespace AIG
namespace RefVec

variable {α : Type} [Hashable α] [DecidableEq α] {aig : AIG α}

@[specialize]
def fold (aig : AIG α) (vec : RefVec aig len)
    (func : (aig : AIG α) → BinaryInput aig → Entrypoint α) [LawfulOperator α BinaryInput func] :
    Entrypoint α :=
  let acc := aig.mkConstCached true
  go aig acc 0 len vec func
where
  @[specialize]
  go (aig : AIG α) (acc : Ref aig) (idx : Nat) (len : Nat) (input : RefVec aig len)
     (f : (aig : AIG α) → BinaryInput aig → Entrypoint α) [LawfulOperator α BinaryInput f] :
     Entrypoint α :=
    if hidx : idx < len then
      let res := f aig ⟨acc, input.get idx hidx⟩
      let aig := res.aig
      let newAcc := res.ref
      let input := input.cast <| by
        intros
        apply LawfulOperator.le_size_of_le_aig_size (f := f)
        omega
      go aig newAcc (idx + 1) len input f
    else
      ⟨aig, acc⟩
  termination_by len - idx

theorem fold.go_le_size {aig : AIG α} (acc : Ref aig) (idx : Nat) (s : RefVec aig len)
    (f : (aig : AIG α) → BinaryInput aig → Entrypoint α) [LawfulOperator α BinaryInput f] :
    aig.decls.size ≤ (go aig acc idx len s f).1.decls.size := by
  unfold go
  split
  next h =>
    dsimp only
    refine Nat.le_trans ?_ (by apply fold.go_le_size)
    apply LawfulOperator.le_size
  · simp
  termination_by len - idx

theorem fold_le_size {aig : AIG α} (vec : RefVec aig len)
    (func : (aig : AIG α) → BinaryInput aig → Entrypoint α)
    [LawfulOperator α BinaryInput func] :
    aig.decls.size ≤ (fold aig vec func).1.decls.size := by
  unfold fold
  dsimp only
  apply fold.go_le_size

theorem fold.go_decl_eq {aig : AIG α} (acc : Ref aig) (i : Nat) (s : RefVec aig len)
    (f : (aig : AIG α) → BinaryInput aig → Entrypoint α) [LawfulOperator α BinaryInput f] :
    ∀ (idx : Nat) (h1) (h2),
      (go aig acc i len s f).1.decls[idx]'h2 = aig.decls[idx]'h1 := by
  generalize hgo : go aig acc i len s f = res
  unfold go at hgo
  split at hgo
  · dsimp only at hgo
    rw [← hgo]
    intros
    rw [go_decl_eq]
    rw [LawfulOperator.decl_eq]
    apply LawfulOperator.lt_size_of_lt_aig_size
    assumption
  · rw [← hgo]
    intros
    simp
termination_by len - i

theorem fold_decl_eq {aig : AIG α} (vec : RefVec aig len)
    (func : (aig : AIG α) → BinaryInput aig → Entrypoint α) [LawfulOperator α BinaryInput func] :
    ∀ idx (h1 : idx < aig.decls.size) (h2),
      (fold aig vec func).1.decls[idx]'h2
        =
      aig.decls[idx]'h1 := by
  intros
  unfold fold
  dsimp only
  rw [fold.go_decl_eq]

theorem fold_lt_size_of_lt_aig_size (aig : AIG α) (vec : RefVec aig len)
    (func : (aig : AIG α) → BinaryInput aig → Entrypoint α) [LawfulOperator α BinaryInput func]
    (h : x < aig.decls.size) :
    x < (fold aig vec func).aig.decls.size := by
  apply Nat.lt_of_lt_of_le
  · exact h
  · apply fold_le_size

theorem fold_le_size_of_le_aig_size (aig : AIG α) (vec : RefVec aig len)
    (func : (aig : AIG α) → BinaryInput aig → Entrypoint α) [LawfulOperator α BinaryInput func]
    (h : x ≤ aig.decls.size) :
    x ≤ (fold aig vec func).aig.decls.size := by
  apply Nat.le_trans
  · exact h
  · apply fold_le_size

namespace fold

theorem denote_go_and {aig : AIG α} (acc : AIG.Ref aig) (curr : Nat)
    (hcurr : curr ≤ len) (input : RefVec aig len) :
    ⟦
      (go aig acc curr len input mkAndCached).aig,
      (go aig acc curr len input mkAndCached).ref,
      assign
    ⟧
      =
    (
      ⟦aig, acc, assign⟧
        ∧
      (∀ (idx : Nat) (hidx1 : idx < len), curr ≤ idx → ⟦aig, input.get idx hidx1, assign⟧)
    ) := by
  generalize hgo : go aig acc curr len input mkAndCached = res
  unfold go at hgo
  split at hgo
  · dsimp only at hgo
    rw [← hgo]
    rw [denote_go_and]
    · simp only [denote_projected_entry, denote_mkAndCached, Bool.and_eq_true, get_cast,
        eq_iff_iff]
      constructor
      · intro h
        rcases h with ⟨⟨h1, h2⟩, h3⟩
        constructor
        · assumption
        · intro idx hidx1 hidx2
          cases Nat.eq_or_lt_of_le hidx2 with
          | inl heq => simpa [heq] using h2
          | inr hlt =>
            specialize h3 idx hidx1 (by omega)
            rw [← h3]
            rw [AIG.LawfulOperator.denote_mem_prefix (f := AIG.mkAndCached)]
            · simp
            · simp [Ref.hgate]
      · simp only [and_imp]
        intro hacc hrest
        constructor
        · simp [hacc, hrest]
        · intro idx hidx1 hidx2
          specialize hrest idx hidx1 (by omega)
          rw [← hrest]
          rw [AIG.LawfulOperator.denote_mem_prefix (f := AIG.mkAndCached)]
          · simp
          · simp [Ref.hgate]
    · omega
  · rw [← hgo]
    simp only [eq_iff_iff, iff_self_and]
    omega
termination_by len - curr

end fold

@[simp]
theorem denote_fold_and {aig : AIG α} (s : RefVec aig len) :
    ⟦(fold aig s AIG.mkAndCached), assign⟧
      ↔
    (∀ (idx : Nat) (hidx : idx < len), ⟦aig, s.get idx hidx, assign⟧) := by
  unfold fold
  rw [fold.denote_go_and]
  · simp
  · omega

end RefVec
end AIG

end Sat
end Std
