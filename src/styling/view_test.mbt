///|
using @debug {assert_eq}

///|
test "col joins children vertically" {
  let result = col <| [
      "hello", "world",
    ]
  assert_eq(result, "hello\nworld")
}

///|
test "col with empty array" {
  let result = col <| []
  assert_eq(result, "")
}

///|
test "row joins children horizontally" {
  let result = row <| [
      "ab", "cd",
    ]
  assert_eq(result, "abcd")
}

///|
test "nested col and row" {
  let result = col <| [
      "header",
      row <| [
        "left", " | ", "right",
      ],
      "footer",
    ]
  // col (join_vertical) pads lines to equal width
  assert_eq(result, "header      \nleft | right\nfooter      ")
}

///|
test "text is identity" {
  assert_eq(text("hello"), "hello")
}

///|
test "lines joins with newlines" {
  let result = lines(["a", "b", "c"])
  assert_eq(result, "a\nb\nc")
}

///|
test "gap produces blank lines" {
  assert_eq(gap(), "")
  assert_eq(gap(n=2), "\n")
  assert_eq(gap(n=3), "\n\n")
}

///|
test "hgap produces spaces" {
  assert_eq(hgap(), " ")
  assert_eq(hgap(n=3), "   ")
}
