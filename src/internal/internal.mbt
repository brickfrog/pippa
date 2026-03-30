///|
/// Internal shared string and border rendering helpers used across packages.

///|
pub fn clamp_non_negative(n : Int) -> Int {
  n.max(0)
}

///|
pub fn max_visible_width(
  lines : Array[String],
  width_of : (String) -> Int,
) -> Int {
  let mut max_width = 0
  for line in lines {
    let width = width_of(line)
    if width > max_width {
      max_width = width
    }
  }
  max_width
}

///|
pub fn join_lines(lines : Array[String]) -> String {
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
pub fn repeat_string(s : String, count : Int) -> String {
  let buf = StringBuilder::new()
  for _ in 0..<count {
    buf.write_string(s)
  }
  buf.to_string()
}

///|
pub fn normalize_border_piece(
  piece : String,
  width_of : (String) -> Int,
) -> String {
  if width_of(piece) == 1 {
    piece
  } else {
    "*"
  }
}

///|
pub fn render_border(
  top_left : String,
  top_right : String,
  bottom_left : String,
  bottom_right : String,
  horizontal_piece : String,
  vertical_piece : String,
  lines : Array[String],
  inner_width : Int,
  width_of : (String) -> Int,
  top : Bool,
  right : Bool,
  bottom : Bool,
  left : Bool,
) -> String {
  let safe_top_left = normalize_border_piece(top_left, width_of)
  let safe_top_right = normalize_border_piece(top_right, width_of)
  let safe_bottom_left = normalize_border_piece(bottom_left, width_of)
  let safe_bottom_right = normalize_border_piece(bottom_right, width_of)
  let safe_horizontal_piece = normalize_border_piece(horizontal_piece, width_of)
  let safe_vertical_piece = normalize_border_piece(vertical_piece, width_of)
  let horizontal = repeat_string(safe_horizontal_piece, inner_width)
  let rows : Array[String] = []
  if top {
    rows.push(
      (if left { safe_top_left } else { "" }) +
      horizontal +
      (if right { safe_top_right } else { "" }),
    )
  }
  for line in lines {
    rows.push(
      (if left { safe_vertical_piece } else { "" }) +
      line +
      (if right { safe_vertical_piece } else { "" }),
    )
  }
  if bottom {
    rows.push(
      (if left { safe_bottom_left } else { "" }) +
      horizontal +
      (if right { safe_bottom_right } else { "" }),
    )
  }
  join_lines(rows)
}
