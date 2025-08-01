/-
Copyright (c) 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura
-/
module

prelude
public import Init.Grind.Ordered.Module
public import Lean.Meta.Tactic.Grind.Simp
public import Lean.Meta.Tactic.Grind.SynthInstance
public import Lean.Meta.Tactic.Grind.Arith.Cutsat.ToInt
public import Lean.Meta.Tactic.Grind.Arith.CommRing.RingId
public import Lean.Meta.Tactic.Grind.Arith.CommRing.Util
public import Lean.Meta.Tactic.Grind.Arith.Linear.Util
public import Lean.Meta.Tactic.Grind.Arith.Linear.Var

public section

namespace Lean.Meta.Grind.Arith.Linear

private def preprocess (e : Expr) : GoalM Expr := do
  shareCommon (← canon e)

private def internalizeFn (fn : Expr) : GoalM Expr := do
  preprocess fn

private def preprocessConst (c : Expr) : GoalM Expr := do
  let c ← preprocess c
  internalize c 0 none
  return c

private def internalizeConst (c : Expr) : GoalM Expr := do
  let c ← shareCommon (← canon c)
  internalize c 0 none
  return c

open Grind.Linarith (Poly)

private def mkExpectedDefEqMsg (a b : Expr) : MetaM MessageData :=
  return m!"`grind linarith` expected{indentExpr a}\nto be definitionally equal to{indentExpr b}"

private def ensureDefEq (a b : Expr) : MetaM Unit := do
  unless (← withDefault <| isDefEq a b) do
    throwError (← mkExpectedDefEqMsg a b)

private def addZeroLtOne (one : Var) : LinearM Unit := do
  let p := Poly.add (-1) one .nil
  modifyStruct fun s => { s with
    lowers := s.lowers.modify one fun cs => cs.push { p, h := .oneGtZero, strict := true }
  }

private def addZeroNeOne (one : Var) : LinearM Unit := do
  let p := Poly.add 1 one .nil
  modifyStruct fun s => { s with
    diseqs := s.diseqs.modify one fun cs => cs.push { p, h := .oneNeZero }
  }

private def isNonTrivialIsCharInst (isCharInst? : Option (Expr × Nat)) : Bool :=
  match isCharInst? with
  | some (_, c) => c != 1
  | none => false

private def isCutsatType (type : Expr) : GoalM Bool := do
  if (← getConfig).cutsat then
    if (← Cutsat.isSupportedType type) then
      -- If `type` is supported by cutsat, let it handle
      return true
  return false

private def getCommRingInst? (ringId? : Option Nat) : GoalM (Option Expr) := do
  let some ringId := ringId? | return none
  return some (← CommRing.RingM.run ringId do return (← CommRing.getRing).commRingInst)

private def mkRingInst? (u : Level) (type : Expr) (commRingInst? : Option Expr) : GoalM (Option Expr) := do
  if let some commRingInst := commRingInst? then
    return mkApp2 (mkConst ``Grind.CommRing.toRing [u]) type commRingInst
  else
    synthInstance? <| mkApp (mkConst ``Grind.Ring [u]) type

private def mkIntModuleInst? (u : Level) (type : Expr) (ringInst? : Option Expr) : GoalM (Option Expr) := do
  if let some ringInst := ringInst? then
    return some <| mkApp2 (mkConst ``Grind.Ring.toIntModule [u]) type ringInst
  else
    synthInstance? <| mkApp (mkConst ``Grind.IntModule [u]) type

private def mkSemiringInst? (u : Level) (type : Expr) (ringInst? : Option Expr) : GoalM (Option Expr) := do
  if let some ringInst := ringInst? then
    return some <| mkApp2 (mkConst ``Grind.Ring.toSemiring [u]) type ringInst
  else
    synthInstance? <| mkApp (mkConst ``Grind.Semiring [u]) type

private def mkOne? (u : Level) (type : Expr) : GoalM (Option Expr) := do
  let some oneInst ← synthInstance? (mkApp (mkConst ``One [u]) type) | return none
  let one ← internalizeConst <| mkApp2 (mkConst ``One.one [u]) type oneInst
  let one' ← mkNumeral type 1
  unless (← withDefault <| isDefEq one one') do reportIssue! (← mkExpectedDefEqMsg one one')
  return some one

private def mkOrderedRingInst? (u : Level) (type : Expr) (semiringInst? preorderInst? : Option Expr) : GoalM (Option Expr) := do
  let some semiringInst := semiringInst? | return none
  let some preorderInst := preorderInst? | return none
  let isOrdType := mkApp3 (mkConst ``Grind.OrderedRing [u]) type semiringInst preorderInst
  let some inst ← synthInstance? isOrdType
    | reportIssue! "type has a `Preorder` and is a `Semiring`, but is not an ordered ring, failed to synthesize{indentExpr isOrdType}"
      return none
  return some inst

private def mkNoNatZeroDivInst? (u : Level) (type : Expr) : GoalM (Option Expr) := do
  let natModuleType := mkApp (mkConst ``Grind.NatModule [u]) type
  let some natModuleInst ← synthInstance? natModuleType | return none
  synthInstance? <| mkApp2 (mkConst ``Grind.NoNatZeroDivisors [u]) type natModuleInst

def getStructId? (type : Expr) : GoalM (Option Nat) := do
  unless (← getConfig).linarith do return none
  if (← isCutsatType type) then return none
  if let some id? := (← get').typeIdOf.find? { expr := type } then
    return id?
  else
    let id? ← go?
    modify' fun s => { s with typeIdOf := s.typeIdOf.insert { expr := type } id? }
    return id?
where
  go? : GoalM (Option Nat) := do
    let u ← getDecLevel type
    let rec getInst? (declName : Name) : GoalM (Option Expr) := do
      synthInstance? <| mkApp (mkConst declName [u]) type
    let rec getInst (declName : Name) : GoalM Expr := do
      synthInstance <| mkApp (mkConst declName [u]) type
    let rec getBinHomoInst (declName : Name) : GoalM Expr := do
      synthInstance <| mkApp3 (mkConst declName [u, u, u]) type type type
    let rec getHMulIntInst : GoalM Expr := do
      synthInstance <| mkApp3 (mkConst ``HMul [0, u, u]) Int.mkType type type
    let rec getHMulNatInst : GoalM Expr := do
      synthInstance <| mkApp3 (mkConst ``HMul [0, u, u]) Nat.mkType type type
    let rec checkToFieldDefEq? (parentInst? : Option Expr) (instDeclName : Name) (toFieldName : Name) : GoalM (Option Expr) := do
      let some parentInst := parentInst? | return none
      let some inst ← getInst? instDeclName | return none
      let toField := mkApp2 (mkConst toFieldName [u]) type inst
      unless (← withDefault <| isDefEq parentInst toField) do
        reportIssue! (← mkExpectedDefEqMsg parentInst toField)
        return none
      return some inst
    let rec ensureToFieldDefEq (parentInst : Expr) (inst : Expr) (toFieldName : Name) : GoalM Unit := do
      let toField := mkApp2 (mkConst toFieldName [u]) type inst
      ensureDefEq parentInst toField
    let rec ensureToHomoFieldDefEq (parentInst : Expr) (inst : Expr) (toFieldName : Name) (toHeteroName : Name) : GoalM Unit := do
      let toField := mkApp2 (mkConst toFieldName [u]) type inst
      let heteroToField := mkApp2 (mkConst toHeteroName [u]) type toField
      ensureDefEq parentInst heteroToField
    let ringId? ← CommRing.getRingId? type
    let preorderInst? ← getInst? ``Grind.Preorder
    if (← getConfig).ring && ringId?.isSome && preorderInst?.isNone then
      -- If `type` is a `CommRing`, but it is not even a preorder, there is no point in use this module.
      -- `ring` module should handle it.
      return none
    let commRingInst? ← getCommRingInst? ringId?
    let ringInst? ← mkRingInst? u type commRingInst?
    let some intModuleInst ← mkIntModuleInst? u type ringInst? | return none
    let addInst ← getBinHomoInst ``HAdd
    let addFn ← internalizeFn <| mkApp4 (mkConst ``HAdd.hAdd [u, u, u]) type type type addInst
    let orderedAddInst? ← if let some preorderInst := preorderInst? then
      synthInstance? <| mkApp3 (mkConst ``Grind.OrderedAdd [u]) type addInst preorderInst
    else
      pure none
    let preorderInst? := if orderedAddInst?.isNone then none else preorderInst?
    -- preorderInst? may have been reset, check again whether this module is needed.
    if (← getConfig).ring && ringId?.isSome && preorderInst?.isNone then
      return none
    let partialInst? ← checkToFieldDefEq? preorderInst? ``Grind.PartialOrder ``Grind.PartialOrder.toPreorder
    let linearInst? ← checkToFieldDefEq? partialInst? ``Grind.LinearOrder ``Grind.LinearOrder.toPartialOrder
    let addCommGroupInst := mkApp2 (mkConst ``Grind.IntModule.toAddCommGroup [u]) type intModuleInst
    let addCommMonoidInst := mkApp2 (mkConst ``Grind.AddCommGroup.toAddCommMonoid [u]) type addCommGroupInst
    let semiringInst? ← mkSemiringInst? u type ringInst?
    let fieldInst? ← getInst? ``Grind.Field
    let one? ← mkOne? u type -- One must be created eagerly
    let orderedRingInst? ← mkOrderedRingInst? u type semiringInst? preorderInst?
    let charInst? ← if let some semiringInst := semiringInst? then getIsCharInst? u type semiringInst else pure none
    let noNatDivInst? ← mkNoNatZeroDivInst? u type
    -- TODO: generate the remaining fields on demand
    let zeroInst ← getInst ``Zero
    let zero ← internalizeConst <| mkApp2 (mkConst ``Zero.zero [u]) type zeroInst
    let ofNatZeroType := mkApp2 (mkConst ``OfNat [u]) type (mkRawNatLit 0)
    let some ofNatZeroInst ← synthInstance? ofNatZeroType | return none
    -- `ofNatZero` is used internally, we don't need to internalize
    let ofNatZero ← preprocess <| mkApp3 (mkConst ``OfNat.ofNat [u]) type (mkRawNatLit 0) ofNatZeroInst
    ensureDefEq zero ofNatZero
    let subInst ← getBinHomoInst ``HSub
    let subFn ← internalizeFn <| mkApp4 (mkConst ``HSub.hSub [u, u, u]) type type type subInst
    let negInst ← getInst ``Neg
    let negFn ← internalizeFn <| mkApp2 (mkConst ``Neg.neg [u]) type negInst
    let zsmulInst ← getHMulIntInst
    let zsmulFn ← internalizeFn <| mkApp4 (mkConst ``HMul.hMul [0, u, u]) Int.mkType type type zsmulInst
    let nsmulInst ← getHMulNatInst
    let nsmulFn ← internalizeFn <| mkApp4 (mkConst ``HMul.hMul [0, u, u]) Nat.mkType type type nsmulInst
    ensureToFieldDefEq zeroInst addCommMonoidInst ``Grind.AddCommMonoid.toZero
    ensureToHomoFieldDefEq addInst addCommMonoidInst ``Grind.AddCommMonoid.toAdd ``instHAdd
    ensureToHomoFieldDefEq subInst addCommGroupInst ``Grind.AddCommGroup.toSub ``instHSub
    ensureToFieldDefEq negInst addCommGroupInst ``Grind.AddCommGroup.toNeg
    ensureToFieldDefEq zsmulInst intModuleInst ``Grind.IntModule.zsmul
    ensureToFieldDefEq nsmulInst intModuleInst ``Grind.IntModule.nsmul
    let (leFn?, ltFn?) ← if let some preorderInst := preorderInst? then
      let leInst ← getInst ``LE
      let ltInst ← getInst ``LT
      let leFn ← internalizeFn <| mkApp2 (mkConst ``LE.le [u]) type leInst
      let ltFn ← internalizeFn <| mkApp2 (mkConst ``LT.lt [u]) type ltInst
      ensureToFieldDefEq leInst preorderInst ``Grind.Preorder.toLE
      ensureToFieldDefEq ltInst preorderInst ``Grind.Preorder.toLT
      pure (some leFn, some ltFn)
    else
      pure (none, none)
    let rec getHSMulFn? : GoalM (Option Expr) := do
      let smulType := mkApp3 (mkConst ``HSMul [0, u, u]) Int.mkType type type
      let some smulInst ← synthInstance? smulType | return none
      internalizeFn <| mkApp4 (mkConst ``HSMul.hSMul [0, u, u]) Int.mkType type smulInst smulInst
    let rec getHSMulNatFn? : GoalM (Option Expr) := do
      let smulType := mkApp3 (mkConst ``HSMul [0, u, u]) Nat.mkType type type
      let some smulInst ← synthInstance? smulType | return none
      internalizeFn <| mkApp4 (mkConst ``HSMul.hSMul [0, u, u]) Nat.mkType type smulInst smulInst
    let zsmulFn? ← getHSMulFn?
    let nsmulFn? ← getHSMulNatFn?
    let homomulFn? ← if commRingInst?.isSome then
      let mulInst ← getBinHomoInst ``HMul
      pure <| some (← internalizeFn <| mkApp4 (mkConst ``HMul.hMul [u, u, u]) type type type mulInst)
    else
      pure none
    let id := (← get').structs.size
    let struct : Struct := {
      id, type, u, intModuleInst, preorderInst?, orderedAddInst?, partialInst?, linearInst?, noNatDivInst?
      leFn?, ltFn?, addFn, subFn, negFn, zsmulFn, nsmulFn, zsmulFn?, nsmulFn?, zero, one?
      ringInst?, commRingInst?, orderedRingInst?, charInst?, ringId?, fieldInst?, ofNatZero, homomulFn?
    }
    modify' fun s => { s with structs := s.structs.push struct }
    if let some one := one? then
      if ringInst?.isSome then LinearM.run id do
        if orderedRingInst?.isSome then
          -- Create `1` variable, and assert strict lower bound `0 < 1` and `0 ≠ 1`
          let x ← mkVar one (mark := false)
          addZeroLtOne x
          addZeroNeOne x
        else if fieldInst?.isSome || isNonTrivialIsCharInst charInst? then
          -- Create `1` variable, and assert `0 ≠ 1`
          let x ← mkVar one (mark := false)
          addZeroNeOne x

    return some id

end Lean.Meta.Grind.Arith.Linear
