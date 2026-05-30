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

///|
test "textarea: view truncates wide text by display width" {
  let c = textarea(width=4, height=1)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetValue("你好x")).model
  assert_eq((c.view)(m1), "你好")
}

///|
test "textarea: view does not split combining marks" {
  let accented = String::from_array(['e', '\u{0301}'])
  let c = textarea(width=1, height=1)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetValue("\{accented}x")).model
  assert_eq((c.view)(m1), accented)
}

///|
test "textarea: cursor movement stays on grapheme boundaries" {
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let c = textarea(width=6, height=1)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetValue("\{technologist}x")).model
  let focused = { ..m1, focused: true, cursor_col: 4 }
  let moved = (c.update)(focused, MoveCursorLeft).model
  assert_eq(moved.cursor_col, 3)
  assert_eq((c.view)(moved), "\{technologist}|x  ")
}

///|
test "textarea: backspace removes emoji ZWJ cluster as one unit" {
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let c = textarea(width=6, height=1)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetValue("\{technologist}x")).model
  let focused = {
    ..m1,
    focused: true,
    cursor_col: technologist.to_array().length(),
  }
  let next = (c.update)(focused, DeleteBefore).model
  assert_eq(next.value, "x")
  assert_eq(next.cursor_row, 0)
  assert_eq(next.cursor_col, 0)
  assert_eq((c.view)(next), "|x    ")
}

///|
test "textarea: vertical movement preserves display cells from wide to ASCII" {
  let c = textarea(width=4, height=2)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetValue("你\nab")).model
  let focused = { ..m1, focused: true, cursor_row: 0, cursor_col: 1 }
  let moved = (c.update)(focused, MoveCursorDown).model
  assert_eq(moved.cursor_row, 1)
  assert_eq(moved.cursor_col, 2)
  assert_eq((c.view)(moved), "你  \nab| ")
}

///|
test "textarea: vertical movement snaps display cells onto wide boundary" {
  let c = textarea(width=4, height=2)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetValue("ab\n你x")).model
  let focused = { ..m1, focused: true, cursor_row: 0, cursor_col: 2 }
  let moved = (c.update)(focused, MoveCursorDown).model
  assert_eq(moved.cursor_row, 1)
  assert_eq(moved.cursor_col, 1)
  assert_eq((c.view)(moved), "ab  \n你|x")
}

///|
test "textarea: placeholder pads ANSI-styled wide text by display width" {
  let c = textarea(width=4, height=1, placeholder="\u001b[31m界\u001b[0m")
  let model = (c.init)().model
  let view = (c.view)(model)
  assert_true(view == "\u001b[2m\u001b[31m界  \u001b[0m\u001b[0m")
}

///|
test "textarea: horizontal scroll inside wide glyph preserves cell columns" {
  let c = textarea(width=2, height=1)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetValue("你x")).model
  let focused = { ..m1, focused: true, cursor_col: 1, scroll_col: 1 }
  assert_eq((c.view)(focused), " |")
}

///|
test "textarea: horizontal scroll inside wide glyph preserves following cells" {
  let c = textarea(width=3, height=1)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetValue("你ab")).model
  let focused = { ..m1, focused: true, cursor_col: 1, scroll_col: 1 }
  assert_eq((c.view)(focused), " |a")
}

///|
test "textarea: truncation keeps styled combining cluster and reset intact" {
  let accented = String::from_array(['e', '\u{0301}'])
  let styled = "\u001b[31m\{accented}\u001b[0m"
  let c = textarea(width=1, height=1)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetValue("\{styled}x")).model
  assert_eq((c.view)(m1), styled)
}
