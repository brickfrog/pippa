///|
test "filepicker selection and hidden toggle update the model" {
  let c = filepicker(height=3)
  let model : FilepickerModel = {
    current_directory: ".",
    entries: [
      { name: ".hidden", path: ".hidden", is_dir: false },
      { name: "src", path: "src", is_dir: true },
      { name: "moon.mod.json", path: "moon.mod.json", is_dir: false },
    ],
    cursor: 0,
    selected_path: None,
    height: 3,
    show_hidden: false,
    allow_files: true,
    allow_directories: false,
    allowed_extensions: [".json"],
    error: None,
  }
  let toggled = (c.update)(model, ToggleHidden).model
  assert_eq(toggled.show_hidden, true)
  let selected = (c.update)({ ..toggled, cursor: 2 }, Select).model
  assert_eq(selected.selected_path, Some("moon.mod.json"))
}

///|
test "filepicker open on disabled file reports an error" {
  let c = filepicker(height=3, allowed_extensions=[".txt"])
  let model : FilepickerModel = {
    current_directory: ".",
    entries: [{ name: "moon.mod.json", path: "moon.mod.json", is_dir: false }],
    cursor: 0,
    selected_path: None,
    height: 3,
    show_hidden: true,
    allow_files: true,
    allow_directories: false,
    allowed_extensions: [".txt"],
    error: None,
  }
  let next = (c.update)(model, Open).model
  assert_true(next.error is Some(_))
}

///|
test "filepicker view marks directories and selected entries" {
  let c = filepicker(height=2)
  let model : FilepickerModel = {
    current_directory: "/tmp",
    entries: [
      { name: "src", path: "/tmp/src", is_dir: true },
      { name: "notes.txt", path: "/tmp/notes.txt", is_dir: false },
    ],
    cursor: 0,
    selected_path: Some("/tmp/notes.txt"),
    height: 2,
    show_hidden: true,
    allow_files: true,
    allow_directories: false,
    allowed_extensions: [],
    error: None,
  }
  let view = (c.view)(model)
  assert_true(view.contains("src/"))
  assert_true(view.contains("notes.txt"))
}
