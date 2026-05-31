///|
test "filepicker parity renders metadata columns and navigates" {
  let model = filepicker_parity_seeded_model()
  let moved = filepicker_parity_update(
      model,
      PickerMsg(@component.HandleInput(@pippa.Key(@pippa.Special("down")))),
    ).model
  let selected = filepicker_parity_update(moved, PickerMsg(@component.Select)).model

  assert_eq(selected.picker.cursor, 1)
  assert_eq(selected.picker.selected_path, Some("./notes.md"))
  let view = @pippa.strip_ansi(filepicker_parity_view(selected))
  assert_true(view.contains("-rw-r--r--"))
  assert_true(view.contains("notes.md"))
  assert_true(view.contains("src/"))
}

///|
test "filepicker parity hidden toggle and metadata flags are scripted" {
  let model = filepicker_parity_seeded_model()
  let toggled = filepicker_parity_update(
      model,
      PickerMsg(@component.HandleInput(@pippa.Key(@pippa.Char('.')))),
    ).model
  let no_size = filepicker_parity_update(
      toggled,
      PickerMsg(@component.SetShowSize(false)),
    ).model

  assert_true(toggled.picker.show_hidden)
  assert_false(
    @pippa.strip_ansi(filepicker_parity_view(no_size)).contains("4096"),
  )
}
