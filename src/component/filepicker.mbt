///|
/// Filepicker component — directory navigation and file selection for native
/// Pippa applications.

///|
pub(all) struct FileEntry {
  name : String
  path : String
  is_dir : Bool
  is_symlink : Bool
  permissions : String
  size : Int
  hidden : Bool
  disabled : Bool
} derive(Debug, Eq)

///|
pub(all) struct FilepickerViewState {
  selected : Int
  min : Int
  max : Int
} derive(Debug, Eq)

///|
pub(all) struct FilepickerTextStyle {
  prefix : String
  suffix : String
} derive(Debug, Eq)

///|
pub(all) struct FilepickerStyles {
  cursor : FilepickerTextStyle
  disabled_cursor : FilepickerTextStyle
  directory : FilepickerTextStyle
  file : FilepickerTextStyle
  symlink : FilepickerTextStyle
  disabled : FilepickerTextStyle
  permissions : FilepickerTextStyle
  size : FilepickerTextStyle
  selected : FilepickerTextStyle
  status : FilepickerTextStyle
  error : FilepickerTextStyle
  loading : FilepickerTextStyle
  empty : FilepickerTextStyle
} derive(Debug, Eq)

///|
pub(all) enum FilepickerAction {
  FilepickerActionMoveUp
  FilepickerActionMoveDown
  FilepickerActionPageUp
  FilepickerActionPageDown
  FilepickerActionMoveToTop
  FilepickerActionMoveToBottom
  FilepickerActionOpen
  FilepickerActionSelect
  FilepickerActionBack
  FilepickerActionToggleHidden
} derive(Debug, Eq)

///|
pub(all) struct FilepickerKeyBinding {
  binding : @pippa.Binding
  action : FilepickerAction
} derive(Debug, Eq)

///|
pub(all) struct FilepickerKeymap {
  bindings : Array[FilepickerKeyBinding]
} derive(Debug, Eq)

///|
pub(all) struct FilepickerModel {
  current_directory : String
  entries : Array[FileEntry]
  cursor : Int
  selected_path : String?
  height : Int
  show_hidden : Bool
  show_permissions : Bool
  show_size : Bool
  allow_files : Bool
  allow_directories : Bool
  allowed_extensions : Array[String]
  allowed_types : Array[String]
  loading : Bool
  scan_handle : Int?
  error : String?
  auto_height : Bool
  available_height : Int
  min_index : Int
  max_index : Int
  selected_stack : Array[Int]
  min_stack : Array[Int]
  max_stack : Array[Int]
  pending_restore : FilepickerViewState?
} derive(Debug, Eq)

///|
pub(all) enum FilepickerMsg {
  Refresh
  CursorUp
  CursorDown
  PageUp
  PageDown
  MoveToTop
  MoveToBottom
  Open
  Select
  Back
  ToggleHidden
  SetDirectory(String)
  SetHeight(Int)
  SetAvailableHeight(Int)
  SetAutoHeight(Bool)
  SetShowPermissions(Bool)
  SetShowSize(Bool)
  SetShowHidden(Bool)
  SetAllowedExtensions(Array[String])
  SetAllowedTypes(Array[String])
  SetSelectionMode(Bool, Bool)
  HandleInput(@pippa.InputEvent)
  ScanOpened(String, Int)
  ContinueScan(String, Int)
  ScanChunk(String, Int, Array[FileEntry])
  ScanFinished(String, Int)
  LoadFailed(String)
} derive(Debug, Eq)

///|
priv struct FilepickerRenderColumns {
  cursor_width : Int
  permissions_width : Int
  size_width : Int
}

///|
pub fn filepicker_text_style(
  prefix? : String = "",
  suffix? : String = "",
) -> FilepickerTextStyle {
  { prefix, suffix }
}

///|
pub fn default_filepicker_styles() -> FilepickerStyles {
  let reset = @pippa.reset()
  {
    cursor: filepicker_text_style(prefix=@pippa.bold(), suffix=reset),
    disabled_cursor: filepicker_text_style(prefix=@pippa.dim(), suffix=reset),
    directory: filepicker_text_style(
      prefix=@pippa.fg_rgb(90, 130, 220),
      suffix=reset,
    ),
    file: filepicker_text_style(),
    symlink: filepicker_text_style(
      prefix=@pippa.fg_rgb(30, 160, 150),
      suffix=reset,
    ),
    disabled: filepicker_text_style(prefix=@pippa.dim(), suffix=reset),
    permissions: filepicker_text_style(prefix=@pippa.dim(), suffix=reset),
    size: filepicker_text_style(prefix=@pippa.dim(), suffix=reset),
    selected: filepicker_text_style(prefix=@pippa.underline(), suffix=reset),
    status: filepicker_text_style(prefix=@pippa.dim(), suffix=reset),
    error: filepicker_text_style(prefix=@pippa.fg_color(1), suffix=reset),
    loading: filepicker_text_style(prefix=@pippa.dim(), suffix=reset),
    empty: filepicker_text_style(prefix=@pippa.dim(), suffix=reset),
  }
}

///|
fn filepicker_apply_style(style : FilepickerTextStyle, text : String) -> String {
  if style.prefix == "" && style.suffix == "" {
    text
  } else {
    style.prefix + text + style.suffix
  }
}

///|
pub fn default_filepicker_keymap() -> FilepickerKeymap {
  {
    bindings: [
      {
        binding: @pippa.binding(keys=["g"], help_key="g", help="first"),
        action: FilepickerActionMoveToTop,
      },
      {
        binding: @pippa.binding(keys=["G"], help_key="G", help="last"),
        action: FilepickerActionMoveToBottom,
      },
      {
        binding: @pippa.binding(
          keys=["up", "k", "ctrl+p"],
          help_key="↑/k",
          help="up",
        ),
        action: FilepickerActionMoveUp,
      },
      {
        binding: @pippa.binding(
          keys=["down", "j", "ctrl+n"],
          help_key="↓/j",
          help="down",
        ),
        action: FilepickerActionMoveDown,
      },
      {
        binding: @pippa.binding(
          keys=["pageup", "K"],
          help_key="pgup/K",
          help="page up",
        ),
        action: FilepickerActionPageUp,
      },
      {
        binding: @pippa.binding(
          keys=["pagedown", "J"],
          help_key="pgdn/J",
          help="page down",
        ),
        action: FilepickerActionPageDown,
      },
      {
        binding: @pippa.binding(
          keys=["left", "h", "backspace", "escape"],
          help_key="←/h",
          help="back",
        ),
        action: FilepickerActionBack,
      },
      {
        binding: @pippa.binding(
          keys=["right", "l", "enter"],
          help_key="→/l",
          help="open",
        ),
        action: FilepickerActionOpen,
      },
      {
        binding: @pippa.binding(keys=[" "], help_key="space", help="select"),
        action: FilepickerActionSelect,
      },
      {
        binding: @pippa.binding(keys=["."], help_key=".", help="hidden"),
        action: FilepickerActionToggleHidden,
      },
    ],
  }
}

///|
pub fn filepicker_keymap_override(
  keymap : FilepickerKeymap,
  action : FilepickerAction,
  binding : @pippa.Binding,
) -> FilepickerKeymap {
  let bindings : Array[FilepickerKeyBinding] = []
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
pub fn filepicker_keymap_disable(
  keymap : FilepickerKeymap,
  action : FilepickerAction,
) -> FilepickerKeymap {
  let bindings : Array[FilepickerKeyBinding] = []
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
fn filepicker_keymap_group_name(action : FilepickerAction) -> String {
  match action {
    FilepickerActionMoveUp => "Navigation"
    FilepickerActionMoveDown => "Navigation"
    FilepickerActionPageUp => "Navigation"
    FilepickerActionPageDown => "Navigation"
    FilepickerActionMoveToTop => "Navigation"
    FilepickerActionMoveToBottom => "Navigation"
    FilepickerActionOpen => "Selection"
    FilepickerActionSelect => "Selection"
    FilepickerActionBack => "Navigation"
    FilepickerActionToggleHidden => "Display"
  }
}

///|
fn filepicker_group_bindings(
  keymap : FilepickerKeymap,
  group_name : String,
) -> Array[@pippa.Binding] {
  let bindings : Array[@pippa.Binding] = []
  for entry in keymap.bindings {
    if filepicker_keymap_group_name(entry.action) == group_name {
      bindings.push(entry.binding)
    }
  }
  bindings
}

///|
pub fn filepicker_keymap_help(keymap : FilepickerKeymap) -> @pippa.KeyMap {
  @pippa.keymap_from_groups([
    @pippa.keymap_group(
      "Navigation",
      filepicker_group_bindings(keymap, "Navigation"),
    ),
    @pippa.keymap_group(
      "Selection",
      filepicker_group_bindings(keymap, "Selection"),
    ),
    @pippa.keymap_group("Display", filepicker_group_bindings(keymap, "Display")),
  ])
}

///|
pub fn filepicker_help_model(
  keymap? : FilepickerKeymap = default_filepicker_keymap(),
  show_full? : Bool = false,
  width? : Int = 0,
) -> @pippa.HelpModel {
  { keymap: filepicker_keymap_help(keymap), show_full, width }
}

///|
pub fn filepicker_help_view(
  keymap? : FilepickerKeymap = default_filepicker_keymap(),
  show_full? : Bool = false,
  width? : Int = 0,
) -> String {
  @pippa.help_view(filepicker_help_model(keymap~, show_full~, width~))
}

///|
fn filepicker_action_from_keymap(
  keymap : FilepickerKeymap,
  key : @pippa.KeyMsg,
) -> FilepickerAction? {
  for entry in keymap.bindings {
    if @pippa.matches(entry.binding, key) {
      return Some(entry.action)
    }
  }
  None
}

///|
fn filepicker_msg_from_action(action : FilepickerAction) -> FilepickerMsg {
  match action {
    FilepickerActionMoveUp => CursorUp
    FilepickerActionMoveDown => CursorDown
    FilepickerActionPageUp => PageUp
    FilepickerActionPageDown => PageDown
    FilepickerActionMoveToTop => MoveToTop
    FilepickerActionMoveToBottom => MoveToBottom
    FilepickerActionOpen => Open
    FilepickerActionSelect => Select
    FilepickerActionBack => Back
    FilepickerActionToggleHidden => ToggleHidden
  }
}

///|
pub fn filepicker_msg_from_input_event(
  event : @pippa.InputEvent,
  keymap? : FilepickerKeymap = default_filepicker_keymap(),
) -> FilepickerMsg? {
  match event {
    @pippa.Key(key) =>
      match filepicker_action_from_keymap(keymap, key) {
        Some(action) => Some(filepicker_msg_from_action(action))
        None => None
      }
    _ => None
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn filepicker_entry(
  name : String,
  path : String,
  is_dir : Bool,
  is_symlink? : Bool = false,
  permissions? : String = "",
  size? : Int = 0,
  hidden? : Bool = false,
  disabled? : Bool = false,
) -> FileEntry {
  {
    name,
    path,
    is_dir,
    is_symlink,
    permissions: if permissions == "" {
      if is_dir {
        "drwxr-xr-x"
      } else {
        "-rw-r--r--"
      }
    } else {
      permissions
    },
    size: size.max(0),
    hidden,
    disabled,
  }
}

///|
fn filepicker_initial_directory(current_directory : String) -> String {
  if current_directory != "" {
    current_directory
  } else {
    match @env.current_dir() {
      Some(path) => path
      None => "."
    }
  }
}

///|
fn filepicker_parent_dir(path : String) -> String {
  if path == "" || path == "." || path == "/" {
    return if path == "" { "." } else { path }
  }
  let trimmed = if path.length() > 1 && path.has_suffix("/") {
    path[:path.length() - 1].to_owned()
  } else {
    path
  }
  match trimmed.rev_find("/") {
    Some(0) => "/"
    Some(i) => trimmed[:i].to_owned()
    None => "."
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn filepicker_join_path(dir : String, name : String) -> String {
  if dir == "" || dir == "." {
    name
  } else if dir == "/" {
    "/" + name
  } else if dir.has_suffix("/") {
    dir + name
  } else {
    dir + "/" + name
  }
}

///|
/// Hidden detection uses scanner-provided platform metadata when available.
/// Native POSIX builds keep dotfile behavior and additionally honor UF_HIDDEN
/// on platforms that expose it; fake/test entries may set `hidden` directly.
fn filepicker_is_hidden(name : String) -> Bool {
  name.has_prefix(".") && name != "." && name != ".."
}

///|
fn filepicker_entry_is_hidden(entry : FileEntry) -> Bool {
  entry.hidden || filepicker_is_hidden(entry.name)
}

///|
#cfg(any(target="native", target="llvm"))
fn filepicker_parse_bool(text : String) -> Bool {
  text == "1" || text == "true"
}

///|
#cfg(any(target="native", target="llvm"))
fn filepicker_parse_nonnegative_int(text : String) -> Int {
  let chars = text.to_array()
  let mut value = 0
  for ch in chars {
    if ch >= '0' && ch <= '9' {
      value = value * 10 + ch.to_int() - '0'.to_int()
    } else {
      return 0
    }
  }
  value.max(0)
}

///|
#cfg(any(target="native", target="llvm"))
fn filepicker_looks_like_metadata_record(
  parts : Array[String],
  i : Int,
) -> Bool {
  if i + 5 >= parts.length() {
    return false
  }
  let symlink = parts[i + 1]
  let permissions = parts[i + 2]
  let hidden = parts[i + 4]
  (symlink == "0" || symlink == "1") &&
  permissions.length() >= 9 &&
  (hidden == "0" || hidden == "1")
}

///|
fn filepicker_sort_entries(entries : Array[FileEntry]) -> Array[FileEntry] {
  let sorted = entries.copy()
  sorted.sort_by(fn(a, b) {
    if a.is_dir && !b.is_dir {
      -1
    } else if !a.is_dir && b.is_dir {
      1
    } else {
      a.name.compare(b.name)
    }
  })
  sorted
}

///|
#cfg(any(target="native", target="llvm"))
fn filepicker_parse_entries(path : String, raw : Bytes) -> Array[FileEntry] {
  if raw.length() == 0 {
    return []
  }
  let encoded = @utf8.decode_lossy(raw[:])
  let nul = String::from_array([(0 : Int).unsafe_to_char()])
  let parts = encoded.split(nul[:]).map(StringView::to_owned).collect()
  let entries : Array[FileEntry] = []
  let mut i = 0
  while i < parts.length() {
    if filepicker_looks_like_metadata_record(parts, i) {
      let kind = parts[i]
      let name = parts[i + 5]
      if kind != "" && name != "" {
        entries.push(
          filepicker_entry(
            name,
            filepicker_join_path(path, name),
            kind == "D",
            is_symlink=filepicker_parse_bool(parts[i + 1]),
            permissions=parts[i + 2],
            size=filepicker_parse_nonnegative_int(parts[i + 3]),
            hidden=filepicker_parse_bool(parts[i + 4]),
          ),
        )
      }
      i = i + 6
    } else if i + 1 < parts.length() {
      let kind = parts[i]
      let name = parts[i + 1]
      if kind != "" && name != "" {
        entries.push(
          filepicker_entry(
            name,
            filepicker_join_path(path, name),
            kind == "D",
            hidden=filepicker_is_hidden(name),
          ),
        )
      }
      i = i + 2
    } else {
      i = parts.length()
    }
  }
  filepicker_sort_entries(entries)
}

///|
fn filepicker_allowed_type_matches(
  name : String,
  allowed_type : String,
) -> Bool {
  if allowed_type == "" {
    return false
  }
  let lower_name = name.to_lower()
  let lower_type = allowed_type.to_lower()
  if lower_type == "*" {
    true
  } else if lower_type.has_prefix(".") {
    lower_name.has_suffix(lower_type)
  } else {
    lower_name.has_suffix("." + lower_type)
  }
}

///|
fn filepicker_allowed_types(model : FilepickerModel) -> Array[String] {
  if model.allowed_types.is_empty() {
    model.allowed_extensions
  } else if model.allowed_extensions.is_empty() {
    model.allowed_types
  } else {
    [..model.allowed_extensions, ..model.allowed_types]
  }
}

///|
fn filepicker_entry_matches_allowed_types(
  model : FilepickerModel,
  entry : FileEntry,
) -> Bool {
  let allowed = filepicker_allowed_types(model)
  if allowed.is_empty() {
    return true
  }
  for ext in allowed {
    if filepicker_allowed_type_matches(entry.name, ext) {
      return true
    }
  }
  false
}

///|
fn filepicker_entry_disabled(
  model : FilepickerModel,
  entry : FileEntry,
) -> Bool {
  if entry.is_dir {
    !model.allow_directories
  } else if !model.allow_files {
    true
  } else {
    !filepicker_entry_matches_allowed_types(model, entry)
  }
}

///|
fn filepicker_apply_disabled(model : FilepickerModel) -> Array[FileEntry] {
  let entries : Array[FileEntry] = []
  for entry in model.entries {
    entries.push({ ..entry, disabled: filepicker_entry_disabled(model, entry) })
  }
  entries
}

///|
fn filepicker_can_select(model : FilepickerModel, entry : FileEntry) -> Bool {
  !filepicker_entry_disabled(model, entry)
}

///|
fn filepicker_open_scan_message(path : String) -> FilepickerMsg {
  match filepicker_open_scan(path) {
    Some(handle) => ScanOpened(path, handle)
    None => LoadFailed("failed to open directory scan: " + path)
  }
}

///|
fn filepicker_open_scan_cmd(path : String) -> @pippa.Cmd[FilepickerMsg] {
  @pippa.Cmd::perform(fn() { Some(filepicker_open_scan_message(path)) })
}

///|
fn filepicker_continue_scan_message(
  path : String,
  handle : Int,
) -> FilepickerMsg {
  match filepicker_scan_next(path, handle, 64) {
    Ok(Some(entries)) => ScanChunk(path, handle, entries)
    Ok(None) => ScanFinished(path, handle)
    Err(err) => LoadFailed(err)
  }
}

///|
fn filepicker_continue_scan_cmd(
  path : String,
  handle : Int,
) -> @pippa.Cmd[FilepickerMsg] {
  @pippa.Cmd::after(1, fn() { ContinueScan(path, handle) })
}

///|
fn filepicker_close_active_scan(model : FilepickerModel) -> Unit {
  model.scan_handle.iter().each(filepicker_close_scan)
}

///|
fn filepicker_effective_height(model : FilepickerModel) -> Int {
  if !model.auto_height || model.available_height <= 0 {
    return model.height.max(1)
  }
  let mut chrome = 2
  if model.error is Some(_) {
    chrome = chrome + 1
  }
  if model.loading {
    chrome = chrome + 1
  }
  (model.available_height - chrome).max(1)
}

///|
fn filepicker_visible_entries(model : FilepickerModel) -> Array[FileEntry] {
  if model.show_hidden {
    model.entries
  } else {
    let visible : Array[FileEntry] = []
    for entry in model.entries {
      if !filepicker_entry_is_hidden(entry) {
        visible.push(entry)
      }
    }
    visible
  }
}

///|
fn filepicker_clamp_window_start(
  requested_min : Int,
  cursor : Int,
  count : Int,
  height : Int,
) -> Int {
  if count <= 0 {
    return requested_min.max(0)
  }
  let max_start = (count - height).max(0)
  let mut start = requested_min.max(0).min(max_start)
  if cursor < start {
    start = cursor.max(0).min(max_start)
  } else if cursor > start + height - 1 {
    start = (cursor - height + 1).max(0).min(max_start)
  }
  start
}

///|
fn filepicker_normalize(model : FilepickerModel) -> FilepickerModel {
  let model = { ..model, entries: filepicker_apply_disabled(model) }
  let visible = filepicker_visible_entries(model)
  let height = filepicker_effective_height(model)
  let restore = model.pending_restore
  let target_cursor = match restore {
    Some(view) => view.selected
    None => model.cursor
  }
  let cursor = if visible.is_empty() {
    if model.loading && restore is Some(_) {
      target_cursor.max(0)
    } else {
      0
    }
  } else {
    target_cursor.max(0).min(visible.length() - 1)
  }
  let requested_min = match restore {
    Some(view) => view.min
    None => model.min_index
  }
  let min_index = filepicker_clamp_window_start(
    requested_min,
    cursor,
    visible.length(),
    height,
  )
  let max_index = if visible.is_empty() {
    match restore {
      Some(view) => view.max.max(min_index)
      None => min_index + height - 1
    }
  } else {
    (min_index + height - 1).min(visible.length() - 1)
  }
  {
    ..model,
    cursor,
    height: model.height.max(1),
    available_height: model.available_height.max(0),
    min_index,
    max_index,
  }
}

///|
fn filepicker_current_entry(model : FilepickerModel) -> FileEntry? {
  let visible = filepicker_visible_entries(model)
  if visible.is_empty() {
    None
  } else {
    Some(visible[model.cursor.max(0).min(visible.length() - 1)])
  }
}

///|
fn filepicker_page_start(model : FilepickerModel) -> Int {
  model.min_index.max(0)
}

///|
fn filepicker_page_end(model : FilepickerModel, visible_count : Int) -> Int {
  (filepicker_page_start(model) + filepicker_effective_height(model)).min(
    visible_count,
  )
}

///|
fn filepicker_push_view(model : FilepickerModel) -> FilepickerModel {
  let selected_stack = model.selected_stack.copy()
  let min_stack = model.min_stack.copy()
  let max_stack = model.max_stack.copy()
  selected_stack.push(model.cursor)
  min_stack.push(model.min_index)
  max_stack.push(model.max_index)
  { ..model, selected_stack, min_stack, max_stack }
}

///|
fn filepicker_pop_view(
  model : FilepickerModel,
) -> (FilepickerModel, FilepickerViewState?) {
  if model.selected_stack.is_empty() ||
    model.min_stack.is_empty() ||
    model.max_stack.is_empty() {
    return (model, None)
  }
  let selected_stack = model.selected_stack.copy()
  let min_stack = model.min_stack.copy()
  let max_stack = model.max_stack.copy()
  let selected = selected_stack.pop().unwrap()
  let min = min_stack.pop().unwrap()
  let max = max_stack.pop().unwrap()
  (
    { ..model, selected_stack, min_stack, max_stack },
    Some({ selected, min, max }),
  )
}

///|
fn filepicker_clear_history(model : FilepickerModel) -> FilepickerModel {
  {
    ..model,
    selected_stack: [],
    min_stack: [],
    max_stack: [],
    pending_restore: None,
  }
}

///|
fn filepicker_begin_loading(
  model : FilepickerModel,
  path : String,
  restore? : FilepickerViewState? = None,
) -> @pippa.UpdateResult[FilepickerModel, FilepickerMsg] {
  filepicker_close_active_scan(model)
  let selected = match restore {
    Some(view) => view.selected
    None => 0
  }
  let min_index = match restore {
    Some(view) => view.min
    None => 0
  }
  let max_index = match restore {
    Some(view) => view.max
    None => filepicker_effective_height(model) - 1
  }
  @pippa.UpdateResult::new(
    model=filepicker_normalize({
      ..model,
      current_directory: path,
      entries: [],
      cursor: selected,
      selected_path: None,
      loading: true,
      scan_handle: None,
      error: None,
      min_index,
      max_index,
      pending_restore: restore,
    }),
    cmd=filepicker_open_scan_cmd(path),
  )
}

///|
fn filepicker_with_cursor(
  model : FilepickerModel,
  cursor : Int,
) -> FilepickerModel {
  filepicker_normalize({ ..model, cursor, pending_restore: None })
}

///|
fn filepicker_with_page_cursor(
  model : FilepickerModel,
  cursor : Int,
  min_index : Int,
) -> FilepickerModel {
  filepicker_normalize({ ..model, cursor, min_index, pending_restore: None })
}

///|
fn filepicker_select_entry(
  model : FilepickerModel,
  entry : FileEntry,
) -> FilepickerModel {
  if filepicker_can_select(model, entry) {
    { ..model, selected_path: Some(entry.path), error: None }
  } else {
    { ..model, error: Some("not selectable: " + entry.name) }
  }
}

///|
fn filepicker_handle_open(
  model : FilepickerModel,
) -> @pippa.UpdateResult[FilepickerModel, FilepickerMsg] {
  match filepicker_current_entry(model) {
    Some(entry) =>
      if entry.is_dir {
        filepicker_begin_loading(filepicker_push_view(model), entry.path)
      } else {
        @pippa.UpdateResult::new(
          model=filepicker_select_entry(model, entry),
          cmd=@pippa.Cmd::none(),
        )
      }
    None => @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
  }
}

///|
fn filepicker_handle_select(
  model : FilepickerModel,
) -> @pippa.UpdateResult[FilepickerModel, FilepickerMsg] {
  match filepicker_current_entry(model) {
    Some(entry) =>
      @pippa.UpdateResult::new(
        model=filepicker_select_entry(model, entry),
        cmd=@pippa.Cmd::none(),
      )
    None => @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
  }
}

///|
fn filepicker_format_size(size : Int) -> String {
  size.max(0).to_string()
}

///|
fn filepicker_pad_left_width(text : String, width : Int) -> String {
  let text_width = @internal.display_width(text)
  if text_width >= width {
    text
  } else {
    String::make(width - text_width, ' ') + text
  }
}

///|
fn filepicker_render_columns(
  visible : Array[FileEntry],
  cursor : String,
) -> FilepickerRenderColumns {
  let mut permissions_width = 0
  let mut size_width = 0
  for entry in visible {
    permissions_width = permissions_width.max(
      @internal.display_width(entry.permissions),
    )
    size_width = size_width.max(
      @internal.display_width(filepicker_format_size(entry.size)),
    )
  }
  {
    cursor_width: @internal.display_width(cursor).max(1),
    permissions_width,
    size_width,
  }
}

///|
fn filepicker_entry_label(entry : FileEntry) -> String {
  if entry.is_symlink {
    entry.name + "@"
  } else if entry.is_dir {
    entry.name + "/"
  } else {
    entry.name
  }
}

///|
fn filepicker_entry_label_style(
  styles : FilepickerStyles,
  entry : FileEntry,
) -> FilepickerTextStyle {
  if entry.disabled {
    styles.disabled
  } else if entry.is_symlink {
    styles.symlink
  } else if entry.is_dir {
    styles.directory
  } else {
    styles.file
  }
}

///|
fn filepicker_render_metadata(
  model : FilepickerModel,
  entry : FileEntry,
  columns : FilepickerRenderColumns,
  styles : FilepickerStyles,
) -> String {
  let parts : Array[String] = []
  if model.show_permissions {
    parts.push(
      filepicker_apply_style(
        styles.permissions,
        @internal.pad_right_width(entry.permissions, columns.permissions_width),
      ),
    )
  }
  if model.show_size {
    parts.push(
      filepicker_apply_style(
        styles.size,
        filepicker_pad_left_width(
          filepicker_format_size(entry.size),
          columns.size_width,
        ),
      ),
    )
  }
  if parts.is_empty() {
    ""
  } else {
    parts.join(" ") + " "
  }
}

///|
fn filepicker_render_entry(
  model : FilepickerModel,
  entry : FileEntry,
  index : Int,
  columns : FilepickerRenderColumns,
  cursor : String,
  styles : FilepickerStyles,
) -> String {
  let active = index == model.cursor
  let cursor_text = if active {
    cursor
  } else {
    String::make(columns.cursor_width, ' ')
  }
  let cursor_style = if entry.disabled {
    styles.disabled_cursor
  } else {
    styles.cursor
  }
  let rendered_cursor = if active {
    filepicker_apply_style(cursor_style, cursor_text)
  } else {
    cursor_text
  }
  let base_label = filepicker_entry_label(entry)
  let styled_label = filepicker_apply_style(
    filepicker_entry_label_style(styles, entry),
    base_label,
  )
  let path_selected = match model.selected_path {
    Some(path) => path == entry.path
    None => false
  }
  let selected = active || path_selected
  let rendered_label = if selected {
    filepicker_apply_style(styles.selected, styled_label)
  } else {
    styled_label
  }
  rendered_cursor +
  filepicker_render_metadata(model, entry, columns, styles) +
  rendered_label
}

///|
pub fn filepicker(
  current_directory? : String = "",
  height? : Int = 8,
  show_hidden? : Bool = false,
  show_permissions? : Bool = true,
  show_size? : Bool = true,
  allow_files? : Bool = true,
  allow_directories? : Bool = false,
  allowed_extensions? : Array[String] = [],
  allowed_types? : Array[String] = [],
  auto_height? : Bool = false,
  available_height? : Int = 0,
  cursor? : String = "> ",
  styles? : FilepickerStyles = default_filepicker_styles(),
  keymap? : FilepickerKeymap = default_filepicker_keymap(),
) -> Component[FilepickerModel, FilepickerMsg] {
  {
    init: fn() {
      let directory = filepicker_initial_directory(current_directory)
      @pippa.UpdateResult::new(
        model=filepicker_normalize({
          current_directory: directory,
          entries: [],
          cursor: 0,
          selected_path: None,
          height,
          show_hidden,
          show_permissions,
          show_size,
          allow_files,
          allow_directories,
          allowed_extensions,
          allowed_types,
          loading: true,
          scan_handle: None,
          error: None,
          auto_height,
          available_height,
          min_index: 0,
          max_index: height.max(1) - 1,
          selected_stack: [],
          min_stack: [],
          max_stack: [],
          pending_restore: None,
        }),
        cmd=filepicker_open_scan_cmd(directory),
      )
    },
    update: fn(model, msg) {
      match msg {
        Refresh => filepicker_begin_loading(model, model.current_directory)
        CursorUp =>
          @pippa.UpdateResult::new(
            model=filepicker_with_cursor(model, model.cursor - 1),
            cmd=@pippa.Cmd::none(),
          )
        CursorDown =>
          @pippa.UpdateResult::new(
            model=filepicker_with_cursor(model, model.cursor + 1),
            cmd=@pippa.Cmd::none(),
          )
        PageUp => {
          let h = filepicker_effective_height(model)
          @pippa.UpdateResult::new(
            model=filepicker_with_page_cursor(
              model,
              model.cursor - h,
              model.min_index - h,
            ),
            cmd=@pippa.Cmd::none(),
          )
        }
        PageDown => {
          let h = filepicker_effective_height(model)
          @pippa.UpdateResult::new(
            model=filepicker_with_page_cursor(
              model,
              model.cursor + h,
              model.min_index + h,
            ),
            cmd=@pippa.Cmd::none(),
          )
        }
        MoveToTop =>
          @pippa.UpdateResult::new(
            model=filepicker_with_page_cursor(model, 0, 0),
            cmd=@pippa.Cmd::none(),
          )
        MoveToBottom => {
          let visible = filepicker_visible_entries(filepicker_normalize(model))
          let last = if visible.is_empty() { 0 } else { visible.length() - 1 }
          let h = filepicker_effective_height(model)
          @pippa.UpdateResult::new(
            model=filepicker_with_page_cursor(model, last, last - h + 1),
            cmd=@pippa.Cmd::none(),
          )
        }
        Open => filepicker_handle_open(model)
        Select => filepicker_handle_select(model)
        Back => {
          let parent = filepicker_parent_dir(model.current_directory)
          let (popped, restore) = filepicker_pop_view(model)
          filepicker_begin_loading(popped, parent, restore~)
        }
        ToggleHidden =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({
              ..model,
              show_hidden: !model.show_hidden,
              pending_restore: None,
            }),
            cmd=@pippa.Cmd::none(),
          )
        SetDirectory(path) => {
          let directory = if path == "" { "." } else { path }
          filepicker_begin_loading(filepicker_clear_history(model), directory)
        }
        SetHeight(height) =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({
              ..model,
              height,
              pending_restore: None,
            }),
            cmd=@pippa.Cmd::none(),
          )
        SetAvailableHeight(available_height) =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({
              ..model,
              available_height,
              pending_restore: None,
            }),
            cmd=@pippa.Cmd::none(),
          )
        SetAutoHeight(auto_height) =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({
              ..model,
              auto_height,
              pending_restore: None,
            }),
            cmd=@pippa.Cmd::none(),
          )
        SetShowPermissions(show_permissions) =>
          @pippa.UpdateResult::new(
            model={ ..model, show_permissions, },
            cmd=@pippa.Cmd::none(),
          )
        SetShowSize(show_size) =>
          @pippa.UpdateResult::new(
            model={ ..model, show_size, },
            cmd=@pippa.Cmd::none(),
          )
        SetShowHidden(show_hidden) =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({
              ..model,
              show_hidden,
              pending_restore: None,
            }),
            cmd=@pippa.Cmd::none(),
          )
        SetAllowedExtensions(allowed_extensions) =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({
              ..model,
              allowed_extensions,
              pending_restore: None,
            }),
            cmd=@pippa.Cmd::none(),
          )
        SetAllowedTypes(allowed_types) =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({
              ..model,
              allowed_types,
              pending_restore: None,
            }),
            cmd=@pippa.Cmd::none(),
          )
        SetSelectionMode(allow_files, allow_directories) =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({
              ..model,
              allow_files,
              allow_directories,
              pending_restore: None,
            }),
            cmd=@pippa.Cmd::none(),
          )
        HandleInput(event) =>
          match filepicker_msg_from_input_event(event, keymap~) {
            Some(next_msg) => (filepicker(keymap~).update)(model, next_msg)
            None => @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          }
        ScanOpened(path, handle) =>
          if model.current_directory != path || model.loading == false {
            filepicker_close_scan(handle)
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            @pippa.UpdateResult::new(
              model={ ..model, scan_handle: Some(handle), error: None },
              cmd=filepicker_continue_scan_cmd(path, handle),
            )
          }
        ContinueScan(path, handle) =>
          match model.scan_handle {
            Some(active) =>
              if active == handle && model.current_directory == path {
                @pippa.UpdateResult::new(
                  model~,
                  cmd=@pippa.Cmd::perform(fn() {
                    Some(filepicker_continue_scan_message(path, handle))
                  }),
                )
              } else {
                filepicker_close_scan(handle)
                @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
              }
            None => {
              filepicker_close_scan(handle)
              @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
            }
          }
        ScanChunk(path, handle, entries) =>
          match model.scan_handle {
            Some(active) =>
              if active == handle && model.current_directory == path {
                @pippa.UpdateResult::new(
                  model=filepicker_normalize({
                    ..model,
                    entries: filepicker_sort_entries(
                      [..model.entries, ..entries],
                    ),
                    error: None,
                  }),
                  cmd=filepicker_continue_scan_cmd(path, handle),
                )
              } else {
                filepicker_close_scan(handle)
                @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
              }
            None => {
              filepicker_close_scan(handle)
              @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
            }
          }
        ScanFinished(path, handle) =>
          match model.scan_handle {
            Some(active) =>
              if active == handle && model.current_directory == path {
                filepicker_close_scan(handle)
                @pippa.UpdateResult::new(
                  model=filepicker_normalize({
                    ..model,
                    loading: false,
                    scan_handle: None,
                    error: None,
                    pending_restore: None,
                  }),
                  cmd=@pippa.Cmd::none(),
                )
              } else {
                filepicker_close_scan(handle)
                @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
              }
            None => {
              filepicker_close_scan(handle)
              @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
            }
          }
        LoadFailed(err) => {
          filepicker_close_active_scan(model)
          let model = filepicker_clear_history(model)
          @pippa.UpdateResult::new(
            model=filepicker_normalize({
              ..model,
              entries: [],
              cursor: 0,
              loading: false,
              scan_handle: None,
              error: Some(err),
              min_index: 0,
              max_index: filepicker_effective_height(model) - 1,
              pending_restore: None,
            }),
            cmd=@pippa.Cmd::none(),
          )
        }
      }
    },
    view: fn(model) {
      let model = filepicker_normalize(model)
      let visible = filepicker_visible_entries(model)
      let page_start = filepicker_page_start(model)
      let page_end = filepicker_page_end(model, visible.length())
      let hidden_label = if model.show_hidden { "on" } else { "off" }
      let columns = filepicker_render_columns(visible, cursor)
      let lines : Array[String] = []
      lines.push(@pippa.bold() + model.current_directory + @pippa.reset())
      model.error
      .iter()
      .each(fn(err) { lines.push(filepicker_apply_style(styles.error, err)) })
      if model.loading {
        lines.push(filepicker_apply_style(styles.loading, "(loading...)"))
      }
      if visible.is_empty() {
        lines.push(
          filepicker_apply_style(
            styles.empty,
            if model.loading {
              "(waiting for entries)"
            } else {
              "(empty directory)"
            },
          ),
        )
      } else {
        for i in page_start..<page_end {
          lines.push(
            filepicker_render_entry(
              model,
              visible[i],
              i,
              columns,
              cursor,
              styles,
            ),
          )
        }
      }
      lines.push(
        filepicker_apply_style(
          styles.status,
          "hidden:\{hidden_label} " +
          "items:\{visible.length()}" +
          (if model.loading { " loading" } else { "" }),
        ),
      )
      lines.join("\n")
    },
  }
}
