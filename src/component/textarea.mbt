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
  /// Vertical scroll offset in logical lines.
  scroll_row : Int
  /// Horizontal scroll offset in columns.
  scroll_col : Int
  /// Hint text shown when the field is empty and unfocused.
  placeholder : String
  /// Whether the field currently has keyboard focus.
  focused : Bool
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
fn textarea_line_len(lines : Array[String], row : Int) -> Int {
  lines[row].to_array().length()
}

///|
fn textarea_normalize(
  value : String,
  cursor_row : Int,
  cursor_col : Int,
  width : Int,
  height : Int,
  scroll_row : Int,
  scroll_col : Int,
  placeholder : String,
  focused : Bool,
) -> TextareaModel {
  let lines = textarea_lines(value)
  let row = textarea_clamp(cursor_row, 0, lines.length() - 1)
  let raw_col = textarea_clamp(cursor_col, 0, textarea_line_len(lines, row))
  let col = component_clamp_grapheme_boundary(lines[row], raw_col)
  let safe_width = width.max(0)
  let safe_height = height.max(0)
  let mut next_scroll_row = scroll_row.max(0)
  let mut next_scroll_col = scroll_col.max(0)
  let cursor_cells = component_prefix_display_width(lines[row], col)

  if safe_height > 0 {
    if row < next_scroll_row {
      next_scroll_row = row
    } else if row >= next_scroll_row + safe_height {
      next_scroll_row = row - safe_height + 1
    }
  } else {
    next_scroll_row = 0
  }

  if safe_width > 0 {
    if cursor_cells < next_scroll_col {
      next_scroll_col = cursor_cells
    } else if cursor_cells >= next_scroll_col + safe_width {
      next_scroll_col = cursor_cells - safe_width + 1
    }
  } else {
    next_scroll_col = 0
  }

  {
    value,
    cursor_row: row,
    cursor_col: col,
    width: safe_width,
    height: safe_height,
    scroll_row: next_scroll_row,
    scroll_col: next_scroll_col,
    placeholder,
    focused,
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
fn textarea_move_to_display_cell_row(
  model : TextareaModel,
  lines : Array[String],
  row : Int,
  col : Int,
  next_row : Int,
  next_scroll_row : Int,
) -> TextareaModel {
  let source_col = component_clamp_grapheme_boundary(lines[row], col)
  let target_cell = component_prefix_display_width(lines[row], source_col)
  let target_col = component_cell_to_grapheme_boundary(
    lines[next_row],
    target_cell,
  )
  textarea_normalize(
    model.value,
    next_row,
    target_col,
    model.width,
    model.height,
    next_scroll_row,
    model.scroll_col,
    model.placeholder,
    model.focused,
  )
}

///|
fn textarea_update(
  model : TextareaModel,
  msg : TextareaMsg,
) -> @pippa.UpdateResult[TextareaModel, TextareaMsg] {
  let lines = textarea_lines(model.value)
  let row = textarea_clamp(model.cursor_row, 0, lines.length() - 1)
  let col = textarea_clamp(model.cursor_col, 0, textarea_line_len(lines, row))

  let next_model = match msg {
    InsertChar(ch) => {
      let (next_lines, next_row, next_col) = textarea_insert_char(
        lines.copy(),
        row,
        col,
        ch,
      )
      textarea_normalize(
        textarea_lines_to_string(next_lines),
        next_row,
        next_col,
        model.width,
        model.height,
        model.scroll_row,
        model.scroll_col,
        model.placeholder,
        model.focused,
      )
    }
    InsertText(text) => {
      let (next_lines, next_row, next_col) = textarea_insert_text(
        lines.copy(),
        row,
        col,
        text,
      )
      textarea_normalize(
        textarea_lines_to_string(next_lines),
        next_row,
        next_col,
        model.width,
        model.height,
        model.scroll_row,
        model.scroll_col,
        model.placeholder,
        model.focused,
      )
    }
    InsertNewline => {
      let (next_lines, next_row, next_col) = textarea_insert_newline(
        lines.copy(),
        row,
        col,
      )
      textarea_normalize(
        textarea_lines_to_string(next_lines),
        next_row,
        next_col,
        model.width,
        model.height,
        model.scroll_row,
        model.scroll_col,
        model.placeholder,
        model.focused,
      )
    }
    DeleteBefore => {
      let (next_lines, next_row, next_col) = textarea_delete_before(
        lines.copy(),
        row,
        col,
      )
      textarea_normalize(
        textarea_lines_to_string(next_lines),
        next_row,
        next_col,
        model.width,
        model.height,
        model.scroll_row,
        model.scroll_col,
        model.placeholder,
        model.focused,
      )
    }
    DeleteAfter => {
      let (next_lines, next_row, next_col) = textarea_delete_after(
        lines.copy(),
        row,
        col,
      )
      textarea_normalize(
        textarea_lines_to_string(next_lines),
        next_row,
        next_col,
        model.width,
        model.height,
        model.scroll_row,
        model.scroll_col,
        model.placeholder,
        model.focused,
      )
    }
    MoveCursorLeft =>
      if col > 0 {
        textarea_normalize(
          model.value,
          row,
          component_previous_grapheme_boundary(lines[row], col),
          model.width,
          model.height,
          model.scroll_row,
          model.scroll_col,
          model.placeholder,
          model.focused,
        )
      } else if row > 0 {
        textarea_normalize(
          model.value,
          row - 1,
          textarea_line_len(lines, row - 1),
          model.width,
          model.height,
          model.scroll_row,
          model.scroll_col,
          model.placeholder,
          model.focused,
        )
      } else {
        model
      }
    MoveCursorRight =>
      if col < textarea_line_len(lines, row) {
        textarea_normalize(
          model.value,
          row,
          component_next_grapheme_boundary(lines[row], col),
          model.width,
          model.height,
          model.scroll_row,
          model.scroll_col,
          model.placeholder,
          model.focused,
        )
      } else if row + 1 < lines.length() {
        textarea_normalize(
          model.value,
          row + 1,
          0,
          model.width,
          model.height,
          model.scroll_row,
          model.scroll_col,
          model.placeholder,
          model.focused,
        )
      } else {
        model
      }
    MoveCursorUp =>
      if row > 0 {
        textarea_move_to_display_cell_row(
          model,
          lines,
          row,
          col,
          row - 1,
          model.scroll_row,
        )
      } else {
        model
      }
    MoveCursorDown =>
      if row + 1 < lines.length() {
        textarea_move_to_display_cell_row(
          model,
          lines,
          row,
          col,
          row + 1,
          model.scroll_row,
        )
      } else {
        model
      }
    MoveToLineStart =>
      textarea_normalize(
        model.value,
        row,
        0,
        model.width,
        model.height,
        model.scroll_row,
        model.scroll_col,
        model.placeholder,
        model.focused,
      )
    MoveToLineEnd =>
      textarea_normalize(
        model.value,
        row,
        textarea_line_len(lines, row),
        model.width,
        model.height,
        model.scroll_row,
        model.scroll_col,
        model.placeholder,
        model.focused,
      )
    MoveToTop =>
      textarea_normalize(
        model.value,
        0,
        0,
        model.width,
        model.height,
        0,
        0,
        model.placeholder,
        model.focused,
      )
    MoveToBottom => {
      let last_row = lines.length() - 1
      textarea_normalize(
        model.value,
        last_row,
        textarea_line_len(lines, last_row),
        model.width,
        model.height,
        model.scroll_row,
        model.scroll_col,
        model.placeholder,
        model.focused,
      )
    }
    PageUp =>
      textarea_move_to_display_cell_row(
        model,
        lines,
        row,
        col,
        (row - model.height.max(1)).max(0),
        model.scroll_row - model.height.max(1),
      )
    PageDown =>
      textarea_move_to_display_cell_row(
        model,
        lines,
        row,
        col,
        (row + model.height.max(1)).min(lines.length() - 1),
        model.scroll_row + model.height.max(1),
      )
    SetValue(value) =>
      textarea_normalize(
        value,
        0,
        0,
        model.width,
        model.height,
        0,
        0,
        model.placeholder,
        model.focused,
      )
    Resize(width, height) =>
      textarea_normalize(
        model.value,
        row,
        col,
        width,
        height,
        model.scroll_row,
        model.scroll_col,
        model.placeholder,
        model.focused,
      )
    Focus => { ..model, focused: true }
    Blur => { ..model, focused: false }
  }

  @pippa.UpdateResult::new(model=next_model, cmd=@pippa.Cmd::none())
}

///|
fn textarea_visible_slice(line : String, start : Int, width : Int) -> String {
  component_visible_cell_slice(line, start, width)
}

///|
fn textarea_cursor_line(model : TextareaModel, line : String) -> String {
  if !model.focused {
    return line
  }
  let cursor = component_clamp_grapheme_boundary(line, model.cursor_col)
  component_char_slice(line, 0, cursor) +
  "|" +
  component_char_slice(line, cursor, component_char_len(line))
}

///|
fn textarea_view(model : TextareaModel) -> String {
  if model.height <= 0 {
    return ""
  }

  if model.value == "" && !model.focused {
    let first_line = @internal.pad_right_width(
      @internal.truncate_width(
        @pippa.dim() + model.placeholder + @pippa.reset(),
        model.width,
      ),
      model.width,
    )
    let rows : Array[String] = [first_line]
    for _ in 1..<model.height {
      rows.push(@internal.pad_right_width("", model.width))
    }
    return rows.join("\n")
  }

  let lines = textarea_lines(model.value)
  let rows : Array[String] = []
  for i in 0..<model.height {
    let line_index = model.scroll_row + i
    let line = if line_index < lines.length() { lines[line_index] } else { "" }
    let raw = if model.focused && line_index == model.cursor_row {
      textarea_cursor_line(model, line)
    } else {
      textarea_visible_slice(line, model.scroll_col, model.width)
    }
    let clipped = if model.focused && line_index == model.cursor_row {
      textarea_visible_slice(raw, model.scroll_col, model.width)
    } else {
      raw
    }
    rows.push(component_fit_width(clipped, model.width))
  }
  rows.join("\n")
}

///|
/// Create a textarea component with the given placeholder and size.
pub fn textarea(
  width~ : Int,
  height~ : Int,
  placeholder? : String = "",
) -> Component[TextareaModel, TextareaMsg] {
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model=textarea_normalize(
          "", 0, 0, width, height, 0, 0, placeholder, false,
        ),
        cmd=@pippa.Cmd::none(),
      )
    },
    update: textarea_update,
    view: textarea_view,
  }
}
