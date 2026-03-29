///|
test "diff_views: identical views produce no ops" {
  let ops = diff_views("hello\nworld", "hello\nworld")
  assert_eq(ops, [])
}

///|
test "diff_views: single changed line produces one op" {
  let ops = diff_views("hello\nworld", "hello\nearth")
  assert_eq(ops, [PatchOp::{ row: 2, col: 1, text: "earth" }])
}

///|
test "diff_views: new view has more lines" {
  let ops = diff_views("line1", "line1\nline2")
  assert_eq(ops, [PatchOp::{ row: 2, col: 1, text: "line2" }])
}

///|
test "diff_views: old view has more lines clears extra" {
  let ops = diff_views("line1\nline2", "line1")
  assert_eq(ops, [PatchOp::{ row: 2, col: 1, text: "" }])
}

///|
test "render_patch: empty ops returns empty string" {
  let result = render_patch([])
  assert_eq(result, "")
}

///|
test "render_patch: single op produces correct ANSI sequence" {
  let op = PatchOp::{ row: 1, col: 1, text: "hello" }
  let result = render_patch([op])
  let expected = move_cursor(1, 1) + clear_line() + "hello"
  assert_eq(result, expected)
}

///|
test "render_patch: multiple ops concatenated in order" {
  let ops = [
    PatchOp::{ row: 1, col: 1, text: "first" },
    PatchOp::{ row: 2, col: 1, text: "second" },
  ]
  let result = render_patch(ops)
  let expected = move_cursor(1, 1) +
    clear_line() +
    "first" +
    move_cursor(2, 1) +
    clear_line() +
    "second"
  assert_eq(result, expected)
}
