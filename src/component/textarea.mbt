///|
/// Textarea component — a multiline editable text field with scrolling.

///|
/// State of a multiline text input field.
pub(all) struct TextareaModel {
  /// Full text content.
  value : String
  /// Cursor row in logical lines.
  cursor_row : Int
  /// Cursor column in the current logical line.
  cursor_col : Int
  /// Visible width in cells.
  width : Int
  /// Visible height in rows.
  height : Int
  /// Minimum dynamic height in visual rows.
  min_height : Int
  /// Maximum dynamic height in visual rows.
  max_height : Int
  /// Vertical scroll offset in visual rows.
  scroll_row : Int
  /// Horizontal scroll offset in columns.
  scroll_col : Int
  /// Cursor row in the wrapped visual-row stream.
  cursor_visual_row : Int
  /// Prefix rendered before each visual row.
  prompt : String
  /// Whether to render a line-number gutter.
  line_numbers : Bool
  /// Optional maximum value length measured in grapheme clusters.
  char_limit : Int?
  /// Optional maximum number of logical lines.
  line_limit : Int?
  /// Hint text shown when the field is empty and unfocused.
  placeholder : String
  /// Whether the field currently has keyboard focus.
  focused : Bool
  /// Whether input messages should be ignored and the cursor hidden.
  disabled : Bool
} derive(Debug, Eq)

///|
/// Messages that drive a `TextareaModel`.
pub(all) enum TextareaMsg {
  InsertChar(Char)
  InsertText(String)
  InsertNewline
  DeleteBefore
  DeleteAfter
  MoveCursorLeft
  MoveCursorRight
  MoveCursorUp
  MoveCursorDown
  MoveToLineStart
  MoveToLineEnd
  MoveToTop
  MoveToBottom
  PageUp
  PageDown
  SetValue(String)
  Resize(Int, Int)
  Focus
  Blur
} derive(Debug, Eq)

///|
fn textarea_lines(value : String) -> Array[String] {
  @pippa.split_lines(value)
}

///|
fn textarea_chars_to_string(chars : Array[Char]) -> String {
  let buf = StringBuilder::new(size_hint=chars.length() + 4)
  for ch in chars {
    buf.write_char(ch)
  }
  buf.to_string()
}

///|
fn textarea_lines_to_string(lines : Array[String]) -> String {
  lines.join("\n")
}

///|
fn textarea_clamp(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
priv struct TextareaVisualRow {
  logical_row : Int
  start_col : Int
  end_col : Int
  start_cell : Int
  width : Int
  continuation : Bool
}

///|
fn textarea_digits(value : Int) -> Int {
  let mut n = value.max(1)
  let mut digits = 1
  while n >= 10 {
    n = n / 10
    digits = digits + 1
  }
  digits
}

///|
fn textarea_line_count(value : String) -> Int {
  @pippa.line_count(value)
}

///|
fn textarea_line_number_gutter_width(
  line_count : Int,
  line_numbers : Bool,
) -> Int {
  if line_numbers {
    textarea_digits(line_count) + 1
  } else {
    0
  }
}

///|
fn textarea_prompt_width(prompt : String) -> Int {
  @internal.display_width(prompt)
}

///|
fn textarea_content_width(
  width : Int,
  prompt : String,
  line_numbers : Bool,
  line_count : Int,
) -> Int {
  if width <= 0 {
    0
  } else {
    (width -
    textarea_line_number_gutter_width(line_count, line_numbers) -
    textarea_prompt_width(prompt)).max(1)
  }
}

///|
fn textarea_line_len(lines : Array[String], row : Int) -> Int {
  lines[row].to_array().length()
}

///|
fn textarea_cluster_first_text_char(cluster : String) -> Char? {
  let chars = cluster.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\u001b' {
      i = component_skip_ansi_sequence(chars, i)
    } else {
      return Some(chars[i])
    }
  }
  None
}

///|
fn textarea_is_whitespace_char(ch : Char) -> Bool {
  let code = ch.to_int()
  ch == ' ' ||
  ch == '\t' ||
  ch == '\n' ||
  ch == '\r' ||
  code == 0x00A0 ||
  code == 0x1680 ||
  (code >= 0x2000 && code <= 0x200A) ||
  code == 0x2028 ||
  code == 0x2029 ||
  code == 0x202F ||
  code == 0x205F ||
  code == 0x3000
}

///|
fn textarea_is_whitespace_cluster(cluster : String) -> Bool {
  match textarea_cluster_first_text_char(cluster) {
    Some(ch) => textarea_is_whitespace_char(ch)
    None => false
  }
}

///|
fn textarea_cluster_slice(
  chars : Array[Char],
  boundaries : Array[Int],
  index : Int,
) -> String {
  component_char_slice_from_chars(
    chars,
    boundaries[index],
    boundaries[index + 1],
  )
}

///|
fn textarea_word_width_from(
  chars : Array[Char],
  boundaries : Array[Int],
  index : Int,
) -> Int {
  let count = boundaries.length() - 1
  let mut i = index
  let mut width = 0
  while i < count {
    let cluster = textarea_cluster_slice(chars, boundaries, i)
    if textarea_is_whitespace_cluster(cluster) {
      return width
    }
    width = width + @internal.display_width(cluster)
    i = i + 1
  }
  width
}

///|
fn textarea_wrap_end_index(
  chars : Array[Char],
  boundaries : Array[Int],
  start_index : Int,
  width : Int,
) -> Int {
  let count = boundaries.length() - 1
  if width <= 0 || start_index >= count {
    return start_index
  }
  let mut index = start_index
  let mut used = 0
  let mut last_break = start_index
  while index < count {
    let cluster = textarea_cluster_slice(chars, boundaries, index)
    let cluster_width = @internal.display_width(cluster)
    if used > 0 &&
      last_break > start_index &&
      !textarea_is_whitespace_cluster(cluster) &&
      used + textarea_word_width_from(chars, boundaries, index) > width {
      return last_break
    }
    if used > 0 && used + cluster_width > width {
      if last_break > start_index {
        return last_break
      }
      return index
    }
    if used == 0 && cluster_width > width {
      return index + 1
    }
    used = used + cluster_width
    index = index + 1
    if textarea_is_whitespace_cluster(cluster) {
      last_break = index
    }
  }
  count
}

///|
fn textarea_visual_rows_for_line(
  line : String,
  logical_row : Int,
  width : Int,
) -> Array[TextareaVisualRow] {
  let chars = line.to_array()
  let boundaries = component_grapheme_boundaries(line)
  let count = boundaries.length() - 1
  let rows : Array[TextareaVisualRow] = []
  if count == 0 || width <= 0 {
    rows.push({
      logical_row,
      start_col: 0,
      end_col: component_char_len(line),
      start_cell: 0,
      width: @internal.display_width(line),
      continuation: false,
    })
    return rows
  }
  let mut start_index = 0
  let mut continuation = false
  while start_index < count {
    let mut end_index = textarea_wrap_end_index(
      chars, boundaries, start_index, width,
    )
    if end_index <= start_index {
      end_index = start_index + 1
    }
    let start_col = boundaries[start_index]
    let end_col = boundaries[end_index]
    let start_cell = component_prefix_display_width(line, start_col)
    let row_width = (component_prefix_display_width(line, end_col) - start_cell).max(
      0,
    )
    rows.push({
      logical_row,
      start_col,
      end_col,
      start_cell,
      width: row_width,
      continuation,
    })
    continuation = true
    start_index = end_index
  }
  rows
}

///|
fn textarea_visual_rows(
  lines : Array[String],
  content_width : Int,
) -> Array[TextareaVisualRow] {
  let rows : Array[TextareaVisualRow] = []
  for row, line in lines {
    let line_rows = textarea_visual_rows_for_line(line, row, content_width)
    for visual in line_rows {
      rows.push(visual)
    }
  }
  rows
}

///|
fn textarea_visual_row_index_for_cursor(
  rows : Array[TextareaVisualRow],
  row : Int,
  col : Int,
) -> Int {
  let mut fallback = 0
  for i, visual in rows {
    if visual.logical_row == row {
      fallback = i
      let final_visual_row = i + 1 >= rows.length() ||
        rows[i + 1].logical_row != row
      let contains_cursor = if final_visual_row {
        col >= visual.start_col && col <= visual.end_col
      } else {
        col >= visual.start_col && col < visual.end_col
      }
      if contains_cursor {
        return i
      }
    }
  }
  fallback
}

///|
fn textarea_cursor_cell_in_visual_row(
  lines : Array[String],
  visual : TextareaVisualRow,
  col : Int,
) -> Int {
  (component_prefix_display_width(lines[visual.logical_row], col) -
  visual.start_cell).max(0)
}

///|
fn textarea_normalize(
  value : String,
  cursor_row : Int,
  cursor_col : Int,
  width : Int,
  min_height : Int,
  max_height : Int,
  scroll_row : Int,
  _scroll_col : Int,
  prompt : String,
  line_numbers : Bool,
  char_limit : Int?,
  line_limit : Int?,
  placeholder : String,
  focused : Bool,
  disabled : Bool,
) -> TextareaModel {
  let lines = textarea_lines(value)
  let row = textarea_clamp(cursor_row, 0, lines.length() - 1)
  let raw_col = textarea_clamp(cursor_col, 0, textarea_line_len(lines, row))
  let col = component_clamp_grapheme_boundary(lines[row], raw_col)
  let safe_width = width.max(0)
  let safe_max_height = max_height.max(0)
  let safe_min_height = min_height.max(0).min(safe_max_height)
  let content_width = textarea_content_width(
    safe_width,
    prompt,
    line_numbers,
    lines.length(),
  )
  let visual_rows = textarea_visual_rows(lines, content_width)
  let visual_count = visual_rows.length().max(1)
  let safe_height = if safe_max_height == 0 {
    0
  } else {
    textarea_clamp(visual_count, safe_min_height, safe_max_height)
  }
  let cursor_visual_row = textarea_visual_row_index_for_cursor(
    visual_rows, row, col,
  )
  let mut next_scroll_row = scroll_row.max(0)

  if safe_height > 0 {
    if cursor_visual_row < next_scroll_row {
      next_scroll_row = cursor_visual_row
    } else if cursor_visual_row >= next_scroll_row + safe_height {
      next_scroll_row = cursor_visual_row - safe_height + 1
    }
    let max_scroll = (visual_count - safe_height).max(0)
    next_scroll_row = textarea_clamp(next_scroll_row, 0, max_scroll)
  } else {
    next_scroll_row = 0
  }

  {
    value,
    cursor_row: row,
    cursor_col: col,
    width: safe_width,
    height: safe_height,
    min_height: safe_min_height,
    max_height: safe_max_height,
    scroll_row: next_scroll_row,
    scroll_col: 0,
    cursor_visual_row,
    prompt,
    line_numbers,
    char_limit,
    line_limit,
    placeholder,
    focused,
    disabled,
  }
}

///|
fn textarea_insert_char(
  lines : Array[String],
  row : Int,
  col : Int,
  ch : Char,
) -> (Array[String], Int, Int) {
  let cursor = component_clamp_grapheme_boundary(lines[row], col)
  let next_line = component_insert_char_at(lines[row], cursor, ch)
  lines[row] = next_line
  (lines, row, component_next_grapheme_boundary(next_line, cursor))
}

///|
fn textarea_insert_text(
  lines : Array[String],
  row : Int,
  col : Int,
  text : String,
) -> (Array[String], Int, Int) {
  let parts = textarea_lines(text)
  let cursor = component_clamp_grapheme_boundary(lines[row], col)
  match parts {
    [] => (lines, row, col)
    [single] => {
      let single_chars = single.to_array()
      let base_chars = lines[row].to_array()
      let next_chars : Array[Char] = []
      for i in 0..<cursor {
        next_chars.push(base_chars[i])
      }
      for ch in single_chars {
        next_chars.push(ch)
      }
      for i in cursor..<base_chars.length() {
        next_chars.push(base_chars[i])
      }
      lines[row] = textarea_chars_to_string(next_chars)
      (lines, row, cursor + single_chars.length())
    }
    [first, .. rest] => {
      let base_chars = lines[row].to_array()
      let before_chars : Array[Char] = []
      let after_chars : Array[Char] = []
      for i in 0..<cursor {
        before_chars.push(base_chars[i])
      }
      for i in cursor..<base_chars.length() {
        after_chars.push(base_chars[i])
      }
      lines[row] = textarea_chars_to_string(
        [..before_chars, ..first.to_array()],
      )
      let tail_count = rest.length() - 1
      for i, part in rest {
        let insert_at = row + 1 + i
        let line = if i == tail_count {
          textarea_chars_to_string([..part.to_array(), ..after_chars])
        } else {
          part
        }
        lines.insert(insert_at, line)
      }
      let last = rest[tail_count]
      (lines, row + rest.length(), last.to_array().length())
    }
  }
}

///|
fn textarea_insert_newline(
  lines : Array[String],
  row : Int,
  col : Int,
) -> (Array[String], Int, Int) {
  let chars = lines[row].to_array()
  let cursor = component_clamp_grapheme_boundary(lines[row], col)
  let before_chars : Array[Char] = []
  let after_chars : Array[Char] = []
  for i in 0..<cursor {
    before_chars.push(chars[i])
  }
  for i in cursor..<chars.length() {
    after_chars.push(chars[i])
  }
  lines[row] = textarea_chars_to_string(before_chars)
  lines.insert(row + 1, textarea_chars_to_string(after_chars))
  (lines, row + 1, 0)
}

///|
fn textarea_absolute_cursor(lines : Array[String], row : Int, col : Int) -> Int {
  let mut offset = 0
  for i in 0..<row {
    offset = offset + component_char_len(lines[i]) + 1
  }
  offset + col
}

///|
fn textarea_value_within_limits(
  value : String,
  char_limit : Int?,
  line_limit : Int?,
) -> Bool {
  let char_ok = match char_limit {
    None => true
    Some(limit) => component_grapheme_count(value) <= limit.max(0)
  }
  let line_ok = match line_limit {
    None => true
    Some(limit) => textarea_line_count(value) <= limit.max(1)
  }
  char_ok && line_ok
}

///|
fn textarea_limit_value(
  value : String,
  char_limit : Int?,
  line_limit : Int?,
) -> String {
  if textarea_value_within_limits(value, char_limit, line_limit) {
    return value
  }
  let chars = value.to_array()
  let boundaries = component_grapheme_boundaries(value)
  let mut accepted = ""
  for i in 0..<(boundaries.length() - 1) {
    let cluster = component_char_slice_from_chars(
      chars,
      boundaries[i],
      boundaries[i + 1],
    )
    let candidate = accepted + cluster
    if textarea_value_within_limits(candidate, char_limit, line_limit) {
      accepted = candidate
    } else {
      return accepted
    }
  }
  accepted
}

///|
fn textarea_allowed_insert_text(
  model : TextareaModel,
  row : Int,
  col : Int,
  text : String,
) -> String {
  if model.char_limit is None && model.line_limit is None {
    return text
  }
  let lines = textarea_lines(model.value)
  let cursor = textarea_absolute_cursor(lines, row, col)
  let before = component_char_slice(model.value, 0, cursor)
  let after = component_char_slice(
    model.value,
    cursor,
    component_char_len(model.value),
  )
  let chars = text.to_array()
  let boundaries = component_grapheme_boundaries(text)
  let mut accepted = ""
  for i in 0..<(boundaries.length() - 1) {
    let cluster = component_char_slice_from_chars(
      chars,
      boundaries[i],
      boundaries[i + 1],
    )
    let candidate_insert = accepted + cluster
    let candidate = before + candidate_insert + after
    if textarea_value_within_limits(
        candidate,
        model.char_limit,
        model.line_limit,
      ) {
      accepted = candidate_insert
    } else {
      return accepted
    }
  }
  accepted
}

///|
fn textarea_delete_before(
  lines : Array[String],
  row : Int,
  col : Int,
) -> (Array[String], Int, Int) {
  let line = lines[row]
  let end = if component_is_grapheme_boundary(line, col) {
    textarea_clamp(col, 0, component_char_len(line))
  } else {
    component_next_grapheme_boundary(line, col)
  }
  if end > 0 {
    let start = component_previous_grapheme_boundary(line, end)
    lines[row] = component_remove_char_range(line, start, end)
    (lines, row, start)
  } else if row > 0 {
    let prev = lines[row - 1]
    let prev_len = prev.to_array().length()
    lines[row - 1] = prev + lines[row]
    ignore(lines.remove(row))
    (lines, row - 1, prev_len)
  } else {
    (lines, row, col)
  }
}

///|
fn textarea_delete_after(
  lines : Array[String],
  row : Int,
  col : Int,
) -> (Array[String], Int, Int) {
  let line = lines[row]
  let start = component_clamp_grapheme_boundary(line, col)
  if start < component_char_len(line) {
    let end = component_next_grapheme_boundary(line, start)
    lines[row] = component_remove_char_range(line, start, end)
    (lines, row, start)
  } else if row + 1 < lines.length() {
    lines[row] = lines[row] + lines[row + 1]
    ignore(lines.remove(row + 1))
    (lines, row, col)
  } else {
    (lines, row, col)
  }
}

///|
fn textarea_move_to_visual_row(
  model : TextareaModel,
  lines : Array[String],
  row : Int,
  col : Int,
  delta : Int,
) -> TextareaModel {
  let content_width = textarea_content_width(
    model.width,
    model.prompt,
    model.line_numbers,
    lines.length(),
  )
  let visual_rows = textarea_visual_rows(lines, content_width)
  if visual_rows.length() == 0 {
    return model
  }
  let source_col = component_clamp_grapheme_boundary(lines[row], col)
  let source_visual_index = textarea_visual_row_index_for_cursor(
    visual_rows, row, source_col,
  )
  let target_visual_index = textarea_clamp(
    source_visual_index + delta,
    0,
    visual_rows.length() - 1,
  )
  let source_visual = visual_rows[source_visual_index]
  let target_visual = visual_rows[target_visual_index]
  let source_cell = textarea_cursor_cell_in_visual_row(
    lines, source_visual, source_col,
  )
  let target_cell = target_visual.start_cell + source_cell
  let raw_target_col = component_cell_to_grapheme_boundary(
    lines[target_visual.logical_row],
    target_cell,
  )
  let target_col = textarea_clamp(
    raw_target_col,
    target_visual.start_col,
    target_visual.end_col,
  )
  textarea_normalize(
    model.value,
    target_visual.logical_row,
    target_col,
    model.width,
    model.min_height,
    model.max_height,
    model.scroll_row,
    model.scroll_col,
    model.prompt,
    model.line_numbers,
    model.char_limit,
    model.line_limit,
    model.placeholder,
    model.focused,
    model.disabled,
  )
}

///|
fn textarea_normalize_model(
  model : TextareaModel,
  value : String,
  row : Int,
  col : Int,
) -> TextareaModel {
  textarea_normalize(
    value,
    row,
    col,
    model.width,
    model.min_height,
    model.max_height,
    model.scroll_row,
    model.scroll_col,
    model.prompt,
    model.line_numbers,
    model.char_limit,
    model.line_limit,
    model.placeholder,
    model.focused,
    model.disabled,
  )
}

///|
fn textarea_update(
  model : TextareaModel,
  msg : TextareaMsg,
) -> @pippa.UpdateResult[TextareaModel, TextareaMsg] {
  if model.disabled {
    return @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
  }

  let lines = textarea_lines(model.value)
  let row = textarea_clamp(model.cursor_row, 0, lines.length() - 1)
  let col = textarea_clamp(model.cursor_col, 0, textarea_line_len(lines, row))

  let next_model = match msg {
    InsertChar(ch) => {
      let text = textarea_allowed_insert_text(
        model,
        row,
        col,
        String::make(1, ch),
      )
      if text == "" {
        model
      } else {
        let (next_lines, next_row, next_col) = textarea_insert_char(
          lines.copy(),
          row,
          col,
          ch,
        )
        textarea_normalize_model(
          model,
          textarea_lines_to_string(next_lines),
          next_row,
          next_col,
        )
      }
    }
    InsertText(text) => {
      let accepted = textarea_allowed_insert_text(model, row, col, text)
      if accepted == "" {
        model
      } else {
        let (next_lines, next_row, next_col) = textarea_insert_text(
          lines.copy(),
          row,
          col,
          accepted,
        )
        textarea_normalize_model(
          model,
          textarea_lines_to_string(next_lines),
          next_row,
          next_col,
        )
      }
    }
    InsertNewline => {
      let accepted = textarea_allowed_insert_text(model, row, col, "\n")
      if accepted == "" {
        model
      } else {
        let (next_lines, next_row, next_col) = textarea_insert_newline(
          lines.copy(),
          row,
          col,
        )
        textarea_normalize_model(
          model,
          textarea_lines_to_string(next_lines),
          next_row,
          next_col,
        )
      }
    }
    DeleteBefore => {
      let (next_lines, next_row, next_col) = textarea_delete_before(
        lines.copy(),
        row,
        col,
      )
      textarea_normalize_model(
        model,
        textarea_lines_to_string(next_lines),
        next_row,
        next_col,
      )
    }
    DeleteAfter => {
      let (next_lines, next_row, next_col) = textarea_delete_after(
        lines.copy(),
        row,
        col,
      )
      textarea_normalize_model(
        model,
        textarea_lines_to_string(next_lines),
        next_row,
        next_col,
      )
    }
    MoveCursorLeft =>
      if col > 0 {
        textarea_normalize_model(
          model,
          model.value,
          row,
          component_previous_grapheme_boundary(lines[row], col),
        )
      } else if row > 0 {
        textarea_normalize_model(
          model,
          model.value,
          row - 1,
          textarea_line_len(lines, row - 1),
        )
      } else {
        model
      }
    MoveCursorRight =>
      if col < textarea_line_len(lines, row) {
        textarea_normalize_model(
          model,
          model.value,
          row,
          component_next_grapheme_boundary(lines[row], col),
        )
      } else if row + 1 < lines.length() {
        textarea_normalize_model(model, model.value, row + 1, 0)
      } else {
        model
      }
    MoveCursorUp => textarea_move_to_visual_row(model, lines, row, col, -1)
    MoveCursorDown => textarea_move_to_visual_row(model, lines, row, col, 1)
    MoveToLineStart => textarea_normalize_model(model, model.value, row, 0)
    MoveToLineEnd =>
      textarea_normalize_model(
        model,
        model.value,
        row,
        textarea_line_len(lines, row),
      )
    MoveToTop =>
      textarea_normalize(
        model.value,
        0,
        0,
        model.width,
        model.min_height,
        model.max_height,
        0,
        0,
        model.prompt,
        model.line_numbers,
        model.char_limit,
        model.line_limit,
        model.placeholder,
        model.focused,
        model.disabled,
      )
    MoveToBottom => {
      let last_row = lines.length() - 1
      textarea_normalize_model(
        model,
        model.value,
        last_row,
        textarea_line_len(lines, last_row),
      )
    }
    PageUp =>
      textarea_move_to_visual_row(model, lines, row, col, -model.height.max(1))
    PageDown =>
      textarea_move_to_visual_row(model, lines, row, col, model.height.max(1))
    SetValue(value) => {
      let limited = textarea_limit_value(
        value,
        model.char_limit,
        model.line_limit,
      )
      textarea_normalize(
        limited,
        0,
        0,
        model.width,
        model.min_height,
        model.max_height,
        0,
        0,
        model.prompt,
        model.line_numbers,
        model.char_limit,
        model.line_limit,
        model.placeholder,
        model.focused,
        model.disabled,
      )
    }
    Resize(width, height) => {
      let safe_height = height.max(0)
      let next_min_height = if model.min_height == model.max_height {
        safe_height
      } else {
        model.min_height.min(safe_height)
      }
      textarea_normalize(
        model.value,
        row,
        col,
        width,
        next_min_height,
        safe_height,
        model.scroll_row,
        model.scroll_col,
        model.prompt,
        model.line_numbers,
        model.char_limit,
        model.line_limit,
        model.placeholder,
        model.focused,
        model.disabled,
      )
    }
    Focus =>
      textarea_normalize(
        model.value,
        row,
        col,
        model.width,
        model.min_height,
        model.max_height,
        model.scroll_row,
        model.scroll_col,
        model.prompt,
        model.line_numbers,
        model.char_limit,
        model.line_limit,
        model.placeholder,
        true,
        model.disabled,
      )
    Blur =>
      textarea_normalize(
        model.value,
        row,
        col,
        model.width,
        model.min_height,
        model.max_height,
        model.scroll_row,
        model.scroll_col,
        model.prompt,
        model.line_numbers,
        model.char_limit,
        model.line_limit,
        model.placeholder,
        false,
        model.disabled,
      )
  }

  @pippa.UpdateResult::new(model=next_model, cmd=@pippa.Cmd::none())
}

///|
fn textarea_visible_slice(line : String, start : Int, width : Int) -> String {
  component_visible_cell_slice(line, start, width)
}

///|
fn textarea_line_number_gutter(
  row : Int,
  line_count : Int,
  continuation : Bool,
  line_numbers : Bool,
) -> String {
  if !line_numbers {
    return ""
  }
  let digits = textarea_digits(line_count)
  let label = if continuation { "" } else { (row + 1).to_string() }
  @internal.pad_right_width(label, digits) + " "
}

///|
fn textarea_row_prefix(
  model : TextareaModel,
  line_count : Int,
  row : Int,
  continuation : Bool,
) -> String {
  textarea_line_number_gutter(row, line_count, continuation, model.line_numbers) +
  model.prompt
}

///|
fn textarea_render_with_prefix(
  model : TextareaModel,
  prefix : String,
  content : String,
  content_width : Int,
) -> String {
  component_fit_width(
    prefix + component_fit_width(content, content_width),
    model.width,
  )
}

///|
fn textarea_render_placeholder_row(
  model : TextareaModel,
  line_count : Int,
  content_width : Int,
) -> String {
  let prefix = textarea_row_prefix(model, line_count, 0, false)
  let placeholder = textarea_visible_slice(
    @pippa.dim() + model.placeholder + @pippa.reset(),
    0,
    content_width,
  )
  textarea_render_with_prefix(model, prefix, placeholder, content_width)
}

///|
fn textarea_render_blank_row(
  model : TextareaModel,
  line_count : Int,
  content_width : Int,
) -> String {
  let prefix = textarea_row_prefix(model, line_count, 0, true)
  textarea_render_with_prefix(model, prefix, "", content_width)
}

///|
fn textarea_visual_line_with_cursor(line : String, cursor_col : Int) -> String {
  let cursor = component_clamp_grapheme_boundary(line, cursor_col)
  component_char_slice(line, 0, cursor) +
  "|" +
  component_char_slice(line, cursor, component_char_len(line))
}

///|
fn textarea_render_visual_row(
  model : TextareaModel,
  lines : Array[String],
  visual : TextareaVisualRow,
  visual_index : Int,
  cursor_visual_index : Int,
  content_width : Int,
) -> String {
  let line = lines[visual.logical_row]
  let prefix = textarea_row_prefix(
    model,
    lines.length(),
    visual.logical_row,
    visual.continuation,
  )
  let show_cursor = model.focused &&
    !model.disabled &&
    visual_index == cursor_visual_index &&
    visual.logical_row == model.cursor_row
  let source = if show_cursor {
    textarea_visual_line_with_cursor(line, model.cursor_col)
  } else {
    line
  }
  let cursor_at_full_row_end = show_cursor &&
    model.cursor_col == visual.end_col &&
    visual.width >= content_width &&
    content_width > 0
  let content = if cursor_at_full_row_end {
    textarea_visible_slice(line, visual.start_cell, (content_width - 1).max(0)) +
    "|"
  } else {
    let slice_width = if show_cursor {
      (visual.width + 1).max(1)
    } else {
      visual.width
    }
    textarea_visible_slice(source, visual.start_cell, slice_width)
  }
  textarea_render_with_prefix(model, prefix, content, content_width)
}

///|
fn textarea_view(model : TextareaModel) -> String {
  if model.height <= 0 {
    return ""
  }

  let lines = textarea_lines(model.value)
  let content_width = textarea_content_width(
    model.width,
    model.prompt,
    model.line_numbers,
    lines.length(),
  )

  if model.value == "" && !model.focused {
    let first_line = textarea_render_placeholder_row(
      model,
      lines.length(),
      content_width,
    )
    let rows : Array[String] = [first_line]
    for _ in 1..<model.height {
      rows.push(textarea_render_blank_row(model, lines.length(), content_width))
    }
    return rows.join("\n")
  }

  let visual_rows = textarea_visual_rows(lines, content_width)
  let cursor_row = textarea_clamp(model.cursor_row, 0, lines.length() - 1)
  let cursor_col = component_clamp_grapheme_boundary(
    lines[cursor_row],
    textarea_clamp(model.cursor_col, 0, textarea_line_len(lines, cursor_row)),
  )
  let cursor_visual_index = textarea_visual_row_index_for_cursor(
    visual_rows, cursor_row, cursor_col,
  )
  let rows : Array[String] = []
  for i in 0..<model.height {
    let visual_index = model.scroll_row + i
    if visual_index < visual_rows.length() {
      rows.push(
        textarea_render_visual_row(
          model,
          lines,
          visual_rows[visual_index],
          visual_index,
          cursor_visual_index,
          content_width,
        ),
      )
    } else {
      rows.push(textarea_render_blank_row(model, lines.length(), content_width))
    }
  }
  rows.join("\n")
}

///|
/// Create a textarea component with the given placeholder and size.
pub fn textarea(
  width~ : Int,
  height~ : Int,
  placeholder? : String = "",
  min_height? : Int = height,
  max_height? : Int = height,
  prompt? : String = "",
  line_numbers? : Bool = false,
  char_limit? : Int? = None,
  line_limit? : Int? = None,
  disabled? : Bool = false,
) -> Component[TextareaModel, TextareaMsg] {
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model=textarea_normalize(
          "", 0, 0, width, min_height, max_height, 0, 0, prompt, line_numbers, char_limit,
          line_limit, placeholder, false, disabled,
        ),
        cmd=@pippa.Cmd::none(),
      )
    },
    update: textarea_update,
    view: textarea_view,
  }
}
