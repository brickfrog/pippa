///|
fn filepicker_test_entry(
  name : String,
  path : String,
  is_dir : Bool,
  is_symlink? : Bool = false,
  permissions? : String = "-rw-r--r--",
  size? : Int = 0,
  hidden? : Bool = false,
  disabled? : Bool = false,
) -> FileEntry {
  { name, path, is_dir, is_symlink, permissions, size, hidden, disabled }
}

///|
fn filepicker_test_model(
  current_directory? : String = ".",
  entries? : Array[FileEntry] = [],
  cursor? : Int = 0,
  selected_path? : String? = None,
  height? : Int = 3,
  show_hidden? : Bool = false,
  show_permissions? : Bool = true,
  show_size? : Bool = true,
  allow_files? : Bool = true,
  allow_directories? : Bool = false,
  allowed_extensions? : Array[String] = [],
  allowed_types? : Array[String] = [],
  loading? : Bool = false,
  scan_handle? : Int? = None,
  error? : String? = None,
  auto_height? : Bool = false,
  available_height? : Int = 0,
  min_index? : Int = 0,
  max_index? : Int = 2,
  selected_stack? : Array[Int] = [],
  min_stack? : Array[Int] = [],
  max_stack? : Array[Int] = [],
  pending_restore? : FilepickerViewState? = None,
) -> FilepickerModel {
  {
    current_directory,
    entries,
    cursor,
    selected_path,
    height,
    show_hidden,
    show_permissions,
    show_size,
    allow_files,
    allow_directories,
    allowed_extensions,
    allowed_types,
    loading,
    scan_handle,
    error,
    auto_height,
    available_height,
    min_index,
    max_index,
    selected_stack,
    min_stack,
    max_stack,
    pending_restore,
  }
}

///|
fn filepicker_test_prefix_width(line : String, name : String) -> Int {
  let stripped = @pippa.strip_ansi(line)
  match stripped.rev_find(name) {
    Some(i) => @internal.display_width(stripped[:i].to_owned())
    None => -1
  }
}

///|
fn filepicker_test_large_entries(count : Int) -> Array[FileEntry] {
  let entries : Array[FileEntry] = []
  for i in 0..<count {
    entries.push(
      filepicker_test_entry(
        "item\{i}.txt",
        "./item\{i}.txt",
        false,
        permissions="-rw-r--r--",
        size=100 + i,
      ),
    )
  }
  entries
}

///|
test "filepicker selection and hidden toggle update the model" {
  let c = filepicker(height=3)
  let model = filepicker_test_model(
    entries=[
      filepicker_test_entry(".hidden", ".hidden", false, hidden=true),
      filepicker_test_entry("src", "src", true, permissions="drwxr-xr-x"),
      filepicker_test_entry("moon.mod.json", "moon.mod.json", false),
    ],
    allowed_extensions=[".json"],
  )
  let toggled = (c.update)(model, ToggleHidden).model
  assert_eq(toggled.show_hidden, true)
  let selected = (c.update)({ ..toggled, cursor: 2 }, Select).model
  @test.assert_eq(selected.selected_path, Some("moon.mod.json"))
}

///|
test "filepicker open on disabled file reports an error" {
  let c = filepicker(height=3, allowed_extensions=[".txt"])
  let model = filepicker_test_model(
    entries=[filepicker_test_entry("moon.mod.json", "moon.mod.json", false)],
    show_hidden=true,
    allowed_extensions=[".txt"],
  )
  let next = (c.update)(model, Open).model
  assert_true(next.error is Some(_))
}

///|
test "filepicker view marks directories and selected entries" {
  let c = filepicker(height=2)
  let model = filepicker_test_model(
    current_directory="/tmp",
    entries=[
      filepicker_test_entry("src", "/tmp/src", true, permissions="drwxr-xr-x"),
      filepicker_test_entry("notes.txt", "/tmp/notes.txt", false, size=42),
    ],
    selected_path=Some("/tmp/notes.txt"),
    height=2,
    show_hidden=true,
    max_index=1,
  )
  let view = (c.view)(model)
  assert_true(view.contains("src/"))
  assert_true(view.contains("notes.txt"))
}

///|
test "filepicker scan chunks append entries and keep loading until finished" {
  let c = filepicker(height=3)
  let model = filepicker_test_model(
    show_hidden=true,
    loading=true,
    scan_handle=Some(7),
  )
  let chunked = (c.update)(
    model,
    ScanChunk(".", 7, [
      filepicker_test_entry("src", "./src", true, permissions="drwxr-xr-x"),
    ]),
  )
  assert_true(chunked.model.loading)
  assert_eq(chunked.model.entries.length(), 1)
  assert_false(chunked.cmd.is_none())
  let finished = (c.update)(chunked.model, ScanFinished(".", 7))
  assert_false(finished.model.loading)
  @test.assert_eq(finished.model.scan_handle, None)
}

///|
test "filepicker scan continuation preserves metadata across large chunks" {
  let c = filepicker(height=4)
  let model = filepicker_test_model(
    entries=[],
    height=4,
    show_hidden=true,
    loading=true,
    scan_handle=Some(9),
    max_index=3,
  )
  let first = (c.update)(
    model,
    ScanChunk(".", 9, filepicker_test_large_entries(64)),
  )
  assert_true(first.model.loading)
  assert_false(first.cmd.is_none())
  assert_eq(first.model.entries.length(), 64)
  assert_eq(first.model.entries[63].permissions, "-rw-r--r--")
  assert_eq(first.model.entries[63].size, 163)
  let second = (c.update)(
    first.model,
    ScanChunk(".", 9, [
      filepicker_test_entry("last.log", "./last.log", false, size=4096),
    ]),
  )
  assert_eq(second.model.entries.length(), 65)
  let mut saw_last = false
  for entry in second.model.entries {
    if entry.name == "last.log" {
      saw_last = true
      assert_eq(entry.size, 4096)
    }
  }
  assert_true(saw_last)
  assert_false(second.cmd.is_none())
}

///|
test "filepicker renders metadata columns and honors show toggles" {
  let c = filepicker(height=4, cursor="» ")
  let model = filepicker_test_model(
    entries=[
      filepicker_test_entry("界.mbt", "./界.mbt", false, size=7),
      filepicker_test_entry("plain.txt", "./plain.txt", false, size=12345),
      filepicker_test_entry(
        "link",
        "./link",
        false,
        is_symlink=true,
        permissions="lrwxrwxrwx",
        size=3,
      ),
    ],
    height=4,
    show_hidden=true,
    show_permissions=true,
    show_size=true,
    max_index=3,
  )
  let view = @pippa.strip_ansi((c.view)(model))
  assert_true(view.contains("» "))
  assert_true(view.contains("-rw-r--r--"))
  assert_true(view.contains("lrwxrwxrwx"))
  assert_true(view.contains("12345"))
  assert_true(view.contains("@"))
  let lines = @pippa.split_lines(view)
  assert_eq(
    filepicker_test_prefix_width(lines[1], "界.mbt"),
    filepicker_test_prefix_width(lines[2], "plain.txt"),
  )

  let no_permissions = (c.update)(model, SetShowPermissions(false)).model
  assert_false(
    @pippa.strip_ansi((c.view)(no_permissions)).contains("-rw-r--r--"),
  )
  let no_size = (c.update)(no_permissions, SetShowSize(false)).model
  assert_false(@pippa.strip_ansi((c.view)(no_size)).contains("12345"))
}

///|
test "filepicker allowed types and file directory modes drive disabled and selection" {
  let c = filepicker(height=4, allowed_types=[".mbt"])
  let model = filepicker_test_model(
    entries=[
      filepicker_test_entry("main.mbt", "./main.mbt", false),
      filepicker_test_entry("notes.txt", "./notes.txt", false),
      filepicker_test_entry("src", "./src", true, permissions="drwxr-xr-x"),
    ],
    height=4,
    show_hidden=true,
    allow_files=true,
    allow_directories=false,
    allowed_types=[".mbt"],
    max_index=3,
  )
  let normalized = (c.update)(model, SetAllowedTypes([".mbt"])).model
  assert_false(normalized.entries[0].disabled)
  assert_true(normalized.entries[1].disabled)
  assert_true(normalized.entries[2].disabled)

  let disabled = (c.update)({ ..normalized, cursor: 1 }, Select).model
  @test.assert_eq(disabled.selected_path, None)
  assert_true(disabled.error is Some(_))

  let dirs_only = (c.update)(normalized, SetSelectionMode(false, true)).model
  assert_true(dirs_only.entries[0].disabled)
  assert_false(dirs_only.entries[2].disabled)
  let selected_dir = (c.update)({ ..dirs_only, cursor: 2 }, Select).model
  @test.assert_eq(selected_dir.selected_path, Some("./src"))
}

///|
test "filepicker back restores previous cursor and window" {
  let c = filepicker(height=2)
  let model = filepicker_test_model(
    current_directory="/repo",
    entries=[
      filepicker_test_entry("alpha.txt", "/repo/alpha.txt", false),
      filepicker_test_entry("sub", "/repo/sub", true, permissions="drwxr-xr-x"),
      filepicker_test_entry("zeta.txt", "/repo/zeta.txt", false),
    ],
    cursor=1,
    height=2,
    show_hidden=true,
    min_index=1,
    max_index=2,
  )
  let entered = (c.update)(model, Open).model
  assert_eq(entered.current_directory, "/repo/sub")
  assert_eq(entered.selected_stack, [1])
  assert_eq(entered.min_stack, [1])
  assert_eq(entered.max_stack, [2])

  let inside = {
    ..entered,
    entries: [
      filepicker_test_entry("deep-a.txt", "/repo/sub/deep-a.txt", false),
      filepicker_test_entry("deep-b.txt", "/repo/sub/deep-b.txt", false),
    ],
    cursor: 1,
    min_index: 0,
    max_index: 1,
    loading: false,
  }
  let backed = (c.update)(inside, Back).model
  assert_eq(backed.current_directory, "/repo")
  assert_eq(backed.cursor, 1)
  assert_eq(backed.min_index, 1)
  assert_eq(backed.max_index, 2)
  assert_eq(backed.selected_stack, [])
}

///|
test "filepicker keymap can be overridden disabled and rendered as help" {
  let keymap = filepicker_keymap_disable(
    filepicker_keymap_override(
      default_filepicker_keymap(),
      FilepickerActionToggleHidden,
      @pippa.binding(keys=["."], help_key=".", help="dotfiles"),
    ),
    FilepickerActionPageDown,
  )
  @test.assert_eq(
    filepicker_msg_from_input_event(@pippa.Key(@pippa.Char('.')), keymap~),
    Some(ToggleHidden),
  )
  @test.assert_eq(
    filepicker_msg_from_input_event(
      @pippa.Key(@pippa.Special("pagedown")),
      keymap~,
    ),
    None,
  )
  let help = filepicker_help_view(keymap~, show_full=false, width=0)
  assert_true(help.contains(". dotfiles"))
  assert_false(help.contains("page down"))
}
