///|
/// List component - a delegated, fuzzy-filtering list of structured items.

///|
pub(all) struct ListItem[T] {
  id : String
  filter_value : String
  title : String
  description : String?
  payload : T?
} derive(Debug, Eq)

///|
pub(all) enum ListFilterState {
  Unfiltered
  Filtering
  FilterApplied
} derive(Debug, Eq)

///|
pub(all) struct ListFuzzyMatch {
  score : Int
  matched_indexes : Array[Int]
} derive(Debug, Eq)

///|
pub(all) struct ListVisibleItem[T] {
  item : ListItem[T]
  index : Int
  score : Int
  matched_indexes : Array[Int]
} derive(Debug, Eq)

///|
pub(all) struct ListRenderContext[T] {
  item : ListItem[T]
  selected : Bool
  cursor : Bool
  index : Int
  matched_indexes : Array[Int]
  filter_state : ListFilterState
  filter_query : String
} derive(Debug, Eq)

///|
pub(all) struct ListDelegate[T] {
  render : (ListRenderContext[T]) -> String
  update : ((ListItem[T], String) -> ListItem[T])?
}

///|
pub(all) enum ListAction {
  ListActionCursorUp
  ListActionCursorDown
  ListActionPageUp
  ListActionPageDown
  ListActionFilter
  ListActionClearFilter
  ListActionAccept
  ListActionCancel
  ListActionToggleHelp
  ListActionQuit
} derive(Debug, Eq)

///|
pub(all) struct ListKeyBinding {
  binding : @pippa.Binding
  action : ListAction
} derive(Debug, Eq)

///|
pub(all) struct ListKeymap {
  bindings : Array[ListKeyBinding]
} derive(Debug, Eq)

///|
pub(all) struct ListSections {
  title : Bool
  filter : Bool
  status : Bool
  pagination : Bool
  help : Bool
} derive(Debug, Eq)

///|
pub(all) struct ListStatusToken {
  instance_id : Int64
  generation : Int64
} derive(Debug, Eq)

///|
pub(all) struct ListModel[T] {
  items : Array[ListItem[T]]
  filter_state : ListFilterState
  committed_filter : String
  filter_input : TextInputModel
  cursor : Int
  cursor_id : String?
  selected_id : String?
  page_size : Int
  paginator : PaginatorModel
  title : String
  sections : ListSections
  status_message : String?
  status_instance_id : Int64
  status_generation : Int64
  status_duration_ms : Int
  help : @pippa.HelpModel
  focused : Bool
} derive(Debug, Eq)

///|
pub(all) enum ListMsg[T] {
  CursorUp
  CursorDown
  PageUp
  PageDown
  Select
  Accept
  SetItems(Array[ListItem[T]])
  SetFilter(String)
  StartFilter
  AcceptFilter
  CancelFilter
  FilterInsertChar(Char)
  FilterBackspace
  FilterInput(TextInputMsg)
  ClearFilter
  SetStatus(String, Int)
  ResetStatus
  StatusExpired(ListStatusToken)
  SetSections(ListSections)
  SetTitle(String)
  ToggleHelp
  Focus
  Blur
  HandleInput(@pippa.InputEvent)
  DelegateMsg(String, String)
  Quit
} derive(Debug, Eq)

///|
let list_instance_counter : Ref[Int64] = Ref(0L)

///|
fn list_next_instance_id() -> Int64 {
  list_instance_counter.val = list_instance_counter.val + 1L
  list_instance_counter.val
}

///|
pub fn default_list_sections() -> ListSections {
  { title: true, filter: true, status: true, pagination: true, help: true }
}

///|
fn[T] list_display_text(item : ListItem[T]) -> String {
  if item.title == "" {
    item.filter_value
  } else {
    item.title
  }
}

///|
fn[T] list_default_render(ctx : ListRenderContext[T]) -> String {
  let prefix = if ctx.cursor {
    @pippa.bold() + "> " + @pippa.reset()
  } else {
    "  "
  }
  let selected_prefix = if ctx.selected { @pippa.underline() } else { "" }
  let selected_suffix = if ctx.selected { @pippa.reset() } else { "" }
  let description = match ctx.item.description {
    Some(text) =>
      if text == "" {
        ""
      } else {
        @pippa.dim() + " - " + text + @pippa.reset()
      }
    None => ""
  }
  prefix +
  selected_prefix +
  list_display_text(ctx.item) +
  selected_suffix +
  description
}

///|
pub fn[T] default_list_delegate() -> ListDelegate[T] {
  { render: list_default_render, update: None }
}

///|
pub fn default_list_keymap() -> ListKeymap {
  {
    bindings: [
      { binding: @pippa.up_binding(), action: ListActionCursorUp },
      { binding: @pippa.down_binding(), action: ListActionCursorDown },
      {
        binding: @pippa.binding(
          keys=["pageup", "b"],
          help_key="pgup/b",
          help="page up",
        ),
        action: ListActionPageUp,
      },
      {
        binding: @pippa.binding(
          keys=["pagedown", "f"],
          help_key="pgdn/f",
          help="page down",
        ),
        action: ListActionPageDown,
      },
      {
        binding: @pippa.binding(keys=["/"], help_key="/", help="filter"),
        action: ListActionFilter,
      },
      {
        binding: @pippa.binding(
          keys=["ctrl+l"],
          help_key="C-l",
          help="clear filter",
        ),
        action: ListActionClearFilter,
      },
      { binding: @pippa.enter_binding(), action: ListActionAccept },
      { binding: @pippa.escape_binding(), action: ListActionCancel },
      { binding: @pippa.help_binding(), action: ListActionToggleHelp },
      { binding: @pippa.quit_binding(), action: ListActionQuit },
    ],
  }
}

///|
pub fn list_keymap_override(
  keymap : ListKeymap,
  action : ListAction,
  binding : @pippa.Binding,
) -> ListKeymap {
  let bindings : Array[ListKeyBinding] = []
  let mut replaced = false
  for entry in keymap.bindings {
    if entry.action == action {
      bindings.push({ binding, action })
      replaced = true
    } else {
      bindings.push(entry)
    }
  }
  if !replaced {
    bindings.push({ binding, action })
  }
  { bindings, }
}

///|
pub fn list_keymap_disable(
  keymap : ListKeymap,
  action : ListAction,
) -> ListKeymap {
  let bindings : Array[ListKeyBinding] = []
  for entry in keymap.bindings {
    if entry.action == action {
      bindings.push({
        ..entry,
        binding: @pippa.set_disabled(entry.binding, true),
      })
    } else {
      bindings.push(entry)
    }
  }
  { bindings, }
}

///|
fn list_keymap_group_name(action : ListAction) -> String {
  match action {
    ListActionCursorUp => "Navigation"
    ListActionCursorDown => "Navigation"
    ListActionPageUp => "Navigation"
    ListActionPageDown => "Navigation"
    ListActionFilter => "Filtering"
    ListActionClearFilter => "Filtering"
    ListActionAccept => "Selection"
    ListActionCancel => "Filtering"
    ListActionToggleHelp => "System"
    ListActionQuit => "System"
  }
}

///|
fn list_group_bindings(
  keymap : ListKeymap,
  group_name : String,
) -> Array[@pippa.Binding] {
  let bindings : Array[@pippa.Binding] = []
  for entry in keymap.bindings {
    if list_keymap_group_name(entry.action) == group_name {
      bindings.push(entry.binding)
    }
  }
  bindings
}

///|
pub fn list_keymap_help(keymap : ListKeymap) -> @pippa.KeyMap {
  @pippa.keymap_from_groups([
    @pippa.keymap_group("Navigation", list_group_bindings(keymap, "Navigation")),
    @pippa.keymap_group("Filtering", list_group_bindings(keymap, "Filtering")),
    @pippa.keymap_group("Selection", list_group_bindings(keymap, "Selection")),
    @pippa.keymap_group("System", list_group_bindings(keymap, "System")),
  ])
}

///|
pub fn list_help_model(
  keymap? : ListKeymap = default_list_keymap(),
  show_full? : Bool = false,
  width? : Int = 0,
) -> @pippa.HelpModel {
  { keymap: list_keymap_help(keymap), show_full, width }
}

///|
pub fn list_help_view(
  keymap? : ListKeymap = default_list_keymap(),
  show_full? : Bool = false,
  width? : Int = 0,
) -> String {
  @pippa.help_view(list_help_model(keymap~, show_full~, width~))
}

///|
fn list_action_from_keymap(
  keymap : ListKeymap,
  key : @pippa.KeyMsg,
) -> ListAction? {
  for entry in keymap.bindings {
    if @pippa.matches(entry.binding, key) {
      return Some(entry.action)
    }
  }
  None
}

///|
fn[T] list_msg_from_action(action : ListAction) -> ListMsg[T] {
  match action {
    ListActionCursorUp => CursorUp
    ListActionCursorDown => CursorDown
    ListActionPageUp => PageUp
    ListActionPageDown => PageDown
    ListActionFilter => StartFilter
    ListActionClearFilter => ClearFilter
    ListActionAccept => Accept
    ListActionCancel => CancelFilter
    ListActionToggleHelp => ToggleHelp
    ListActionQuit => Quit
  }
}

///|
pub fn[T] list_msg_from_input_event(
  event : @pippa.InputEvent,
  keymap? : ListKeymap = default_list_keymap(),
) -> ListMsg[T]? {
  match event {
    @pippa.Key(key) =>
      match list_action_from_keymap(keymap, key) {
        Some(action) => Some(list_msg_from_action(action))
        None => None
      }
    _ => None
  }
}

///|
fn list_text_input_with_value(
  input : TextInputModel,
  value : String,
  focused : Bool,
) -> TextInputModel {
  text_input_normalize_state(
    value,
    component_char_len(value),
    input.width,
    input.scroll_col,
    input.prompt,
    input.placeholder,
    input.echo_mode,
    input.char_limit,
    input.validation,
    input.suggestions,
    focused,
    input.disabled,
  )
}

///|
pub fn[T] list_filter_query(model : ListModel[T]) -> String {
  match model.filter_state {
    Unfiltered => ""
    Filtering => model.filter_input.value
    FilterApplied => model.committed_filter
  }
}

///|
fn list_empty_match() -> ListFuzzyMatch {
  { score: 0, matched_indexes: [] }
}

///|
pub fn list_fuzzy_match(value : String, query : String) -> ListFuzzyMatch? {
  if query == "" {
    return Some(list_empty_match())
  }
  let value_chars = value.to_lower().to_array()
  let query_chars = query.to_lower().to_array()
  if query_chars.is_empty() {
    return Some(list_empty_match())
  }
  let matched_indexes : Array[Int] = []
  let mut search_from = 0
  for query_char in query_chars {
    let mut found = -1
    let mut i = search_from
    while i < value_chars.length() && found < 0 {
      if value_chars[i] == query_char {
        found = i
      }
      i = i + 1
    }
    if found < 0 {
      return None
    }
    matched_indexes.push(found)
    search_from = found + 1
  }
  let first = matched_indexes[0]
  let last = matched_indexes[matched_indexes.length() - 1]
  let span = last - first + 1
  let gap_count = span - matched_indexes.length()
  let mut score = 1000 -
    first * 8 -
    gap_count * 24 -
    (value_chars.length() - query_chars.length()).max(0)
  if first == 0 {
    score = score + 100
  }
  if gap_count == 0 {
    score = score + 200
  }
  let mut consecutive_pairs = 0
  for i in 1..<matched_indexes.length() {
    if matched_indexes[i] == matched_indexes[i - 1] + 1 {
      consecutive_pairs = consecutive_pairs + 1
    }
  }
  score = score + consecutive_pairs * 20
  Some({ score, matched_indexes })
}

///|
fn[T] list_visible_item_from_match(
  item : ListItem[T],
  index : Int,
  fuzzy_match : ListFuzzyMatch,
) -> ListVisibleItem[T] {
  {
    item,
    index,
    score: fuzzy_match.score,
    matched_indexes: fuzzy_match.matched_indexes,
  }
}

///|
pub fn[T] list_visible_items(model : ListModel[T]) -> Array[ListVisibleItem[T]] {
  let query = list_filter_query(model)
  let visible : Array[ListVisibleItem[T]] = []
  if query == "" {
    for index, item in model.items {
      visible.push(
        list_visible_item_from_match(item, index, list_empty_match()),
      )
    }
    return visible
  }
  for index, item in model.items {
    match list_fuzzy_match(item.filter_value, query) {
      Some(fuzzy_match) =>
        visible.push(list_visible_item_from_match(item, index, fuzzy_match))
      None => ()
    }
  }
  visible.sort_by(fn(a, b) {
    if a.score > b.score {
      -1
    } else if a.score < b.score {
      1
    } else {
      a.index.compare(b.index)
    }
  })
  visible
}

///|
fn[T] list_find_item_by_id(
  items : Array[ListItem[T]],
  id : String,
) -> ListItem[T]? {
  for item in items {
    if item.id == id {
      return Some(item)
    }
  }
  None
}

///|
fn[T] list_id_exists(items : Array[ListItem[T]], id : String) -> Bool {
  list_find_item_by_id(items, id) is Some(_)
}

///|
pub fn[T] list_selected_item(model : ListModel[T]) -> ListItem[T]? {
  match model.selected_id {
    Some(id) => list_find_item_by_id(model.items, id)
    None => None
  }
}

///|
fn[T] list_visible_index_for_id(
  visible : Array[ListVisibleItem[T]],
  id : String,
) -> Int? {
  for i, entry in visible {
    if entry.item.id == id {
      return Some(i)
    }
  }
  None
}

///|
fn list_page_size(page_size : Int) -> Int {
  page_size.max(1)
}

///|
fn list_page_for_cursor(cursor : Int, per_page : Int) -> Int {
  cursor / per_page
}

///|
fn[T] list_normalize(model : ListModel[T]) -> ListModel[T] {
  let page_size = list_page_size(model.page_size)
  let selected_id = match model.selected_id {
    Some(id) => if list_id_exists(model.items, id) { Some(id) } else { None }
    None => None
  }
  let base = { ..model, page_size, selected_id }
  let visible = list_visible_items(base)
  let cursor = if visible.is_empty() {
    0
  } else {
    match base.cursor_id {
      Some(id) =>
        match list_visible_index_for_id(visible, id) {
          Some(index) => index
          None => base.cursor.max(0).min(visible.length() - 1)
        }
      None => base.cursor.max(0).min(visible.length() - 1)
    }
  }
  let cursor_id = if visible.is_empty() {
    None
  } else {
    Some(visible[cursor].item.id)
  }
  let paginator = paginator_normalize(
    list_page_for_cursor(cursor, page_size),
    page_size,
    visible.length(),
  )
  { ..base, cursor, cursor_id, paginator }
}

///|
fn[T] list_set_cursor(model : ListModel[T], cursor : Int) -> ListModel[T] {
  let visible = list_visible_items(model)
  if visible.is_empty() {
    list_normalize({ ..model, cursor: 0, cursor_id: None })
  } else {
    let safe_cursor = cursor.max(0).min(visible.length() - 1)
    list_normalize({
      ..model,
      cursor: safe_cursor,
      cursor_id: Some(visible[safe_cursor].item.id),
    })
  }
}

///|
fn[T] list_move_cursor(model : ListModel[T], delta : Int) -> ListModel[T] {
  list_set_cursor(model, model.cursor + delta)
}

///|
fn[T] list_start_filter(model : ListModel[T]) -> ListModel[T] {
  let query = list_filter_query(model)
  list_normalize({
    ..model,
    filter_state: Filtering,
    filter_input: list_text_input_with_value(model.filter_input, query, true),
  })
}

///|
fn list_filter_state_for_query(query : String) -> ListFilterState {
  if query == "" {
    Unfiltered
  } else {
    FilterApplied
  }
}

///|
fn[T] list_set_committed_filter(
  model : ListModel[T],
  query : String,
) -> ListModel[T] {
  list_normalize({
    ..model,
    filter_state: list_filter_state_for_query(query),
    committed_filter: query,
    filter_input: list_text_input_with_value(model.filter_input, query, false),
    cursor: 0,
    cursor_id: None,
  })
}

///|
fn[T] list_accept_filter(model : ListModel[T]) -> ListModel[T] {
  list_set_committed_filter(model, model.filter_input.value)
}

///|
fn[T] list_cancel_filter(model : ListModel[T]) -> ListModel[T] {
  list_normalize({
    ..model,
    filter_state: list_filter_state_for_query(model.committed_filter),
    filter_input: list_text_input_with_value(
      model.filter_input,
      model.committed_filter,
      false,
    ),
  })
}

///|
fn[T] list_apply_filter_input(
  model : ListModel[T],
  msg : TextInputMsg,
  filter_component : Component[TextInputModel, TextInputMsg],
) -> ListModel[T] {
  let editing = if model.filter_state == Filtering {
    model
  } else {
    list_start_filter(model)
  }
  let next_input = (filter_component.update)(editing.filter_input, msg).model
  list_normalize({ ..editing, filter_input: next_input })
}

///|
fn[T] list_status_token(model : ListModel[T]) -> ListStatusToken {
  { instance_id: model.status_instance_id, generation: model.status_generation }
}

///|
fn[T] list_status_cmd(
  duration_ms : Int,
  token : ListStatusToken,
) -> @pippa.Cmd[ListMsg[T]] {
  @pippa.Cmd::after(duration_ms.max(1), fn() { StatusExpired(token) })
}

///|
fn[T] list_set_status(
  model : ListModel[T],
  message : String,
  duration_ms : Int,
) -> @pippa.UpdateResult[ListModel[T], ListMsg[T]] {
  let generation = model.status_generation + 1L
  let next = {
    ..model,
    status_message: Some(message),
    status_generation: generation,
    status_duration_ms: duration_ms.max(1),
  }
  let token = list_status_token(next)
  @pippa.UpdateResult::new(
    model=list_normalize(next),
    cmd=list_status_cmd(duration_ms, token),
  )
}

///|
fn[T] list_reset_status(model : ListModel[T]) -> ListModel[T] {
  list_normalize({
    ..model,
    status_message: None,
    status_generation: model.status_generation + 1L,
  })
}

///|
fn[T] list_expire_status(
  model : ListModel[T],
  token : ListStatusToken,
) -> ListModel[T] {
  if token == list_status_token(model) {
    list_normalize({ ..model, status_message: None })
  } else {
    list_normalize(model)
  }
}

///|
fn[T] list_apply_delegate_update(
  model : ListModel[T],
  item_id : String,
  message : String,
  delegate : ListDelegate[T],
) -> ListModel[T] {
  match delegate.update {
    None => list_normalize(model)
    Some(update_item) => {
      let items : Array[ListItem[T]] = []
      for item in model.items {
        if item.id == item_id {
          items.push(update_item(item, message))
        } else {
          items.push(item)
        }
      }
      list_normalize({ ..model, items, })
    }
  }
}

///|
fn list_input_event_is_text(event : @pippa.InputEvent) -> Bool {
  match event {
    @pippa.Key(@pippa.Char(_)) => true
    @pippa.Key(@pippa.Text(_)) => true
    @pippa.Paste(_) => true
    _ => false
  }
}

///|
fn[T] list_apply_action(
  model : ListModel[T],
  action : ListAction,
) -> @pippa.UpdateResult[ListModel[T], ListMsg[T]] {
  let next = match action {
    ListActionCursorUp => list_move_cursor(model, -1)
    ListActionCursorDown => list_move_cursor(model, 1)
    ListActionPageUp => list_move_cursor(model, -model.page_size)
    ListActionPageDown => list_move_cursor(model, model.page_size)
    ListActionFilter => list_start_filter(model)
    ListActionClearFilter => list_set_committed_filter(model, "")
    ListActionAccept =>
      if model.filter_state == Filtering {
        list_accept_filter(model)
      } else {
        match list_visible_items(model) {
          [] => list_normalize(model)
          visible => {
            let safe_cursor = model.cursor.max(0).min(visible.length() - 1)
            list_normalize({
              ..model,
              selected_id: Some(visible[safe_cursor].item.id),
            })
          }
        }
      }
    ListActionCancel =>
      if model.filter_state == Filtering {
        list_cancel_filter(model)
      } else {
        list_normalize(model)
      }
    ListActionToggleHelp =>
      list_normalize({ ..model, help: @pippa.toggle_help(model.help) })
    ListActionQuit => model
  }
  let cmd : @pippa.Cmd[ListMsg[T]] = match action {
    ListActionQuit => @pippa.Cmd::quit()
    _ => @pippa.Cmd::none()
  }
  @pippa.UpdateResult::new(model=next, cmd~)
}

///|
fn[T] list_handle_input(
  model : ListModel[T],
  event : @pippa.InputEvent,
  keymap : ListKeymap,
  filter_component : Component[TextInputModel, TextInputMsg],
) -> @pippa.UpdateResult[ListModel[T], ListMsg[T]] {
  if !model.focused {
    return @pippa.UpdateResult::new(
      model=list_normalize(model),
      cmd=@pippa.Cmd::none(),
    )
  }
  match event {
    @pippa.Key(key) =>
      if model.filter_state == Filtering && list_input_event_is_text(event) {
        match text_input_msg_from_input_event(event) {
          Some(text_msg) =>
            @pippa.UpdateResult::new(
              model=list_apply_filter_input(model, text_msg, filter_component),
              cmd=@pippa.Cmd::none(),
            )
          None =>
            @pippa.UpdateResult::new(
              model=list_normalize(model),
              cmd=@pippa.Cmd::none(),
            )
        }
      } else {
        match list_action_from_keymap(keymap, key) {
          Some(action) =>
            list_apply_action(model, action)
          None =>
            if model.filter_state == Filtering {
              match text_input_msg_from_input_event(event) {
                Some(text_msg) =>
                  @pippa.UpdateResult::new(
                    model=list_apply_filter_input(
                      model, text_msg, filter_component,
                    ),
                    cmd=@pippa.Cmd::none(),
                  )
                None =>
                  @pippa.UpdateResult::new(
                    model=list_normalize(model),
                    cmd=@pippa.Cmd::none(),
                  )
              }
            } else {
              @pippa.UpdateResult::new(
                model=list_normalize(model),
                cmd=@pippa.Cmd::none(),
              )
            }
        }
      }
    @pippa.Paste(_) =>
      if model.filter_state == Filtering {
        match text_input_msg_from_input_event(event) {
          Some(text_msg) =>
            @pippa.UpdateResult::new(
              model=list_apply_filter_input(model, text_msg, filter_component),
              cmd=@pippa.Cmd::none(),
            )
          None =>
            @pippa.UpdateResult::new(
              model=list_normalize(model),
              cmd=@pippa.Cmd::none(),
            )
        }
      } else {
        @pippa.UpdateResult::new(
          model=list_normalize(model),
          cmd=@pippa.Cmd::none(),
        )
      }
    _ =>
      @pippa.UpdateResult::new(
        model=list_normalize(model),
        cmd=@pippa.Cmd::none(),
      )
  }
}

///|
fn[T] list_update(
  model : ListModel[T],
  msg : ListMsg[T],
  delegate : ListDelegate[T],
  keymap : ListKeymap,
  filter_component : Component[TextInputModel, TextInputMsg],
) -> @pippa.UpdateResult[ListModel[T], ListMsg[T]] {
  match msg {
    CursorUp =>
      @pippa.UpdateResult::new(
        model=list_move_cursor(model, -1),
        cmd=@pippa.Cmd::none(),
      )
    CursorDown =>
      @pippa.UpdateResult::new(
        model=list_move_cursor(model, 1),
        cmd=@pippa.Cmd::none(),
      )
    PageUp =>
      @pippa.UpdateResult::new(
        model=list_move_cursor(model, -model.page_size),
        cmd=@pippa.Cmd::none(),
      )
    PageDown =>
      @pippa.UpdateResult::new(
        model=list_move_cursor(model, model.page_size),
        cmd=@pippa.Cmd::none(),
      )
    Select =>
      @pippa.UpdateResult::new(
        model=match list_visible_items(model) {
          [] => list_normalize(model)
          visible => {
            let safe_cursor = model.cursor.max(0).min(visible.length() - 1)
            list_normalize({
              ..model,
              selected_id: Some(visible[safe_cursor].item.id),
            })
          }
        },
        cmd=@pippa.Cmd::none(),
      )
    Accept =>
      list_apply_action(model, ListActionAccept)
    SetItems(items) =>
      @pippa.UpdateResult::new(
        model=list_normalize({ ..model, items, }),
        cmd=@pippa.Cmd::none(),
      )
    SetFilter(query) =>
      @pippa.UpdateResult::new(
        model=list_set_committed_filter(model, query),
        cmd=@pippa.Cmd::none(),
      )
    StartFilter =>
      @pippa.UpdateResult::new(
        model=list_start_filter(model),
        cmd=@pippa.Cmd::none(),
      )
    AcceptFilter =>
      @pippa.UpdateResult::new(
        model=list_accept_filter(model),
        cmd=@pippa.Cmd::none(),
      )
    CancelFilter =>
      @pippa.UpdateResult::new(
        model=list_cancel_filter(model),
        cmd=@pippa.Cmd::none(),
      )
    FilterInsertChar(ch) =>
      @pippa.UpdateResult::new(
        model=list_apply_filter_input(model, InsertChar(ch), filter_component),
        cmd=@pippa.Cmd::none(),
      )
    FilterBackspace =>
      @pippa.UpdateResult::new(
        model=list_apply_filter_input(model, DeleteBefore, filter_component),
        cmd=@pippa.Cmd::none(),
      )
    FilterInput(text_msg) =>
      @pippa.UpdateResult::new(
        model=list_apply_filter_input(model, text_msg, filter_component),
        cmd=@pippa.Cmd::none(),
      )
    ClearFilter =>
      @pippa.UpdateResult::new(
        model=list_set_committed_filter(model, ""),
        cmd=@pippa.Cmd::none(),
      )
    SetStatus(message, duration_ms) =>
      list_set_status(model, message, duration_ms)
    ResetStatus =>
      @pippa.UpdateResult::new(
        model=list_reset_status(model),
        cmd=@pippa.Cmd::none(),
      )
    StatusExpired(token) =>
      @pippa.UpdateResult::new(
        model=list_expire_status(model, token),
        cmd=@pippa.Cmd::none(),
      )
    SetSections(sections) =>
      @pippa.UpdateResult::new(
        model=list_normalize({ ..model, sections, }),
        cmd=@pippa.Cmd::none(),
      )
    SetTitle(title) =>
      @pippa.UpdateResult::new(
        model=list_normalize({ ..model, title, }),
        cmd=@pippa.Cmd::none(),
      )
    ToggleHelp =>
      @pippa.UpdateResult::new(
        model=list_normalize({ ..model, help: @pippa.toggle_help(model.help) }),
        cmd=@pippa.Cmd::none(),
      )
    Focus =>
      @pippa.UpdateResult::new(
        model=list_normalize({ ..model, focused: true }),
        cmd=@pippa.Cmd::none(),
      )
    Blur =>
      @pippa.UpdateResult::new(
        model=list_normalize({ ..model, focused: false }),
        cmd=@pippa.Cmd::none(),
      )
    HandleInput(event) =>
      list_handle_input(model, event, keymap, filter_component)
    DelegateMsg(item_id, message) =>
      @pippa.UpdateResult::new(
        model=list_apply_delegate_update(model, item_id, message, delegate),
        cmd=@pippa.Cmd::none(),
      )
    Quit =>
      @pippa.UpdateResult::new(
        model=list_normalize(model),
        cmd=@pippa.Cmd::quit(),
      )
  }
}

///|
fn list_page_start(paginator : PaginatorModel) -> Int {
  paginator.page * paginator.per_page
}

///|
fn[T] list_render_items(
  model : ListModel[T],
  delegate : ListDelegate[T],
) -> Array[String] {
  let visible = list_visible_items(model)
  if visible.is_empty() {
    return [@pippa.dim() + "(no items)" + @pippa.reset()]
  }
  let lines : Array[String] = []
  let page_start = list_page_start(model.paginator)
  let page_end = (page_start + model.paginator.per_page).min(visible.length())
  for i in page_start..<page_end {
    let entry = visible[i]
    lines.push(
      (delegate.render)({
        item: entry.item,
        selected: model.selected_id == Some(entry.item.id),
        cursor: i == model.cursor,
        index: i,
        matched_indexes: entry.matched_indexes,
        filter_state: model.filter_state,
        filter_query: list_filter_query(model),
      }),
    )
  }
  lines
}

///|
fn[T] list_filter_view(
  model : ListModel[T],
  filter_component : Component[TextInputModel, TextInputMsg],
) -> String {
  if model.filter_state == Filtering {
    (filter_component.view)(model.filter_input)
  } else {
    "Filter: " + list_filter_query(model)
  }
}

///|
fn[T] list_view(
  model : ListModel[T],
  delegate : ListDelegate[T],
  filter_component : Component[TextInputModel, TextInputMsg],
) -> String {
  let model = list_normalize(model)
  let lines : Array[String] = []
  if model.sections.title && model.title != "" {
    lines.push(model.title)
  }
  if model.sections.filter && model.filter_state != Unfiltered {
    lines.push(list_filter_view(model, filter_component))
  }
  if model.sections.status {
    match model.status_message {
      Some(message) => lines.push(message)
      None => ()
    }
  }
  for line in list_render_items(model, delegate) {
    lines.push(line)
  }
  if model.sections.pagination {
    lines.push(
      @pippa.dim() +
      (paginator(per_page=model.paginator.per_page).view)(model.paginator) +
      @pippa.reset(),
    )
  }
  if model.sections.help {
    let help = @pippa.help_view(model.help)
    if help != "" {
      lines.push(@pippa.dim() + help + @pippa.reset())
    }
  }
  lines.join("\n")
}

///|
pub fn[T] ListItem::new(
  id~ : String,
  filter_value~ : String,
  title? : String = "",
  description? : String? = None,
  payload? : T? = None,
) -> ListItem[T] {
  { id, filter_value, title, description, payload }
}

///|
pub fn list_items_from_strings(
  items : Array[String],
) -> Array[ListItem[String]] {
  let structured : Array[ListItem[String]] = []
  for index, item in items {
    structured.push({
      id: index.to_string() + ":" + item,
      filter_value: item,
      title: item,
      description: None,
      payload: Some(item),
    })
  }
  structured
}

///|
pub fn string_list(
  items? : Array[String] = [],
  page_size? : Int = 8,
  title? : String = "",
  sections? : ListSections = default_list_sections(),
  keymap? : ListKeymap = default_list_keymap(),
  status_duration_ms? : Int = 2000,
  focused? : Bool = true,
) -> Component[ListModel[String], ListMsg[String]] {
  list(
    items=list_items_from_strings(items),
    page_size~,
    title~,
    sections~,
    keymap~,
    status_duration_ms~,
    focused~,
  )
}

///|
pub fn[T] list(
  items? : Array[ListItem[T]] = [],
  page_size? : Int = 8,
  title? : String = "",
  sections? : ListSections = default_list_sections(),
  keymap? : ListKeymap = default_list_keymap(),
  delegate? : ListDelegate[T] = default_list_delegate(),
  status_duration_ms? : Int = 2000,
  focused? : Bool = true,
) -> Component[ListModel[T], ListMsg[T]] {
  let safe_page_size = list_page_size(page_size)
  let filter_component = text_input(placeholder="Filter", prompt="Filter: ")
  {
    init: fn() {
      let instance_id = list_next_instance_id()
      @pippa.UpdateResult::new(
        model=list_normalize({
          items,
          filter_state: Unfiltered,
          committed_filter: "",
          filter_input: (filter_component.init)().model,
          cursor: 0,
          cursor_id: None,
          selected_id: None,
          page_size: safe_page_size,
          paginator: paginator_normalize(0, safe_page_size, items.length()),
          title,
          sections,
          status_message: None,
          status_instance_id: instance_id,
          status_generation: 0L,
          status_duration_ms: status_duration_ms.max(1),
          help: list_help_model(keymap~),
          focused,
        }),
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model, msg) {
      list_update(model, msg, delegate, keymap, filter_component)
    },
    view: fn(model) { list_view(model, delegate, filter_component) },
  }
}
