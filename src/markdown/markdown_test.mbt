///|
fn no_color_ctx() -> @profile.RenderContext {
  @profile.RenderContext::default().with_color_profile(@profile.NoColor)
}

///|
fn stripped(s : String) -> String {
  @pippa.strip_ansi(s)
}

///|
fn assert_line_widths_at_most(rendered : String, width : Int) -> Unit raise {
  for line in @pippa.split_lines(rendered) {
    assert_true(@pippa.visible_width(line) <= width)
  }
}

///|
test "parse exposes cmark doc and renderer handles README grade markdown" {
  let source =
    #|# Pippa Markdown
    #|
    #|A paragraph with *emphasis*, **strong text**, `inline code`, and [docs](https://example.com/docs).
    #|
    #|> quoted text wraps cleanly
    #|
    #|- unordered item
    #|1. ordered item
    #|
    #|```moonbit
    #|println("plain code")
    #|```
    #|
    #|---
    #|
  let doc = parse(source)
  let rendered = render_doc(
    doc,
    width=48,
    theme=@theme.default_theme(),
    ctx=no_color_ctx(),
    link_mode=Plain,
  )
  let expected =
    #|# Pippa Markdown
    #|
    #|A paragraph with emphasis, strong text,
    #|inline code, and docs.
    #|
    #|| quoted text wraps cleanly
    #|
    #|- unordered item
    #|
    #|1. ordered item
    #|
    #|println("plain code")
    #|
    #|------------------------------------------------
  assert_eq(stripped(rendered), expected)
}

///|
test "styled paragraph wraps by visible plaintext width" {
  let rendered = render(
    "alpha beta **strong** `code` [link](https://example.com) tail",
    width=12,
    theme=@theme.default_theme(),
    ctx=no_color_ctx(),
    link_mode=Osc8,
  )
  assert_line_widths_at_most(rendered, 12)
  assert_eq(stripped(rendered), "alpha beta\nstrong code\nlink tail")
  assert_true(rendered.contains("\u001b]8;;https://example.com\u001b\\"))
  assert_true(rendered.contains("\u001b]8;;\u001b\\"))
}

///|
test "blockquote and list continuation indents align to markers" {
  let source =
    #|> quoted words wrap here and continue
    #|
    #|- first item wraps around marker
    #|10. ordered item wraps around marker
  let rendered = render(
    source,
    width=20,
    theme=@theme.default_theme(),
    ctx=no_color_ctx(),
    link_mode=Plain,
  )
  let expected =
    #|| quoted words wrap
    #|| here and continue
    #|
    #|- first item wraps
    #|  around marker
    #|
    #|10. ordered item
    #|    wraps around
    #|    marker
  assert_eq(stripped(rendered), expected)
}

///|
test "link mode controls OSC8 footnote and plain rendering" {
  let source = "[Docs](https://example.com/docs) and [API](https://example.com/api)"
  let theme = @theme.default_theme()
  let ctx = no_color_ctx()
  let osc8 = render(source, width=80, theme~, ctx~, link_mode=Osc8)
  assert_eq(stripped(osc8), "Docs and API")
  assert_true(osc8.contains("\u001b]8;;https://example.com/docs\u001b\\"))
  assert_true(osc8.contains("\u001b]8;;https://example.com/api\u001b\\"))

  let footnote = render(source, width=80, theme~, ctx~, link_mode=Footnote)
  let expected_footnote =
    #|Docs [1] and API [2]
    #|
    #|[1]: https://example.com/docs
    #|[2]: https://example.com/api
  assert_eq(stripped(footnote), expected_footnote)

  let plain = render(source, width=80, theme~, ctx~, link_mode=Plain)
  assert_eq(stripped(plain), "Docs and API")
}

///|
test "render reflows the parsed AST at different widths" {
  let doc = parse(
    "A markdown renderer should reflow from the AST when the terminal is resized.",
  )
  let narrow = render_doc(
    doc,
    width=18,
    theme=@theme.default_theme(),
    ctx=no_color_ctx(),
    link_mode=Plain,
  )
  let wide = render_doc(
    doc,
    width=42,
    theme=@theme.default_theme(),
    ctx=no_color_ctx(),
    link_mode=Plain,
  )
  assert_true(stripped(narrow) != stripped(wide))
  assert_eq(
    stripped(narrow),
    "A markdown\nrenderer should\nreflow from the\nAST when the\nterminal is\nresized.",
  )
  assert_eq(
    stripped(wide),
    "A markdown renderer should reflow from the\nAST when the terminal is resized.",
  )
  assert_line_widths_at_most(narrow, 18)
  assert_line_widths_at_most(wide, 42)
}

///|
test "non-positive width disables paragraph blockquote and list wrapping" {
  let source =
    #|alpha beta gamma delta
    #|
    #|> quoted words should not wrap when width is disabled
    #|
    #|- list words should not wrap when width is disabled
  let expected =
    #|alpha beta gamma delta
    #|
    #|| quoted words should not wrap when width is disabled
    #|
    #|- list words should not wrap when width is disabled
  let theme = @theme.default_theme()
  let ctx = no_color_ctx()
  assert_eq(
    stripped(render(source, width=0, theme~, ctx~, link_mode=Plain)),
    expected,
  )
  assert_eq(
    stripped(render(source, width=-1, theme~, ctx~, link_mode=Plain)),
    expected,
  )
}
