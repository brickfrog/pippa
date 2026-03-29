///|
/// TextInput component — a single-line editable text field.
///
/// Embed this inside a parent application by including `TextInputModel` as a
/// field in the parent's model, wiring `TextInputMsg` into the parent's message
/// type, and delegating update/view calls to the component returned by
/// `text_input`.

///|
/// State of a single-line text input field.
pub(all) struct TextInputModel {
  /// Current text content.
  value : String
  /// Cursor position as a character index, clamped to [0, value char length].
  cursor : Int
  /// Hint text shown when the field is empty and unfocused.
  placeholder : String
  /// Whether the field currently has keyboard focus.
  focused : Bool
} derive(Show, Eq)

///|
/// Messages that drive a `TextInputModel`.
pub(all) enum TextInputMsg {
  /// Insert a character at the current cursor position.
  InsertChar(Char)
  /// Delete the character immediately before the cursor (backspace).
  DeleteBefore
  /// Delete the character immediately after the cursor (delete key).
  DeleteAfter
  /// Move the cursor one character to the left.
  MoveCursorLeft
  /// Move the cursor one character to the right.
  MoveCursorRight
  /// Jump the cursor to the beginning of the input.
  MoveToStart
  /// Jump the cursor to the end of the input.
  MoveToEnd
  /// Give focus to this input.
  Focus
  /// Remove focus from this input.
  Blur
} derive(Show, Eq)

///|
fn text_input_chars_to_string(chars : Array[Char]) -> String {
  let buf = StringBuilder::new(size_hint=chars.length() + 4)
  for ch in chars {
    buf.write_char(ch)
  }
  buf.to_string()
}

///|
fn text_input_update(
  model : TextInputModel,
  msg : TextInputMsg,
) -> @pippa.UpdateResult[TextInputModel, TextInputMsg] {
  let chars = model.value.to_array()
  let n = chars.length()
  let new_model : TextInputModel = match msg {
    InsertChar(c) => {
      let new_chars : Array[Char] = []
      for i in 0..<model.cursor {
        new_chars.push(chars[i])
      }
      new_chars.push(c)
      for i in model.cursor..<n {
        new_chars.push(chars[i])
      }
      {
        ..model,
        value: text_input_chars_to_string(new_chars),
        cursor: model.cursor + 1,
      }
    }
    DeleteBefore =>
      if model.cursor > 0 {
        let new_chars : Array[Char] = []
        let end = model.cursor - 1
        for i in 0..<end {
          new_chars.push(chars[i])
        }
        for i in model.cursor..<n {
          new_chars.push(chars[i])
        }
        {
          ..model,
          value: text_input_chars_to_string(new_chars),
          cursor: model.cursor - 1,
        }
      } else {
        model
      }
    DeleteAfter =>
      if model.cursor < n {
        let new_chars : Array[Char] = []
        for i in 0..<model.cursor {
          new_chars.push(chars[i])
        }
        let start = model.cursor + 1
        for i in start..<n {
          new_chars.push(chars[i])
        }
        { ..model, value: text_input_chars_to_string(new_chars) }
      } else {
        model
      }
    MoveCursorLeft =>
      { ..model, cursor: if model.cursor > 0 { model.cursor - 1 } else { 0 } }
    MoveCursorRight =>
      { ..model, cursor: if model.cursor < n { model.cursor + 1 } else { n } }
    MoveToStart => { ..model, cursor: 0 }
    MoveToEnd => { ..model, cursor: n }
    Focus => { ..model, focused: true }
    Blur => { ..model, focused: false }
  }
  @pippa.UpdateResult::new(model=new_model, cmd=@pippa.Cmd::none())
}

///|
fn text_input_view(model : TextInputModel) -> String {
  let buf = StringBuilder::new(size_hint=64)
  if not(model.focused) && model.value == "" {
    // Show placeholder with dim styling
    buf.write_string(@pippa.dim())
    buf.write_string(model.placeholder)
    buf.write_string(@pippa.reset())
  } else if model.focused {
    // Show value with '|' cursor marker at cursor position
    let chars = model.value.to_array()
    let n = chars.length()
    for i in 0..<n {
      if i == model.cursor {
        buf.write_char('|')
      }
      buf.write_char(chars[i])
    }
    if model.cursor == n {
      buf.write_char('|')
    }
  } else {
    // Unfocused with non-empty value — show value as-is
    buf.write_string(model.value)
  }
  buf.to_string()
}

///|
/// Create a text input component with the given placeholder.
///
/// # Example
/// ```moonbit ignore
/// let input = text_input(placeholder="Enter name…")
/// let { model, .. } = input.init()
/// ```
pub fn text_input(
  placeholder~ : String,
) -> Component[TextInputModel, TextInputMsg] {
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model={ value: "", cursor: 0, placeholder, focused: false },
        cmd=@pippa.Cmd::none(),
      )
    },
    update: text_input_update,
    view: text_input_view,
  }
}
