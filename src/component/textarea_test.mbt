///|
test "textarea: init uses size and placeholder" {
  let c = textarea(width=12, height=3, placeholder="notes")
  let model = (c.init)().model
  assert_eq(model.width, 12)
  assert_eq(model.height, 3)
  assert_eq(model.placeholder, "notes")
  assert_eq(model.value, "")
  assert_eq(model.cursor_row, 0)
  assert_eq(model.cursor_col, 0)
}

///|
test "textarea: insert chars and newline" {
  let c = textarea(width=12, height=3)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, InsertChar('a')).model
  let m2 = (c.update)(m1, InsertChar('b')).model
  let m3 = (c.update)(m2, InsertNewline).model
  let m4 = (c.update)(m3, InsertChar('c')).model
  assert_eq(m4.value, "ab\nc")
  assert_eq(m4.cursor_row, 1)
  assert_eq(m4.cursor_col, 1)
}

///|
test "textarea: delete before merges lines" {
  let c = textarea(width=12, height=3)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetValue("ab\ncd")).model
  let m2 = { ..m1, cursor_row: 1, cursor_col: 0 }
  let m3 = (c.update)(m2, DeleteBefore).model
  assert_eq(m3.value, "abcd")
  assert_eq(m3.cursor_row, 0)
  assert_eq(m3.cursor_col, 2)
}

///|
test "textarea: moving vertically clamps to target line length" {
  let c = textarea(width=12, height=3)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetValue("abcd\nx")).model
  let m2 = { ..m1, cursor_row: 0, cursor_col: 4 }
  let m3 = (c.update)(m2, MoveCursorDown).model
  assert_eq(m3.cursor_row, 1)
  assert_eq(m3.cursor_col, 1)
}

///|
test "textarea: view shows placeholder when empty and blurred" {
  let c = textarea(width=8, height=2, placeholder="empty")
  let model = (c.init)().model
  let view = (c.view)(model)
  assert_true(view.contains("empty"))
}

///|
test "textarea: cursor stays visible by scrolling" {
  let c = textarea(width=4, height=2)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetValue("abcd\nefgh\nijkl")).model
  let m2 = { ..m1, focused: true, cursor_row: 2, cursor_col: 4 }
  let m3 = (c.update)(m2, MoveToLineEnd).model
  assert_eq(m3.scroll_row, 1)
  assert_eq(m3.scroll_col, 1)
  let view = (c.view)(m3)
  assert_true(view.contains("|"))
}
