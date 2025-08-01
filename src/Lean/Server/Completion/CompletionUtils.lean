/-
Copyright (c) 2024 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura, Marc Huisinga
-/
module

prelude
public import Init.Prelude
public import Lean.Meta.WHNF

public section

partial def String.charactersIn (a b : String) : Bool :=
  go ⟨0⟩ ⟨0⟩
where
  go (aPos bPos : String.Pos) : Bool :=
    if ha : a.atEnd aPos then
      true
    else if hb : b.atEnd bPos then
      false
    else
      let ac := a.get' aPos ha
      let bc := b.get' bPos hb
      let bPos := b.next' bPos hb
      if ac == bc then
        let aPos := a.next' aPos ha
        go aPos bPos
      else
        go aPos bPos

namespace Lean.Server.Completion
open Elab

inductive HoverInfo : Type where
  | after
  | inside (delta : Nat)

structure ContextualizedCompletionInfo where
  hoverInfo : HoverInfo
  ctx       : ContextInfo
  info      : CompletionInfo

partial def minimizeGlobalIdentifierInContext (currNamespace : Name) (openDecls : List OpenDecl) (id : Name)
    : Name := Id.run do
  let mut minimized := shortenIn id currNamespace
  for openDecl in openDecls do
    let candidate? := match openDecl with
      | .simple ns except =>
        let candidate := shortenIn id ns
        if ! except.contains candidate then
          some candidate
        else
          none
      | .explicit alias declName =>
        if declName == id then
          some alias
        else
          none
    if let some candidate := candidate? then
      if candidate.getNumParts < minimized.getNumParts then
        minimized := candidate
  return minimized
where
  shortenIn (id : Name) (contextNamespace : Name) : Name :=
    if contextNamespace matches .anonymous then
      id
    else if contextNamespace.isPrefixOf id then
      id.replacePrefix contextNamespace .anonymous
    else
      shortenIn id contextNamespace.getPrefix

def unfoldDefinitionGuarded? (e : Expr) : MetaM (Option Expr) :=
  try Lean.Meta.unfoldDefinition? e catch _ => pure none

/-- Get type names for resolving `id` in `s.id x₁ ... xₙ` notation. -/
partial def getDotCompletionTypeNames (type : Expr) : MetaM (Array Name) :=
  return (← visit type |>.run #[]).2
where
  visit (type : Expr) : StateRefT (Array Name) MetaM Unit := do
    let .const typeName _ := type.getAppFn | return ()
    modify fun s => s.push typeName
    if isStructure (← getEnv) typeName then
      for parentName in (← getAllParentStructures typeName) do
        modify fun s => s.push parentName
    let some type ← unfoldDefinitionGuarded? type | return ()
    visit type

/--
Gets type names for resolving `id` in `.id x₁ ... xₙ` notation.
The process mimics the dotted indentifier notation elaboration procedure at `Lean.Elab.App`.
Catches and ignores all errors, so no need to run this within `try`/`catch`.
-/
partial def getDotIdCompletionTypeNames (type : Expr) : MetaM (Array Name) :=
  return (← visit type |>.run #[]).2
where
  visit (type : Expr) : StateRefT (Array Name) MetaM Unit := do
    try
      let type ← try Meta.whnfCoreUnfoldingAnnotations type catch _ => pure type
      if type.isForall then
        Meta.forallTelescope type fun _ type => visit type
      else
        let type ← instantiateMVars type
        let .const typeName _ := type.getAppFn | return ()
        modify fun s => s.push typeName
        if let some type' ← unfoldDefinitionGuarded? type then
          visit type'
    catch _ =>
      pure ()

end Lean.Server.Completion
