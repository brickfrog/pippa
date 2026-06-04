///|
pub(all) enum LinkMode {
  Osc8
  Footnote
  Plain
} derive(Eq)

///|
priv struct RenderState {
  width : Int
  theme : @theme.Theme
  ctx : @profile.RenderContext
  link_mode : LinkMode
  defs : Map[String, @cmark.LabelDef]
  footnotes : Array[String]
}

///|
fn paragraph_role() -> @theme.RoleKey {
  @theme.RoleKey::markdown("paragraph")
}

///|
fn heading_role(level : Int) -> @theme.RoleKey {
  let clamped = level.max(1).min(6)
  @theme.RoleKey::markdown("heading.\{clamped}")
}

///|
fn span(text : String, role : @theme.RoleKey) -> @theme.StyledSpan {
  @theme.StyledSpan::new(text, role)
}

///|
fn append_spans(
  target : Array[@theme.StyledSpan],
  source : Array[@theme.StyledSpan],
) -> Unit {
  for item in source {
    target.push(item)
  }
}

///|
fn spans_with_role(
  spans : Array[@theme.StyledSpan],
  role : @theme.RoleKey,
) -> Array[@theme.StyledSpan] {
  let out : Array[@theme.StyledSpan] = []
  for item in spans {
    out.push({ ..item, role, })
  }
  out
}

///|
fn spans_with_href(
  spans : Array[@theme.StyledSpan],
  href : String,
) -> Array[@theme.StyledSpan] {
  let out : Array[@theme.StyledSpan] = []
  for item in spans {
    out.push({
      ..item,
      role: @theme.RoleKey::markdown("link"),
      href: Some(href),
    })
  }
  out
}

///|
fn render_wrapped_lines(
  spans : Array[@theme.StyledSpan],
  width : Int,
  state : RenderState,
) -> Array[String] {
  if spans.length() == 0 {
    return []
  }
  @pippa.split_lines(
    @theme.render_wrapped_spans(spans, width.max(1), state.theme, state.ctx),
  )
}

///|
fn render_plain_line(
  text : String,
  role : @theme.RoleKey,
  state : RenderState,
) -> String {
  @theme.render_spans([span(text, role)], state.theme, state.ctx)
}

///|
fn append_rendered_block(
  out : Array[String],
  block_lines : Array[String],
) -> Unit {
  if block_lines.length() == 0 {
    return
  }
  if out.length() > 0 {
    out.push("")
  }
  for line in block_lines {
    out.push(line)
  }
}

///|
fn tight_seq_text(seq : @cmark.Seq[@cmark.Tight]) -> String {
  let buf = StringBuilder::new()
  for tight in seq {
    buf.write_string(tight.to_string())
  }
  buf.to_string()
}

///|
fn code_lines(code : @cmark.Seq[@cmark.Node[String]]) -> Array[String] {
  let lines : Array[String] = []
  for line in code {
    lines.push(line.v)
  }
  lines
}

///|
fn link_definition_dest(def : @cmark.LinkDefinition) -> String? {
  match def.dest {
    Some(dest) => Some(dest.v)
    None => None
  }
}

///|
fn link_dest(link : @cmark.InlineLink, state : RenderState) -> String? {
  match link.reference {
    @cmark.ReferenceKind::Inline(def) => link_definition_dest(def.v)
    @cmark.ReferenceKind::Ref(_, _, label) =>
      match state.defs.get(label.key) {
        Some(@cmark.LabelDef::LinkDef(def)) => link_definition_dest(def.v)
        _ => None
      }
  }
}

///|
fn render_link_spans(
  link : @cmark.InlineLink,
  base_role : @theme.RoleKey,
  state : RenderState,
) -> Array[@theme.StyledSpan] {
  let text_spans = spans_with_role(
    inline_spans(link.text, base_role, state),
    @theme.RoleKey::markdown("link"),
  )
  match link_dest(link, state) {
    Some(url) =>
      match state.link_mode {
        Osc8 => spans_with_href(text_spans, url)
        Footnote => {
          let index = state.footnotes.length() + 1
          state.footnotes.push(url)
          let out : Array[@theme.StyledSpan] = []
          append_spans(out, text_spans)
          out.push(span(" [\{index}]", @theme.RoleKey::markdown("link")))
          out
        }
        Plain => text_spans
      }
    None => text_spans
  }
}

///|
fn autolink_spans(
  autolink : @cmark.InlineAutolink,
  state : RenderState,
) -> Array[@theme.StyledSpan] {
  let label = autolink.link.v
  let url = if autolink.is_email { "mailto:\{label}" } else { label }
  let spans = [span(label, @theme.RoleKey::markdown("link"))]
  match state.link_mode {
    Osc8 => spans_with_href(spans, url)
    Footnote => {
      let index = state.footnotes.length() + 1
      state.footnotes.push(url)
      [
        span(label, @theme.RoleKey::markdown("link")),
        span(" [\{index}]", @theme.RoleKey::markdown("link")),
      ]
    }
    Plain => spans
  }
}

///|
fn inline_spans(
  inline : @cmark.Inline,
  base_role : @theme.RoleKey,
  state : RenderState,
) -> Array[@theme.StyledSpan] {
  match inline {
    @cmark.Inline::Text(node) => [span(node.v, base_role)]
    @cmark.Inline::Inlines(node) => {
      let out : Array[@theme.StyledSpan] = []
      for item in node.v {
        append_spans(out, inline_spans(item, base_role, state))
      }
      out
    }
    @cmark.Inline::Emphasis(node) =>
      inline_spans(node.v.inline, @theme.RoleKey::markdown("emphasis"), state)
    @cmark.Inline::StrongEmphasis(node) =>
      inline_spans(node.v.inline, @theme.RoleKey::markdown("strong"), state)
    @cmark.Inline::CodeSpan(node) =>
      [
        @theme.StyledSpan::new(
          node.v.code(),
          @theme.RoleKey::markdown("code.inline"),
          no_wrap=true,
        ),
      ]
    @cmark.Inline::Link(node) => render_link_spans(node.v, base_role, state)
    @cmark.Inline::Image(node) => inline_spans(node.v.text, base_role, state)
    @cmark.Inline::Autolink(node) => autolink_spans(node.v, state)
    @cmark.Inline::Break(node) =>
      match node.v.ty {
        @cmark.InlineBreakType::Hard => [span("\n", base_role)]
        @cmark.InlineBreakType::Soft => [span(" ", base_role)]
      }
    @cmark.Inline::RawHtml(node) => [span(tight_seq_text(node.v.0), base_role)]
    @cmark.Inline::ExtStrikethrough(node) =>
      // TODO(pippa-7w2.4): render GFM strikethrough with its own role.
      inline_spans(node.v.0, base_role, state)
    @cmark.Inline::ExtMathSpan(node) =>
      // TODO(pippa-7w2.4): render GFM math spans with a dedicated role.
      [span(node.v.tex(), base_role)]
  }
}

///|
fn render_paragraph_lines(
  para : @cmark.BlockParagraph,
  state : RenderState,
) -> Array[String] {
  render_wrapped_lines(
    inline_spans(para.inline, paragraph_role(), state),
    state.width,
    state,
  )
}

///|
fn render_heading_lines(
  heading : @cmark.BlockHeading,
  state : RenderState,
) -> Array[String] {
  let role = heading_role(heading.level)
  let prefix = String::make(heading.level.max(1).min(6), '#') + " "
  let spans = [span(prefix, role)]
  append_spans(spans, inline_spans(heading.inline, role, state))
  render_wrapped_lines(spans, state.width, state)
}

///|
fn render_code_block_lines(
  code : @cmark.CodeBlock,
  state : RenderState,
) -> Array[String] {
  let role = @theme.RoleKey::markdown("code.block")
  let out : Array[String] = []
  for line in code_lines(code.code) {
    out.push(render_plain_line(line, role, state))
  }
  out
}

///|
fn render_thematic_break(state : RenderState) -> Array[String] {
  let width = state.width.max(3)
  [
    render_plain_line(
      String::make(width, '-'),
      @theme.RoleKey::markdown("thematic_break"),
      state,
    ),
  ]
}

///|
fn render_blockquote_lines(
  quote : @cmark.BlockQuote,
  state : RenderState,
) -> Array[String] {
  let prefix_width = 2
  let nested = { ..state, width: (state.width - prefix_width).max(1) }
  let prefix = @theme.render_spans(
    [
      span("|", @theme.RoleKey::markdown("blockquote")),
      span(" ", @theme.RoleKey::markdown("blockquote")),
    ],
    state.theme,
    state.ctx,
  )
  let out : Array[String] = []
  for line in render_block_lines(quote.block, nested) {
    out.push(prefix + line)
  }
  out
}

///|
fn render_list_item_lines(
  item : @cmark.ListItem,
  state : RenderState,
) -> Array[String] {
  let marker_text = if item.marker.v == "" { "-" } else { item.marker.v }
  let gap = String::make(item.after_marker.max(1), ' ')
  let marker_width = @pippa.visible_width(marker_text + gap)
  let nested = { ..state, width: (state.width - marker_width).max(1) }
  let marker = @theme.render_spans(
    [
      span(marker_text, @theme.RoleKey::markdown("list.marker")),
      span(gap, paragraph_role()),
    ],
    state.theme,
    state.ctx,
  )
  let continuation = String::make(marker_width, ' ')
  let rendered = render_block_lines(item.block, nested)
  let out : Array[String] = []
  for i in 0..<rendered.length() {
    if i == 0 {
      out.push(marker + rendered[i])
    } else {
      out.push(continuation + rendered[i])
    }
  }
  out
}

///|
fn render_list_lines(
  list : @cmark.BlockList,
  state : RenderState,
) -> Array[String] {
  let out : Array[String] = []
  for item in list.items {
    if out.length() > 0 && !list.tight {
      out.push("")
    }
    for line in render_list_item_lines(item.v, state) {
      out.push(line)
    }
  }
  out
}

///|
fn render_html_block_lines(
  html : @cmark.HtmlBlock,
  state : RenderState,
) -> Array[String] {
  let out : Array[String] = []
  for line in html.0 {
    out.push(render_plain_line(line.v, paragraph_role(), state))
  }
  out
}

///|
fn inline_plain_text(inline : @cmark.Inline, state : RenderState) -> String {
  @theme.span_plain_text(inline_spans(inline, paragraph_role(), state))
}

///|
fn render_table_lines(
  table : @cmark.Table,
  state : RenderState,
) -> Array[String] {
  // TODO(pippa-7w2.4): render GFM tables with cell alignment and borders.
  let out : Array[String] = []
  for row in table.rows {
    match row.0.v {
      @cmark.TableRow::Header(cells) | @cmark.TableRow::Data(cells) => {
        let parts : Array[String] = []
        for cell in cells {
          parts.push(inline_plain_text(cell.0, state))
        }
        if parts.length() > 0 {
          out.push(
            render_plain_line(parts.join(" | "), paragraph_role(), state),
          )
        }
      }
      @cmark.TableRow::Sep(_) => ()
    }
  }
  out
}

///|
fn render_footnote_definition_lines(
  footnote : @cmark.Footnote,
  state : RenderState,
) -> Array[String] {
  // TODO(pippa-7w2.4): render GFM footnote definitions with backlinks.
  render_block_lines(footnote.block, state)
}

///|
fn render_block_lines(
  block : @cmark.Block,
  state : RenderState,
) -> Array[String] {
  match block {
    @cmark.Block::BlankLine(_) | @cmark.Block::LinkRefDefinition(_) => []
    @cmark.Block::Blocks(node) => {
      let out : Array[String] = []
      for item in node.v {
        append_rendered_block(out, render_block_lines(item, state))
      }
      out
    }
    @cmark.Block::Paragraph(node) => render_paragraph_lines(node.v, state)
    @cmark.Block::Heading(node) => render_heading_lines(node.v, state)
    @cmark.Block::CodeBlock(node) => render_code_block_lines(node.v, state)
    @cmark.Block::ThematicBreak(_) => render_thematic_break(state)
    @cmark.Block::BlockQuote(node) => render_blockquote_lines(node.v, state)
    @cmark.Block::List(node) => render_list_lines(node.v, state)
    @cmark.Block::HtmlBlock(node) => render_html_block_lines(node.v, state)
    @cmark.Block::ExtMathBlock(node) =>
      // TODO(pippa-7w2.4): render math blocks with a dedicated role.
      render_code_block_lines(node.v, state)
    @cmark.Block::ExtTable(node) => render_table_lines(node.v, state)
    @cmark.Block::ExtFootnoteDefinition(node) =>
      render_footnote_definition_lines(node.v, state)
  }
}

///|
fn append_link_footnotes(lines : Array[String], state : RenderState) -> Unit {
  if state.link_mode != Footnote || state.footnotes.length() == 0 {
    return
  }
  if lines.length() > 0 {
    lines.push("")
  }
  for i in 0..<state.footnotes.length() {
    let text = "[\{i + 1}]: \{state.footnotes[i]}"
    lines.push(render_plain_line(text, @theme.RoleKey::markdown("link"), state))
  }
}

///|
pub fn parse(source : String) -> @cmark.Doc {
  @cmark.Doc::from_string(source)
}

///|
pub fn render_doc(
  doc : @cmark.Doc,
  width~ : Int,
  theme~ : @theme.Theme,
  ctx~ : @profile.RenderContext,
  link_mode? : LinkMode = Osc8,
) -> String {
  let state = { width, theme, ctx, link_mode, defs: doc.defs, footnotes: [] }
  let lines = render_block_lines(doc.block, state)
  append_link_footnotes(lines, state)
  lines.join("\n")
}

///|
pub fn render(
  source : String,
  width~ : Int,
  theme~ : @theme.Theme,
  ctx~ : @profile.RenderContext,
  link_mode? : LinkMode = Osc8,
) -> String {
  render_doc(parse(source), width~, theme~, ctx~, link_mode~)
}
