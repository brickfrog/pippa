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
test "styling faint aliases dim without duplicate sgr" {
  assert_eq(
    style().faint().dim().render("hello"),
    @pippa.dim() + "hello" + @pippa.reset(),
  )
}

///|
test "styling strikethrough emits sgr 9" {
  assert_eq(
    style().strikethrough().render("hello"),
    @pippa.strikethrough() + "hello" + @pippa.reset(),
  )
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

///|
test "styling render_with degrades content and border colors" {
  let ctx = @profile.RenderContext::default().with_color_profile(
    @profile.NoColor,
  )
  let actual = style()
    .foreground_rgb(255, 0, 0)
    .border(border_ascii())
    .border_foreground(color_rgb(0, 255, 0))
    .bold()
    .render_with("hi", ctx)
  assert_false(actual.contains("\u001b[38;"))
  assert_false(actual.contains("\u001b[48;"))
  assert_true(actual.contains(@pippa.bold()))
  assert_eq(@pippa.strip_ansi(actual), "+--+\n|hi|\n+--+")
}

///|
test "styling adaptive color mirrors root style semantics" {
  let light = @profile.RenderContext::default().with_background(@profile.Light)
  let unknown = @profile.RenderContext::default()
  let adaptive = color_adaptive(color_ansi(1), color_ansi(2))
  assert_eq(
    style().foreground(adaptive).render_with("x", unknown),
    @pippa.fg_color(2) + "x" + @pippa.reset(),
  )
  assert_eq(
    style().foreground(adaptive).render_with("x", light),
    @pippa.fg_color(1) + "x" + @pippa.reset(),
  )
}
