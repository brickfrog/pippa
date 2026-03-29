///|
/// Tests for the TextInput component.

///|
test "text_input: insert char into empty field" {
  let comp = text_input(placeholder="hint")
  let m0 = comp.init().model
  let m1 = comp.update(m0, InsertChar('a')).model
  assert_eq(m1.value, "a")
  assert_eq(m1.cursor, 1)
}

///|
test "text_input: insert multiple chars" {
  let comp = text_input(placeholder="")
  let m0 = comp.init().model
  let m1 = comp.update(m0, InsertChar('h')).model
  let m2 = comp.update(m1, InsertChar('i')).model
  assert_eq(m2.value, "hi")
  assert_eq(m2.cursor, 2)
}

///|
test "text_input: insert char in the middle" {
  let comp = text_input(placeholder="")
  let m0 = comp.init().model
  let m1 = comp.update(m0, InsertChar('a')).model
  let m2 = comp.update(m1, InsertChar('c')).model
  // Move to position 1 (between 'a' and 'c') then insert 'b'
  let m3 = comp.update(m2, MoveToStart).model
  let m4 = comp.update(m3, MoveCursorRight).model
  let m5 = comp.update(m4, InsertChar('b')).model
  assert_eq(m5.value, "abc")
  assert_eq(m5.cursor, 2)
}

///|
test "text_input: delete before (backspace) removes char" {
  let comp = text_input(placeholder="")
  let m0 = comp.init().model
  let m1 = comp.update(m0, InsertChar('a')).model
  let m2 = comp.update(m1, InsertChar('b')).model
  let m3 = comp.update(m2, DeleteBefore).model
  assert_eq(m3.value, "a")
  assert_eq(m3.cursor, 1)
}

///|
test "text_input: delete before at start does nothing" {
  let comp = text_input(placeholder="")
  let m0 = comp.init().model
  let m1 = comp.update(m0, DeleteBefore).model
  assert_eq(m1.value, "")
  assert_eq(m1.cursor, 0)
}

///|
test "text_input: delete after removes char at cursor" {
  let comp = text_input(placeholder="")
  let m0 = comp.init().model
  let m1 = comp.update(m0, InsertChar('a')).model
  let m2 = comp.update(m1, InsertChar('b')).model
  // Move to start then delete the 'a'
  let m3 = comp.update(m2, MoveToStart).model
  let m4 = comp.update(m3, DeleteAfter).model
  assert_eq(m4.value, "b")
  assert_eq(m4.cursor, 0)
}

///|
test "text_input: delete after at end does nothing" {
  let comp = text_input(placeholder="")
  let m0 = comp.init().model
  let m1 = comp.update(m0, InsertChar('x')).model
  let m2 = comp.update(m1, DeleteAfter).model
  assert_eq(m2.value, "x")
  assert_eq(m2.cursor, 1)
}

///|
test "text_input: cursor movement left and right" {
  let comp = text_input(placeholder="")
  let m0 = comp.init().model
  let m1 = comp.update(m0, InsertChar('x')).model
  assert_eq(m1.cursor, 1)
  let m2 = comp.update(m1, MoveCursorLeft).model
  assert_eq(m2.cursor, 0)
  // Can't go further left
  let m3 = comp.update(m2, MoveCursorLeft).model
  assert_eq(m3.cursor, 0)
  let m4 = comp.update(m3, MoveCursorRight).model
  assert_eq(m4.cursor, 1)
  // Can't go further right
  let m5 = comp.update(m4, MoveCursorRight).model
  assert_eq(m5.cursor, 1)
}

///|
test "text_input: move to start and end" {
  let comp = text_input(placeholder="")
  let m0 = comp.init().model
  let m1 = comp.update(m0, InsertChar('a')).model
  let m2 = comp.update(m1, InsertChar('b')).model
  let m3 = comp.update(m2, InsertChar('c')).model
  let m4 = comp.update(m3, MoveToStart).model
  assert_eq(m4.cursor, 0)
  let m5 = comp.update(m4, MoveToEnd).model
  assert_eq(m5.cursor, 3)
}

///|
test "text_input: focus and blur" {
  let comp = text_input(placeholder="")
  let m0 = comp.init().model
  assert_eq(m0.focused, false)
  let m1 = comp.update(m0, Focus).model
  assert_eq(m1.focused, true)
  let m2 = comp.update(m1, Blur).model
  assert_eq(m2.focused, false)
}

///|
test "text_input: view shows cursor at end when focused" {
  let comp = text_input(placeholder="")
  let m0 = comp.init().model
  let m1 = comp.update(m0, Focus).model
  let m2 = comp.update(m1, InsertChar('a')).model
  let m3 = comp.update(m2, InsertChar('b')).model
  assert_eq(comp.view(m3), "ab|")
}

///|
test "text_input: view shows cursor in the middle when focused" {
  let comp = text_input(placeholder="")
  let m0 = comp.init().model
  let m1 = comp.update(m0, Focus).model
  let m2 = comp.update(m1, InsertChar('a')).model
  let m3 = comp.update(m2, InsertChar('b')).model
  let m4 = comp.update(m3, MoveCursorLeft).model
  assert_eq(comp.view(m4), "a|b")
}

///|
test "text_input: view shows cursor at start when focused" {
  let comp = text_input(placeholder="")
  let m0 = comp.init().model
  let m1 = comp.update(m0, Focus).model
  let m2 = comp.update(m1, InsertChar('x')).model
  let m3 = comp.update(m2, MoveToStart).model
  assert_eq(comp.view(m3), "|x")
}

///|
test "text_input: view shows placeholder (dimmed) when empty and unfocused" {
  let comp = text_input(placeholder="type here")
  let m0 = comp.init().model
  let v = comp.view(m0)
  // Strip ANSI sequences — plain text should be just the placeholder
  assert_eq(@pippa.strip_ansi(v), "type here")
}

///|
test "text_input: view shows plain value when unfocused and non-empty" {
  let comp = text_input(placeholder="hint")
  let m0 = comp.init().model
  let m1 = comp.update(m0, InsertChar('h')).model
  let m2 = comp.update(m1, InsertChar('i')).model
  assert_eq(comp.view(m2), "hi")
}

///|
test "text_input: view shows empty cursor when focused and empty" {
  let comp = text_input(placeholder="hint")
  let m0 = comp.init().model
  let m1 = comp.update(m0, Focus).model
  assert_eq(comp.view(m1), "|")
}
