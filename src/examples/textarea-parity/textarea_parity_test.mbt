///|
test "textarea parity scripts multiline editing and soft wrap" {
  let model = textarea_parity_run_script([
    @pippa.Key(@pippa.Text("alpha beta")),
    @pippa.Key(@pippa.Special("enter")),
    @pippa.Key(@pippa.Text("gamma")),
  ])

  assert_eq(model.editor.value, "alpha beta\ngamma")
  assert_eq(model.editor.cursor_row, 1)
  assert_eq(model.editor.cursor_col, 5)
  assert_eq(
    textarea_parity_editor_snapshot(model),
    "  > beta\n2 > gamm\n  > a   ",
  )
}

///|
test "textarea parity resize keeps wrap fixture deterministic" {
  let { model, .. } = textarea_parity_init()
  let seeded = textarea_parity_update(
      model,
      EditorMsg(@component.SetValue("abcd")),
    ).model
  let resized = textarea_parity_update(
      seeded,
      EditorMsg(@component.Resize(8, 2)),
    ).model

  assert_eq(resized.editor.width, 8)
  assert_eq(textarea_parity_editor_snapshot(resized), "1 > abcd")
}
