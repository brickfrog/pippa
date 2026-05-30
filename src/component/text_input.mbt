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
/// Autocomplete suggestions for a text input.
pub(all) struct TextInputSuggestionState {
  /// Candidate values that can be previewed and accepted.
  items : Array[String]
  /// Currently selected suggestion index.
  selected : Int
} derive(Debug, Eq)

///|
/// Editing actions that can be triggered by a keymap binding.
pub(all) enum TextInputEditingAction {
  /// Move the cursor one grapheme cluster to the left.
  TextInputActionMoveCursorLeft
  /// Move the cursor one grapheme cluster to the right.
  TextInputActionMoveCursorRight
  /// Move the cursor to the previous word/run boundary.
  TextInputActionMoveWordLeft
  /// Move the cursor to the next word/run boundary.
  TextInputActionMoveWordRight
  /// Delete the grapheme cluster before the cursor.
  TextInputActionDeleteBefore
  /// Delete the grapheme cluster after the cursor.
  TextInputActionDeleteAfter
  /// Delete the word/run before the cursor.
  TextInputActionDeleteWordBackward
  /// Delete the word/run after the cursor.
  TextInputActionDeleteWordForward
  /// Move the cursor to the beginning of the input.
  TextInputActionMoveToStart
  /// Move the cursor to the end of the input.
  TextInputActionMoveToEnd
  /// Commit the currently selected suggestion.
  TextInputActionAcceptSuggestion
  /// Select the next suggestion.
  TextInputActionCycleSuggestionNext
  /// Select the previous suggestion.
  TextInputActionCycleSuggestionPrev
} derive(Debug, Eq)

///|
/// One key binding entry in a text input keymap.
pub(all) struct TextInputKeyBinding {
  /// Key combination(s) that trigger the action.
  binding : @pippa.Binding
  /// Editing action invoked by this binding.
  action : TextInputEditingAction
} derive(Debug, Eq)

///|
/// Key bindings used when handling raw input events for a text input.
pub(all) struct TextInputKeymap {
  /// Ordered bindings. Earlier entries win when multiple bindings match.
  bindings : Array[TextInputKeyBinding]
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
  /// Autocomplete suggestion state.
  suggestions : TextInputSuggestionState
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
  /// Move the cursor to the previous word/run boundary.
  MoveWordLeft
  /// Move the cursor to the next word/run boundary.
  MoveWordRight
  /// Delete the word/run immediately before the cursor.
  DeleteWordBackward
  /// Delete the word/run immediately after the cursor.
  DeleteWordForward
  /// Jump the cursor to the beginning of the input.
  MoveToStart
  /// Jump the cursor to the end of the input.
  MoveToEnd
  /// Commit the currently selected suggestion.
  AcceptSuggestion
  /// Select the next suggestion.
  CycleSuggestionNext
  /// Select the previous suggestion.
  CycleSuggestionPrev
  /// Replace the available suggestions and reset selection.
  SetSuggestions(Array[String])
  /// Handle a raw runtime input event through the configured keymap.
  HandleInput(@pippa.InputEvent)
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
fn text_input_normalize_suggestions(
  suggestions : TextInputSuggestionState,
) -> TextInputSuggestionState {
  let count = suggestions.items.length()
  if count == 0 {
    { items: suggestions.items, selected: 0 }
  } else {
    {
      items: suggestions.items,
      selected: clamp(suggestions.selected, 0, count - 1),
    }
  }
}

///|
pub fn default_text_input_keymap() -> TextInputKeymap {
  {
    bindings: [
      {
        binding: { keys: ["left"], help: "left" },
        action: TextInputActionMoveCursorLeft,
      },
      {
        binding: { keys: ["right"], help: "right" },
        action: TextInputActionMoveCursorRight,
      },
      {
        binding: { keys: ["home"], help: "start" },
        action: TextInputActionMoveToStart,
      },
      {
        binding: { keys: ["end"], help: "end" },
        action: TextInputActionMoveToEnd,
      },
      {
        binding: { keys: ["backspace"], help: "delete before" },
        action: TextInputActionDeleteBefore,
      },
      {
        binding: { keys: ["delete"], help: "delete after" },
        action: TextInputActionDeleteAfter,
      },
      {
        binding: { keys: ["alt+b"], help: "word left" },
        action: TextInputActionMoveWordLeft,
      },
      {
        binding: { keys: ["alt+f"], help: "word right" },
        action: TextInputActionMoveWordRight,
      },
      {
        binding: { keys: ["ctrl+w"], help: "delete word backward" },
        action: TextInputActionDeleteWordBackward,
      },
      {
        binding: { keys: ["alt+d"], help: "delete word forward" },
        action: TextInputActionDeleteWordForward,
      },
      {
        binding: { keys: ["tab"], help: "accept suggestion" },
        action: TextInputActionAcceptSuggestion,
      },
      {
        binding: { keys: ["down"], help: "next suggestion" },
        action: TextInputActionCycleSuggestionNext,
      },
      {
        binding: { keys: ["up", "shift+tab"], help: "previous suggestion" },
        action: TextInputActionCycleSuggestionPrev,
      },
    ],
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
  suggestions : TextInputSuggestionState,
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
    suggestions: text_input_normalize_suggestions(suggestions),
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
  suggestions : TextInputSuggestionState,
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
    suggestions,
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
    model.suggestions,
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
priv enum TextInputClusterClass {
  TextInputClusterAsciiWord
  TextInputClusterWhitespace
  TextInputClusterWide
  TextInputClusterPunctuation
} derive(Eq)

///|
fn text_input_is_ascii_word_char(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= 'a' && ch <= 'z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '_'
}

///|
fn text_input_is_whitespace_char(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == '\u{3000}'
}

///|
fn text_input_cluster_first_text_char(cluster : String) -> Char? {
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
fn text_input_cluster_class(cluster : String) -> TextInputClusterClass {
  match text_input_cluster_first_text_char(cluster) {
    None => TextInputClusterPunctuation
    Some(ch) =>
      if text_input_is_whitespace_char(ch) {
        TextInputClusterWhitespace
      } else if text_input_is_ascii_word_char(ch) {
        TextInputClusterAsciiWord
      } else if @internal.display_width(cluster) > 1 {
        TextInputClusterWide
      } else {
        TextInputClusterPunctuation
      }
  }
}

///|
fn text_input_boundary_index(boundaries : Array[Int], pos : Int) -> Int {
  let mut previous = 0
  for i, boundary in boundaries {
    if boundary == pos {
      return i
    } else if boundary > pos {
      return previous
    }
    previous = i
  }
  boundaries.length() - 1
}

///|
fn text_input_cluster_class_at(
  chars : Array[Char],
  boundaries : Array[Int],
  index : Int,
) -> TextInputClusterClass {
  text_input_cluster_class(
    component_char_slice_from_chars(
      chars,
      boundaries[index],
      boundaries[index + 1],
    ),
  )
}

///|
fn text_input_word_left(value : String, cursor : Int) -> Int {
  let pos = component_clamp_grapheme_boundary(value, cursor)
  if pos <= 0 {
    return 0
  }
  let chars = value.to_array()
  let boundaries = component_grapheme_boundaries(value)
  let mut index = text_input_boundary_index(boundaries, pos) - 1
  let class = text_input_cluster_class_at(chars, boundaries, index)
  while index > 0 &&
        text_input_cluster_class_at(chars, boundaries, index - 1) == class {
    index = index - 1
  }
  boundaries[index]
}

///|
fn text_input_word_right(value : String, cursor : Int) -> Int {
  let pos = component_clamp_grapheme_boundary(value, cursor)
  let chars = value.to_array()
  let boundaries = component_grapheme_boundaries(value)
  let count = boundaries.length() - 1
  let mut index = text_input_boundary_index(boundaries, pos)
  if index >= count {
    return component_char_len(value)
  }
  let class = text_input_cluster_class_at(chars, boundaries, index)
  index = index + 1
  while index < count &&
        text_input_cluster_class_at(chars, boundaries, index) == class {
    index = index + 1
  }
  boundaries[index]
}

///|
fn text_input_limit_text_to_char_limit(
  text : String,
  char_limit : Int?,
) -> String {
  match char_limit {
    None => text
    Some(limit) => {
      let max_clusters = limit.max(0)
      let boundaries = component_grapheme_boundaries(text)
      let count = boundaries.length() - 1
      let keep = max_clusters.min(count)
      component_char_slice(text, 0, boundaries[keep])
    }
  }
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
fn text_input_current_suggestion(model : TextInputModel) -> String? {
  let suggestions = text_input_normalize_suggestions(model.suggestions)
  if suggestions.items.is_empty() {
    None
  } else {
    Some(suggestions.items[suggestions.selected])
  }
}

///|
fn text_input_string_starts_with(value : String, prefix : String) -> Bool {
  let prefix_len = component_char_len(prefix)
  component_char_len(value) >= prefix_len &&
  component_char_slice(value, 0, prefix_len) == prefix
}

///|
fn text_input_suggestion_hint(model : TextInputModel) -> String? {
  if !model.focused ||
    model.disabled ||
    model.cursor != component_char_len(model.value) {
    return None
  }
  match model.echo_mode {
    Normal =>
      match text_input_current_suggestion(model) {
        Some(suggestion) =>
          if text_input_string_starts_with(suggestion, model.value) {
            let hint = component_char_slice(
              suggestion,
              component_char_len(model.value),
              component_char_len(suggestion),
            )
            if hint == "" {
              None
            } else {
              Some(hint)
            }
          } else {
            None
          }
        None => None
      }
    _ => None
  }
}

///|
fn text_input_accept_suggestion(
  model : TextInputModel,
  validator : (String) -> Result[Unit, String],
) -> TextInputModel {
  match text_input_current_suggestion(model) {
    None => model
    Some(suggestion) => {
      let value = text_input_limit_text_to_char_limit(
        suggestion,
        model.char_limit,
      )
      text_input_normalize_model_validated(
        model,
        value,
        component_char_len(value),
        validator,
      )
    }
  }
}

///|
fn text_input_cycle_suggestion(
  model : TextInputModel,
  delta : Int,
) -> TextInputModel {
  let suggestions = text_input_normalize_suggestions(model.suggestions)
  let count = suggestions.items.length()
  if count == 0 {
    return model
  }
  let raw = (suggestions.selected + delta) % count
  let selected = if raw < 0 { raw + count } else { raw }
  text_input_normalize_model(
    { ..model, suggestions: { items: suggestions.items, selected } },
    model.value,
    model.cursor,
    model.validation,
  )
}

///|
fn text_input_msg_from_action(action : TextInputEditingAction) -> TextInputMsg {
  match action {
    TextInputActionMoveCursorLeft => MoveCursorLeft
    TextInputActionMoveCursorRight => MoveCursorRight
    TextInputActionMoveWordLeft => MoveWordLeft
    TextInputActionMoveWordRight => MoveWordRight
    TextInputActionDeleteBefore => DeleteBefore
    TextInputActionDeleteAfter => DeleteAfter
    TextInputActionDeleteWordBackward => DeleteWordBackward
    TextInputActionDeleteWordForward => DeleteWordForward
    TextInputActionMoveToStart => MoveToStart
    TextInputActionMoveToEnd => MoveToEnd
    TextInputActionAcceptSuggestion => AcceptSuggestion
    TextInputActionCycleSuggestionNext => CycleSuggestionNext
    TextInputActionCycleSuggestionPrev => CycleSuggestionPrev
  }
}

///|
fn text_input_keymap_action(
  keymap : TextInputKeymap,
  key : @pippa.KeyMsg,
) -> TextInputEditingAction? {
  for entry in keymap.bindings {
    if @pippa.matches(entry.binding, key) {
      return Some(entry.action)
    }
  }
  None
}

///|
pub fn text_input_msg_from_input_event(
  event : @pippa.InputEvent,
  keymap? : TextInputKeymap = default_text_input_keymap(),
) -> TextInputMsg? {
  match event {
    @pippa.Paste(text) => Some(InsertText(text))
    @pippa.Key(@pippa.Char(ch)) => Some(InsertChar(ch))
    @pippa.Key(@pippa.Text(text)) => Some(InsertText(text))
    @pippa.Key(key) =>
      match text_input_keymap_action(keymap, key) {
        Some(action) => Some(text_input_msg_from_action(action))
        None => None
      }
    _ => None
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
  keymap : TextInputKeymap,
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
    DeleteWordBackward => {
      let n = component_char_len(model.value)
      let cursor = clamp(model.cursor, 0, n)
      let end = if component_is_grapheme_boundary(model.value, cursor) {
        cursor
      } else {
        component_next_grapheme_boundary(model.value, cursor)
      }
      if end > 0 {
        let start = text_input_word_left(model.value, end)
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
    DeleteWordForward => {
      let n = component_char_len(model.value)
      let cursor = clamp(model.cursor, 0, n)
      if cursor < n {
        let start = component_clamp_grapheme_boundary(model.value, cursor)
        let end = text_input_word_right(model.value, start)
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
    MoveWordLeft =>
      text_input_normalize_model(
        model,
        model.value,
        text_input_word_left(model.value, model.cursor),
        model.validation,
      )
    MoveWordRight =>
      text_input_normalize_model(
        model,
        model.value,
        text_input_word_right(model.value, model.cursor),
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
    AcceptSuggestion => text_input_accept_suggestion(model, validator)
    CycleSuggestionNext => text_input_cycle_suggestion(model, 1)
    CycleSuggestionPrev => text_input_cycle_suggestion(model, -1)
    SetSuggestions(items) =>
      text_input_normalize_model(
        { ..model, suggestions: { items, selected: 0 } },
        model.value,
        model.cursor,
        model.validation,
      )
    HandleInput(event) =>
      match text_input_msg_from_input_event(event, keymap~) {
        Some(next_msg) =>
          text_input_update(model, next_msg, validator, keymap).model
        None => model
      }
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
    let hint = match text_input_suggestion_hint(model) {
      Some(suffix) => @pippa.dim() + suffix + @pippa.reset()
      None => ""
    }
    text_input_visible_slice(
      model,
      component_char_slice(echo_value, 0, echo_cursor) +
      "|" +
      component_char_slice(
        echo_value,
        echo_cursor,
        component_char_len(echo_value),
      ) +
      hint,
    )
  } else {
    text_input_visible_slice(model, echo_value)
  }
}

///|
fn text_input_view(model : TextInputModel) -> String {
  text_input_prompt_view(model) +
  (if model.value == "" && text_input_suggestion_hint(model) is None {
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
  suggestions? : Array[String] = [],
  keymap? : TextInputKeymap = default_text_input_keymap(),
  disabled? : Bool = false,
  validator? : (String) -> Result[Unit, String] = fn(_value) { Ok(()) },
) -> Component[TextInputModel, TextInputMsg] {
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model=text_input_normalize_validated(
          "",
          0,
          width,
          0,
          prompt,
          placeholder,
          echo_mode,
          char_limit,
          { items: suggestions, selected: 0 },
          false,
          disabled,
          validator,
        ),
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model, msg) { text_input_update(model, msg, validator, keymap) },
    view: text_input_view,
  }
}
