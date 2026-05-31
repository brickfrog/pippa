///|
fn filepicker_wbtest_entry(
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
#cfg(any(target="native", target="llvm"))
test "filepicker native scanner can stream chunks" {
  match filepicker_open_scan(".") {
    Some(handle) => {
      defer filepicker_close_scan(handle)
      match filepicker_scan_next(".", handle, 8) {
        Ok(Some(entries)) => {
          assert_true(entries.length() > 0)
          assert_true(entries[0].permissions.length() >= 10)
          assert_true(entries[0].size >= 0)
        }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "filepicker parent dir handles repo-like paths" {
  assert_eq(filepicker_parent_dir("src/component"), "src")
  assert_eq(filepicker_parent_dir("/tmp/demo"), "/tmp")
  assert_eq(filepicker_parent_dir("/tmp"), "/")
}

///|
#cfg(any(target="native", target="llvm"))
test "filepicker parse_entries keeps directories first" {
  let nul = String::from_array([(0 : Int).unsafe_to_char()])
  let raw = @utf8.encode(
    ("F" +
    nul +
    "0" +
    nul +
    "-rw-r--r--" +
    nul +
    "12" +
    nul +
    "0" +
    nul +
    "zeta.txt" +
    nul +
    "D" +
    nul +
    "0" +
    nul +
    "drwxr-xr-x" +
    nul +
    "0" +
    nul +
    "0" +
    nul +
    "alpha" +
    nul +
    "F" +
    nul +
    "0" +
    nul +
    "-rw-r--r--" +
    nul +
    "4" +
    nul +
    "0" +
    nul +
    "beta.txt" +
    nul)[:],
  )
  let entries = filepicker_parse_entries(".", raw)
  @test.assert_eq(
    entries[0],
    filepicker_wbtest_entry("alpha", "alpha", true, permissions="drwxr-xr-x"),
  )
  @test.assert_eq(entries[1], {
    ..filepicker_wbtest_entry("beta.txt", "beta.txt", false),
    size: 4,
  })
  @test.assert_eq(entries[2], {
    ..filepicker_wbtest_entry("zeta.txt", "zeta.txt", false),
    size: 12,
  })
}

///|
#cfg(any(target="native", target="llvm"))
test "filepicker parse_entries populates symlink permissions size and hidden metadata" {
  let nul = String::from_array([(0 : Int).unsafe_to_char()])
  let raw = @utf8.encode(
    ("F" +
    nul +
    "1" +
    nul +
    "lrwxrwxrwx" +
    nul +
    "99" +
    nul +
    "1" +
    nul +
    ".linked" +
    nul)[:],
  )
  let entries = filepicker_parse_entries("/tmp", raw)
  assert_eq(entries.length(), 1)
  assert_true(entries[0].is_symlink)
  assert_eq(entries[0].permissions, "lrwxrwxrwx")
  assert_eq(entries[0].size, 99)
  assert_true(entries[0].hidden)
  assert_false(entries[0].disabled)
}

///|
test "filepicker auto height sizes list to available rows but fixed height remains fixed" {
  let auto = filepicker_normalize({
    current_directory: ".",
    entries: [
      filepicker_wbtest_entry("one", "one", false),
      filepicker_wbtest_entry("two", "two", false),
      filepicker_wbtest_entry("three", "three", false),
      filepicker_wbtest_entry("four", "four", false),
    ],
    cursor: 0,
    selected_path: None,
    height: 8,
    show_hidden: true,
    show_permissions: true,
    show_size: true,
    allow_files: true,
    allow_directories: false,
    allowed_extensions: [],
    allowed_types: [],
    loading: false,
    scan_handle: None,
    error: None,
    auto_height: true,
    available_height: 5,
    min_index: 0,
    max_index: 7,
    selected_stack: [],
    min_stack: [],
    max_stack: [],
    pending_restore: None,
  })
  assert_eq(filepicker_effective_height(auto), 3)
  assert_eq(auto.max_index, 2)

  let fixed = filepicker_normalize({ ..auto, auto_height: false, height: 2 })
  assert_eq(filepicker_effective_height(fixed), 2)
  assert_eq(fixed.max_index, 1)
}
