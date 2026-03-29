///|
/// Tests for the SelectList component.

///|
test "select_list/init default cursor and selected" {
  let sl = select_list(items=["a", "b", "c"])
  let { model, .. } = (sl.init)()
  assert_eq(model.cursor, 0)
  assert_eq(model.selected, -1)
  assert_eq(model.items.length(), 3)
}

///|
test "select_list/cursor_down moves cursor" {
  let sl = select_list(items=["a", "b", "c"])
  let { model: m0, .. } = (sl.init)()
  let { model: m1, .. } = (sl.update)(m0, CursorDown)
  assert_eq(m1.cursor, 1)
  let { model: m2, .. } = (sl.update)(m1, CursorDown)
  assert_eq(m2.cursor, 2)
}

///|
test "select_list/cursor_up moves cursor" {
  let sl = select_list(items=["a", "b", "c"])
  let { model: m0, .. } = (sl.init)()
  let { model: m1, .. } = (sl.update)(m0, CursorDown)
  let { model: m2, .. } = (sl.update)(m1, CursorDown)
  assert_eq(m2.cursor, 2)
  let { model: m3, .. } = (sl.update)(m2, CursorUp)
  assert_eq(m3.cursor, 1)
}

///|
test "select_list/cursor clamps at top" {
  let sl = select_list(items=["a", "b", "c"])
  let { model: m0, .. } = (sl.init)()
  assert_eq(m0.cursor, 0)
  let { model: m1, .. } = (sl.update)(m0, CursorUp)
  assert_eq(m1.cursor, 0)
}

///|
test "select_list/cursor clamps at bottom" {
  let sl = select_list(items=["a", "b", "c"])
  let { model: m0, .. } = (sl.init)()
  let { model: m1, .. } = (sl.update)(m0, CursorDown)
  let { model: m2, .. } = (sl.update)(m1, CursorDown)
  assert_eq(m2.cursor, 2)
  let { model: m3, .. } = (sl.update)(m2, CursorDown)
  assert_eq(m3.cursor, 2)
}

///|
test "select_list/select confirms cursor" {
  let sl = select_list(items=["a", "b", "c"])
  let { model: m0, .. } = (sl.init)()
  let { model: m1, .. } = (sl.update)(m0, CursorDown)
  let { model: m2, .. } = (sl.update)(m1, Select)
  assert_eq(m2.selected, 1)
  assert_eq(m2.cursor, 1)
}

///|
test "select_list/set_items resets state" {
  let sl = select_list(items=["a", "b", "c"])
  let { model: m0, .. } = (sl.init)()
  let { model: m1, .. } = (sl.update)(m0, CursorDown)
  let { model: m2, .. } = (sl.update)(m1, Select)
  assert_eq(m2.selected, 1)
  let { model: m3, .. } = (sl.update)(m2, SetItems(["x", "y"]))
  assert_eq(m3.cursor, 0)
  assert_eq(m3.selected, -1)
  assert_eq(m3.items.length(), 2)
}

///|
test "select_list/view renders items with cursor prefix" {
  let sl = select_list(items=["foo", "bar", "baz"])
  let { model, .. } = (sl.init)()
  let v = (sl.view)(model)
  // cursor is at index 0, so first item has "> " prefix with bold
  assert_true(v.contains("> "))
  assert_true(v.contains("foo"))
  assert_true(v.contains("bar"))
  assert_true(v.contains("baz"))
}

///|
test "select_list/view empty items" {
  let sl = select_list(items=[])
  let { model, .. } = (sl.init)()
  let v = (sl.view)(model)
  assert_eq(v, "")
}

///|
test "select_list/cursor_down no-op on empty list" {
  let sl = select_list(items=[])
  let { model: m0, .. } = (sl.init)()
  let { model: m1, .. } = (sl.update)(m0, CursorDown)
  assert_eq(m1.cursor, 0)
}

///|
test "select_list/select no-op on empty list" {
  let sl = select_list(items=[])
  let { model: m0, .. } = (sl.init)()
  let { model: m1, .. } = (sl.update)(m0, Select)
  assert_eq(m1.selected, -1)
}
