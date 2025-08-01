/-
Copyright (c) 2024 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Henrik Böving
-/
module

prelude
public import Lean.Elab.Tactic.BVDecide.Frontend.Attr
public import Lean.Elab.Tactic.BVDecide.LRAT.Trim
public import Lean.Elab.Tactic.BVDecide.External
public import Std.Tactic.BVDecide.LRAT.Checker
public import Std.Sat.CNF.Dimacs

public section

/-!
This module contains the logic around writing proofs of UNSAT, using LRAT proofs, as meta code.
-/

namespace Lean.Elab.Tactic.BVDecide
namespace Frontend

open Std.Sat
open Std.Tactic.BVDecide
open Lean.Meta

/--
The context for the `bv_decide` tactic.
-/
structure TacticContext where
  exprDef : Name
  certDef : Name
  reflectionDef : Name
  solver : System.FilePath
  lratPath : System.FilePath
  config : BVDecideConfig

def TacticContext.new (lratPath : System.FilePath) (config : BVDecideConfig) :
    TermElabM TacticContext := do
  let exprDef ← Lean.Elab.Term.mkAuxName `_expr_def
  let certDef ← Lean.Elab.Term.mkAuxName `_cert_def
  let reflectionDef ← Lean.Elab.Term.mkAuxName `_reflection_def
  let solver ← determineSolver
  trace[Meta.Tactic.sat] m!"Using SAT solver at '{solver}'"
  return {
    exprDef,
    certDef,
    reflectionDef,
    solver,
    lratPath,
    config
  }
where
  determineSolver : CoreM System.FilePath := do
    let opts ← getOptions
    let option := sat.solver.get opts
    if option == "" then
      let cadicalPath := (← IO.appPath).parent.get! / "cadical" |>.withExtension System.FilePath.exeExtension
      if ← cadicalPath.pathExists then
        return cadicalPath
      else
        return "cadical"
    else
      return option

/-- An LRAT proof read from a file. This will get parsed using ofReduceBool. -/
abbrev LratCert := String

instance : ToExpr LRAT.IntAction where
  toExpr action :=
    let beta := mkApp (mkConst ``Array [.zero]) (mkConst ``Int)
    let alpha := mkConst ``Nat
    match action with
    | .addEmpty id hints =>
      mkApp4 (mkConst ``LRAT.Action.addEmpty [.zero, .zero]) beta alpha (toExpr id) (toExpr hints)
    | .addRup id c hints =>
      mkApp5 (mkConst ``LRAT.Action.addRup [.zero, .zero])
        beta
        alpha
        (toExpr id)
        (toExpr c)
        (toExpr hints)
    | .addRat id c pivot rupHints ratHints =>
      mkApp7 (mkConst ``LRAT.Action.addRat [.zero, .zero])
        beta
        alpha
        (toExpr id)
        (toExpr c)
        (toExpr pivot)
        (toExpr rupHints)
        (toExpr ratHints)
    | .del ids =>
      mkApp3 (mkConst ``LRAT.Action.del [.zero, .zero]) beta alpha (toExpr ids)
  toTypeExpr := mkConst ``LRAT.IntAction

def LratCert.load (lratPath : System.FilePath) (trimProofs : Bool) : CoreM (Array LRAT.IntAction) := do
  let proofInput ← IO.FS.readBinFile lratPath
  let proof ←
    withTraceNode `Meta.Tactic.sat (fun _ => return s!"Parsing LRAT file") do
      -- lazyPure to prevent compiler lifting
      let proof? ← IO.lazyPure (fun _ => LRAT.parseLRATProof proofInput)
      match proof? with
      | .ok proof => pure proof
      | .error err => throwError "SAT solver produced invalid LRAT: {err}"

  trace[Meta.Tactic.sat] s!"LRAT proof has {proof.size} steps before trimming"

  let proof ←
    if trimProofs then
      withTraceNode `Meta.Tactic.sat (fun _ => return "Trimming LRAT proof") do
        -- lazyPure to prevent compiler lifting
        let trimmed ← IO.lazyPure (fun _ => LRAT.trim proof)
        IO.ofExcept trimmed
    else
      pure proof

  trace[Meta.Tactic.sat] s!"LRAT proof has {proof.size} steps after trimming"
  return proof

def LratCert.ofFile (lratPath : System.FilePath) (trimProofs : Bool) : CoreM LratCert := do
  let proof ← LratCert.load lratPath trimProofs

  -- This is necessary because the proof might be in the binary format in which case we cannot
  -- store it as a string in the environment (yet) due to missing support for binary literals.
  let newProof := LRAT.lratProofToString proof
  return newProof

/--
Run an external SAT solver on the `CNF` to obtain an LRAT proof.

This will obtain an `LratCert` if the formula is UNSAT and throw errors otherwise.
-/
def runExternal (cnf : CNF Nat) (solver : System.FilePath) (lratPath : System.FilePath)
    (trimProofs : Bool) (timeout : Nat) (binaryProofs : Bool) :
    CoreM (Except (Array (Bool × Nat)) LratCert) := do
  IO.FS.withTempFile fun cnfHandle cnfPath => do
    withTraceNode `Meta.Tactic.sat (fun _ => return "Serializing SAT problem to DIMACS file") do
      -- lazyPure to prevent compiler lifting
      cnfHandle.putStr  (← IO.lazyPure (fun _ => cnf.dimacs))
      cnfHandle.flush

    let res ←
      withTraceNode `Meta.Tactic.sat (fun _ => return "Running SAT solver") do
        External.satQuery solver cnfPath lratPath timeout binaryProofs
    if let .sat assignment := res then
      return .error assignment

    let lratProof ←
      withTraceNode `Meta.Tactic.sat (fun _ => return "Obtaining LRAT certificate") do
        LratCert.ofFile lratPath trimProofs

    return .ok lratProof

end Frontend
end Lean.Elab.Tactic.BVDecide
