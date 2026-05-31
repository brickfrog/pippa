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
#borrow(out_buf)
extern "C" fn pippa_filepicker_test_fixture_create(
  out_buf : Bytes,
  out_len : Int,
) -> Int = "pippa_filepicker_test_fixture_create"

///|
#cfg(any(target="native", target="llvm"))
#borrow(path_buf)
extern "C" fn pippa_filepicker_test_fixture_cleanup(
  path_buf : Bytes,
  path_len : Int,
) -> Unit = "pippa_filepicker_test_fixture_cleanup"

///|
#cfg(any(target="native", target="llvm"))
fn filepicker_create_native_test_fixture() -> String? {
  let out = Bytes::new(4096)
  let written = pippa_filepicker_test_fixture_create(out, out.length())
  if written > 0 {
    Some(@utf8.decode_lossy(out[0:written]))
  } else {
    None
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn filepicker_cleanup_native_test_fixture(path : String) -> Unit {
  let path_buf = @utf8.encode(path[:])
  pippa_filepicker_test_fixture_cleanup(path_buf, path_buf.length())
}

///|
#cfg(any(target="native", target="llvm"))
fn filepicker_wbtest_scan_all(
  path : String,
  max_entries : Int,
) -> Result[(Array[FileEntry], Int), String] {
  match filepicker_open_scan(path) {
    Some(handle) => {
      defer filepicker_close_scan(handle)
      let entries : Array[FileEntry] = []
      let mut chunks = 0
      let mut done = false
      while !done {
        match filepicker_scan_next(path, handle, max_entries) {
          Ok(Some(chunk)) => {
            chunks = chunks + 1
            for entry in chunk {
              entries.push(entry)
            }
          }
          Ok(None) => done = true
          Err(err) => return Err(err)
        }
      }
      Ok((filepicker_sort_entries(entries), chunks))
    }
    None => Err("failed to open fixture scan")
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn filepicker_wbtest_find_entry(
  entries : Array[FileEntry],
  name : String,
) -> FileEntry? {
  for entry in entries {
    if entry.name == name {
      return Some(entry)
    }
  }
  None
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
#cfg(any(target="native", target="llvm"))
test "filepicker native scanner populates deterministic metadata and continues past 64 entries" {
  match filepicker_create_native_test_fixture() {
    Some(root) => {
      defer filepicker_cleanup_native_test_fixture(root)
      match filepicker_wbtest_scan_all(root, 64) {
        Ok((entries, chunks)) => {
          assert_true(chunks >= 2)
          assert_true(entries.length() >= 76)
          match filepicker_wbtest_find_entry(entries, "regular.txt") {
            Some(entry) => {
              assert_false(entry.is_dir)
              assert_false(entry.is_symlink)
              assert_eq(entry.permissions, "-rw-r-----")
              assert_eq(entry.size, 8)
              assert_false(entry.hidden)
            }
            None => assert_true(false)
          }
          match filepicker_wbtest_find_entry(entries, "subdir") {
            Some(entry) => {
              assert_true(entry.is_dir)
              assert_false(entry.is_symlink)
              assert_eq(entry.permissions, "drwxr-x---")
            }
            None => assert_true(false)
          }
          match filepicker_wbtest_find_entry(entries, ".hidden") {
            Some(entry) => {
              assert_false(entry.is_dir)
              assert_eq(entry.permissions, "-rw-------")
              assert_eq(entry.size, 7)
              assert_true(entry.hidden)
            }
            None => assert_true(false)
          }
          match filepicker_wbtest_find_entry(entries, "link-file") {
            Some(entry) => {
              assert_false(entry.is_dir)
              assert_true(entry.is_symlink)
              assert_true(entry.permissions.has_prefix("l"))
              assert_eq(entry.size, "regular.txt".length())
            }
            None => assert_true(false)
          }
          match filepicker_wbtest_find_entry(entries, "link-dir") {
            Some(entry) => {
              assert_true(entry.is_dir)
              assert_true(entry.is_symlink)
              assert_true(entry.permissions.has_prefix("l"))
              assert_eq(entry.size, "subdir".length())
            }
            None => assert_true(false)
          }
          match filepicker_wbtest_find_entry(entries, "broken-link") {
            Some(entry) => {
              assert_false(entry.is_dir)
              assert_true(entry.is_symlink)
              assert_true(entry.permissions.has_prefix("l"))
              assert_eq(entry.size, "missing-target".length())
            }
            None => assert_true(false)
          }
          match filepicker_wbtest_find_entry(entries, "extra-69.txt") {
            Some(entry) => {
              assert_false(entry.is_dir)
              assert_false(entry.is_symlink)
              assert_eq(entry.size, 1)
            }
            None => assert_true(false)
          }
        }
        Err(_) => assert_true(false)
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
