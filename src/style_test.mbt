///|
test "style render passthrough without styling" {
  assert_eq(style().render("hello\nworld"), "hello\nworld")
}

///|
test "style render bold wraps content in ansi" {
  assert_eq(style().bold().render("hello"), bold() + "hello" + reset())
}

///|
test "style render faint aliases dim without duplicate sgr" {
  assert_eq(style().faint().dim().render("hello"), "[2mhello[0m")
}

///|
test "style render strikethrough emits sgr 9" {
  assert_eq(style().strikethrough().render("hello"), "[9mhello[0m")
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

///|
test "style render_with degrades colors and keeps ambient untouched" {
  let s = style().foreground_rgb(255, 0, 0).background_hex("#0000ff").bold()
  let default_ctx = @profile.RenderContext::default()
  let previous = @profile.ambient_context()
  defer @profile.set_render_context(previous)
  @profile.set_render_context(default_ctx)
  assert_eq(s.render("hi"), s.render_with("hi", default_ctx))

  let ambient = default_ctx.with_color_profile(@profile.Ansi16)
  @profile.set_render_context(ambient)
  let explicit = default_ctx.with_color_profile(@profile.NoColor)
  let actual = s.render_with("hi", explicit)
  assert_false(actual.contains("\u001b[38;"))
  assert_false(actual.contains("\u001b[48;"))
  assert_true(actual.contains(bold()))
  assert_eq(@profile.ambient_context(), ambient)
}

///|
test "style adaptive color resolves dark unknown light and nested" {
  let light = @profile.RenderContext::default().with_background(@profile.Light)
  let dark = @profile.RenderContext::default().with_background(@profile.Dark)
  let unknown = @profile.RenderContext::default()
  let adaptive = color_adaptive(color_ansi(1), color_ansi(2))
  assert_eq(
    style().foreground(adaptive).render_with("x", dark),
    fg_color(2) + "x" + reset(),
  )
  assert_eq(
    style().foreground(adaptive).render_with("x", unknown),
    fg_color(2) + "x" + reset(),
  )
  assert_eq(
    style().foreground(adaptive).render_with("x", light),
    fg_color(1) + "x" + reset(),
  )
  let nested = color_adaptive(
    color_ansi(3),
    color_adaptive(color_ansi(4), color_ansi(5)),
  )
  assert_eq(
    style().foreground(nested).render_with("x", dark),
    fg_color(5) + "x" + reset(),
  )
}

///|
test "style invalid hex stays empty under every profile" {
  let s = style().foreground(color_hex("#zzz")).underline()
  let contexts = [
    @profile.RenderContext::default(),
    @profile.RenderContext::default().with_color_profile(@profile.Ansi256),
    @profile.RenderContext::default().with_color_profile(@profile.Ansi16),
    @profile.RenderContext::default().with_color_profile(@profile.NoColor),
  ]
  for ctx in contexts {
    let out = s.render_with("x", ctx)
    assert_false(out.contains("\u001b[38;"))
    assert_true(out.contains(underline()))
  }
}

///|
test "style supports rgb and hex colors plus extra ansi flags" {
  let actual = style()
    .foreground_hex("#ff00aa")
    .background_rgb(1, 2, 3)
    .italic()
    .reverse()
    .render("hi")
  let expected = fg_rgb(255, 0, 170) +
    bg_rgb(1, 2, 3) +
    "\{CSI}3m" +
    reverse() +
    "hi" +
    reset()
  assert_eq(actual, expected)
}

///|
test "style margin and height expand the rendered block" {
  let actual = style().width(4).height(2).margin(1, 2, 1, 1).render("hi")
  let expected = "       \n hi    \n       \n       "
  assert_eq(actual, expected)
}

///|
test "style place centers content within a region" {
  let actual = place(6, 3, "xy", align=Center, valign=Middle)
  let expected = "      \n  xy  \n      "
  assert_eq(actual, expected)
}

///|
test "style join_horizontal honors vertical alignment" {
  let actual = join_horizontal(["A", "B\nC"], valign=Bottom)
  let expected = " B\nAC"
  assert_eq(actual, expected)
}

///|
test "style join_vertical aligns blocks to a common width" {
  let actual = join_vertical(["A", "ZZ"], align=Right)
  let expected = " A\nZZ"
  assert_eq(actual, expected)
}

///|
test "style border_sides can suppress vertical edges" {
  let actual = style()
    .border(border_ascii())
    .border_sides(true, false, true, false)
    .render("hi")
  let expected = "--\nhi\n--"
  assert_eq(actual, expected)
}

///|
test "style border colors render separately from content colors" {
  let actual = style()
    .foreground(color_ansi(2))
    .border(border_ascii())
    .border_foreground(color_ansi(1))
    .render("hi")
  let expected = fg_color(1) +
    "+--+" +
    reset() +
    "\n" +
    fg_color(1) +
    "|" +
    reset() +
    fg_color(2) +
    "hi" +
    reset() +
    fg_color(1) +
    "|" +
    reset() +
    "\n" +
    fg_color(1) +
    "+--+" +
    reset()
  assert_eq(actual, expected)
}

///|
test "style render_with degrades content and border colors" {
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
  assert_true(actual.contains(bold()))
  assert_eq(strip_ansi(actual), "+--+\n|hi|\n+--+")
}
