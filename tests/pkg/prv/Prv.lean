import Prv.Foo

#check { name := "leo", val := 15 : Foo }
#check { name := "leo", val := 15 : Foo }.name
/-- error: Field `val` from structure `Foo` is private -/
#guard_msgs in
#check { name := "leo", val := 15 : Foo }.val

/-- error: Unknown identifier `a` -/
#guard_msgs in
#check a

/--
error: overloaded, errors ⏎
  failed to synthesize
    EmptyCollection (Name "hello")
  ⏎
  Hint: Additional diagnostic information may be available using the `set_option diagnostics true` command.
  ⏎
  invalid {...} notation, constructor for 'Name' is marked as private
-/
#guard_msgs in
def m1 : Name "hello" := {}

/-- error: Invalid `⟨...⟩` notation: Constructor for `Name` is marked as private -/
#guard_msgs in
def m2 : Name "hello" := ⟨"hello"⟩

/-- error: Unknown constant `Name.mk` -/
#guard_msgs in
def m3 : Name "hello" := Name.mk "hello"
