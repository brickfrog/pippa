///|
/// A richer styling and layout layer for Pippa.

///|
pub(all) enum Color {
  Ansi(Int)
  RGB(Int, Int, Int)
  Hex(String)
} derive(Show, Eq)

///|
pub(all) enum Align {
  Left
  Center
  Right
} derive(Show, Eq)

///|
pub(all) enum VerticalAlign {
  Top
  Middle
  Bottom
} derive(Show, Eq)

///|
pub(all) struct Style {
  fg : Color?
  bg : Color?
  bold : Bool
  dim : Bool
  italic : Bool
  underline : Bool
  blink : Bool
  reverse : Bool
  border : @pippa.Border?
  padding_top : Int
  padding_bottom : Int
  padding_left : Int
  padding_right : Int
  margin_top : Int
  margin_bottom : Int
  margin_left : Int
  margin_right : Int
  width : Int?
  height : Int?
  min_width : Int
  min_height : Int
  max_width : Int?
  max_height : Int?
  align : Align
} derive(Show, Eq)

///|
pub fn border_normal() -> @pippa.Border {
  @pippa.border_normal()
}

///|
pub fn border_rounded() -> @pippa.Border {
  @pippa.border_rounded()
}

///|
pub fn border_thick() -> @pippa.Border {
  @pippa.border_thick()
}

///|
pub fn border_double() -> @pippa.Border {
  @pippa.border_double()
}

///|
pub fn border_ascii() -> @pippa.Border {
  @pippa.border_ascii()
}

///|
pub fn color_ansi(n : Int) -> Color {
  Ansi(n)
}

///|
pub fn color_rgb(r : Int, g : Int, b : Int) -> Color {
  RGB(clamp_channel(r), clamp_channel(g), clamp_channel(b))
}

///|
pub fn color_hex(hex : String) -> Color {
  Hex(hex)
}

///|
pub fn style() -> Style {
  {
    fg: None,
    bg: None,
    bold: false,
    dim: false,
    italic: false,
    underline: false,
    blink: false,
    reverse: false,
    border: None,
    padding_top: 0,
    padding_bottom: 0,
    padding_left: 0,
    padding_right: 0,
    margin_top: 0,
    margin_bottom: 0,
    margin_left: 0,
    margin_right: 0,
    width: None,
    height: None,
    min_width: 0,
    min_height: 0,
    max_width: None,
    max_height: None,
    align: Left,
  }
}

///|
pub fn Style::foreground(self : Style, color : Color) -> Style {
  { ..self, fg: Some(color) }
}

///|
pub fn Style::background(self : Style, color : Color) -> Style {
  { ..self, bg: Some(color) }
}

///|
pub fn Style::foreground_rgb(self : Style, r : Int, g : Int, b : Int) -> Style {
  self.foreground(color_rgb(r, g, b))
}

///|
pub fn Style::background_rgb(self : Style, r : Int, g : Int, b : Int) -> Style {
  self.background(color_rgb(r, g, b))
}

///|
pub fn Style::foreground_hex(self : Style, hex : String) -> Style {
  self.foreground(color_hex(hex))
}

///|
pub fn Style::background_hex(self : Style, hex : String) -> Style {
  self.background(color_hex(hex))
}

///|
pub fn Style::bold(self : Style) -> Style {
  { ..self, bold: true }
}

///|
pub fn Style::dim(self : Style) -> Style {
  { ..self, dim: true }
}

///|
pub fn Style::italic(self : Style) -> Style {
  { ..self, italic: true }
}

///|
pub fn Style::underline(self : Style) -> Style {
  { ..self, underline: true }
}

///|
pub fn Style::blink(self : Style) -> Style {
  { ..self, blink: true }
}

///|
pub fn Style::reverse(self : Style) -> Style {
  { ..self, reverse: true }
}

///|
pub fn Style::border(self : Style, border : @pippa.Border) -> Style {
  { ..self, border: Some(border) }
}

///|
pub fn Style::padding(
  self : Style,
  top : Int,
  right : Int,
  bottom : Int,
  left : Int,
) -> Style {
  {
    ..self,
    padding_top: clamp_non_negative(top),
    padding_right: clamp_non_negative(right),
    padding_bottom: clamp_non_negative(bottom),
    padding_left: clamp_non_negative(left),
  }
}

///|
pub fn Style::margin(
  self : Style,
  top : Int,
  right : Int,
  bottom : Int,
  left : Int,
) -> Style {
  {
    ..self,
    margin_top: clamp_non_negative(top),
    margin_right: clamp_non_negative(right),
    margin_bottom: clamp_non_negative(bottom),
    margin_left: clamp_non_negative(left),
  }
}

///|
pub fn Style::width(self : Style, width : Int) -> Style {
  { ..self, width: Some(clamp_non_negative(width)) }
}

///|
pub fn Style::height(self : Style, height : Int) -> Style {
  { ..self, height: Some(clamp_non_negative(height)) }
}

///|
pub fn Style::min_width(self : Style, width : Int) -> Style {
  { ..self, min_width: clamp_non_negative(width) }
}

///|
pub fn Style::min_height(self : Style, height : Int) -> Style {
  { ..self, min_height: clamp_non_negative(height) }
}

///|
pub fn Style::max_width(self : Style, width : Int) -> Style {
  { ..self, max_width: Some(clamp_non_negative(width)) }
}

///|
pub fn Style::max_height(self : Style, height : Int) -> Style {
  { ..self, max_height: Some(clamp_non_negative(height)) }
}

///|
pub fn Style::align(self : Style, align : Align) -> Style {
  { ..self, align, }
}

///|
pub fn Style::render(self : Style, content : String) -> String {
  let content_lines = @pippa.split_lines(content)
  let target_width = resolve_width(self, content_lines)
  let base_lines = shape_content_lines(content_lines, target_width, self.align)
  let target_height = resolve_height(self, base_lines.length())
  let height_fitted = fit_height(base_lines, target_width, target_height)
  let padded = apply_padding(height_fitted, self)
  let bordered = match self.border {
    Some(border) => render_border(border, padded, max_visible_width(padded))
    None => join_lines(padded)
  }
  let margined = apply_margin(
    bordered,
    self.margin_top,
    self.margin_right,
    self.margin_bottom,
    self.margin_left,
  )
  let prefix = build_ansi_prefix(self)
  if prefix == "" {
    margined
  } else {
    prefix + margined + @pippa.reset()
  }
}

///|
pub fn join_horizontal(
  blocks : Array[String],
  valign? : VerticalAlign = Top,
) -> String {
  if blocks.is_empty() {
    return ""
  }
  let split_blocks : Array[Array[String]] = []
  let widths : Array[Int] = []
  let heights : Array[Int] = []
  let mut max_height = 0
  for block in blocks {
    let lines = @pippa.split_lines(block)
    let width = max_visible_width(lines)
    split_blocks.push(lines)
    widths.push(width)
    heights.push(lines.length())
    if lines.length() > max_height {
      max_height = lines.length()
    }
  }
  let rows : Array[String] = []
  for row in 0..<max_height {
    let buf = StringBuilder::new()
    for i in 0..<split_blocks.length() {
      let lines = split_blocks[i]
      let top_pad = vertical_offset(max_height, heights[i], valign)
      if row < top_pad || row >= top_pad + heights[i] {
        buf.write_string(String::make(widths[i], ' '))
      } else {
        let line = lines[row - top_pad]
        buf.write_string(fit_line_width(line, widths[i], Left))
      }
    }
    rows.push(buf.to_string())
  }
  join_lines(rows)
}

///|
pub fn join_vertical(blocks : Array[String], align? : Align = Left) -> String {
  if blocks.is_empty() {
    return ""
  }
  let split_blocks : Array[Array[String]] = []
  let mut max_width = 0
  for block in blocks {
    let lines = @pippa.split_lines(block)
    let width = max_visible_width(lines)
    if width > max_width {
      max_width = width
    }
    split_blocks.push(lines)
  }
  let rows : Array[String] = []
  for block_lines in split_blocks {
    for line in block_lines {
      rows.push(fit_line_width(line, max_width, align))
    }
  }
  join_lines(rows)
}

///|
pub fn place(
  width : Int,
  height : Int,
  content : String,
  align? : Align = Left,
  valign? : VerticalAlign = Top,
) -> String {
  let safe_width = clamp_non_negative(width)
  let safe_height = clamp_non_negative(height)
  let lines = @pippa.split_lines(content)
  let trimmed : Array[String] = []
  for i in 0..<min_int(lines.length(), safe_height) {
    trimmed.push(fit_line_width(lines[i], safe_width, align))
  }
  let top_pad = vertical_offset(safe_height, trimmed.length(), valign)
  let rows : Array[String] = []
  let blank = String::make(safe_width, ' ')
  for _ in 0..<top_pad {
    rows.push(blank)
  }
  for line in trimmed {
    rows.push(line)
  }
  while rows.length() < safe_height {
    rows.push(blank)
  }
  join_lines(rows)
}

///|
fn clamp_non_negative(n : Int) -> Int {
  if n < 0 {
    0
  } else {
    n
  }
}

///|
fn clamp_channel(n : Int) -> Int {
  if n < 0 {
    0
  } else if n > 255 {
    255
  } else {
    n
  }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn resolve_width(style : Style, lines : Array[String]) -> Int {
  let natural = max_visible_width(lines)
  let from_width = match style.width {
    Some(width) => width
    None => natural
  }
  let with_min = max_int(from_width, style.min_width)
  match style.max_width {
    Some(max_width) => min_int(with_min, max_width)
    None => with_min
  }
}

///|
fn resolve_height(style : Style, line_count : Int) -> Int {
  let from_height = match style.height {
    Some(height) => height
    None => line_count
  }
  let with_min = max_int(from_height, style.min_height)
  match style.max_height {
    Some(max_height) => min_int(with_min, max_height)
    None => with_min
  }
}

///|
fn shape_content_lines(
  lines : Array[String],
  target_width : Int,
  align : Align,
) -> Array[String] {
  let shaped : Array[String] = []
  for line in lines {
    shaped.push(fit_line_width(line, target_width, align))
  }
  shaped
}

///|
fn fit_line_width(line : String, target_width : Int, align : Align) -> String {
  let truncated = @pippa.truncate(line, target_width)
  let width = @pippa.visible_width(truncated)
  if width >= target_width {
    truncated
  } else {
    match align {
      Left => @pippa.pad_right(truncated, target_width)
      Center => @pippa.center(truncated, target_width)
      Right => @pippa.pad_left(truncated, target_width)
    }
  }
}

///|
fn fit_height(
  lines : Array[String],
  target_width : Int,
  target_height : Int,
) -> Array[String] {
  let fitted : Array[String] = []
  for i in 0..<min_int(lines.length(), target_height) {
    fitted.push(lines[i])
  }
  let blank = String::make(target_width, ' ')
  while fitted.length() < target_height {
    fitted.push(blank)
  }
  fitted
}

///|
fn apply_padding(lines : Array[String], self : Style) -> Array[String] {
  let padded : Array[String] = []
  let inner_width = max_visible_width(lines)
  let row_width = inner_width + self.padding_left + self.padding_right
  let blank = String::make(row_width, ' ')
  for _ in 0..<self.padding_top {
    padded.push(blank)
  }
  for line in lines {
    let fitted = if @pippa.visible_width(line) < inner_width {
      @pippa.pad_right(line, inner_width)
    } else {
      line
    }
    padded.push(
      String::make(self.padding_left, ' ') +
      fitted +
      String::make(self.padding_right, ' '),
    )
  }
  for _ in 0..<self.padding_bottom {
    padded.push(blank)
  }
  padded
}

///|
fn apply_margin(
  block : String,
  top : Int,
  right : Int,
  bottom : Int,
  left : Int,
) -> String {
  if top == 0 && right == 0 && bottom == 0 && left == 0 {
    return block
  }
  let lines = @pippa.split_lines(block)
  let inner_width = max_visible_width(lines)
  let full_width = inner_width + left + right
  let blank = String::make(full_width, ' ')
  let rows : Array[String] = []
  for _ in 0..<top {
    rows.push(blank)
  }
  for line in lines {
    let fitted = if @pippa.visible_width(line) < inner_width {
      @pippa.pad_right(line, inner_width)
    } else {
      line
    }
    rows.push(String::make(left, ' ') + fitted + String::make(right, ' '))
  }
  for _ in 0..<bottom {
    rows.push(blank)
  }
  join_lines(rows)
}

///|
fn max_visible_width(lines : Array[String]) -> Int {
  let mut max_width = 0
  for line in lines {
    let width = @pippa.visible_width(line)
    if width > max_width {
      max_width = width
    }
  }
  max_width
}

///|
fn join_lines(lines : Array[String]) -> String {
  let buf = StringBuilder::new()
  for i, line in lines {
    if i > 0 {
      buf.write_string("\n")
    }
    buf.write_string(line)
  }
  buf.to_string()
}

///|
fn repeat_string(s : String, count : Int) -> String {
  let buf = StringBuilder::new()
  for _ in 0..<count {
    buf.write_string(s)
  }
  buf.to_string()
}

///|
fn render_border(
  border : @pippa.Border,
  lines : Array[String],
  inner_width : Int,
) -> String {
  let top_left = normalize_border_piece(border.top_left)
  let top_right = normalize_border_piece(border.top_right)
  let bottom_left = normalize_border_piece(border.bottom_left)
  let bottom_right = normalize_border_piece(border.bottom_right)
  let horizontal_piece = normalize_border_piece(border.horizontal)
  let vertical_piece = normalize_border_piece(border.vertical)
  let horizontal = repeat_string(horizontal_piece, inner_width)
  let buf = StringBuilder::new()
  buf.write_string(top_left)
  buf.write_string(horizontal)
  buf.write_string(top_right)
  for line in lines {
    buf.write_string("\n")
    buf.write_string(vertical_piece)
    buf.write_string(line)
    buf.write_string(vertical_piece)
  }
  buf.write_string("\n")
  buf.write_string(bottom_left)
  buf.write_string(horizontal)
  buf.write_string(bottom_right)
  buf.to_string()
}

///|
fn normalize_border_piece(piece : String) -> String {
  if @pippa.visible_width(piece) == 1 {
    piece
  } else {
    "*"
  }
}

///|
fn build_ansi_prefix(style : Style) -> String {
  let buf = StringBuilder::new()
  match style.fg {
    Some(color) => buf.write_string(foreground_sequence(color))
    None => ()
  }
  match style.bg {
    Some(color) => buf.write_string(background_sequence(color))
    None => ()
  }
  if style.bold {
    buf.write_string(@pippa.bold())
  }
  if style.dim {
    buf.write_string(@pippa.dim())
  }
  if style.italic {
    buf.write_string("\{@pippa.CSI}3m")
  }
  if style.underline {
    buf.write_string(@pippa.underline())
  }
  if style.blink {
    buf.write_string(@pippa.blink())
  }
  if style.reverse {
    buf.write_string(@pippa.reverse())
  }
  buf.to_string()
}

///|
fn foreground_sequence(color : Color) -> String {
  match color {
    Ansi(n) => @pippa.fg_color(clamp_non_negative(n))
    RGB(r, g, b) =>
      @pippa.fg_rgb(clamp_channel(r), clamp_channel(g), clamp_channel(b))
    Hex(hex) =>
      match hex_to_rgb(hex) {
        Some((r, g, b)) => @pippa.fg_rgb(r, g, b)
        None => ""
      }
  }
}

///|
fn background_sequence(color : Color) -> String {
  match color {
    Ansi(n) => @pippa.bg_color(clamp_non_negative(n))
    RGB(r, g, b) =>
      @pippa.bg_rgb(clamp_channel(r), clamp_channel(g), clamp_channel(b))
    Hex(hex) =>
      match hex_to_rgb(hex) {
        Some((r, g, b)) => @pippa.bg_rgb(r, g, b)
        None => ""
      }
  }
}

///|
fn hex_to_rgb(hex : String) -> (Int, Int, Int)? {
  let view = if hex.length() > 0 && hex[0] == '#' { hex[:][1:] } else { hex[:] }
  let normalized = if view.length() == 3 {
    let buf = StringBuilder::new(size_hint=6)
    for ch in view.iter() {
      buf.write_char(ch)
      buf.write_char(ch)
    }
    Some(buf.to_string())
  } else if view.length() == 6 {
    Some(view.to_string())
  } else {
    None
  }
  match normalized {
    Some(value) => {
      let parts = value[:]
      let r = try? @strconv.parse_uint(parts[0:2], base=16)
      let g = try? @strconv.parse_uint(parts[2:4], base=16)
      let b = try? @strconv.parse_uint(parts[4:6], base=16)
      match (r, g, b) {
        (Ok(rv), Ok(gv), Ok(bv)) =>
          Some(
            (
              rv.reinterpret_as_int(),
              gv.reinterpret_as_int(),
              bv.reinterpret_as_int(),
            ),
          )
        _ => None
      }
    }
    None => None
  }
}

///|
fn vertical_offset(
  container : Int,
  content : Int,
  align : VerticalAlign,
) -> Int {
  if content >= container {
    return 0
  }
  match align {
    Top => 0
    Middle => (container - content) / 2
    Bottom => container - content
  }
}
