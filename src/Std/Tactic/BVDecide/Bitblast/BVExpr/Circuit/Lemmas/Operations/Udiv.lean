/-
Copyright (c) 2024 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Henrik Böving
-/
module

prelude
public import Std.Tactic.BVDecide.Bitblast.BVExpr.Circuit.Lemmas.Basic
public import Std.Tactic.BVDecide.Bitblast.BVExpr.Circuit.Lemmas.Const
public import Std.Tactic.BVDecide.Bitblast.BVExpr.Circuit.Lemmas.Operations.Sub
public import Std.Tactic.BVDecide.Bitblast.BVExpr.Circuit.Lemmas.Operations.ZeroExtend
public import Std.Tactic.BVDecide.Bitblast.BVExpr.Circuit.Lemmas.Operations.Eq
public import Std.Tactic.BVDecide.Bitblast.BVExpr.Circuit.Lemmas.Operations.Ult
public import Std.Tactic.BVDecide.Bitblast.BVExpr.Circuit.Lemmas.Operations.GetLsbD
public import Std.Tactic.BVDecide.Bitblast.BVExpr.Circuit.Impl.Operations.Udiv
import all Std.Tactic.BVDecide.Bitblast.BVExpr.Circuit.Impl.Operations.Udiv
public import Std.Tactic.BVDecide.Normalize.BitVec

@[expose] public section

/-!
This module contains the verification of the `BitVec.udiv` bitblaster from `Impl.Operations.Udiv`.
-/

namespace Std.Tactic.BVDecide

open Std.Sat
open Std.Sat.AIG

namespace BVExpr
namespace bitblast

variable [Hashable α] [DecidableEq α]

namespace blastUdiv

theorem denote_blastShiftConcat (aig : AIG α) (target : ShiftConcatInput aig w)
  (assign : α → Bool) :
  ∀ (idx : Nat) (hidx : idx < w),
      ⟦(blastShiftConcat aig target).aig, (blastShiftConcat aig target).vec.get idx hidx, assign⟧
        =
      if idx = 0 then
        ⟦aig, target.bit, assign⟧
      else
        ⟦aig, target.lhs.get (idx - 1) (by omega), assign⟧
      := by
  intro idx hidx
  unfold blastShiftConcat
  have hidx_lt : idx < 1 + w := by omega
  by_cases hidx_eq : idx = 0 <;> simp +arith [hidx_lt, hidx_eq, RefVec.get_append]

theorem denote_blastShiftConcat_eq_shiftConcat (aig : AIG α) (target : ShiftConcatInput aig w)
  (x : BitVec w) (b : Bool) (assign : α → Bool)
  (hx : ∀ idx hidx, ⟦aig, target.lhs.get idx hidx, assign⟧ = x.getLsbD idx)
  (hb : ⟦aig, target.bit, assign⟧ = b) :
  ∀ (idx : Nat) (hidx : idx < w),
      ⟦(blastShiftConcat aig target).aig, (blastShiftConcat aig target).vec.get idx hidx, assign⟧
        =
      (BitVec.shiftConcat x b).getLsbD idx := by
  intro idx hidx
  simp only [denote_blastShiftConcat, hb, hx, BitVec.getLsbD_shiftConcat, hidx, decide_true,
    Bool.true_and]


theorem blastDivSubtractShift_denote_mem_prefix (aig : AIG α)
    (n d q r : AIG.RefVec aig w) (wn wr : Nat) (start : Nat) (hstart) :
    ⟦
      (blastDivSubtractShift aig n d wn wr q r).aig,
      ⟨start, inv, by apply Nat.lt_of_lt_of_le; exact hstart; apply blastDivSubtractShift_le_size⟩,
      assign
    ⟧
      =
    ⟦aig, ⟨start, inv, hstart⟩, assign⟧ := by
  apply denote.eq_of_isPrefix (entry := ⟨aig, start, inv, hstart⟩)
  apply IsPrefix.of
  · intros
    apply blastDivSubtractShift_decl_eq
  · intros
    apply blastDivSubtractShift_le_size

theorem denote_blastDivSubtractShift_q (aig : AIG α) (assign : α → Bool) (lhs rhs : BitVec w)
    (n d : AIG.RefVec aig w) (wn wr : Nat)
    (q r : AIG.RefVec aig w) (qbv rbv : BitVec w)
    (hleft : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, n.get idx hidx, assign⟧ = lhs.getLsbD idx)
    (hright : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, d.get idx hidx, assign⟧ = rhs.getLsbD idx)
    (hq : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, q.get idx hidx, assign⟧ = qbv.getLsbD idx)
    (hr : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, r.get idx hidx, assign⟧ = rbv.getLsbD idx) :
    ∀ (idx : Nat) (hidx : idx < w),
      ⟦
        (blastDivSubtractShift aig n d wn wr q r).aig,
        (blastDivSubtractShift aig n d wn wr q r).q.get idx hidx,
        assign
      ⟧
        =
      (BitVec.divSubtractShift { n := lhs, d := rhs } { wn := wn, wr := wr, q := qbv, r := rbv }).q.getLsbD idx := by
  intro idx hidx
  unfold blastDivSubtractShift BitVec.divSubtractShift
  dsimp only
  rw [AIG.LawfulVecOperator.denote_mem_prefix (f := AIG.RefVec.ite)]
  . simp only [Ref.cast_eq, RefVec.cast_cast, RefVec.get_cast]
    rw [AIG.RefVec.denote_ite]
    conv =>
      rhs
      rw [apply_ite (f := BitVec.DivModState.q)]
      rw [apply_ite (f := (BitVec.getLsbD · idx))]
    apply ite_congr
    · rw [BVPred.mkUlt_denote_eq (assign := assign) (lhs := rbv.shiftConcat (lhs.getLsbD (wn - 1))) (rhs := rhs)]
      · simp [Std.Tactic.BVDecide.Normalize.BitVec.lt_ult]
      · intro idx hidx
        simp only [RefVec.get_cast, Ref.cast_eq]
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastSub)]
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
        rw [denote_blastShiftConcat_eq_shiftConcat]
        · simp [hr]
        · rw [BVPred.denote_getD_eq_getLsbD]
          · simp [hleft]
          · simp
      · intro idx hidx
        simp only [RefVec.get_cast, Ref.cast_eq]
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastSub)]
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
        · simp [hright]
        · simp [Ref.hgate]
    · intro h
      simp only [RefVec.get_cast, Ref.cast_eq]
      rw [AIG.LawfulOperator.denote_mem_prefix (f := BVPred.mkUlt)]
      rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastSub)]
      rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
      rw [denote_blastShiftConcat_eq_shiftConcat]
      · intro idx hidx
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
        · simp [hq]
        · simp [Ref.hgate]
      · rw [denote_mkConstCached]
    · intro h
      simp only [RefVec.get_cast, Ref.cast_eq]
      rw [AIG.LawfulOperator.denote_mem_prefix (f := BVPred.mkUlt)]
      rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastSub)]
      rw [denote_blastShiftConcat_eq_shiftConcat]
      · intro idx hidx
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
        · simp [hq]
        · simp [Ref.hgate]
      · rw [denote_mkConstCached]
  . simp [Ref.hgate]

theorem denote_blastDivSubtractShift_r (aig : AIG α) (assign : α → Bool) (lhs rhs : BitVec w)
    (n d : AIG.RefVec aig w) (wn wr : Nat)
    (q r : AIG.RefVec aig w) (qbv rbv : BitVec w)
    (hleft : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, n.get idx hidx, assign⟧ = lhs.getLsbD idx)
    (hright : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, d.get idx hidx, assign⟧ = rhs.getLsbD idx)
    (hr : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, r.get idx hidx, assign⟧ = rbv.getLsbD idx)
      :
    ∀ (idx : Nat) (hidx : idx < w),
      ⟦
        (blastDivSubtractShift aig n d wn wr q r).aig,
        (blastDivSubtractShift aig n d wn wr q r).r.get idx hidx,
        assign
      ⟧
        =
      (BitVec.divSubtractShift { n := lhs, d := rhs } { wn := wn, wr := wr, q := qbv, r := rbv }).r.getLsbD idx := by
  intro idx hidx
  unfold blastDivSubtractShift BitVec.divSubtractShift
  simp only [RefVec.denote_ite, LawfulVecOperator.denote_cast_entry, RefVec.get_cast]
  rw [BVPred.mkUlt_denote_eq (lhs := rbv.shiftConcat (lhs.getLsbD (wn - 1))) (rhs := rhs)]
  · split
    next hdiscr =>
      rw [← Normalize.BitVec.lt_ult] at hdiscr
      simp only [Ref.cast_eq, hdiscr, ↓reduceIte]
      rw [AIG.LawfulVecOperator.denote_mem_prefix (f := AIG.RefVec.ite)]
      rw [AIG.LawfulOperator.denote_mem_prefix (f := BVPred.mkUlt)]
      rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastSub)]
      rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
      rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
      rw [denote_blastShiftConcat_eq_shiftConcat]
      · intro idx hidx
        simp [hr]
      · rw [BVPred.denote_getD_eq_getLsbD]
        · exact hleft
        · simp
    next hdiscr =>
      rw [← Normalize.BitVec.lt_ult] at hdiscr
      simp only [Ref.cast_eq, hdiscr, ↓reduceIte]
      rw [AIG.LawfulVecOperator.denote_mem_prefix (f := AIG.RefVec.ite)]
      rw [AIG.LawfulOperator.denote_mem_prefix (f := BVPred.mkUlt)]
      rw [denote_blastSub]
      · intro idx hidx
        simp only [RefVec.get_cast, Ref.cast_eq]
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
        rw [denote_blastShiftConcat_eq_shiftConcat]
        · simp [hr]
        · rw [BVPred.denote_getD_eq_getLsbD]
          · exact hleft
          · simp
      · intro idx hidx
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
        rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
        · simp [hright]
        · simp [Ref.hgate]
  · intro idx hidx
    rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastSub)]
    rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
    rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
    . simp only [Ref.cast_eq, RefVec.get_cast]
      rw [denote_blastShiftConcat_eq_shiftConcat]
      . simp [hr]
      . dsimp only
        rw [BVPred.denote_getD_eq_getLsbD]
        · exact hleft
        · simp
    . simp [Ref.hgate]
  · intro idx hidx
    rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastSub)]
    rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
    rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
    rw [AIG.LawfulVecOperator.denote_mem_prefix (f := blastShiftConcat)]
    . simp [hright]
    . simp [Ref.hgate]

@[simp]
theorem denote_blastDivSubtractShift_wn (aig : AIG α) (lhs rhs : BitVec w)
    (n d : AIG.RefVec aig w) (wn wr : Nat)
    (q r : AIG.RefVec aig w) (qbv rbv : BitVec w)
      :
    (blastDivSubtractShift aig n d wn wr q r).wn
      =
    (BitVec.divSubtractShift { n := lhs, d := rhs } { wn := wn, wr := wr, q := qbv, r := rbv }).wn := by
  unfold blastDivSubtractShift BitVec.divSubtractShift
  dsimp only
  split <;> simp

@[simp]
theorem denote_blastDivSubtractShift_wr (aig : AIG α) (lhs rhs : BitVec w)
    (n d : AIG.RefVec aig w) (wn wr : Nat)
    (q r : AIG.RefVec aig w) (qbv rbv : BitVec w)
      :
    (blastDivSubtractShift aig n d wn wr q r).wr
      =
    (BitVec.divSubtractShift { n := lhs, d := rhs } { wn := wn, wr := wr, q := qbv, r := rbv }).wr := by
  unfold blastDivSubtractShift BitVec.divSubtractShift
  dsimp only
  split <;> simp

theorem denote_go_eq_divRec_q (aig : AIG α) (assign : α → Bool) (curr : Nat) (lhs rhs rbv qbv : BitVec w)
    (n d q r : AIG.RefVec aig w) (wn wr : Nat)
    (hleft : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, n.get idx hidx, assign⟧ = lhs.getLsbD idx)
    (hright : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, d.get idx hidx, assign⟧ = rhs.getLsbD idx)
    (hq : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, q.get idx hidx, assign⟧ = qbv.getLsbD idx)
    (hr : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, r.get idx hidx, assign⟧ = rbv.getLsbD idx)
      :
    ∀ (idx : Nat) (hidx : idx < w),
      ⟦
        (go aig curr n d wn wr q r).aig,
        (go aig curr n d wn wr q r).q.get idx hidx,
        assign
      ⟧
        =
      (BitVec.divRec curr { n := lhs, d := rhs} { wn, wr, q := qbv, r := rbv }).q.getLsbD idx := by
  induction curr generalizing aig wn wr q r qbv rbv with
  | zero =>
    intro idx hidx
    simp [go, hq]
  | succ curr ih =>
    intro idx hidx
    rw [go, BitVec.divRec_succ, BitVec.divSubtractShift]
    split
    next hdiscr =>
      rw [ih]
      · rfl
      · intro idx hidx
        rw [blastDivSubtractShift_denote_mem_prefix]
        · simp [hleft]
        · simp [Ref.hgate]
      · intro idx hidx
        rw [blastDivSubtractShift_denote_mem_prefix]
        · simp [hright]
        · simp [Ref.hgate]
      · intro idx hidx
        rw [denote_blastDivSubtractShift_q (rbv := rbv) (qbv := qbv) (lhs := lhs) (rhs := rhs)]
        · rw [BitVec.divSubtractShift]
          simp [hdiscr]
        · exact hleft
        · exact hright
        · exact hq
        · exact hr
      · intro idx hidx
        rw [denote_blastDivSubtractShift_r (rbv := rbv) (qbv := qbv) (lhs := lhs) (rhs := rhs)]
        · rw [BitVec.divSubtractShift]
          simp [hdiscr]
        · exact hleft
        · exact hright
        · exact hr
    next hdiscr =>
      rw [ih]
      · rfl
      · intro idx hidx
        rw [blastDivSubtractShift_denote_mem_prefix]
        · simp [hleft]
        · simp [Ref.hgate]
      · intro idx hidx
        rw [blastDivSubtractShift_denote_mem_prefix]
        · simp [hright]
        · simp [Ref.hgate]
      · intro idx hidx
        rw [denote_blastDivSubtractShift_q (rbv := rbv) (qbv := qbv) (lhs := lhs) (rhs := rhs)]
        · rw [BitVec.divSubtractShift]
          simp [hdiscr]
        · exact hleft
        · exact hright
        · exact hq
        · exact hr
      · intro idx hidx
        rw [denote_blastDivSubtractShift_r (rbv := rbv) (qbv := qbv) (lhs := lhs) (rhs := rhs)]
        · rw [BitVec.divSubtractShift]
          simp [hdiscr]
        · exact hleft
        · exact hright
        · exact hr

theorem denote_go (aig : AIG α) (assign : α → Bool) (lhs rhs : BitVec w)
    (n d q r : AIG.RefVec aig w)
    (hleft : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, n.get idx hidx, assign⟧ = lhs.getLsbD idx)
    (hright : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, d.get idx hidx, assign⟧ = rhs.getLsbD idx)
    (hq : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, q.get idx hidx, assign⟧ = false)
    (hr : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, r.get idx hidx, assign⟧ = false)
    (hzero : 0#w < rhs)
      :
    ∀ (idx : Nat) (hidx : idx < w),
      ⟦
        (go aig w n d w 0 q r).aig,
        (go aig w n d w 0 q r).q.get idx hidx,
        assign
      ⟧
        =
      (lhs / rhs).getLsbD idx := by
  intro idx hidx
  rw [BitVec.udiv_eq_divRec hzero]
  rw [BitVec.DivModState.init]
  rw [denote_go_eq_divRec_q (lhs := lhs) (rhs := rhs) (qbv := 0#w) (rbv := 0#w)]
  · exact hleft
  · exact hright
  · simp [hq]
  · simp [hr]

theorem go_denote_mem_prefix (aig : AIG α) (curr : Nat)
    (n d q r : AIG.RefVec aig w) (wn wr : Nat) (start : Nat) (hstart) :
    ⟦
      (go aig curr n d wn wr q r).aig,
      ⟨start, inv, by apply Nat.lt_of_lt_of_le; exact hstart; apply go_le_size⟩,
      assign
    ⟧
      =
    ⟦aig, ⟨start, inv, hstart⟩, assign⟧ := by
  apply denote.eq_of_isPrefix (entry := ⟨aig, start, inv, hstart⟩)
  apply IsPrefix.of
  · intros
    apply go_decl_eq
  · intros
    apply go_le_size

end blastUdiv

theorem denote_blastUdiv (aig : AIG α) (lhs rhs : BitVec w) (assign : α → Bool)
      (input : BinaryRefVec aig w)
      (hleft : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, input.lhs.get idx hidx, assign⟧ = lhs.getLsbD idx)
      (hright : ∀ (idx : Nat) (hidx : idx < w), ⟦aig, input.rhs.get idx hidx, assign⟧ = rhs.getLsbD idx) :
      ∀ (idx : Nat) (hidx : idx < w),
        ⟦(blastUdiv aig input).aig, (blastUdiv aig input).vec.get idx hidx, assign⟧
          =
        (lhs / rhs).getLsbD idx := by
  intro idx hidx
  unfold blastUdiv
  simp only [Ref.cast_eq, RefVec.denote_ite,
    RefVec.get_cast]
  split
  next hdiscr =>
    rw [blastUdiv.go_denote_mem_prefix] at hdiscr
    rw [BVPred.mkEq_denote_eq (lhs := rhs) (rhs := 0#w)] at hdiscr
    · simp only [beq_iff_eq] at hdiscr
      rw [hdiscr]
      rw [blastUdiv.go_denote_mem_prefix]
      rw [AIG.LawfulOperator.denote_mem_prefix (f := BVPred.mkEq)]
      rw [denote_blastConst]
      simp
    · intro idx hidx
      simp [hright]
    · intro idx hidx
      simp
  next hdiscr =>
    rw [blastUdiv.go_denote_mem_prefix] at hdiscr
    rw [BVPred.mkEq_denote_eq (lhs := rhs) (rhs := 0#w)] at hdiscr
    · have hzero : 0#w < rhs := by
        rw [Normalize.BitVec.zero_lt_iff_zero_neq]
        simpa using hdiscr
      rw [blastUdiv.denote_go (hzero := hzero)]
      · intro idx hidx
        rw [AIG.LawfulOperator.denote_mem_prefix (f := BVPred.mkEq)]
        · simp [hleft]
        · simp [Ref.hgate]
      · intro idx hidx
        rw [AIG.LawfulOperator.denote_mem_prefix (f := BVPred.mkEq)]
        · simp [hright]
        · simp [Ref.hgate]
      · intro idx hidx
        rw [AIG.LawfulOperator.denote_mem_prefix (f := BVPred.mkEq)]
        · simp only [RefVec.get_cast, Ref.cast_eq]
          rw [denote_blastConst]
          simp
        · simp [Ref.hgate]
      · intro idx hidx
        rw [AIG.LawfulOperator.denote_mem_prefix (f := BVPred.mkEq)]
        · simp only [RefVec.get_cast, Ref.cast_eq]
          rw [denote_blastConst]
          simp
        · simp [Ref.hgate]
    · intro idx hdix
      simp [hright]
    · intro idx hdix
      simp

end bitblast
end BVExpr

end Std.Tactic.BVDecide
