/-
Copyright (c) 2020 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura
-/
module

prelude
public import Lean.Meta.Tactic.Rewrite
public import Lean.Meta.Tactic.Replace
public import Lean.Elab.Tactic.Location
public import Lean.Elab.Tactic.Config
import Lean.Meta.Eqns

public section

namespace Lean.Elab.Tactic
open Meta

def rewriteTarget (stx : Syntax) (symm : Bool) (config : Rewrite.Config := {}) : TacticM Unit := do
  Term.withSynthesize <| withMainContext do
    let e ← elabTerm stx none true
    if e.hasSyntheticSorry then
      throwAbortTactic
    let r ← (← getMainGoal).rewrite (← getMainTarget) e symm (config := config)
    let mvarId' ← (← getMainGoal).replaceTargetEq r.eNew r.eqProof
    replaceMainGoal (mvarId' :: r.mvarIds)

def rewriteLocalDecl (stx : Syntax) (symm : Bool) (fvarId : FVarId) (config : Rewrite.Config := {}) :
    TacticM Unit := withMainContext do
  -- Note: we cannot execute `replaceLocalDecl` inside `Term.withSynthesize`.
  -- See issues #2711 and #2727.
  let rwResult ← Term.withSynthesize <| withMainContext do
    let e ← elabTerm stx none true
    if e.hasSyntheticSorry then
      throwAbortTactic
    let localDecl ← fvarId.getDecl
    (← getMainGoal).rewrite localDecl.type e symm (config := config)
  let replaceResult ← (← getMainGoal).replaceLocalDecl fvarId rwResult.eNew rwResult.eqProof
  replaceMainGoal (replaceResult.mvarId :: rwResult.mvarIds)

def withRWRulesSeq (token : Syntax) (rwRulesSeqStx : Syntax) (x : (symm : Bool) → (term : Syntax) → TacticM Unit) : TacticM Unit := do
  let lbrak := rwRulesSeqStx[0]
  let rules := rwRulesSeqStx[1].getArgs
  -- show initial state up to (incl.) `[`
  withTacticInfoContext (mkNullNode #[token, lbrak]) (pure ())
  let numRules := (rules.size + 1) / 2
  for i in *...numRules do
    let rule := rules[i * 2]!
    let sep  := rules.getD (i * 2 + 1) Syntax.missing
    -- show rule state up to (incl.) next `,`
    withTacticInfoContext (mkNullNode #[rule, sep]) do
      -- show errors on rule
      withRef rule do
        let symm := !rule[0].isNone
        let term := rule[1]
        let processId (id : Syntax) : TacticM Unit := do
          -- See if we can interpret `id` as a hypothesis first.
          if (← withMainContext <| Term.isLocalIdent? id).isSome then
            x symm term
          else
            -- Try to get equation theorems for `id`.
            let declName ← try realizeGlobalConstNoOverload id catch _ => return (← x symm term)
            let some eqThms ← getEqnsFor? declName | x symm term
            let hint := if eqThms.size = 1 then m!"" else
              .hint' m!"Try rewriting with `{Name.str declName unfoldThmSuffix}`"
            let rec go : List Name →  TacticM Unit
              | [] => throwError m!"Failed to rewrite using equation theorems for `{declName}`" ++ hint
              | eqThm::eqThms => (x symm (mkCIdentFrom id eqThm)) <|> go eqThms
            discard <| Term.addTermInfo id (← mkConstWithFreshMVarLevels declName) (lctx? := ← getLCtx)
            go eqThms.toList
        match term with
        | `($id:ident)  => processId id
        | `(@$id:ident) => processId id
        | _ => x symm term


declare_config_elab elabRewriteConfig Rewrite.Config

@[builtin_tactic Lean.Parser.Tactic.rewriteSeq] def evalRewriteSeq : Tactic := fun stx => do
  let cfg ← elabRewriteConfig stx[1]
  let loc   := expandOptLocation stx[3]
  withRWRulesSeq stx[0] stx[2] fun symm term => do
    withLocation loc
      (rewriteLocalDecl term symm · cfg)
      (rewriteTarget term symm cfg)
      (throwTacticEx `rewrite · "Did not find an occurrence of the pattern in the current goal")

end Lean.Elab.Tactic
