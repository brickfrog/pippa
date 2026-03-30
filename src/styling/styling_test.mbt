///|
test "styling render matches existing width border padding behavior" {
  let actual = style()
    .border(border_ascii())
    .padding(0, 1, 0, 1)
    .width(4)
    .align(Right)
    .render("hi")
  assert_eq(actual, "+------+\n|   hi |\n+------+")
}

///|
test "styling supports rgb and hex colors plus extra ansi flags" {
  let actual = style()
    .foreground_hex("#ff00aa")
    .background_rgb(1, 2, 3)
    .italic()
    .reverse()
    .render("hi")
  let expected = @pippa.fg_rgb(255, 0, 170) +
    @pippa.bg_rgb(1, 2, 3) +
    "\{@pippa.CSI}3m" +
    @pippa.reverse() +
    "hi" +
    @pippa.reset()
  assert_eq(actual, expected)
}

///|
test "styling margin and height expand the rendered block" {
  let actual = style().width(4).height(2).margin(1, 2, 1, 1).render("hi")
  let expected = "       \n hi    \n       \n       "
  assert_eq(actual, expected)
}

///|
test "styling place centers content within a region" {
  let actual = place(6, 3, "xy", align=Center, valign=Middle)
  let expected = "      \n  xy  \n      "
  assert_eq(actual, expected)
}

///|
test "styling join_horizontal honors vertical alignment" {
  let actual = join_horizontal(["A", "B\nC"], valign=Bottom)
  let expected = " B\nAC"
  assert_eq(actual, expected)
}

///|
test "styling join_vertical aligns blocks to a common width" {
  let actual = join_vertical(["A", "ZZ"], align=Right)
  let expected = " A\nZZ"
  assert_eq(actual, expected)
}

///|
test "styling border_sides can suppress vertical edges" {
  let actual = style()
    .border(border_ascii())
    .border_sides(true, false, true, false)
    .render("hi")
  let expected = "--\nhi\n--"
  assert_eq(actual, expected)
}

///|
test "styling border colors render separately from content colors" {
  let actual = style()
    .foreground(color_ansi(2))
    .border(border_ascii())
    .border_foreground(color_ansi(1))
    .render("hi")
  let expected = @pippa.fg_color(1) +
    "+--+" +
    @pippa.reset() +
    "\n" +
    @pippa.fg_color(1) +
    "|" +
    @pippa.reset() +
    @pippa.fg_color(2) +
    "hi" +
    @pippa.reset() +
    @pippa.fg_color(1) +
    "|" +
    @pippa.reset() +
    "\n" +
    @pippa.fg_color(1) +
    "+--+" +
    @pippa.reset()
  assert_eq(actual, expected)
}
