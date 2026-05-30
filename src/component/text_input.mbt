///|
/// TextInput component — a single-line editable text field.
///
/// Embed this inside a parent application by including `TextInputModel` as a
/// field in the parent's model, wiring `TextInputMsg` into the parent's message
/// type, and delegating update/view calls to the component returned by
/// `text_input`.

///|
/// How a text input renders its stored value.
pub(all) enum TextInputEchoMode {
  /// Render the value exactly as stored.
  Normal
  /// Render one mask character per visible grapheme cluster.
  Password(Char)
  /// Render no value content. Cursor/editing still use the real value.
  Hidden
} derive(Debug, Eq)

///|
/// Latest validation state for the text input value.
pub(all) enum TextInputValidation {
  /// The value passed validation.
  Valid
  /// The value was accepted but failed validation with this message.
  Invalid(String)
} derive(Debug, Eq)

///|
/// State of a single-line text input field.
pub(all) struct TextInputModel {
  /// Current text content.
  value : String
  /// Cursor position as a character index clamped to a grapheme boundary.
  cursor : Int
  /// Visible width for the value area in display cells; 0 means unbounded.
  width : Int
  /// Horizontal scroll offset for the rendered value area in display cells.
  scroll_col : Int
  /// Prefix rendered before the value or placeholder.
  prompt : String
  /// Hint text shown when the field is empty.
  placeholder : String
  /// Value echo mode used by the view.
  echo_mode : TextInputEchoMode
  /// Optional maximum value length measured in grapheme clusters.
  char_limit : Int?
  /// Latest validation result. Invalid values are accepted and flagged here.
  validation : TextInputValidation
  /// Whether the field currently has keyboard focus.
  focused : Bool
  /// Whether input messages should be ignored.
  disabled : Bool
} derive(Debug, Eq)

///|
/// Messages that drive a `TextInputModel`.
pub(all) enum TextInputMsg {
  /// Insert a character at the current cursor position.
  InsertChar(Char)
  /// Insert text at the current cursor position.
  InsertText(String)
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
fn text_input_validate(
  value : String,
  validator : (String) -> Result[Unit, String],
) -> TextInputValidation {
  match validator(value) {
    Ok(_) => Valid
    Err(message) => Invalid(message)
  }
}

///|
fn text_input_echo_value_and_cursor(
  value : String,
  cursor : Int,
  echo_mode : TextInputEchoMode,
) -> (String, Int) {
  let safe_cursor = component_clamp_grapheme_boundary(value, cursor)
  match echo_mode {
    Normal => (value, safe_cursor)
    Password(mask) => {
      let boundaries = component_grapheme_boundaries(value)
      let buf = StringBuilder::new(size_hint=boundaries.length())
      let mut display_cursor = 0
      for i in 0..<(boundaries.length() - 1) {
        if boundaries[i] < safe_cursor {
          display_cursor = display_cursor + 1
        }
        buf.write_char(mask)
      }
      (buf.to_string(), display_cursor)
    }
    Hidden => ("", 0)
  }
}

///|
fn text_input_prompt_width(prompt : String) -> Int {
  @internal.display_width(prompt)
}

///|
fn text_input_value_width(width : Int, prompt : String) -> Int {
  let safe_width = width.max(0)
  if safe_width > 0 {
    (safe_width - text_input_prompt_width(prompt)).max(0)
  } else {
    0
  }
}

///|
fn text_input_normalize_state(
  value : String,
  cursor : Int,
  width : Int,
  scroll_col : Int,
  prompt : String,
  placeholder : String,
  echo_mode : TextInputEchoMode,
  char_limit : Int?,
  validation : TextInputValidation,
  focused : Bool,
  disabled : Bool,
) -> TextInputModel {
  let safe_width = width.max(0)
  let safe_cursor = component_clamp_grapheme_boundary(value, cursor)
  let (echo_value, echo_cursor) = text_input_echo_value_and_cursor(
    value, safe_cursor, echo_mode,
  )
  let cursor_cells = component_prefix_display_width(echo_value, echo_cursor)
  let value_width = text_input_value_width(safe_width, prompt)
  let mut next_scroll_col = scroll_col.max(0)
  if value_width > 0 {
    if cursor_cells < next_scroll_col {
      next_scroll_col = cursor_cells
    } else if cursor_cells >= next_scroll_col + value_width {
      next_scroll_col = cursor_cells - value_width + 1
    }
  } else {
    next_scroll_col = 0
  }
  {
    value,
    cursor: safe_cursor,
    width: safe_width,
    scroll_col: next_scroll_col,
    prompt,
    placeholder,
    echo_mode,
    char_limit,
    validation,
    focused,
    disabled,
  }
}

///|
fn text_input_normalize_validated(
  value : String,
  cursor : Int,
  width : Int,
  scroll_col : Int,
  prompt : String,
  placeholder : String,
  echo_mode : TextInputEchoMode,
  char_limit : Int?,
  focused : Bool,
  disabled : Bool,
  validator : (String) -> Result[Unit, String],
) -> TextInputModel {
  text_input_normalize_state(
    value,
    cursor,
    width,
    scroll_col,
    prompt,
    placeholder,
    echo_mode,
    char_limit,
    text_input_validate(value, validator),
    focused,
    disabled,
  )
}

///|
fn text_input_normalize_model(
  model : TextInputModel,
  value : String,
  cursor : Int,
  validation : TextInputValidation,
) -> TextInputModel {
  text_input_normalize_state(
    value,
    cursor,
    model.width,
    model.scroll_col,
    model.prompt,
    model.placeholder,
    model.echo_mode,
    model.char_limit,
    validation,
    model.focused,
    model.disabled,
  )
}

///|
fn text_input_normalize_model_validated(
  model : TextInputModel,
  value : String,
  cursor : Int,
  validator : (String) -> Result[Unit, String],
) -> TextInputModel {
  text_input_normalize_model(
    model,
    value,
    cursor,
    text_input_validate(value, validator),
  )
}

///|
fn text_input_allowed_insert_text(
  model : TextInputModel,
  cursor : Int,
  text : String,
) -> String {
  match model.char_limit {
    None => text
    Some(limit) => {
      let max_clusters = limit.max(0)
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
        if component_grapheme_count(candidate) <= max_clusters {
          accepted = candidate_insert
        } else {
          return accepted
        }
      }
      accepted
    }
  }
}

///|
fn text_input_insert_limited(
  model : TextInputModel,
  cursor : Int,
  text : String,
) -> (String, Int) {
  let inserted = text_input_allowed_insert_text(model, cursor, text)
  if inserted == "" {
    (model.value, cursor)
  } else {
    let value = component_insert_string_at(model.value, cursor, inserted)
    (
      value,
      component_clamp_grapheme_boundary(
        value,
        cursor + component_char_len(inserted),
      ),
    )
  }
}

///|
fn text_input_update(
  model : TextInputModel,
  msg : TextInputMsg,
  validator : (String) -> Result[Unit, String],
) -> @pippa.UpdateResult[TextInputModel, TextInputMsg] {
  if model.disabled {
    return @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
  }

  // Char-array allocation is deferred into the branches that actually need it.
  // Focus/Blur/MoveCursorLeft/MoveToStart never allocate.
  let new_model : TextInputModel = match msg {
    InsertChar(c) => {
      let cursor = component_clamp_grapheme_boundary(model.value, model.cursor)
      let (value, next_cursor) = text_input_insert_limited(
        model,
        cursor,
        String::make(1, c),
      )
      text_input_normalize_model_validated(model, value, next_cursor, validator)
    }
    InsertText(text) => {
      let cursor = component_clamp_grapheme_boundary(model.value, model.cursor)
      let (value, next_cursor) = text_input_insert_limited(model, cursor, text)
      text_input_normalize_model_validated(model, value, next_cursor, validator)
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
        text_input_normalize_model_validated(
          model,
          component_remove_char_range(model.value, start, end),
          start,
          validator,
        )
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
        text_input_normalize_model_validated(
          model,
          component_remove_char_range(model.value, start, end),
          start,
          validator,
        )
      } else {
        model
      }
    }
    MoveCursorLeft =>
      text_input_normalize_model(
        model,
        model.value,
        component_previous_grapheme_boundary(model.value, model.cursor),
        model.validation,
      )
    MoveCursorRight =>
      text_input_normalize_model(
        model,
        model.value,
        component_next_grapheme_boundary(model.value, model.cursor),
        model.validation,
      )
    MoveToStart =>
      text_input_normalize_model(model, model.value, 0, model.validation)
    MoveToEnd =>
      text_input_normalize_model(
        model,
        model.value,
        component_char_len(model.value),
        model.validation,
      )
    Focus => { ..model, focused: true }
    Blur => { ..model, focused: false }
  }
  @pippa.UpdateResult::new(model=new_model, cmd=@pippa.Cmd::none())
}

///|
fn text_input_visible_slice(model : TextInputModel, s : String) -> String {
  let value_width = text_input_value_width(model.width, model.prompt)
  if value_width > 0 {
    component_visible_cell_slice(s, model.scroll_col, value_width)
  } else if model.width > 0 {
    ""
  } else {
    s
  }
}

///|
fn text_input_prompt_view(model : TextInputModel) -> String {
  if model.width > 0 {
    component_visible_cell_slice(model.prompt, 0, model.width)
  } else {
    model.prompt
  }
}

///|
fn text_input_placeholder_view(model : TextInputModel) -> String {
  let buf = StringBuilder::new(size_hint=64)
  if model.focused && !model.disabled {
    buf.write_char('|')
  }
  if model.placeholder != "" {
    buf.write_string(@pippa.dim())
    buf.write_string(model.placeholder)
    buf.write_string(@pippa.reset())
  }
  text_input_visible_slice(model, buf.to_string())
}

///|
fn text_input_value_view(model : TextInputModel) -> String {
  let (echo_value, echo_cursor) = text_input_echo_value_and_cursor(
    model.value,
    model.cursor,
    model.echo_mode,
  )
  if model.focused && !model.disabled {
    text_input_visible_slice(
      model,
      component_char_slice(echo_value, 0, echo_cursor) +
      "|" +
      component_char_slice(
        echo_value,
        echo_cursor,
        component_char_len(echo_value),
      ),
    )
  } else {
    text_input_visible_slice(model, echo_value)
  }
}

///|
fn text_input_view(model : TextInputModel) -> String {
  text_input_prompt_view(model) +
  (if model.value == "" {
    text_input_placeholder_view(model)
  } else {
    text_input_value_view(model)
  })
}

///|
/// Create a text input component with the given placeholder.
///
/// Validators are accepted-but-flagged: every edit updates `value`, then stores
/// `Valid` or `Invalid(message)` in `model.validation` for callers to render.
///
/// # Example
/// ```moonbit ignore
/// let input = text_input(placeholder="Enter name…")
/// let { model, .. } = input.init()
/// ```
pub fn text_input(
  placeholder~ : String,
  prompt? : String = "",
  width? : Int = 0,
  echo_mode? : TextInputEchoMode = Normal,
  char_limit? : Int? = None,
  disabled? : Bool = false,
  validator? : (String) -> Result[Unit, String] = fn(_value) { Ok(()) },
) -> Component[TextInputModel, TextInputMsg] {
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model=text_input_normalize_validated(
          "", 0, width, 0, prompt, placeholder, echo_mode, char_limit, false, disabled,
          validator,
        ),
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model, msg) { text_input_update(model, msg, validator) },
    view: text_input_view,
  }
}
