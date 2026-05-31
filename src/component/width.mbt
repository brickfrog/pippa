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
fn component_write_chars(
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
fn component_char_slice_from_chars(
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> String {
  let n = chars.length()
  let from = start.max(0).min(n)
  let to = end_index.max(from).min(n)
  let buf = StringBuilder::new(size_hint=to - from)
  component_write_chars(buf, chars, from, to)
  buf.to_string()
}

///|
fn component_char_slice(s : String, start : Int, end_index : Int) -> String {
  component_char_slice_from_chars(s.to_array(), start, end_index)
}

///|
fn component_char_len(s : String) -> Int {
  s.to_array().length()
}

///|
fn component_is_csi_terminator(ch : Char) -> Bool {
  ch >= '@' && ch <= '~'
}

///|
fn component_skip_ansi_sequence(chars : Array[Char], start : Int) -> Int {
  let n = chars.length()
  let mut i = start + 1
  if i < n {
    let next = chars[i]
    i = i + 1
    if next == '[' {
      while i < n && !component_is_csi_terminator(chars[i]) {
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
fn component_is_sgr_reset_sequence(
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> Bool {
  if !component_is_sgr_sequence(chars, start, end_index) {
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
fn component_is_sgr_sequence(
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
fn component_sgr_state_after_range(
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
      let next = component_skip_ansi_sequence(chars, i).min(limit)
      if component_is_sgr_sequence(chars, seq_start, next) {
        if component_is_sgr_reset_sequence(chars, seq_start, next) {
          active = ""
        } else {
          active = active +
            component_char_slice_from_chars(chars, seq_start, next)
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
fn component_write_first_sgr_reset_after(
  buf : StringBuilder,
  chars : Array[Char],
  from : Int,
) -> Bool {
  let n = chars.length()
  let mut i = from.max(0).min(n)
  while i < n {
    if chars[i] == '\u001b' {
      let start = i
      let next = component_skip_ansi_sequence(chars, i)
      if component_is_sgr_reset_sequence(chars, start, next) {
        component_write_chars(buf, chars, start, next)
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
fn component_close_sgr_state(
  buf : StringBuilder,
  chars : Array[Char],
  from : Int,
  state : String,
) -> Unit {
  if state != "" && !component_write_first_sgr_reset_after(buf, chars, from) {
    buf.write_string("\u001b[0m")
  }
}

///|
fn component_grapheme_count(s : String) -> Int {
  @internal.grapheme_boundaries(s).length() - 1
}

///|
fn component_grapheme_boundaries(s : String) -> Array[Int] {
  @internal.grapheme_boundaries(s)
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
fn component_insert_string_at(
  s : String,
  cursor : Int,
  text : String,
) -> String {
  let chars = s.to_array()
  let text_chars = text.to_array()
  let n = chars.length()
  let pos = cursor.max(0).min(n)
  let out : Array[Char] = []
  for i in 0..<pos {
    out.push(chars[i])
  }
  for ch in text_chars {
    out.push(ch)
  }
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
fn component_prefix_display_width(s : String, cursor : Int) -> Int {
  @internal.display_width(component_char_slice(s, 0, cursor))
}

///|
fn component_cell_to_grapheme_boundary(s : String, target_cell : Int) -> Int {
  let target = target_cell.max(0)
  if target == 0 {
    return 0
  }
  let chars = s.to_array()
  let boundaries = @internal.grapheme_boundaries(s)
  let mut cell = 0
  for i in 0..<(boundaries.length() - 1) {
    let cluster = component_char_slice_from_chars(
      chars,
      boundaries[i],
      boundaries[i + 1],
    )
    let next_cell = cell + @internal.display_width(cluster)
    if target < next_cell {
      return boundaries[i]
    } else if target == next_cell {
      return boundaries[i + 1]
    }
    cell = next_cell
  }
  component_char_len(s)
}

///|
fn component_truncate_width(s : String, width : Int) -> String {
  if width <= 0 {
    return ""
  }
  let chars = s.to_array()
  let boundaries = @internal.grapheme_boundaries(s)
  let buf = StringBuilder::new(size_hint=chars.length())
  let mut used = 0
  let mut emitted_style = ""
  for i in 0..<(boundaries.length() - 1) {
    if used >= width {
      component_close_sgr_state(buf, chars, boundaries[i], emitted_style)
      return buf.to_string()
    }
    let cluster = component_char_slice_from_chars(
      chars,
      boundaries[i],
      boundaries[i + 1],
    )
    let cluster_width = @internal.display_width(cluster)
    if used + cluster_width > width {
      component_close_sgr_state(buf, chars, boundaries[i], emitted_style)
      return buf.to_string()
    }
    component_write_chars(buf, chars, boundaries[i], boundaries[i + 1])
    emitted_style = component_sgr_state_after_range(
      chars,
      boundaries[i],
      boundaries[i + 1],
      emitted_style,
    )
    used = used + cluster_width
  }
  component_close_sgr_state(buf, chars, chars.length(), emitted_style)
  buf.to_string()
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
    return component_truncate_width(s, width)
  }
  let chars = s.to_array()
  let boundaries = @internal.grapheme_boundaries(s)
  let buf = StringBuilder::new(size_hint=chars.length())
  let mut cell = 0
  let mut used = 0
  let mut active_style = ""
  let mut emitted_style = ""
  let mut slice_started = false
  for i in 0..<(boundaries.length() - 1) {
    if used >= width {
      component_close_sgr_state(buf, chars, boundaries[i], emitted_style)
      return buf.to_string()
    }
    let cluster = component_char_slice_from_chars(
      chars,
      boundaries[i],
      boundaries[i + 1],
    )
    let cluster_width = @internal.display_width(cluster)
    if cell + cluster_width <= start {
      active_style = component_sgr_state_after_range(
        chars,
        boundaries[i],
        boundaries[i + 1],
        active_style,
      )
      cell = cell + cluster_width
    } else if cell < start {
      if !slice_started {
        if active_style != "" {
          buf.write_string(active_style)
          emitted_style = active_style
        }
        slice_started = true
      }
      let visible_tail = cluster_width - (start - cell)
      let spaces = visible_tail.min(width - used)
      for _ in 0..<spaces {
        buf.write_char(' ')
      }
      used = used + spaces
      cell = cell + cluster_width
    } else if used + cluster_width <= width {
      if !slice_started {
        if active_style != "" {
          buf.write_string(active_style)
          emitted_style = active_style
        }
        slice_started = true
      }
      component_write_chars(buf, chars, boundaries[i], boundaries[i + 1])
      emitted_style = component_sgr_state_after_range(
        chars,
        boundaries[i],
        boundaries[i + 1],
        emitted_style,
      )
      used = used + cluster_width
      cell = cell + cluster_width
    } else {
      component_close_sgr_state(buf, chars, boundaries[i], emitted_style)
      return buf.to_string()
    }
  }
  component_close_sgr_state(buf, chars, chars.length(), emitted_style)
  buf.to_string()
}

///|
fn component_fit_width(s : String, width : Int) -> String {
  @internal.pad_right_width(component_truncate_width(s, width), width)
}
