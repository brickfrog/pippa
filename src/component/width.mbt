///|
/// Shared width helpers for components that keep cursor positions as character
/// offsets but must render and move by grapheme/display-cell boundaries.

///|
fn component_chars_to_string(chars : Array[Char]) -> String {
  let buf = StringBuilder::new(size_hint=chars.length() + 4)
  for ch in chars {
    buf.write_char(ch)
  }
  buf.to_string()
}

///|
fn component_char_slice(s : String, start : Int, end_index : Int) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let from = start.max(0).min(n)
  let to = end_index.max(from).min(n)
  let out : Array[Char] = []
  for i in from..<to {
    out.push(chars[i])
  }
  component_chars_to_string(out)
}

///|
fn component_char_len(s : String) -> Int {
  s.to_array().length()
}

///|
fn component_grapheme_count(s : String) -> Int {
  let mut count = 0
  let mut cluster = @internal.grapheme_slice(s, count, count + 1)
  while cluster != "" {
    count = count + 1
    cluster = @internal.grapheme_slice(s, count, count + 1)
  }
  count
}

///|
fn component_grapheme_boundaries(s : String) -> Array[Int] {
  let boundaries : Array[Int] = [0]
  let mut chars = 0
  let mut index = 0
  let mut cluster = @internal.grapheme_slice(s, index, index + 1)
  while cluster != "" {
    chars = chars + component_char_len(cluster)
    boundaries.push(chars)
    index = index + 1
    cluster = @internal.grapheme_slice(s, index, index + 1)
  }
  boundaries
}

///|
fn component_is_grapheme_boundary(s : String, cursor : Int) -> Bool {
  let pos = cursor.max(0).min(component_char_len(s))
  for boundary in component_grapheme_boundaries(s) {
    if boundary == pos {
      return true
    }
  }
  false
}

///|
fn component_previous_grapheme_boundary(s : String, cursor : Int) -> Int {
  let pos = cursor.max(0).min(component_char_len(s))
  let mut previous = 0
  for boundary in component_grapheme_boundaries(s) {
    if boundary < pos {
      previous = boundary
    } else {
      return previous
    }
  }
  previous
}

///|
fn component_next_grapheme_boundary(s : String, cursor : Int) -> Int {
  let pos = cursor.max(0).min(component_char_len(s))
  let end = component_char_len(s)
  for boundary in component_grapheme_boundaries(s) {
    if boundary > pos {
      return boundary
    }
  }
  end
}

///|
fn component_clamp_grapheme_boundary(s : String, cursor : Int) -> Int {
  let pos = cursor.max(0).min(component_char_len(s))
  let mut previous = 0
  for boundary in component_grapheme_boundaries(s) {
    if boundary == pos {
      return pos
    } else if boundary > pos {
      return previous
    }
    previous = boundary
  }
  previous
}

///|
fn component_insert_char_at(s : String, cursor : Int, ch : Char) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let pos = cursor.max(0).min(n)
  let out : Array[Char] = []
  for i in 0..<pos {
    out.push(chars[i])
  }
  out.push(ch)
  for i in pos..<n {
    out.push(chars[i])
  }
  component_chars_to_string(out)
}

///|
fn component_remove_char_range(
  s : String,
  start : Int,
  end_index : Int,
) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let from = start.max(0).min(n)
  let to = end_index.max(from).min(n)
  let out : Array[Char] = []
  for i in 0..<from {
    out.push(chars[i])
  }
  for i in to..<n {
    out.push(chars[i])
  }
  component_chars_to_string(out)
}

///|
fn component_without_last_grapheme(s : String) -> String {
  let count = component_grapheme_count(s)
  if count <= 0 {
    ""
  } else {
    @internal.grapheme_slice(s, 0, count - 1)
  }
}

///|
fn component_prefix_display_width(s : String, cursor : Int) -> Int {
  @internal.display_width(component_char_slice(s, 0, cursor))
}

///|
fn component_visible_cell_slice(
  s : String,
  start_cell : Int,
  width : Int,
) -> String {
  if width <= 0 {
    return ""
  }
  let start = start_cell.max(0)
  if start == 0 {
    return @internal.truncate_width(s, width)
  }
  let buf = StringBuilder::new(size_hint=component_char_len(s))
  let mut cell = 0
  let mut used = 0
  let mut index = 0
  let mut cluster = @internal.grapheme_slice(s, index, index + 1)
  while cluster != "" && used < width {
    let cluster_width = @internal.display_width(cluster)
    if cell + cluster_width <= start {
      cell = cell + cluster_width
    } else if cell < start {
      cell = cell + cluster_width
    } else if used + cluster_width <= width {
      buf.write_string(cluster)
      used = used + cluster_width
      cell = cell + cluster_width
    } else {
      return buf.to_string()
    }
    index = index + 1
    cluster = @internal.grapheme_slice(s, index, index + 1)
  }
  buf.to_string()
}

///|
fn component_fit_width(s : String, width : Int) -> String {
  @internal.pad_right_width(@internal.truncate_width(s, width), width)
}
