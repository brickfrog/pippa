///|
test "role keys compare and hash by scope and name" {
  let first = RoleKey::ui("error")
  let same = RoleKey::new(scope="ui", name="error")
  let other = RoleKey::markdown("error")
  assert_true(first == same)
  assert_true(first != other)

  let map : Map[RoleKey, String] = Map([])
  map.set(first, "registered")
  @test.assert_eq(map.get(same), Some("registered"))
  @test.assert_eq(map.get(other), None)
}

///|
test "theme returns registered style and fallback style" {
  let fallback = @pippa.style().foreground(@pippa.color_ansi(7))
  let registered = @pippa.style().foreground(@pippa.color_ansi(2)).bold()
  let base = Theme::new(fallback~)
  let theme = base.with_role(RoleKey::ui("success"), registered)
  let missing = RoleKey::ui("missing")
  @test.assert_eq(base.style(RoleKey::ui("success")), fallback)
  @test.assert_eq(theme.style(RoleKey::ui("success")), registered)
  @test.assert_eq(theme.style(missing), fallback)
}

///|
test "default ui error adapts at render time and honors no color profile" {
  let theme = default_theme()
  let role = RoleKey::ui("error")
  let dark = @profile.RenderContext::default().with_background(@profile.Dark)
  let light = @profile.RenderContext::default().with_background(@profile.Light)
  let dark_rendered = theme.render(role, "boom", dark)
  let light_rendered = theme.render(role, "boom", light)
  assert_eq(dark_rendered, "\u001b[38;2;248;113;113mboom\u001b[0m")
  assert_eq(light_rendered, "\u001b[38;2;185;28;28mboom\u001b[0m")
  assert_true(dark_rendered != light_rendered)
  assert_eq(@pippa.strip_ansi(dark_rendered), "boom")
  assert_eq(@pippa.strip_ansi(light_rendered), "boom")

  let no_color = dark.with_color_profile(@profile.NoColor)
  assert_eq(theme.render(role, "boom", no_color), "boom")
}

///|
test "default ui error downsampling follows profile and background" {
  let theme = default_theme()
  let role = RoleKey::ui("error")
  let dark = @profile.RenderContext::default().with_background(@profile.Dark)
  let light = @profile.RenderContext::default().with_background(@profile.Light)
  assert_eq(
    theme.render(role, "boom", dark.with_color_profile(@profile.Ansi256)),
    "\u001b[38;5;203mboom\u001b[0m",
  )
  assert_eq(
    theme.render(role, "boom", dark.with_color_profile(@profile.Ansi16)),
    "\u001b[91mboom\u001b[0m",
  )
  assert_eq(
    theme.render(role, "boom", light.with_color_profile(@profile.Ansi256)),
    "\u001b[38;5;124mboom\u001b[0m",
  )
  assert_eq(
    theme.render(role, "boom", light.with_color_profile(@profile.Ansi16)),
    "\u001b[31mboom\u001b[0m",
  )
}

///|
test "styled spans wrap on plaintext and render ANSI last" {
  let theme = Theme::new()
    .with_role(RoleKey::markdown("paragraph"), @pippa.style())
    .with_role(
      RoleKey::markdown("strong"),
      @pippa.style().foreground(@pippa.color_ansi(2)).bold(),
    )
  let ctx = @profile.RenderContext::default().with_color_profile(
    @profile.Ansi16,
  )
  let spans = [
    StyledSpan::new("alpha ", RoleKey::markdown("paragraph")),
    StyledSpan::new("strong words", RoleKey::markdown("strong"), no_wrap=true),
    StyledSpan::new(" tail", RoleKey::markdown("paragraph")),
  ]
  let lines = wrap_spans(spans, 12)
  assert_eq(lines.length(), 3)
  let rendered = render_span_lines(lines, theme, ctx)
  assert_eq(@pippa.strip_ansi(rendered), "alpha\nstrong words\ntail")
  for line in @pippa.split_lines(rendered) {
    assert_true(@pippa.visible_width(line) <= 12)
  }
  assert_true(rendered.contains("\u001b[32m"))
  assert_true(rendered.contains("\u001b[1mstrong words"))
}
