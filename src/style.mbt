///|
/// Border characters used to render a box around styled content.
pub(all) struct Border {
  top_left : String
  top_right : String
  bottom_left : String
  bottom_right : String
  horizontal : String
  vertical : String
} derive(Debug, Eq)

///|
/// Horizontal alignment within a styled width.
pub(all) enum Align {
  Left
  Center
  Right
} derive(Debug, Eq)

///|
/// Rich color representation used by the styling APIs.
pub(all) enum Color {
  Ansi(Int)
  RGB(Int, Int, Int)
  Hex(String)
} derive(Debug, Eq)

///|
/// Vertical alignment for layout helpers.
pub(all) enum VerticalAlign {
  Top
  Middle
  Bottom
} derive(Debug, Eq)

///|
/// A composable style description for terminal strings.
pub(all) struct Style {
  fg : Int?
  bg : Int?
  fg_ext : Color?
  bg_ext : Color?
  border_fg : Color?
  border_bg : Color?
  bold : Bool
  dim : Bool
  italic : Bool
  underline : Bool
  blink : Bool
  reverse : Bool
  border : Border?
  border_top : Bool
  border_right : Bool
  border_bottom : Bool
  border_left : Bool
  padding_top : Int
  padding_bottom : Int
  padding_left : Int
  padding_right : Int
  margin_top : Int
  margin_bottom : Int
  margin_left : Int
  margin_right : Int
  width : Int
  height : Int?
  min_width : Int
  min_height : Int
  max_width : Int?
  max_height : Int?
  align : Align
} derive(Debug, Eq)

///|
pub fn border_normal() -> Border {
  {
    top_left: "┌",
    top_right: "┐",
    bottom_left: "└",
    bottom_right: "┘",
    horizontal: "─",
    vertical: "│",
  }
}

///|
pub fn border_rounded() -> Border {
  {
    top_left: "╭",
    top_right: "╮",
    bottom_left: "╰",
    bottom_right: "╯",
    horizontal: "─",
    vertical: "│",
  }
}

///|
pub fn border_thick() -> Border {
  {
    top_left: "┏",
    top_right: "┓",
    bottom_left: "┗",
    bottom_right: "┛",
    horizontal: "━",
    vertical: "┃",
  }
}

///|
pub fn border_double() -> Border {
  {
    top_left: "╔",
    top_right: "╗",
    bottom_left: "╚",
    bottom_right: "╝",
    horizontal: "═",
    vertical: "║",
  }
}

///|
pub fn border_ascii() -> Border {
  {
    top_left: "+",
    top_right: "+",
    bottom_left: "+",
    bottom_right: "+",
    horizontal: "-",
    vertical: "|",
  }
}

///|
pub fn color_ansi(n : Int) -> Color {
  Ansi(@internal.clamp_non_negative(n))
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
    fg_ext: None,
    bg_ext: None,
    border_fg: None,
    border_bg: None,
    bold: false,
    dim: false,
    italic: false,
    underline: false,
    blink: false,
    reverse: false,
    border: None,
    border_top: true,
    border_right: true,
    border_bottom: true,
    border_left: true,
    padding_top: 0,
    padding_bottom: 0,
    padding_left: 0,
    padding_right: 0,
    margin_top: 0,
    margin_bottom: 0,
    margin_left: 0,
    margin_right: 0,
    width: 0,
    height: None,
    min_width: 0,
    min_height: 0,
    max_width: None,
    max_height: None,
    align: Left,
  }
}

///|
pub fn Style::fg_color(self : Style, n : Int) -> Style {
  let color = color_ansi(n)
  { ..self, fg: Some(@internal.clamp_non_negative(n)), fg_ext: Some(color) }
}

///|
pub fn Style::bg_color(self : Style, n : Int) -> Style {
  let color = color_ansi(n)
  { ..self, bg: Some(@internal.clamp_non_negative(n)), bg_ext: Some(color) }
}

///|
pub fn Style::foreground(self : Style, color : Color) -> Style {
  {
    ..self,
    fg_ext: Some(color),
    fg: match color {
      Ansi(n) => Some(@internal.clamp_non_negative(n))
      _ => None
    },
  }
}

///|
pub fn Style::background(self : Style, color : Color) -> Style {
  {
    ..self,
    bg_ext: Some(color),
    bg: match color {
      Ansi(n) => Some(@internal.clamp_non_negative(n))
      _ => None
    },
  }
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
pub fn Style::border_foreground(self : Style, color : Color) -> Style {
  { ..self, border_fg: Some(color) }
}

///|
pub fn Style::border_background(self : Style, color : Color) -> Style {
  { ..self, border_bg: Some(color) }
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
pub fn Style::border(self : Style, b : Border) -> Style {
  { ..self, border: Some(b) }
}

///|
pub fn Style::border_sides(
  self : Style,
  top : Bool,
  right : Bool,
  bottom : Bool,
  left : Bool,
) -> Style {
  {
    ..self,
    border_top: top,
    border_right: right,
    border_bottom: bottom,
    border_left: left,
  }
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
    padding_top: @internal.clamp_non_negative(top),
    padding_right: @internal.clamp_non_negative(right),
    padding_bottom: @internal.clamp_non_negative(bottom),
    padding_left: @internal.clamp_non_negative(left),
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
    margin_top: @internal.clamp_non_negative(top),
    margin_right: @internal.clamp_non_negative(right),
    margin_bottom: @internal.clamp_non_negative(bottom),
    margin_left: @internal.clamp_non_negative(left),
  }
}

///|
pub fn Style::width(self : Style, w : Int) -> Style {
  { ..self, width: @internal.clamp_non_negative(w) }
}

///|
pub fn Style::height(self : Style, h : Int) -> Style {
  { ..self, height: Some(@internal.clamp_non_negative(h)) }
}

///|
pub fn Style::min_width(self : Style, width : Int) -> Style {
  { ..self, min_width: @internal.clamp_non_negative(width) }
}

///|
pub fn Style::min_height(self : Style, height : Int) -> Style {
  { ..self, min_height: @internal.clamp_non_negative(height) }
}

///|
pub fn Style::max_width(self : Style, width : Int) -> Style {
  { ..self, max_width: Some(@internal.clamp_non_negative(width)) }
}

///|
pub fn Style::max_height(self : Style, height : Int) -> Style {
  { ..self, max_height: Some(@internal.clamp_non_negative(height)) }
}

///|
pub fn Style::align(self : Style, a : Align) -> Style {
  { ..self, align: a }
}

///|
pub fn Style::render(self : Style, content : String) -> String {
  let effective_style = {
    ..self,
    fg: self.fg.map(@internal.clamp_non_negative),
    bg: self.bg.map(@internal.clamp_non_negative),
    padding_top: @internal.clamp_non_negative(self.padding_top),
    padding_bottom: @internal.clamp_non_negative(self.padding_bottom),
    padding_left: @internal.clamp_non_negative(self.padding_left),
    padding_right: @internal.clamp_non_negative(self.padding_right),
    margin_top: @internal.clamp_non_negative(self.margin_top),
    margin_bottom: @internal.clamp_non_negative(self.margin_bottom),
    margin_left: @internal.clamp_non_negative(self.margin_left),
    margin_right: @internal.clamp_non_negative(self.margin_right),
    width: @internal.clamp_non_negative(self.width),
    height: self.height.map(@internal.clamp_non_negative),
    min_width: @internal.clamp_non_negative(self.min_width),
    min_height: @internal.clamp_non_negative(self.min_height),
    max_width: self.max_width.map(@internal.clamp_non_negative),
    max_height: self.max_height.map(@internal.clamp_non_negative),
  }
  let content_lines = split_lines(content)
  let target_width = resolve_width(effective_style, content_lines)
  let base_lines = shape_content_lines(
    content_lines,
    target_width,
    effective_style.align,
  )
  let target_height = resolve_height(effective_style, base_lines.length())
  let height_fitted = fit_height(base_lines, target_width, target_height)
  let padded = apply_padding(height_fitted, effective_style)
  let bordered = match effective_style.border {
    Some(border) =>
      render_border_block(
        border,
        padded,
        @internal.max_visible_width(padded, visible_width),
        effective_style,
      )
    None => @internal.join_lines(padded)
  }
  let margined = apply_margin(
    bordered,
    effective_style.margin_top,
    effective_style.margin_right,
    effective_style.margin_bottom,
    effective_style.margin_left,
  )
  apply_style_prefix(effective_style, margined)
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
    let lines = split_lines(block)
    let width = @internal.max_visible_width(lines, visible_width)
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
        buf.write_string(fit_line_width(lines[row - top_pad], widths[i], Left))
      }
    }
    rows.push(buf.to_string())
  }
  @internal.join_lines(rows)
}

///|
pub fn join_vertical(blocks : Array[String], align? : Align = Left) -> String {
  if blocks.is_empty() {
    return ""
  }
  let split_blocks : Array[Array[String]] = []
  let mut max_width = 0
  for block in blocks {
    let lines = split_lines(block)
    let width = @internal.max_visible_width(lines, visible_width)
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
  @internal.join_lines(rows)
}

///|
pub fn place(
  width : Int,
  height : Int,
  content : String,
  align? : Align = Left,
  valign? : VerticalAlign = Top,
) -> String {
  let safe_width = @internal.clamp_non_negative(width)
  let safe_height = @internal.clamp_non_negative(height)
  let lines = split_lines(content)
  let trimmed : Array[String] = []
  for i in 0..<lines.length().min(safe_height) {
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
  for _ in rows.length()..<safe_height {
    rows.push(blank)
  }
  @internal.join_lines(rows)
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
fn effective_foreground(style : Style) -> Color? {
  match style.fg_ext {
    Some(color) => Some(color)
    None => style.fg.map(color_ansi)
  }
}

///|
fn effective_background(style : Style) -> Color? {
  match style.bg_ext {
    Some(color) => Some(color)
    None => style.bg.map(color_ansi)
  }
}

///|
fn resolve_width(style : Style, lines : Array[String]) -> Int {
  let natural = @internal.max_visible_width(lines, visible_width)
  let from_width = if style.width > 0 { style.width } else { natural }
  let with_min = from_width.max(style.min_width)
  match style.max_width {
    Some(max_width) => with_min.min(max_width)
    None => with_min
  }
}

///|
fn resolve_height(style : Style, line_count : Int) -> Int {
  let from_height = match style.height {
    Some(height) => height
    None => line_count
  }
  let with_min = from_height.max(style.min_height)
  match style.max_height {
    Some(max_height) => with_min.min(max_height)
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
  let truncated = truncate(line, target_width)
  let width = visible_width(truncated)
  if width >= target_width {
    truncated
  } else {
    match align {
      Left => pad_right(truncated, target_width)
      Center => center(truncated, target_width)
      Right => pad_left(truncated, target_width)
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
  for i in 0..<lines.length().min(target_height) {
    fitted.push(lines[i])
  }
  let blank = String::make(target_width, ' ')
  for _ in fitted.length()..<target_height {
    fitted.push(blank)
  }
  fitted
}

///|
fn apply_padding(lines : Array[String], self : Style) -> Array[String] {
  let padded : Array[String] = []
  let inner_width = @internal.max_visible_width(lines, visible_width)
  let row_width = inner_width + self.padding_left + self.padding_right
  let blank = String::make(row_width, ' ')
  for _ in 0..<self.padding_top {
    padded.push(blank)
  }
  for line in lines {
    let fitted = if visible_width(line) < inner_width {
      pad_right(line, inner_width)
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
  let lines = split_lines(block)
  let inner_width = @internal.max_visible_width(lines, visible_width)
  let full_width = inner_width + left + right
  let blank = String::make(full_width, ' ')
  let rows : Array[String] = []
  for _ in 0..<top {
    rows.push(blank)
  }
  for line in lines {
    let fitted = if visible_width(line) < inner_width {
      pad_right(line, inner_width)
    } else {
      line
    }
    rows.push(String::make(left, ' ') + fitted + String::make(right, ' '))
  }
  for _ in 0..<bottom {
    rows.push(blank)
  }
  @internal.join_lines(rows)
}

///|
fn render_border_block(
  border : Border,
  lines : Array[String],
  inner_width : Int,
  style : Style,
) -> String {
  if style.border_fg is None && style.border_bg is None {
    return @internal.render_border(
      border.top_left,
      border.top_right,
      border.bottom_left,
      border.bottom_right,
      border.horizontal,
      border.vertical,
      lines,
      inner_width,
      visible_width,
      style.border_top,
      style.border_right,
      style.border_bottom,
      style.border_left,
    )
  }
  let top_left = @internal.normalize_border_piece(
    border.top_left,
    visible_width,
  )
  let top_right = @internal.normalize_border_piece(
    border.top_right,
    visible_width,
  )
  let bottom_left = @internal.normalize_border_piece(
    border.bottom_left,
    visible_width,
  )
  let bottom_right = @internal.normalize_border_piece(
    border.bottom_right,
    visible_width,
  )
  let horizontal_piece = @internal.normalize_border_piece(
    border.horizontal,
    visible_width,
  )
  let vertical_piece = @internal.normalize_border_piece(
    border.vertical,
    visible_width,
  )
  let horizontal = @internal.repeat_string(horizontal_piece, inner_width)
  let rows : Array[String] = []
  let border_prefix = build_border_ansi_prefix(style)
  let content_prefix = build_ansi_prefix(style)
  if style.border_top {
    rows.push(
      decorate_segment(
        border_prefix,
        (if style.border_left { top_left } else { "" }) +
        horizontal +
        (if style.border_right { top_right } else { "" }),
      ),
    )
  }
  for line in lines {
    rows.push(
      decorate_segment(
        border_prefix,
        if style.border_left {
          vertical_piece
        } else {
          ""
        },
      ) +
      decorate_segment(content_prefix, line) +
      decorate_segment(
        border_prefix,
        if style.border_right {
          vertical_piece
        } else {
          ""
        },
      ),
    )
  }
  if style.border_bottom {
    rows.push(
      decorate_segment(
        border_prefix,
        (if style.border_left { bottom_left } else { "" }) +
        horizontal +
        (if style.border_right { bottom_right } else { "" }),
      ),
    )
  }
  @internal.join_lines(rows)
}

///|
fn decorate_segment(prefix : String, segment : String) -> String {
  if prefix == "" || segment == "" {
    segment
  } else {
    prefix + segment + reset()
  }
}

///|
fn build_border_ansi_prefix(style : Style) -> String {
  build_ansi_prefix_with_colors(
    style,
    match style.border_fg {
      Some(color) => Some(color)
      None => effective_foreground(style)
    },
    match style.border_bg {
      Some(color) => Some(color)
      None => effective_background(style)
    },
  )
}

///|
fn apply_style_prefix(style : Style, block : String) -> String {
  if style.border is Some(_) &&
    (style.border_fg is Some(_) || style.border_bg is Some(_)) {
    return block
  }
  let prefix = build_ansi_prefix(style)
  if prefix == "" {
    block
  } else {
    prefix + block + reset()
  }
}

///|
fn build_ansi_prefix(style : Style) -> String {
  build_ansi_prefix_with_colors(
    style,
    effective_foreground(style),
    effective_background(style),
  )
}

///|
fn build_ansi_prefix_with_colors(
  style : Style,
  fg : Color?,
  bg : Color?,
) -> String {
  let buf = StringBuilder::new()
  fg.iter().each(fn(color) { buf.write_string(foreground_sequence(color)) })
  bg.iter().each(fn(color) { buf.write_string(background_sequence(color)) })
  if style.bold {
    buf.write_string(bold())
  }
  if style.dim {
    buf.write_string(dim())
  }
  if style.italic {
    buf.write_string("\{CSI}3m")
  }
  if style.underline {
    buf.write_string(underline())
  }
  if style.blink {
    buf.write_string(blink())
  }
  if style.reverse {
    buf.write_string(reverse())
  }
  buf.to_string()
}

///|
fn foreground_sequence(color : Color) -> String {
  match color {
    Ansi(n) => fg_color(@internal.clamp_non_negative(n))
    RGB(r, g, b) => fg_rgb(clamp_channel(r), clamp_channel(g), clamp_channel(b))
    Hex(hex) =>
      match hex_to_rgb(hex) {
        Some((r, g, b)) => fg_rgb(r, g, b)
        None => ""
      }
  }
}

///|
fn background_sequence(color : Color) -> String {
  match color {
    Ansi(n) => bg_color(@internal.clamp_non_negative(n))
    RGB(r, g, b) => bg_rgb(clamp_channel(r), clamp_channel(g), clamp_channel(b))
    Hex(hex) =>
      match hex_to_rgb(hex) {
        Some((r, g, b)) => bg_rgb(r, g, b)
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
      let r = try? @string.parse_uint(parts[0:2], base=16)
      let g = try? @string.parse_uint(parts[2:4], base=16)
      let b = try? @string.parse_uint(parts[4:6], base=16)
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
