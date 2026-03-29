///|
/// Border characters used to render a box around styled content.
pub(all) struct Border {
  top_left : String
  top_right : String
  bottom_left : String
  bottom_right : String
  horizontal : String
  vertical : String
} derive(Show, Eq)

///|
/// Horizontal alignment within a styled width.
pub(all) enum Align {
  Left
  Center
  Right
} derive(Show, Eq)

///|
/// A composable style description for terminal strings.
pub(all) struct Style {
  fg : Int?
  bg : Int?
  bold : Bool
  dim : Bool
  underline : Bool
  border : Border?
  padding_top : Int
  padding_bottom : Int
  padding_left : Int
  padding_right : Int
  width : Int
  align : Align
} derive(Show, Eq)

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
pub fn style() -> Style {
  {
    fg: None,
    bg: None,
    bold: false,
    dim: false,
    underline: false,
    border: None,
    padding_top: 0,
    padding_bottom: 0,
    padding_left: 0,
    padding_right: 0,
    width: 0,
    align: Left,
  }
}

///|
pub fn Style::fg_color(self : Style, n : Int) -> Style {
  { ..self, fg: Some(n) }
}

///|
pub fn Style::bg_color(self : Style, n : Int) -> Style {
  { ..self, bg: Some(n) }
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
pub fn Style::underline(self : Style) -> Style {
  { ..self, underline: true }
}

///|
pub fn Style::border(self : Style, b : Border) -> Style {
  { ..self, border: Some(b) }
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
pub fn Style::width(self : Style, w : Int) -> Style {
  { ..self, width: clamp_non_negative(w) }
}

///|
pub fn Style::align(self : Style, a : Align) -> Style {
  { ..self, align: a }
}

///|
pub fn Style::render(self : Style, content : String) -> String {
  let effective_style = {
    ..self,
    padding_top: clamp_non_negative(self.padding_top),
    padding_bottom: clamp_non_negative(self.padding_bottom),
    padding_left: clamp_non_negative(self.padding_left),
    padding_right: clamp_non_negative(self.padding_right),
    width: clamp_non_negative(self.width),
  }
  let content_lines = split_lines(content)
  let normalize = effective_style.width > 0 ||
    effective_style.padding_top > 0 ||
    effective_style.padding_bottom > 0 ||
    effective_style.padding_left > 0 ||
    effective_style.padding_right > 0 ||
    (match effective_style.border {
      Some(_) => true
      None => false
    })

  let content_width = if effective_style.width > 0 {
    effective_style.width
  } else if normalize {
    max_visible_width(content_lines)
  } else {
    0
  }

  let lines : Array[String] = []
  for line in content_lines {
    let prepared = if normalize {
      align_line(
        truncate(line, content_width),
        content_width,
        effective_style.align,
      )
    } else {
      line
    }
    lines.push(
      String::make(effective_style.padding_left, ' ') +
      prepared +
      String::make(effective_style.padding_right, ' '),
    )
  }

  let inner_width = max_visible_width(lines)
  let padded_lines : Array[String] = []
  let empty_line = String::make(inner_width, ' ')
  let mut top_padding = 0
  while top_padding < effective_style.padding_top {
    padded_lines.push(empty_line)
    top_padding = top_padding + 1
  }
  for line in lines {
    padded_lines.push(
      if normalize && visible_width(line) < inner_width {
        pad_right(line, inner_width)
      } else {
        line
      },
    )
  }
  let mut bottom_padding = 0
  while bottom_padding < effective_style.padding_bottom {
    padded_lines.push(empty_line)
    bottom_padding = bottom_padding + 1
  }

  let block = match effective_style.border {
    Some(border) => render_border(border, padded_lines, inner_width)
    None => join_lines(padded_lines)
  }

  let prefix = build_ansi_prefix(effective_style)
  if prefix.length() == 0 {
    block
  } else {
    prefix + block + reset()
  }
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
fn max_visible_width(lines : Array[String]) -> Int {
  let mut max_width = 0
  for line in lines {
    let width = visible_width(line)
    if width > max_width {
      max_width = width
    }
  }
  max_width
}

///|
fn align_line(line : String, width : Int, align : Align) -> String {
  match align {
    Left => pad_right(line, width)
    Center => center(line, width)
    Right => pad_left(line, width)
  }
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
  let mut i = 0
  while i < count {
    buf.write_string(s)
    i = i + 1
  }
  buf.to_string()
}

///|
fn render_border(
  border : Border,
  lines : Array[String],
  inner_width : Int,
) -> String {
  let top_left = normalize_border_piece(border.top_left)
  let top_right = normalize_border_piece(border.top_right)
  let bottom_left = normalize_border_piece(border.bottom_left)
  let bottom_right = normalize_border_piece(border.bottom_right)
  let horizontal_piece = normalize_border_piece(border.horizontal)
  let vertical_piece = normalize_border_piece(border.vertical)
  let buf = StringBuilder::new()
  let horizontal = repeat_string(horizontal_piece, inner_width)
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
  if visible_width(piece) == 1 {
    piece
  } else {
    "*"
  }
}

///|
fn build_ansi_prefix(style : Style) -> String {
  let buf = StringBuilder::new()
  match style.fg {
    Some(n) => buf.write_string(fg_color(n))
    None => ()
  }
  match style.bg {
    Some(n) => buf.write_string(bg_color(n))
    None => ()
  }
  if style.bold {
    buf.write_string(bold())
  }
  if style.dim {
    buf.write_string(dim())
  }
  if style.underline {
    buf.write_string(underline())
  }
  buf.to_string()
}
