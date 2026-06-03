///|
/// Static table renderer inspired by lipgloss/table.

///|
pub const HEADER_ROW : Int = -1

///|
priv struct TableBorder {
  top_left : String
  top_right : String
  bottom_left : String
  bottom_right : String
  horizontal : String
  vertical : String
  middle_top : String
  middle_bottom : String
  middle_left : String
  middle_right : String
  middle : String
}

///|
struct Table {
  headers : Array[String]
  rows : Array[Array[String]]
  border : @pippa.Border
  border_top : Bool
  border_bottom : Bool
  border_left : Bool
  border_right : Bool
  border_header : Bool
  border_column : Bool
  border_row : Bool
  border_style : @pippa.Style
  style_func : (Int, Int) -> @pippa.Style
  width : Int
  height : Int
  wrap : Bool
}

///|
fn default_style(_row : Int, _col : Int) -> @pippa.Style {
  @pippa.style()
}

///|
pub fn new() -> Table {
  {
    headers: [],
    rows: [],
    border: @pippa.border_normal(),
    border_top: true,
    border_bottom: true,
    border_left: true,
    border_right: true,
    border_header: true,
    border_column: true,
    border_row: false,
    border_style: @pippa.style(),
    style_func: default_style,
    width: 0,
    height: 0,
    wrap: true,
  }
}

///|
fn copy_strings(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn copy_rows(rows : Array[Array[String]]) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  for row in rows {
    out.push(copy_strings(row))
  }
  out
}

///|
fn append_row(
  rows : Array[Array[String]],
  row : Array[String],
) -> Array[Array[String]] {
  let out = copy_rows(rows)
  out.push(copy_strings(row))
  out
}

///|
pub fn Table::headers(self : Table, headers : Array[String]) -> Table {
  { ..self, headers: copy_strings(headers) }
}

///|
pub fn Table::get_headers(self : Table) -> Array[String] {
  copy_strings(self.headers)
}

///|
pub fn Table::clear_rows(self : Table) -> Table {
  { ..self, rows: [] }
}

///|
pub fn Table::row(self : Table, row : Array[String]) -> Table {
  { ..self, rows: append_row(self.rows, row) }
}

///|
pub fn Table::rows(self : Table, rows : Array[Array[String]]) -> Table {
  let mut table = self
  for row in rows {
    table = table.row(row)
  }
  table
}

///|
pub fn Table::get_rows(self : Table) -> Array[Array[String]] {
  copy_rows(self.rows)
}

///|
pub fn Table::border(self : Table, border : @pippa.Border) -> Table {
  { ..self, border, }
}

///|
pub fn Table::border_style(self : Table, style : @pippa.Style) -> Table {
  { ..self, border_style: style }
}

///|
pub fn Table::border_top(self : Table, value : Bool) -> Table {
  { ..self, border_top: value }
}

///|
pub fn Table::border_bottom(self : Table, value : Bool) -> Table {
  { ..self, border_bottom: value }
}

///|
pub fn Table::border_left(self : Table, value : Bool) -> Table {
  { ..self, border_left: value }
}

///|
pub fn Table::border_right(self : Table, value : Bool) -> Table {
  { ..self, border_right: value }
}

///|
pub fn Table::border_header(self : Table, value : Bool) -> Table {
  { ..self, border_header: value }
}

///|
pub fn Table::border_column(self : Table, value : Bool) -> Table {
  { ..self, border_column: value }
}

///|
pub fn Table::border_row(self : Table, value : Bool) -> Table {
  { ..self, border_row: value }
}

///|
pub fn Table::style_func(
  self : Table,
  style_func : (Int, Int) -> @pippa.Style,
) -> Table {
  { ..self, style_func, }
}

///|
/// Set the table's target visible width.
///
/// During resizing and final fitting, cell content is truncated to its column
/// width. If a column is narrower than a cell's widest grapheme display width,
/// that grapheme is dropped whole rather than split, matching lipgloss/table's
/// truncate-to-column-width behavior. Columns wide enough to hold the grapheme
/// preserve it.
pub fn Table::width(self : Table, width : Int) -> Table {
  { ..self, width: @internal.clamp_non_negative(width) }
}

///|
/// Set a best-effort table height cap.
///
/// The static renderer caps rendered data rows while preserving table structure
/// such as the bottom border. Lip Gloss-style overflow rows are tracked as
/// follow-up work.
pub fn Table::height(self : Table, height : Int) -> Table {
  { ..self, height: @internal.clamp_non_negative(height) }
}

///|
pub fn Table::wrap(self : Table, wrap : Bool) -> Table {
  { ..self, wrap, }
}

///|
fn style_for(table : Table, row : Int, col : Int) -> @pippa.Style {
  (table.style_func)(row, col)
}

///|
fn column_count(table : Table) -> Int {
  let mut count = table.headers.length()
  for row in table.rows {
    if row.length() > count {
      count = row.length()
    }
  }
  count
}

///|
fn cell_at(row : Array[String], col : Int) -> String {
  if col < 0 || col >= row.length() {
    ""
  } else {
    row[col]
  }
}

///|
fn style_horizontal_frame(style : @pippa.Style) -> Int {
  let mut width = style.padding_left +
    style.padding_right +
    style.margin_left +
    style.margin_right
  match style.border {
    Some(_) => {
      if style.border_left {
        width = width + 1
      }
      if style.border_right {
        width = width + 1
      }
    }
    None => ()
  }
  width
}

///|
fn fixed_cell_width(style : @pippa.Style) -> Int {
  if style.width > 0 {
    style.width + style_horizontal_frame(style)
  } else {
    0
  }
}

///|
fn cell_fixed_width(table : Table, row_index : Int, col : Int) -> Int {
  fixed_cell_width(style_for(table, row_index, col))
}

///|
fn fixed_widths(table : Table, count : Int) -> Array[Int] {
  let widths : Array[Int] = []
  for col in 0..<count {
    let mut width = 0
    if !table.headers.is_empty() {
      width = width.max(cell_fixed_width(table, HEADER_ROW, col))
    }
    for row_index in 0..<table.rows.length() {
      width = width.max(cell_fixed_width(table, row_index, col))
    }
    widths.push(width)
  }
  widths
}

///|
fn cell_natural_width(
  table : Table,
  row_index : Int,
  col : Int,
  value : String,
) -> Int {
  let style = style_for(table, row_index, col)
  let fixed = fixed_cell_width(style)
  if fixed > 0 {
    fixed
  } else {
    @pippa.max_line_width(value) + style_horizontal_frame(style)
  }
}

///|
fn natural_widths(
  table : Table,
  count : Int,
  fixed_widths : Array[Int],
) -> Array[Int] {
  let widths : Array[Int] = []
  for col in 0..<count {
    if fixed_widths[col] > 0 {
      widths.push(fixed_widths[col])
      continue
    }
    let mut width = 0
    if !table.headers.is_empty() {
      width = width.max(
        cell_natural_width(table, HEADER_ROW, col, cell_at(table.headers, col)),
      )
    }
    for row_index in 0..<table.rows.length() {
      width = width.max(
        cell_natural_width(
          table,
          row_index,
          col,
          cell_at(table.rows[row_index], col),
        ),
      )
    }
    widths.push(width)
  }
  widths
}

///|
fn sum_widths(widths : Array[Int]) -> Int {
  let mut total = 0
  for width in widths {
    total = total + width
  }
  total
}

///|
fn horizontal_border_width(table : Table, count : Int) -> Int {
  if count <= 0 {
    0
  } else {
    (if table.border_left { 1 } else { 0 }) +
    (if table.border_right { 1 } else { 0 }) +
    (if table.border_column { count - 1 } else { 0 })
  }
}

///|
fn index_of_shortest_resizable(
  widths : Array[Int],
  fixed_widths : Array[Int],
) -> Int {
  let mut index = -1
  let mut value = 0x7FFFFFFF
  for i, width in widths {
    if fixed_widths[i] == 0 && width < value {
      value = width
      index = i
    }
  }
  index
}

///|
fn index_of_largest_resizable(
  widths : Array[Int],
  fixed_widths : Array[Int],
) -> Int {
  let mut index = -1
  let mut value = -1
  for i, width in widths {
    if fixed_widths[i] == 0 && width > value && width > 0 {
      value = width
      index = i
    }
  }
  index
}

///|
fn resize_widths(
  table : Table,
  widths : Array[Int],
  fixed_widths : Array[Int],
) -> Array[Int] {
  let resized = widths.copy()
  if table.width <= 0 || resized.is_empty() {
    return resized
  }
  let available = (table.width -
  horizontal_border_width(table, resized.length())).max(0)
  while sum_widths(resized) < available {
    let index = index_of_shortest_resizable(resized, fixed_widths)
    if index < 0 {
      break
    }
    resized[index] = resized[index] + 1
  }
  while sum_widths(resized) > available {
    let index = index_of_largest_resizable(resized, fixed_widths)
    if index < 0 {
      break
    }
    resized[index] = resized[index] - 1
  }
  resized
}

///|
fn table_border(border : @pippa.Border) -> TableBorder {
  let top_left = @internal.normalize_border_piece(
    border.top_left,
    @pippa.visible_width,
  )
  let top_right = @internal.normalize_border_piece(
    border.top_right,
    @pippa.visible_width,
  )
  let bottom_left = @internal.normalize_border_piece(
    border.bottom_left,
    @pippa.visible_width,
  )
  let bottom_right = @internal.normalize_border_piece(
    border.bottom_right,
    @pippa.visible_width,
  )
  let horizontal = @internal.normalize_border_piece(
    border.horizontal,
    @pippa.visible_width,
  )
  let vertical = @internal.normalize_border_piece(
    border.vertical,
    @pippa.visible_width,
  )
  if horizontal == "-" && vertical == "|" {
    return {
      top_left,
      top_right,
      bottom_left,
      bottom_right,
      horizontal,
      vertical,
      middle_top: "+",
      middle_bottom: "+",
      middle_left: "+",
      middle_right: "+",
      middle: "+",
    }
  }
  if horizontal == "━" && vertical == "┃" {
    return {
      top_left,
      top_right,
      bottom_left,
      bottom_right,
      horizontal,
      vertical,
      middle_top: "┳",
      middle_bottom: "┻",
      middle_left: "┣",
      middle_right: "┫",
      middle: "╋",
    }
  }
  if horizontal == "═" && vertical == "║" {
    return {
      top_left,
      top_right,
      bottom_left,
      bottom_right,
      horizontal,
      vertical,
      middle_top: "╦",
      middle_bottom: "╩",
      middle_left: "╠",
      middle_right: "╣",
      middle: "╬",
    }
  }
  {
    top_left,
    top_right,
    bottom_left,
    bottom_right,
    horizontal,
    vertical,
    middle_top: "┬",
    middle_bottom: "┴",
    middle_left: "├",
    middle_right: "┤",
    middle: "┼",
  }
}

///|
fn styled_border(table : Table, value : String) -> String {
  table.border_style.render(value)
}

///|
fn render_border_line(
  table : Table,
  widths : Array[Int],
  left : String,
  middle : String,
  right : String,
) -> String {
  let pieces = table_border(table.border)
  let buf = StringBuilder::new()
  if table.border_left {
    buf.write_string(styled_border(table, left))
  }
  for i, width in widths {
    buf.write_string(
      styled_border(table, @internal.repeat_string(pieces.horizontal, width)),
    )
    if i < widths.length() - 1 && table.border_column {
      buf.write_string(styled_border(table, middle))
    }
  }
  if table.border_right {
    buf.write_string(styled_border(table, right))
  }
  buf.to_string()
}

///|
fn render_top_border(table : Table, widths : Array[Int]) -> String {
  let pieces = table_border(table.border)
  render_border_line(
    table,
    widths,
    pieces.top_left,
    pieces.middle_top,
    pieces.top_right,
  )
}

///|
fn render_middle_border(table : Table, widths : Array[Int]) -> String {
  let pieces = table_border(table.border)
  render_border_line(
    table,
    widths,
    pieces.middle_left,
    pieces.middle,
    pieces.middle_right,
  )
}

///|
fn render_bottom_border(table : Table, widths : Array[Int]) -> String {
  let pieces = table_border(table.border)
  render_border_line(
    table,
    widths,
    pieces.bottom_left,
    pieces.middle_bottom,
    pieces.bottom_right,
  )
}

///|
fn fit_line_to_width(line : String, width : Int) -> String {
  // `@pippa.truncate` is grapheme-aware, so under-width wide glyphs are
  // dropped whole instead of split across terminal cells.
  if width <= 0 {
    ""
  } else {
    @pippa.pad_right(@pippa.truncate(line, width), width)
  }
}

///|
fn fit_block_to_width(block : String, width : Int) -> String {
  let rows : Array[String] = []
  for line in @pippa.split_lines(block) {
    rows.push(fit_line_to_width(line, width))
  }
  @internal.join_lines(rows)
}

///|
fn table_write_chars(
  buf : StringBuilder,
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> Unit {
  for i in start..<end_index {
    buf.write_char(chars[i])
  }
}

///|
fn table_chars_to_string(
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> String {
  let n = chars.length()
  let from = start.max(0).min(n)
  let to = end_index.max(from).min(n)
  let buf = StringBuilder::new(size_hint=to - from)
  table_write_chars(buf, chars, from, to)
  buf.to_string()
}

///|
fn table_is_csi_terminator(ch : Char) -> Bool {
  ch >= '@' && ch <= '~'
}

///|
fn table_skip_ansi_sequence(chars : Array[Char], start : Int) -> Int {
  let n = chars.length()
  let mut i = start + 1
  if i < n {
    let next = chars[i]
    i = i + 1
    if next == '[' {
      while i < n && !table_is_csi_terminator(chars[i]) {
        i = i + 1
      }
      if i < n {
        i = i + 1
      }
    }
  }
  i
}

///|
fn table_is_sgr_sequence(
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> Bool {
  end_index >= start + 3 &&
  chars[start] == '\u001b' &&
  chars[start + 1] == '[' &&
  chars[end_index - 1] == 'm'
}

///|
fn table_is_sgr_reset_sequence(
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> Bool {
  if !table_is_sgr_sequence(chars, start, end_index) {
    return false
  }
  if end_index == start + 3 {
    return true
  }
  let mut value = 0
  let mut saw_digit = false
  for i in (start + 2)..<(end_index - 1) {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      value = value * 10 + ch.to_int() - '0'.to_int()
      saw_digit = true
    } else if ch == ';' {
      value = 0
      saw_digit = false
    } else {
      return false
    }
  }
  !saw_digit || value == 0
}

///|
fn table_sgr_state_after_range(
  chars : Array[Char],
  start : Int,
  end_index : Int,
  state : String,
) -> String {
  let limit = end_index.max(0).min(chars.length())
  let mut active = state
  let mut i = start.max(0).min(limit)
  while i < limit {
    if chars[i] == '\u001b' {
      let seq_start = i
      let next = table_skip_ansi_sequence(chars, i).min(limit)
      if table_is_sgr_sequence(chars, seq_start, next) {
        if table_is_sgr_reset_sequence(chars, seq_start, next) {
          active = ""
        } else {
          active = active + table_chars_to_string(chars, seq_start, next)
        }
      }
      i = next
    } else {
      i = i + 1
    }
  }
  active
}

///|
fn table_write_first_sgr_reset_after(
  buf : StringBuilder,
  chars : Array[Char],
  from : Int,
) -> Bool {
  let n = chars.length()
  let mut i = from.max(0).min(n)
  while i < n {
    if chars[i] == '\u001b' {
      let start = i
      let next = table_skip_ansi_sequence(chars, i)
      if table_is_sgr_reset_sequence(chars, start, next) {
        table_write_chars(buf, chars, start, next)
        return true
      }
      i = next
    } else {
      i = i + 1
    }
  }
  false
}

///|
fn table_close_sgr_state(
  buf : StringBuilder,
  chars : Array[Char],
  from : Int,
  state : String,
) -> Unit {
  if state != "" && !table_write_first_sgr_reset_after(buf, chars, from) {
    buf.write_string(@pippa.reset())
  }
}

///|
fn table_visible_cell_slice(
  s : String,
  start_cell : Int,
  width : Int,
) -> (String, Int) {
  if width <= 0 {
    return ("", 0)
  }
  let start = start_cell.max(0)
  let chars = s.to_array()
  let boundaries = @internal.grapheme_boundaries(s)
  let buf = StringBuilder::new(size_hint=chars.length())
  let mut cell = 0
  let mut used = 0
  let mut consumed = 0
  let mut active_style = ""
  let mut emitted_style = ""
  let mut slice_started = false
  for i in 0..<(boundaries.length() - 1) {
    if used >= width {
      table_close_sgr_state(buf, chars, boundaries[i], emitted_style)
      return (buf.to_string(), consumed)
    }
    let cluster = table_chars_to_string(chars, boundaries[i], boundaries[i + 1])
    let cluster_width = @pippa.visible_width(cluster)
    if cell + cluster_width <= start {
      active_style = table_sgr_state_after_range(
        chars,
        boundaries[i],
        boundaries[i + 1],
        active_style,
      )
      cell = cell + cluster_width
    } else if used + cluster_width <= width || used == 0 {
      if !slice_started {
        if active_style != "" {
          buf.write_string(active_style)
          emitted_style = active_style
        }
        slice_started = true
      }
      table_write_chars(buf, chars, boundaries[i], boundaries[i + 1])
      emitted_style = table_sgr_state_after_range(
        chars,
        boundaries[i],
        boundaries[i + 1],
        emitted_style,
      )
      used = used + cluster_width
      consumed = consumed + cluster_width
      cell = cell + cluster_width
    } else {
      table_close_sgr_state(buf, chars, boundaries[i], emitted_style)
      return (buf.to_string(), consumed)
    }
  }
  table_close_sgr_state(buf, chars, chars.length(), emitted_style)
  (buf.to_string(), consumed)
}

///|
fn wrap_line(line : String, width : Int) -> Array[String] {
  if width <= 0 {
    return [""]
  }
  let visible = @pippa.visible_width(line)
  if visible == 0 {
    return [line]
  }
  let segments : Array[String] = []
  let mut start = 0
  while start < visible {
    let (segment, consumed) = table_visible_cell_slice(line, start, width)
    segments.push(segment)
    let step = if consumed > 0 { consumed } else { width }
    start = start + step
  }
  segments
}

///|
fn wrapped_content_lines(content : String, width : Int) -> Array[String] {
  let rows : Array[String] = []
  for line in @pippa.split_lines(content) {
    for segment in wrap_line(line, width) {
      rows.push(segment)
    }
  }
  rows
}

///|
fn unwrapped_content_lines(content : String, width : Int) -> Array[String] {
  let rows : Array[String] = []
  for line in @pippa.split_lines(content) {
    rows.push(@pippa.truncate(line, width))
  }
  rows
}

///|
fn cell_line_style(
  style : @pippa.Style,
  content_width : Int,
  line_index : Int,
  line_count : Int,
) -> @pippa.Style {
  let base = if style.width > 0 { style } else { style.width(content_width) }
  if line_count <= 1 {
    return base
  }
  {
    ..base,
    padding_top: if line_index == 0 {
      base.padding_top
    } else {
      0
    },
    padding_bottom: if line_index == line_count - 1 {
      base.padding_bottom
    } else {
      0
    },
    margin_top: if line_index == 0 {
      base.margin_top
    } else {
      0
    },
    margin_bottom: if line_index == line_count - 1 {
      base.margin_bottom
    } else {
      0
    },
  }
}

///|
fn render_cell(
  table : Table,
  style : @pippa.Style,
  value : String,
  width : Int,
) -> String {
  let content_width = (width - style_horizontal_frame(style)).max(0)
  let content_lines = if content_width == 0 {
    [""]
  } else if table.wrap {
    wrapped_content_lines(value, content_width)
  } else {
    unwrapped_content_lines(value, content_width)
  }
  let rendered_lines : Array[String] = []
  for i, line in content_lines {
    rendered_lines.push(
      cell_line_style(style, content_width, i, content_lines.length()).render(
        line,
      ),
    )
  }
  let rendered = @internal.join_lines(rendered_lines)
  fit_block_to_width(rendered, width)
}

///|
fn blank_cell(width : Int) -> String {
  String::make(width.max(0), ' ')
}

///|
fn render_row(
  table : Table,
  row_index : Int,
  cells : Array[String],
  widths : Array[Int],
) -> String {
  let pieces = table_border(table.border)
  let cell_lines : Array[Array[String]] = []
  let mut height = 1
  for col in 0..<widths.length() {
    let block = render_cell(
      table,
      style_for(table, row_index, col),
      cell_at(cells, col),
      widths[col],
    )
    let lines = @pippa.split_lines(block)
    if lines.length() > height {
      height = lines.length()
    }
    cell_lines.push(lines)
  }
  let rows : Array[String] = []
  for line_index in 0..<height {
    let buf = StringBuilder::new()
    if table.border_left {
      buf.write_string(styled_border(table, pieces.vertical))
    }
    for col in 0..<widths.length() {
      let lines = cell_lines[col]
      if line_index < lines.length() {
        buf.write_string(fit_line_to_width(lines[line_index], widths[col]))
      } else {
        buf.write_string(blank_cell(widths[col]))
      }
      if col < widths.length() - 1 && table.border_column {
        buf.write_string(styled_border(table, pieces.vertical))
      }
    }
    if table.border_right {
      buf.write_string(styled_border(table, pieces.vertical))
    }
    rows.push(buf.to_string())
  }
  @internal.join_lines(rows)
}

///|
fn block_height(block : String) -> Int {
  if block == "" {
    0
  } else {
    @pippa.split_lines(block).length()
  }
}

///|
fn blocks_height(blocks : Array[String]) -> Int {
  let mut height = 0
  for block in blocks {
    height = height + block_height(block)
  }
  height
}

///|
fn can_fit_blocks(
  table : Table,
  blocks : Array[String],
  candidate : String,
  reserved_bottom : Int,
) -> Bool {
  table.height <= 0 ||
  blocks_height(blocks) + block_height(candidate) + reserved_bottom <=
  table.height
}

///|
fn maybe_push_block(
  table : Table,
  blocks : Array[String],
  block : String,
  reserved_bottom : Int,
) -> Bool {
  if can_fit_blocks(table, blocks, block, reserved_bottom) {
    blocks.push(block)
    true
  } else {
    false
  }
}

///|
fn bottom_reservation(table : Table) -> Int {
  if table.border_bottom {
    1
  } else {
    0
  }
}

///|
pub fn Table::render(self : Table) -> String {
  let count = column_count(self)
  if count == 0 {
    return ""
  }
  let fixed_widths = fixed_widths(self, count)
  let widths = resize_widths(
    self,
    natural_widths(self, count, fixed_widths),
    fixed_widths,
  )
  let rows : Array[String] = []
  let reserved_bottom = bottom_reservation(self)
  if self.border_top {
    ignore(
      maybe_push_block(
        self,
        rows,
        render_top_border(self, widths),
        reserved_bottom,
      ),
    )
  }
  if !self.headers.is_empty() {
    let header = render_row(self, HEADER_ROW, self.headers, widths)
    ignore(maybe_push_block(self, rows, header, reserved_bottom))
    if self.border_header {
      ignore(
        maybe_push_block(
          self,
          rows,
          render_middle_border(self, widths),
          reserved_bottom,
        ),
      )
    }
  }
  for row_index in 0..<self.rows.length() {
    let row = render_row(self, row_index, self.rows[row_index], widths)
    if !maybe_push_block(self, rows, row, reserved_bottom) {
      break
    }
    if self.border_row && row_index < self.rows.length() - 1 {
      ignore(
        maybe_push_block(
          self,
          rows,
          render_middle_border(self, widths),
          reserved_bottom,
        ),
      )
    }
  }
  if self.border_bottom {
    let bottom = render_bottom_border(self, widths)
    if self.height <= 0 || blocks_height(rows) < self.height {
      rows.push(bottom)
    } else if rows.is_empty() && self.height > 0 {
      rows.push(bottom)
    }
  }
  @internal.join_lines(rows)
}

///|
pub fn Table::to_string(self : Table) -> String {
  self.render()
}
