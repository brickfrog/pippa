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
