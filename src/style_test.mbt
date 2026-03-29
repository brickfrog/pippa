///|
test "style render passthrough without styling" {
  assert_eq(style().render("hello\nworld"), "hello\nworld")
}

///|
test "style render bold wraps content in ansi" {
  assert_eq(style().bold().render("hello"), bold() + "hello" + reset())
}

///|
test "style render rounded border" {
  let actual = style().border(border_rounded()).render("hi")
  let expected = "╭──╮\n│hi│\n╰──╯"
  assert_eq(actual, expected)
}

///|
test "style render padding adds surrounding space" {
  let actual = style().padding(1, 2, 1, 1).render("hi")
  let expected = "     \n hi  \n     "
  assert_eq(actual, expected)
}

///|
test "style render width and alignment shape each line" {
  let actual = style().width(5).align(Center).render("hi\nx")
  let expected = " hi  \n  x  "
  assert_eq(actual, expected)
}

///|
test "style render combines ansi border padding width and alignment" {
  let actual = style()
    .fg_color(1)
    .bg_color(2)
    .bold()
    .underline()
    .border(border_ascii())
    .padding(0, 1, 0, 1)
    .width(4)
    .align(Right)
    .render("hi")
  let expected = fg_color(1) +
    bg_color(2) +
    bold() +
    underline() +
    "+------+\n|   hi |\n+------+" +
    reset()
  assert_eq(actual, expected)
}

///|
test "style render clamps negative direct field values" {
  let unsafe_style : Style = {
    ..style(),
    padding_top: -1,
    padding_bottom: -2,
    padding_left: -3,
    padding_right: -4,
    width: -5,
  }
  assert_eq(unsafe_style.render("hi"), "hi")
}

///|
test "style render normalizes invalid custom border pieces" {
  let invalid_border : Border = {
    top_left: "++",
    top_right: "",
    bottom_left: "--",
    bottom_right: "ab",
    horizontal: "==",
    vertical: "",
  }
  let actual = style().border(invalid_border).render("hi")
  let expected = "****\n*hi*\n****"
  assert_eq(actual, expected)
}
