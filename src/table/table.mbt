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
pub fn Table::width(self : Table, width : Int) -> Table {
  { ..self, width: @internal.clamp_non_negative(width) }
}

///|
pub fn Table::height(self : Table, height : Int) -> Table {
  { ..self, height: @internal.clamp_non_negative(height) }
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
fn natural_widths(table : Table, count : Int) -> Array[Int] {
  let widths : Array[Int] = []
  for col in 0..<count {
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
fn index_of_shortest_resizable(widths : Array[Int]) -> Int {
  let mut index = 0
  let mut value = 0x7FFFFFFF
  for i, width in widths {
    if width < value {
      value = width
      index = i
    }
  }
  index
}

///|
fn index_of_largest_resizable(widths : Array[Int]) -> Int {
  let mut index = -1
  let mut value = -1
  for i, width in widths {
    if width > value && width > 0 {
      value = width
      index = i
    }
  }
  index
}

///|
fn resize_widths(table : Table, widths : Array[Int]) -> Array[Int] {
  let resized = widths.copy()
  if table.width <= 0 || resized.is_empty() {
    return resized
  }
  let available = (table.width -
  horizontal_border_width(table, resized.length())).max(0)
  while sum_widths(resized) < available {
    let index = index_of_shortest_resizable(resized)
    resized[index] = resized[index] + 1
  }
  while sum_widths(resized) > available {
    let index = index_of_largest_resizable(resized)
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
fn render_cell(style : @pippa.Style, value : String, width : Int) -> String {
  let content_width = (width - style_horizontal_frame(style)).max(0)
  let content = if content_width == 0 { "" } else { value }
  let rendered = style.width(content_width).render(content)
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
fn fit_table_height(table : Table, block : String) -> String {
  if table.height <= 0 {
    return block
  }
  let lines = @pippa.split_lines(block)
  if lines.length() <= table.height {
    return block
  }
  let out : Array[String] = []
  for i in 0..<table.height {
    out.push(lines[i])
  }
  @internal.join_lines(out)
}

///|
pub fn Table::render(self : Table) -> String {
  let count = column_count(self)
  if count == 0 {
    return ""
  }
  let widths = resize_widths(self, natural_widths(self, count))
  let rows : Array[String] = []
  if self.border_top {
    rows.push(render_top_border(self, widths))
  }
  if !self.headers.is_empty() {
    rows.push(render_row(self, HEADER_ROW, self.headers, widths))
    if self.border_header {
      rows.push(render_middle_border(self, widths))
    }
  }
  for row_index in 0..<self.rows.length() {
    rows.push(render_row(self, row_index, self.rows[row_index], widths))
    if self.border_row && row_index < self.rows.length() - 1 {
      rows.push(render_middle_border(self, widths))
    }
  }
  if self.border_bottom {
    rows.push(render_bottom_border(self, widths))
  }
  fit_table_height(self, @internal.join_lines(rows))
}

///|
pub fn Table::to_string(self : Table) -> String {
  self.render()
}
