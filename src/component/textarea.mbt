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
} derive(Show, Eq)

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
} derive(Show, Eq)

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
  let col = textarea_clamp(cursor_col, 0, textarea_line_len(lines, row))
  let safe_width = width.max(0)
  let safe_height = height.max(0)
  let mut next_scroll_row = scroll_row.max(0)
  let mut next_scroll_col = scroll_col.max(0)

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
    if col < next_scroll_col {
      next_scroll_col = col
    } else if col >= next_scroll_col + safe_width {
      next_scroll_col = col - safe_width + 1
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
  let chars = lines[row].to_array()
  let next_chars : Array[Char] = []
  for i in 0..<col {
    next_chars.push(chars[i])
  }
  next_chars.push(ch)
  for i in col..<chars.length() {
    next_chars.push(chars[i])
  }
  lines[row] = textarea_chars_to_string(next_chars)
  (lines, row, col + 1)
}

///|
fn textarea_insert_text(
  lines : Array[String],
  row : Int,
  col : Int,
  text : String,
) -> (Array[String], Int, Int) {
  let parts = textarea_lines(text)
  match parts {
    [] => (lines, row, col)
    [single] => {
      let single_chars = single.to_array()
      let base_chars = lines[row].to_array()
      let next_chars : Array[Char] = []
      for i in 0..<col {
        next_chars.push(base_chars[i])
      }
      for ch in single_chars {
        next_chars.push(ch)
      }
      for i in col..<base_chars.length() {
        next_chars.push(base_chars[i])
      }
      lines[row] = textarea_chars_to_string(next_chars)
      (lines, row, col + single_chars.length())
    }
    [first, .. rest] => {
      let base_chars = lines[row].to_array()
      let before_chars : Array[Char] = []
      let after_chars : Array[Char] = []
      for i in 0..<col {
        before_chars.push(base_chars[i])
      }
      for i in col..<base_chars.length() {
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
  let before_chars : Array[Char] = []
  let after_chars : Array[Char] = []
  for i in 0..<col {
    before_chars.push(chars[i])
  }
  for i in col..<chars.length() {
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
  if col > 0 {
    let chars = lines[row].to_array()
    let next_chars : Array[Char] = []
    for i in 0..<(col - 1) {
      next_chars.push(chars[i])
    }
    for i in col..<chars.length() {
      next_chars.push(chars[i])
    }
    lines[row] = textarea_chars_to_string(next_chars)
    (lines, row, col - 1)
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
  let chars = lines[row].to_array()
  if col < chars.length() {
    let next_chars : Array[Char] = []
    for i in 0..<col {
      next_chars.push(chars[i])
    }
    for i in (col + 1)..<chars.length() {
      next_chars.push(chars[i])
    }
    lines[row] = textarea_chars_to_string(next_chars)
    (lines, row, col)
  } else if row + 1 < lines.length() {
    lines[row] = lines[row] + lines[row + 1]
    ignore(lines.remove(row + 1))
    (lines, row, col)
  } else {
    (lines, row, col)
  }
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
          col - 1,
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
          col + 1,
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
        textarea_normalize(
          model.value,
          row - 1,
          col,
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
    MoveCursorDown =>
      if row + 1 < lines.length() {
        textarea_normalize(
          model.value,
          row + 1,
          col,
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
      textarea_normalize(
        model.value,
        (row - model.height.max(1)).max(0),
        col,
        model.width,
        model.height,
        model.scroll_row - model.height.max(1),
        model.scroll_col,
        model.placeholder,
        model.focused,
      )
    PageDown =>
      textarea_normalize(
        model.value,
        (row + model.height.max(1)).min(lines.length() - 1),
        col,
        model.width,
        model.height,
        model.scroll_row + model.height.max(1),
        model.scroll_col,
        model.placeholder,
        model.focused,
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
  if width <= 0 {
    return ""
  }
  let chars = line.to_array()
  let from = start.max(0).min(chars.length())
  let to = (from + width).min(chars.length())
  let visible : Array[Char] = []
  for i in from..<to {
    visible.push(chars[i])
  }
  textarea_chars_to_string(visible)
}

///|
fn textarea_cursor_line(model : TextareaModel, line : String) -> String {
  if !model.focused {
    return line
  }
  let chars = line.to_array()
  let start = model.scroll_col
  let cursor = textarea_clamp(model.cursor_col, 0, chars.length())
  let rendered : Array[Char] = []
  for i in start..<chars.length() {
    if i == cursor {
      rendered.push('|')
    }
    rendered.push(chars[i])
    if rendered.length() >= model.width + 1 {
      break
    }
  }
  if cursor == chars.length() {
    rendered.push('|')
  }
  textarea_chars_to_string(rendered)
}

///|
fn textarea_view(model : TextareaModel) -> String {
  if model.height <= 0 {
    return ""
  }

  if model.value == "" && !model.focused {
    let first_line = @pippa.pad_right(
      @pippa.truncate(
        @pippa.dim() + model.placeholder + @pippa.reset(),
        model.width,
      ),
      model.width,
    )
    let rows : Array[String] = [first_line]
    for _ in 1..<model.height {
      rows.push(@pippa.pad_right("", model.width))
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
    rows.push(@pippa.pad_right(@pippa.truncate(raw, model.width), model.width))
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
