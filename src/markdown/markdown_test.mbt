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
fn max_line_width(rendered : String) -> Int {
  let mut width = 0
  for line in @pippa.split_lines(rendered) {
    width = width.max(@pippa.visible_width(line))
  }
  width
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

///|
test "default markdown flavor remains CommonMark strict" {
  let source =
    #|| A | B |
    #||---|---|
    #|| 1 | 2 |
    #|
    #|~~gone~~
  let rendered = render(
    source,
    width=80,
    theme=@theme.default_theme(),
    ctx=no_color_ctx(),
    link_mode=Plain,
  )
  let expected =
    #|| A | B | |---|---| | 1 | 2 |
    #|
    #|~~gone~~
  assert_eq(stripped(rendered), expected)
}

///|
test "gfm task list markers render unicode checkboxes with ascii fallback" {
  let source =
    #|- [x] done
    #|- [ ] todo
  let theme = @theme.default_theme()
  let ctx = no_color_ctx()
  let unicode = render(
    source,
    width=80,
    theme~,
    ctx~,
    link_mode=Plain,
    options=MarkdownOptions::gfm(),
  )
  assert_eq(stripped(unicode), "- ☑ done\n- ☐ todo")

  let ascii = render(
    source,
    width=80,
    theme~,
    ctx~,
    link_mode=Plain,
    options=MarkdownOptions::gfm().with_task_checkbox_style(AsciiCheckbox),
  )
  assert_eq(stripped(ascii), "- [x] done\n- [ ] todo")
}

///|
test "gfm strikethrough and autolinks render through styled spans" {
  let theme = @theme.default_theme()
  let no_color = render(
    "~~gone~~ and <https://example.com>",
    width=80,
    theme~,
    ctx=no_color_ctx(),
    link_mode=Osc8,
    options=MarkdownOptions::gfm(),
  )
  assert_eq(stripped(no_color), "gone and https://example.com")
  assert_true(no_color.contains("\u001b]8;;https://example.com\u001b\\"))
  assert_true(no_color.contains("\u001b]8;;\u001b\\"))

  let bare = render(
    "https://example.com",
    width=80,
    theme~,
    ctx=no_color_ctx(),
    link_mode=Osc8,
    options=MarkdownOptions::gfm(),
  )
  assert_eq(stripped(bare), "https://example.com")
  assert_false(bare.contains("\u001b]8;;https://example.com\u001b\\"))

  let styled = render(
    "~~gone~~",
    width=80,
    theme~,
    ctx=@profile.RenderContext::default(),
    link_mode=Plain,
    options=MarkdownOptions::gfm(),
  )
  assert_true(styled.contains("\u001b[9m"))

  let nested = render(
    "~~**bold** [link](https://example.com)~~",
    width=80,
    theme~,
    ctx=@profile.RenderContext::default(),
    link_mode=Osc8,
    options=MarkdownOptions::gfm(),
  )
  assert_eq(stripped(nested), "bold link")
  assert_true(nested.contains("\u001b[1m"))
  assert_true(nested.contains("\u001b[4m"))
  assert_true(nested.contains("\u001b[9m"))
  assert_true(nested.contains("\u001b]8;;https://example.com\u001b\\"))
}

///|
test "gfm tables align columns and wrap narrow cells by visible width" {
  let source =
    #|| Left | Right | Center |
    #||:-----|------:|:------:|
    #|| alpha beta | 12 | mid |
    #|| long words here | 300 | centered |
  let rendered = render(
    source,
    width=34,
    theme=@theme.default_theme(),
    ctx=no_color_ctx(),
    link_mode=Plain,
    options=MarkdownOptions::gfm().with_table_narrow_mode(Wrap),
  )
  let expected =
    #|| Left     |    Right |  Center  |
    #|| :------- | -------: | :------: |
    #|| alpha    |       12 |   mid    |
    #|| beta     |          |          |
    #|| long     |      300 | centered |
    #|| words    |          |          |
    #|| here     |          |          |
  assert_eq(stripped(rendered), expected)
  assert_line_widths_at_most(stripped(rendered), 34)
}

///|
test "gfm table wrap preserves long no-wrap cell content" {
  let source =
    #|| Code |
    #||------|
    #|| `supercalifragilistic` |
  let rendered = render(
    source,
    width=14,
    theme=@theme.default_theme(),
    ctx=no_color_ctx(),
    link_mode=Plain,
    options=MarkdownOptions::gfm().with_table_narrow_mode(Wrap),
  )
  let expected =
    #|| Code       |
    #|| ---------- |
    #|| supercalif |
    #|| ragilistic |
  assert_eq(stripped(rendered), expected)
  assert_true(stripped(rendered).contains("supercalif"))
  assert_true(stripped(rendered).contains("ragilistic"))
  assert_line_widths_at_most(stripped(rendered), 14)
}

///|
test "gfm tables can truncate narrow cells by visible width" {
  let source =
    #|| Left | Right | Center |
    #||:-----|------:|:------:|
    #|| alpha beta | 12 | mid |
    #|| long words here | 300 | centered |
  let rendered = render(
    source,
    width=34,
    theme=@theme.default_theme(),
    ctx=no_color_ctx(),
    link_mode=Plain,
    options=MarkdownOptions::gfm().with_table_narrow_mode(Truncate),
  )
  let expected =
    #|| Left     |    Right |  Center  |
    #|| :------- | -------: | :------: |
    #|| alpha b… |       12 |   mid    |
    #|| long wo… |      300 | centered |
  assert_eq(stripped(rendered), expected)
  assert_line_widths_at_most(stripped(rendered), 34)
}

///|
test "gfm table width fits except below structural minimum" {
  let source =
    #|| A | B | C | D |
    #||---|---|---|---|
    #|| alpha | beta | gamma | delta |
  let fitted = render(
    source,
    width=17,
    theme=@theme.default_theme(),
    ctx=no_color_ctx(),
    link_mode=Plain,
    options=MarkdownOptions::gfm().with_table_narrow_mode(Wrap),
  )
  assert_line_widths_at_most(stripped(fitted), 17)

  let structural_overflow = render(
    source,
    width=10,
    theme=@theme.default_theme(),
    ctx=no_color_ctx(),
    link_mode=Plain,
    options=MarkdownOptions::gfm().with_table_narrow_mode(Wrap),
  )
  assert_eq(max_line_width(stripped(structural_overflow)), 17)
  assert_true(max_line_width(stripped(structural_overflow)) > 10)

  let wide_source =
    #|| A | B |
    #||---|---|
    #|| 界 | x |
  let wide_fitted = render(
    wide_source,
    width=10,
    theme=@theme.default_theme(),
    ctx=no_color_ctx(),
    link_mode=Plain,
    options=MarkdownOptions::gfm().with_table_narrow_mode(Wrap),
  )
  assert_line_widths_at_most(stripped(wide_fitted), 10)

  let wide_structural_overflow = render(
    wide_source,
    width=9,
    theme=@theme.default_theme(),
    ctx=no_color_ctx(),
    link_mode=Plain,
    options=MarkdownOptions::gfm().with_table_narrow_mode(Wrap),
  )
  assert_eq(max_line_width(stripped(wide_structural_overflow)), 10)
  assert_true(max_line_width(stripped(wide_structural_overflow)) > 9)
}

///|
fn markdown_syntax_theme() -> @theme.Theme {
  @theme.Theme::new()
  .with_role(@theme.RoleKey::markdown("code.block"), @pippa.style())
  .with_role(
    @theme.RoleKey::syntax("keyword"),
    @pippa.style().foreground(@pippa.color_ansi(2)).bold(),
  )
}

///|
fn ansi16_ctx() -> @profile.RenderContext {
  @profile.RenderContext::default().with_color_profile(@profile.Ansi16)
}

///|
test "fenced code highlighting is opt in via syntax registry" {
  let source =
    #|```moonbit
    #|fn main
    #|```
  let theme = markdown_syntax_theme()
  let ctx = ansi16_ctx()
  let plain = render(source, width=80, theme~, ctx~, link_mode=Plain)
  assert_eq(stripped(plain), "fn main")
  assert_true(!plain.contains("\u001b[32m"))

  let highlighted = render(
    source,
    width=80,
    theme~,
    ctx~,
    link_mode=Plain,
    options=MarkdownOptions::default().with_syntax_registry(
      @syntax.SyntaxRegistry::default(),
    ),
  )
  assert_eq(stripped(highlighted), "fn main")
  assert_true(highlighted.contains("\u001b[32m"))
  assert_true(highlighted.contains("\u001b[1mfn"))

  let unknown_source =
    #|```unknown
    #|fn main
    #|```
  let unknown = render(
    unknown_source,
    width=80,
    theme~,
    ctx~,
    link_mode=Plain,
    options=MarkdownOptions::default().with_syntax_registry(
      @syntax.SyntaxRegistry::default(),
    ),
  )
  assert_eq(stripped(unknown), "fn main")
  assert_true(!unknown.contains("\u001b[32m"))
}

///|
test "highlighted text fences keep markdown code block base styling" {
  let source =
    #|```text
    #|plain text
    #|```
  let theme = @theme.Theme::new()
    .with_role(
      @theme.RoleKey::markdown("code.block"),
      @pippa.style().foreground(@pippa.color_ansi(5)),
    )
    .with_role(
      @theme.RoleKey::syntax("text"),
      @pippa.style().foreground(@pippa.color_ansi(2)),
    )
  let highlighted = render(
    source,
    width=80,
    theme~,
    ctx=ansi16_ctx(),
    link_mode=Plain,
    options=MarkdownOptions::default().with_syntax_registry(
      @syntax.SyntaxRegistry::default(),
    ),
  )
  assert_eq(stripped(highlighted), "plain text")
  assert_true(highlighted.contains("\u001b[35mplain text"))
  assert_true(!highlighted.contains("\u001b[32mplain text"))
}
