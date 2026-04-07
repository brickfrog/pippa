///|
/// Filepicker component — directory navigation and file selection for native
/// Pippa applications.

///|
pub(all) struct FileEntry {
  name : String
  path : String
  is_dir : Bool
} derive(Debug, Eq)

///|
pub(all) struct FilepickerModel {
  current_directory : String
  entries : Array[FileEntry]
  cursor : Int
  selected_path : String?
  height : Int
  show_hidden : Bool
  allow_files : Bool
  allow_directories : Bool
  allowed_extensions : Array[String]
  loading : Bool
  scan_handle : Int?
  error : String?
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
  SetAllowedExtensions(Array[String])
  SetSelectionMode(Bool, Bool)
  ScanOpened(String, Int)
  ContinueScan(String, Int)
  ScanChunk(String, Int, Array[FileEntry])
  ScanFinished(String, Int)
  LoadFailed(String)
} derive(Debug, Eq)

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
    path[:path.length() - 1].to_string()
  } else {
    path
  }
  match trimmed.rev_find("/") {
    Some(0) => "/"
    Some(i) => trimmed[:i].to_string()
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
fn filepicker_is_hidden(name : String) -> Bool {
  name.has_prefix(".") && name != "." && name != ".."
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
  let parts = encoded.split(nul[:]).map(StringView::to_string).collect()
  let entries : Array[FileEntry] = []
  let mut i = 0
  while i + 1 < parts.length() {
    let kind = parts[i]
    let name = parts[i + 1]
    if kind != "" && name != "" {
      entries.push({
        name,
        path: filepicker_join_path(path, name),
        is_dir: kind == "D",
      })
    }
    i = i + 2
  }
  filepicker_sort_entries(entries)
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
fn filepicker_begin_loading(
  model : FilepickerModel,
  path : String,
) -> @pippa.UpdateResult[FilepickerModel, FilepickerMsg] {
  filepicker_close_active_scan(model)
  @pippa.UpdateResult::new(
    model=filepicker_normalize({
      ..model,
      current_directory: path,
      entries: [],
      cursor: 0,
      selected_path: None,
      loading: true,
      scan_handle: None,
      error: None,
    }),
    cmd=filepicker_open_scan_cmd(path),
  )
}

///|
fn filepicker_normalize(model : FilepickerModel) -> FilepickerModel {
  let visible = filepicker_visible_entries(model)
  let max_cursor = if visible.is_empty() { 0 } else { visible.length() - 1 }
  {
    ..model,
    cursor: model.cursor.max(0).min(max_cursor),
    height: model.height.max(1),
  }
}

///|
fn filepicker_visible_entries(model : FilepickerModel) -> Array[FileEntry] {
  if model.show_hidden {
    model.entries
  } else {
    let visible : Array[FileEntry] = []
    for entry in model.entries {
      if !filepicker_is_hidden(entry.name) {
        visible.push(entry)
      }
    }
    visible
  }
}

///|
fn filepicker_current_entry(model : FilepickerModel) -> FileEntry? {
  let visible = filepicker_visible_entries(model)
  if visible.is_empty() {
    None
  } else {
    Some(visible[model.cursor])
  }
}

///|
fn filepicker_can_select(model : FilepickerModel, entry : FileEntry) -> Bool {
  if entry.is_dir {
    model.allow_directories
  } else if !model.allow_files {
    false
  } else if model.allowed_extensions.is_empty() {
    true
  } else {
    let mut allowed = false
    for ext in model.allowed_extensions {
      if entry.name.has_suffix(ext) {
        allowed = true
      }
    }
    allowed
  }
}

///|
fn filepicker_page_start(model : FilepickerModel) -> Int {
  model.cursor / model.height * model.height
}

///|
pub fn filepicker(
  current_directory? : String = "",
  height? : Int = 8,
  show_hidden? : Bool = false,
  allow_files? : Bool = true,
  allow_directories? : Bool = false,
  allowed_extensions? : Array[String] = [],
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
          allow_files,
          allow_directories,
          allowed_extensions,
          loading: true,
          scan_handle: None,
          error: None,
        }),
        cmd=filepicker_open_scan_cmd(directory),
      )
    },
    update: fn(model, msg) {
      match msg {
        Refresh => filepicker_begin_loading(model, model.current_directory)
        CursorUp =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({ ..model, cursor: model.cursor - 1 }),
            cmd=@pippa.Cmd::none(),
          )
        CursorDown =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({ ..model, cursor: model.cursor + 1 }),
            cmd=@pippa.Cmd::none(),
          )
        PageUp =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({
              ..model,
              cursor: model.cursor - model.height,
            }),
            cmd=@pippa.Cmd::none(),
          )
        PageDown =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({
              ..model,
              cursor: model.cursor + model.height,
            }),
            cmd=@pippa.Cmd::none(),
          )
        MoveToTop =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({ ..model, cursor: 0 }),
            cmd=@pippa.Cmd::none(),
          )
        MoveToBottom => {
          let visible = filepicker_visible_entries(model)
          let last = if visible.is_empty() { 0 } else { visible.length() - 1 }
          @pippa.UpdateResult::new(
            model=filepicker_normalize({ ..model, cursor: last }),
            cmd=@pippa.Cmd::none(),
          )
        }
        Open =>
          match filepicker_current_entry(model) {
            Some(entry) =>
              if entry.is_dir {
                filepicker_begin_loading(model, entry.path)
              } else if filepicker_can_select(model, entry) {
                @pippa.UpdateResult::new(
                  model={
                    ..model,
                    selected_path: Some(entry.path),
                    error: None,
                  },
                  cmd=@pippa.Cmd::none(),
                )
              } else {
                @pippa.UpdateResult::new(
                  model={
                    ..model,
                    error: Some("not selectable: " + entry.name),
                  },
                  cmd=@pippa.Cmd::none(),
                )
              }
            None => @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          }
        Select =>
          match filepicker_current_entry(model) {
            Some(entry) =>
              if filepicker_can_select(model, entry) {
                @pippa.UpdateResult::new(
                  model={
                    ..model,
                    selected_path: Some(entry.path),
                    error: None,
                  },
                  cmd=@pippa.Cmd::none(),
                )
              } else {
                @pippa.UpdateResult::new(
                  model={
                    ..model,
                    error: Some("not selectable: " + entry.name),
                  },
                  cmd=@pippa.Cmd::none(),
                )
              }
            None => @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          }
        Back => {
          let parent = filepicker_parent_dir(model.current_directory)
          filepicker_begin_loading(model, parent)
        }
        ToggleHidden =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({
              ..model,
              show_hidden: !model.show_hidden,
            }),
            cmd=@pippa.Cmd::none(),
          )
        SetDirectory(path) => {
          let directory = if path == "" { "." } else { path }
          filepicker_begin_loading(model, directory)
        }
        SetHeight(height) =>
          @pippa.UpdateResult::new(
            model=filepicker_normalize({ ..model, height, }),
            cmd=@pippa.Cmd::none(),
          )
        SetAllowedExtensions(allowed_extensions) =>
          @pippa.UpdateResult::new(
            model={ ..model, allowed_extensions, },
            cmd=@pippa.Cmd::none(),
          )
        SetSelectionMode(allow_files, allow_directories) =>
          @pippa.UpdateResult::new(
            model={ ..model, allow_files, allow_directories },
            cmd=@pippa.Cmd::none(),
          )
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
          @pippa.UpdateResult::new(
            model=filepicker_normalize({
              ..model,
              entries: [],
              cursor: 0,
              loading: false,
              scan_handle: None,
              error: Some(err),
            }),
            cmd=@pippa.Cmd::none(),
          )
        }
      }
    },
    view: fn(model) {
      let visible = filepicker_visible_entries(model)
      let page_start = filepicker_page_start(model)
      let page_end = (page_start + model.height).min(visible.length())
      let hidden_label = if model.show_hidden { "on" } else { "off" }
      let lines : Array[String] = []
      lines.push(@pippa.bold() + model.current_directory + @pippa.reset())
      model.error
      .iter()
      .each(fn(err) { lines.push(@pippa.fg_color(1) + err + @pippa.reset()) })
      if model.loading {
        lines.push(@pippa.dim() + "(loading...)" + @pippa.reset())
      }
      if visible.is_empty() {
        lines.push(
          @pippa.dim() +
          (if model.loading {
            "(waiting for entries)"
          } else {
            "(empty directory)"
          }) +
          @pippa.reset(),
        )
      } else {
        for i in page_start..<page_end {
          let entry = visible[i]
          let prefix = if i == model.cursor {
            @pippa.bold() + "> " + @pippa.reset()
          } else {
            "  "
          }
          let label = if entry.is_dir { entry.name + "/" } else { entry.name }
          let selectable = filepicker_can_select(model, entry)
          let selected_prefix = match model.selected_path {
            Some(path) =>
              if path == entry.path {
                @pippa.underline()
              } else {
                ""
              }
            None => ""
          }
          let style_prefix = if entry.is_dir {
            @pippa.fg_rgb(90, 130, 220)
          } else if !selectable {
            @pippa.dim()
          } else {
            ""
          }
          let suffix = if selected_prefix != "" || style_prefix != "" {
            @pippa.reset()
          } else {
            ""
          }
          lines.push(prefix + selected_prefix + style_prefix + label + suffix)
        }
      }
      lines.push(
        @pippa.dim() +
        "hidden:\{hidden_label} " +
        "items:\{visible.length()}" +
        (if model.loading { " loading" } else { "" }) +
        @pippa.reset(),
      )
      lines.join("\n")
    },
  }
}
