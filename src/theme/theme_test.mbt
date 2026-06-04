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

///|
fn span_wrap_role() -> RoleKey {
  RoleKey::markdown("paragraph")
}

///|
fn span_wrap_plain_lines(spans : Array[StyledSpan], width : Int) -> String {
  let out : Array[String] = []
  for line in wrap_spans(spans, width) {
    out.push(span_plain_text(line))
  }
  out.join("\n")
}

///|
fn is_single_grapheme(text : String) -> Bool {
  @internal.grapheme_boundaries(text).length() == 2
}

///|
fn line_allowed_overflow(line : Array[StyledSpan], width : Int) -> Bool {
  let text = span_plain_text(line)
  let line_width = @internal.display_width(text)
  if line_width <= width {
    return true
  }
  if line.length() != 1 {
    return false
  }
  let unit = line[0]
  let unit_width = @internal.display_width(unit.text)
  (unit.no_wrap || is_single_grapheme(unit.text)) && unit_width > width
}

///|
fn assert_wrap_invariant(spans : Array[StyledSpan], width : Int) -> Unit raise {
  let lines = wrap_spans(spans, width)
  if width <= 0 {
    assert_eq(lines.length(), 1)
    assert_eq(span_plain_text(lines[0]), span_plain_text(spans))
    return
  }
  for line in lines {
    assert_true(line_allowed_overflow(line, width))
  }
}

///|
test "wrap_spans keeps ASCII lines within width" {
  let spans = [StyledSpan::new("alpha beta gamma", span_wrap_role())]
  assert_eq(span_wrap_plain_lines(spans, 10), "alpha beta\ngamma")
  assert_wrap_invariant(spans, 10)
}

///|
test "wrap_spans keeps wide CJK lines within width" {
  let spans = [StyledSpan::new("你你你", span_wrap_role())]
  assert_eq(span_wrap_plain_lines(spans, 4), "你你\n你")
  assert_wrap_invariant(spans, 4)
}

///|
test "wrap_spans keeps combining marks with their base grapheme" {
  let accented = String::from_array(['a', '\u{0301}'])
  let spans = [StyledSpan::new("x" + accented + "y", span_wrap_role())]
  assert_eq(span_wrap_plain_lines(spans, 2), "x" + accented + "\ny")
  assert_wrap_invariant(spans, 2)
}

///|
test "wrap_spans keeps emoji ZWJ graphemes intact" {
  let technologist = String::from_array(['\u{1F469}', '\u{200D}', '\u{1F4BB}'])
  let spans = [StyledSpan::new("x" + technologist + "y", span_wrap_role())]
  assert_eq(span_wrap_plain_lines(spans, 3), "x" + technologist + "\ny")
  assert_wrap_invariant(spans, 3)
}

///|
test "wrap_spans hard-breaks overlong breakable words" {
  let spans = [StyledSpan::new("abcdefghi", span_wrap_role())]
  let wrapped = span_wrap_plain_lines(spans, 4)
  assert_eq(@pippa.line_count(wrapped), 3)
  assert_eq(wrapped, "abcd\nefgh\ni")
  assert_wrap_invariant(spans, 4)
}

///|
test "wrap_spans leaves non-positive widths unwrapped" {
  let spans = [
    StyledSpan::new("alpha ", span_wrap_role()),
    StyledSpan::new("beta gamma", span_wrap_role()),
  ]
  assert_eq(span_wrap_plain_lines(spans, 0), "alpha beta gamma")
  assert_eq(span_wrap_plain_lines(spans, -1), "alpha beta gamma")
  assert_wrap_invariant(spans, 0)
  assert_wrap_invariant(spans, -1)
}

///|
test "wrap_spans places overlong no_wrap spans alone without dropping content" {
  let role = span_wrap_role()
  let spans = [
    StyledSpan::new("a", role),
    StyledSpan::new("uvwxyz", role, no_wrap=true),
  ]
  let wrapped = span_wrap_plain_lines(spans, 3)
  assert_eq(@pippa.line_count(wrapped), 2)
  assert_eq(wrapped, "a\nuvwxyz")
  assert_wrap_invariant(spans, 3)
}

///|
test "wrap_spans preserves leading space inside no_wrap spans" {
  let role = span_wrap_role()
  let spans = [
    StyledSpan::new("abc", role),
    StyledSpan::new(" xy", role, no_wrap=true),
  ]
  assert_eq(span_wrap_plain_lines(spans, 3), "abc\n xy")
  assert_wrap_invariant(spans, 3)
}
