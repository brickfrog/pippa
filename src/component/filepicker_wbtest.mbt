///|
#cfg(any(target="native", target="llvm"))
test "filepicker native reader can read the current directory" {
  let result = filepicker_read_dir(".")
  match result {
    Ok(entries) => assert_true(entries.length() > 0)
    Err(_) => assert_true(false)
  }
}

///|
test "filepicker parent dir handles repo-like paths" {
  assert_eq(filepicker_parent_dir("src/component"), "src")
  assert_eq(filepicker_parent_dir("/tmp/demo"), "/tmp")
  assert_eq(filepicker_parent_dir("/tmp"), "/")
}

///|
test "filepicker parse_entries keeps directories first" {
  let nul = String::from_array([(0 : Int).unsafe_to_char()])
  let raw = @utf8.encode(
    ("F" +
    nul +
    "zeta.txt" +
    nul +
    "D" +
    nul +
    "alpha" +
    nul +
    "F" +
    nul +
    "beta.txt" +
    nul)[:],
  )
  let entries = filepicker_parse_entries(".", raw)
  assert_eq(entries[0], { name: "alpha", path: "alpha", is_dir: true })
  assert_eq(entries[1], { name: "beta.txt", path: "beta.txt", is_dir: false })
  assert_eq(entries[2], { name: "zeta.txt", path: "zeta.txt", is_dir: false })
}
