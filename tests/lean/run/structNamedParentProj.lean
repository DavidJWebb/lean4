/-!
# Testing named parent projections for `structure`s
-/

structure S where
  x : Nat
structure T where
  y : Nat
structure U where
  x : Nat

/-!
Non-atomic parent projections are not allowed.
-/
/-- error: Invalid parent projection name `non.atomic`: Name must be atomic -/
#guard_msgs in structure S' extends non.atomic : S

/-!
Shadowing other fields is not allowed.
-/
/--
error: Field `x` has already been declared

Hint: The `toParent : P` syntax can be used to adjust the name for the parent projection
-/
#guard_msgs in  structure S' extends x : S

/-!
Duplicate parent projections
-/
/--
error: Field `toP` has already been declared

Hint: The `toParent : P` syntax can be used to adjust the name for the parent projection
-/
#guard_msgs in structure S' extends toP : S, toP : T

/-!
Duplicate parent projections because from different namespaces
-/
structure NS1.S
structure NS2.S
/--
error: Field `toS` has already been declared

Hint: The `toParent : P` syntax can be used to adjust the name for the parent projection
-/
#guard_msgs in structure S' extends NS1.S, NS2.S

/-!
Duplicate parent projections, when there are overlapping fields
-/
/--
error: Field `toS` has already been declared

Hint: The `toParent : P` syntax can be used to adjust the name for the parent projection
-/
#guard_msgs in structure S' extends S, toS : U
/--
error: Field `toP` has already been declared

Hint: The `toParent : P` syntax can be used to adjust the name for the parent projection
-/
#guard_msgs in structure S' extends toP : S, toP : T

/-!
Duplicate parent projections because from different namespaces, when there are duplicate fields
-/
structure NS1.S' where x : Nat
structure NS2.S' where x : Nat
/--
error: Field `toS'` has already been declared

Hint: The `toParent : P` syntax can be used to adjust the name for the parent projection
-/
#guard_msgs in structure S' extends NS1.S', NS2.S'

/-!
Field conflicts with projection
-/
/-- error: Field `toS` has already been declared as a projection for parent `S` -/
#guard_msgs in structure S' extends S where
  toS : Nat

/-!
Field conflicts with indirect parent projection
-/
structure GP where
structure P extends toGP : GP where
/--
error: Field `toGP` has already been declared as a projection for an indirect parent structure `GP`

Note: This projection was inherited from this structure's immediate parent `P`
-/
#guard_msgs in
structure C extends P where
  toGP : Unit

/-!
Checking that the projection name is honored.
-/
structure S2 extends toTheS : S where
  y : Nat
/--
info: structure S2 : Type
number of parameters: 0
parents:
  S2.toTheS : S
fields:
  S.x : Nat
  S2.y : Nat
constructor:
  S2.mk (toTheS : S) (y : Nat) : S2
field notation resolution order:
  S2, S
-/
#guard_msgs in #print S2

/-!
Checking that the projection name is honored.
-/
structure S2' extends toTheS : S, toTheU : U where
  y : Nat
/--
info: structure S2' : Type
number of parameters: 0
parents:
  S2'.toTheS : S
  S2'.toTheU : U
fields:
  S.x : Nat
  S2'.y : Nat
constructor:
  S2'.mk (toTheS : S) (y : Nat) : S2'
field notation resolution order:
  S2', S, U
-/
#guard_msgs in #print S2'

/-!
Structure instances, setting a parent
-/
/-- info: { toTheS := s, y := 1 } : S2' -/
#guard_msgs in variable (s : S) in #check { toTheS := s, y := 1 : S2' }
/-- info: { x := s.x, y := 1 } : S2' -/
#guard_msgs in variable (s : U) in #check { toTheU := s, y := 1 : S2' }
/-- info: { x := 2, y := 1 } : S2' -/
#guard_msgs in #check { toTheS.x := 2, y := 1 : S2' }
/-- info: { x := 2, y := 1 } : S2' -/
#guard_msgs in #check { toTheU.x := 2, y := 1 : S2' }
