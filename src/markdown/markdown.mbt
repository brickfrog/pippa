///|
pub(all) enum LinkMode {
  Osc8
  Footnote
  Plain
} derive(Eq)

///|
/// Markdown parsing flavor.
///
/// `CommonMark` is the default to preserve the original strict `.3` behavior.
/// Use `Gfm` to parse cmark extensions with `strict=false` and render GitHub
/// Flavored Markdown tables, task lists, strikethrough, and autolinks.
pub(all) enum MarkdownFlavor {
  CommonMark
  Gfm
} derive(Eq)

///|
/// Strategy for tables wider than the render width.
///
/// `Wrap` reflows cell contents within allocated columns. `Truncate` keeps one
/// terminal row per markdown row and clips cell text by visible width. Extremely
/// narrow widths fall back to one terminal cell per markdown column.
pub(all) enum TableNarrowMode {
  Wrap
  Truncate
} derive(Eq)

///|
/// Task-list checkbox glyph style.
///
/// `UnicodeCheckbox` renders checked/unchecked tasks as `☑` and `☐`.
/// `AsciiCheckbox` renders the portable `[x]` and `[ ]` fallback.
pub(all) enum TaskCheckboxStyle {
  UnicodeCheckbox
  AsciiCheckbox
} derive(Eq)

///|
/// Markdown renderer options.
///
/// The default is CommonMark-strict parsing with wrapping table behavior and
/// Unicode task checkboxes. Call `MarkdownOptions::gfm()` to opt into GitHub
/// Flavored Markdown parsing and rendering.
pub(all) struct MarkdownOptions {
  flavor : MarkdownFlavor
  table_narrow_mode : TableNarrowMode
  task_checkbox_style : TaskCheckboxStyle
} derive(Eq)

///|
pub fn MarkdownOptions::default() -> MarkdownOptions {
  {
    flavor: CommonMark,
    table_narrow_mode: Wrap,
    task_checkbox_style: UnicodeCheckbox,
  }
}

///|
pub fn MarkdownOptions::commonmark() -> MarkdownOptions {
  MarkdownOptions::default()
}

///|
pub fn MarkdownOptions::gfm() -> MarkdownOptions {
  { ..MarkdownOptions::default(), flavor: Gfm }
}

///|
pub fn MarkdownOptions::with_flavor(
  self : MarkdownOptions,
  flavor : MarkdownFlavor,
) -> MarkdownOptions {
  { ..self, flavor, }
}

///|
pub fn MarkdownOptions::with_table_narrow_mode(
  self : MarkdownOptions,
  table_narrow_mode : TableNarrowMode,
) -> MarkdownOptions {
  { ..self, table_narrow_mode, }
}

///|
pub fn MarkdownOptions::with_task_checkbox_style(
  self : MarkdownOptions,
  task_checkbox_style : TaskCheckboxStyle,
) -> MarkdownOptions {
  { ..self, task_checkbox_style, }
}

///|
priv struct RenderState {
  width : Int
  theme : @theme.Theme
  ctx : @profile.RenderContext
  link_mode : LinkMode
  options : MarkdownOptions
  defs : Map[String, @cmark.LabelDef]
  footnotes : Array[String]
}

///|
priv struct TableRenderRow {
  cells : Array[Array[@theme.StyledSpan]]
  is_header : Bool
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
fn spans_with_role_and_style(
  spans : Array[@theme.StyledSpan],
  role : @theme.RoleKey,
  style : @pippa.Style,
) -> Array[@theme.StyledSpan] {
  let out : Array[@theme.StyledSpan] = []
  for item in spans {
    out.push({ ..item, role, style_override: Some(style) })
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
    @theme.render_wrapped_spans(spans, width, state.theme, state.ctx),
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
fn strikethrough_spans(
  inline : @cmark.Inline,
  state : RenderState,
) -> Array[@theme.StyledSpan] {
  let role = @theme.RoleKey::markdown("strikethrough")
  spans_with_role_and_style(
    inline_spans(inline, role, state),
    role,
    state.theme.style(role).strikethrough(),
  )
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
      strikethrough_spans(node.v.0, state)
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
fn child_width(parent_width : Int, consumed_width : Int) -> Int {
  if parent_width <= 0 {
    parent_width
  } else {
    (parent_width - consumed_width).max(1)
  }
}

///|
fn task_marker_checked(marker : Char) -> Bool {
  marker == 'x' || marker == 'X'
}

///|
fn task_checkbox_text(marker : Char, style : TaskCheckboxStyle) -> String {
  let checked = task_marker_checked(marker)
  match style {
    UnicodeCheckbox => if checked { "☑" } else { "☐" }
    AsciiCheckbox => if checked { "[x]" } else { "[ ]" }
  }
}

///|
fn task_checkbox_spans(
  marker : @cmark.Node[Char]?,
  state : RenderState,
) -> Array[@theme.StyledSpan] {
  match marker {
    Some(mark) => {
      let checked = task_marker_checked(mark.v)
      let role = if checked {
        @theme.RoleKey::markdown("task.checked")
      } else {
        @theme.RoleKey::markdown("task.unchecked")
      }
      [
        span(
          task_checkbox_text(mark.v, state.options.task_checkbox_style) + " ",
          role,
        ),
      ]
    }
    None => []
  }
}

///|
fn render_blockquote_lines(
  quote : @cmark.BlockQuote,
  state : RenderState,
) -> Array[String] {
  let prefix_width = 2
  let nested = { ..state, width: child_width(state.width, prefix_width) }
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
  let task_spans = task_checkbox_spans(item.ext_task_marker, state)
  let marker_width = @pippa.visible_width(
    marker_text + gap + @theme.span_plain_text(task_spans),
  )
  let nested = { ..state, width: child_width(state.width, marker_width) }
  let marker_spans = [
    span(marker_text, @theme.RoleKey::markdown("list.marker")),
    span(gap, paragraph_role()),
  ]
  append_spans(marker_spans, task_spans)
  let marker = @theme.render_spans(marker_spans, state.theme, state.ctx)
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
fn table_border_role() -> @theme.RoleKey {
  @theme.RoleKey::markdown("table.border")
}

///|
fn table_header_role() -> @theme.RoleKey {
  @theme.RoleKey::markdown("table.header")
}

///|
fn table_cell_role() -> @theme.RoleKey {
  @theme.RoleKey::markdown("table.cell")
}

///|
fn table_border_overhead(col_count : Int) -> Int {
  col_count * 3 + 1
}

///|
fn table_line_width(spans : Array[@theme.StyledSpan]) -> Int {
  @pippa.visible_width(@theme.span_plain_text(spans))
}

///|
fn table_cell_width(spans : Array[@theme.StyledSpan]) -> Int {
  let mut width = 0
  for line in @pippa.split_lines(@theme.span_plain_text(spans)) {
    width = width.max(@pippa.visible_width(line))
  }
  width
}

///|
fn table_align(
  align : @cmark.TableAlign?,
  line : Array[@theme.StyledSpan],
  width : Int,
  role : @theme.RoleKey,
) -> Array[@theme.StyledSpan] {
  let safe_width = width.max(0)
  let clipped = if table_line_width(line) > safe_width {
    table_truncate_line(line, safe_width)
  } else {
    line
  }
  let line_width = table_line_width(clipped)
  let total_pad = (safe_width - line_width).max(0)
  let (left_pad, right_pad) = match align {
    Some(@cmark.TableAlign::Right) => (total_pad, 0)
    Some(@cmark.TableAlign::Center) => {
      let left = total_pad / 2
      (left, total_pad - left)
    }
    _ => (0, total_pad)
  }
  let out : Array[@theme.StyledSpan] = []
  if left_pad > 0 {
    out.push(span(String::make(left_pad, ' '), role))
  }
  append_spans(out, clipped)
  if right_pad > 0 {
    out.push(span(String::make(right_pad, ' '), role))
  }
  out
}

///|
fn table_truncate_line(
  spans : Array[@theme.StyledSpan],
  width : Int,
) -> Array[@theme.StyledSpan] {
  let out : Array[@theme.StyledSpan] = []
  if width <= 0 {
    return out
  }
  let mut remaining = width
  for item in spans {
    if remaining <= 0 {
      break
    }
    let clipped = @pippa.truncate(item.text, remaining)
    if clipped != "" {
      out.push({ ..item, text: clipped })
      remaining = remaining - @pippa.visible_width(clipped)
    }
    if @pippa.visible_width(clipped) < @pippa.visible_width(item.text) {
      break
    }
  }
  out
}

///|
fn table_cell_lines(
  spans : Array[@theme.StyledSpan],
  width : Int,
  mode : TableNarrowMode,
) -> Array[Array[@theme.StyledSpan]] {
  match mode {
    Wrap => @theme.wrap_spans(spans, width.max(1))
    Truncate => [table_truncate_line(spans, width.max(1))]
  }
}

///|
fn table_cells_from_seq(
  cells : @cmark.Seq[(@cmark.Inline, @cmark.TableCellLayout)],
  role : @theme.RoleKey,
  state : RenderState,
) -> Array[Array[@theme.StyledSpan]] {
  let out : Array[Array[@theme.StyledSpan]] = []
  for cell in cells {
    out.push(inline_spans(cell.0, role, state))
  }
  out
}

///|
fn table_default_aligns(col_count : Int) -> Array[@cmark.TableAlign?] {
  let aligns : Array[@cmark.TableAlign?] = []
  for _ in 0..<col_count {
    aligns.push(None)
  }
  aligns
}

///|
fn table_apply_separators(
  aligns : Array[@cmark.TableAlign?],
  seps : @cmark.Seq[@cmark.Node[@cmark.TableSep]],
) -> Unit {
  let mut i = 0
  for sep in seps {
    if i < aligns.length() {
      aligns[i] = sep.v.0.0
    }
    i = i + 1
  }
}

///|
fn table_natural_widths(
  rows : Array[TableRenderRow],
  col_count : Int,
) -> Array[Int] {
  let widths : Array[Int] = []
  for _ in 0..<col_count {
    widths.push(1)
  }
  for row in rows {
    for i in 0..<col_count {
      if i < row.cells.length() {
        widths[i] = widths[i].max(table_cell_width(row.cells[i]).max(1))
      }
    }
  }
  widths
}

///|
fn table_total_width(widths : Array[Int]) -> Int {
  let mut width = table_border_overhead(widths.length())
  for col_width in widths {
    width = width + col_width
  }
  width
}

///|
fn table_fit_widths(widths : Array[Int], target_width : Int) -> Array[Int] {
  if target_width <= 0 || table_total_width(widths) <= target_width {
    return widths
  }
  let col_count = widths.length()
  let available = (target_width - table_border_overhead(col_count)).max(
    col_count,
  )
  let base = (available / col_count).max(1)
  let extra = available % col_count
  let out : Array[Int] = []
  for i in 0..<col_count {
    let width = if i < extra { base + 1 } else { base }
    out.push(width.max(1))
  }
  out
}

///|
fn table_separator_text(width : Int, align : @cmark.TableAlign?) -> String {
  let safe_width = width.max(1)
  match align {
    Some(@cmark.TableAlign::Left) =>
      if safe_width == 1 {
        ":"
      } else {
        ":" + String::make(safe_width - 1, '-')
      }
    Some(@cmark.TableAlign::Right) =>
      if safe_width == 1 {
        ":"
      } else {
        String::make(safe_width - 1, '-') + ":"
      }
    Some(@cmark.TableAlign::Center) =>
      if safe_width == 1 {
        ":"
      } else if safe_width == 2 {
        "::"
      } else {
        ":" + String::make(safe_width - 2, '-') + ":"
      }
    None => String::make(safe_width, '-')
  }
}

///|
fn render_table_separator_line(
  widths : Array[Int],
  aligns : Array[@cmark.TableAlign?],
  state : RenderState,
) -> String {
  let line : Array[@theme.StyledSpan] = [span("| ", table_border_role())]
  for i in 0..<widths.length() {
    if i > 0 {
      line.push(span(" | ", table_border_role()))
    }
    let align = if i < aligns.length() { aligns[i] } else { None }
    line.push(span(table_separator_text(widths[i], align), table_border_role()))
  }
  line.push(span(" |", table_border_role()))
  @theme.render_spans(line, state.theme, state.ctx)
}

///|
fn render_table_row_lines(
  row : TableRenderRow,
  widths : Array[Int],
  aligns : Array[@cmark.TableAlign?],
  state : RenderState,
) -> Array[String] {
  let col_count = widths.length()
  let role = if row.is_header { table_header_role() } else { table_cell_role() }
  let cell_lines : Array[Array[Array[@theme.StyledSpan]]] = []
  let mut height = 1
  for i in 0..<col_count {
    let cell = if i < row.cells.length() { row.cells[i] } else { [] }
    let lines = table_cell_lines(
      cell,
      widths[i],
      state.options.table_narrow_mode,
    )
    height = height.max(lines.length())
    cell_lines.push(lines)
  }
  let rendered : Array[String] = []
  for line_index in 0..<height {
    let line : Array[@theme.StyledSpan] = [span("| ", table_border_role())]
    for col in 0..<col_count {
      if col > 0 {
        line.push(span(" | ", table_border_role()))
      }
      let align = if col < aligns.length() { aligns[col] } else { None }
      let content = if line_index < cell_lines[col].length() {
        cell_lines[col][line_index]
      } else {
        []
      }
      append_spans(line, table_align(align, content, widths[col], role))
    }
    line.push(span(" |", table_border_role()))
    rendered.push(@theme.render_spans(line, state.theme, state.ctx))
  }
  rendered
}

///|
fn render_table_lines(
  table : @cmark.Table,
  state : RenderState,
) -> Array[String] {
  if table.col_count <= 0 {
    return []
  }
  let rows : Array[TableRenderRow] = []
  let aligns = table_default_aligns(table.col_count)
  for row in table.rows {
    match row.0.v {
      @cmark.TableRow::Header(cells) =>
        rows.push({
          cells: table_cells_from_seq(cells, table_header_role(), state),
          is_header: true,
        })
      @cmark.TableRow::Data(cells) =>
        rows.push({
          cells: table_cells_from_seq(cells, table_cell_role(), state),
          is_header: false,
        })
      @cmark.TableRow::Sep(seps) => table_apply_separators(aligns, seps)
    }
  }
  if rows.length() == 0 {
    return []
  }
  let widths = table_fit_widths(
    table_natural_widths(rows, table.col_count),
    state.width,
  )
  let out : Array[String] = []
  let mut rendered_separator = false
  for row in rows {
    for line in render_table_row_lines(row, widths, aligns, state) {
      out.push(line)
    }
    if row.is_header && !rendered_separator {
      out.push(render_table_separator_line(widths, aligns, state))
      rendered_separator = true
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
pub fn parse(
  source : String,
  options? : MarkdownOptions = MarkdownOptions::default(),
) -> @cmark.Doc {
  match options.flavor {
    CommonMark => @cmark.Doc::from_string(source, strict=true)
    Gfm => @cmark.Doc::from_string(source, strict=false)
  }
}

///|
pub fn render_doc(
  doc : @cmark.Doc,
  width~ : Int,
  theme~ : @theme.Theme,
  ctx~ : @profile.RenderContext,
  link_mode? : LinkMode = Osc8,
  options? : MarkdownOptions = MarkdownOptions::default(),
) -> String {
  let state = {
    width,
    theme,
    ctx,
    link_mode,
    options,
    defs: doc.defs,
    footnotes: [],
  }
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
  options? : MarkdownOptions = MarkdownOptions::default(),
) -> String {
  render_doc(
    parse(source, options~),
    width~,
    theme~,
    ctx~,
    link_mode~,
    options~,
  )
}
