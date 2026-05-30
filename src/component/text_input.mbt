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
} derive(Debug, Eq)

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
} derive(Debug, Eq)

///|
// Clamp `v` to the closed interval [lo, hi].
fn clamp(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn text_input_update(
  model : TextInputModel,
  msg : TextInputMsg,
) -> @pippa.UpdateResult[TextInputModel, TextInputMsg] {
  // Char-array allocation is deferred into the branches that actually need it.
  // Focus/Blur/MoveCursorLeft/MoveToStart never allocate.
  let new_model : TextInputModel = match msg {
    InsertChar(c) => {
      let cursor = component_clamp_grapheme_boundary(model.value, model.cursor)
      let value = component_insert_char_at(model.value, cursor, c)
      {
        ..model,
        value,
        cursor: component_next_grapheme_boundary(value, cursor),
      }
    }
    DeleteBefore => {
      let n = component_char_len(model.value)
      let cursor = clamp(model.cursor, 0, n)
      let end = if component_is_grapheme_boundary(model.value, cursor) {
        cursor
      } else {
        component_next_grapheme_boundary(model.value, cursor)
      }
      if end > 0 {
        let start = component_previous_grapheme_boundary(model.value, end)
        {
          ..model,
          value: component_remove_char_range(model.value, start, end),
          cursor: start,
        }
      } else {
        model
      }
    }
    DeleteAfter => {
      let n = component_char_len(model.value)
      let cursor = clamp(model.cursor, 0, n)
      if cursor < n {
        let start = component_clamp_grapheme_boundary(model.value, cursor)
        let end = component_next_grapheme_boundary(model.value, start)
        { ..model, value: component_remove_char_range(model.value, start, end) }
      } else {
        model
      }
    }
    MoveCursorLeft =>
      {
        ..model,
        cursor: component_previous_grapheme_boundary(model.value, model.cursor),
      }
    MoveCursorRight =>
      {
        ..model,
        cursor: component_next_grapheme_boundary(model.value, model.cursor),
      }
    MoveToStart => { ..model, cursor: 0 }
    MoveToEnd => { ..model, cursor: component_char_len(model.value) }
    Focus => { ..model, focused: true }
    Blur => { ..model, focused: false }
  }
  @pippa.UpdateResult::new(model=new_model, cmd=@pippa.Cmd::none())
}

///|
fn text_input_view(model : TextInputModel) -> String {
  let buf = StringBuilder::new(size_hint=64)
  if !model.focused && model.value == "" {
    // Show placeholder with dim styling
    buf.write_string(@pippa.dim())
    buf.write_string(model.placeholder)
    buf.write_string(@pippa.reset())
  } else if model.focused {
    // Show value with '|' cursor marker at cursor position
    let chars = model.value.to_array()
    let n = chars.length()
    let cursor = component_clamp_grapheme_boundary(model.value, model.cursor)
    for i in 0..<n {
      if i == cursor {
        buf.write_char('|')
      }
      buf.write_char(chars[i])
    }
    if cursor == n {
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
