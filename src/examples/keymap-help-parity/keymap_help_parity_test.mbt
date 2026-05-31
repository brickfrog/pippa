///|
test "keymap help parity uses overridden binding and help line" {
  let { model, .. } = keymap_help_parity_init()
  let ignored = keymap_help_parity_update(
      model,
      GridMsg(@component.HandleInput(@pippa.Key(@pippa.Special("down")))),
    ).model
  let moved = keymap_help_parity_update(
      ignored,
      GridMsg(@component.HandleInput(@pippa.Key(@pippa.Char('n')))),
    ).model

  assert_eq(@component.table_cursor(ignored.grid), 0)
  assert_eq(@component.table_cursor(moved.grid), 1)
  assert_true(keymap_help_parity_view(moved).contains("n next task"))
}

///|
test "keymap help parity toggles expanded help" {
  let { model, .. } = keymap_help_parity_init()
  let toggled = keymap_help_parity_update(model, ToggleHelp).model

  assert_true(toggled.show_full_help)
  assert_true(keymap_help_parity_view(toggled).contains("Movement"))
  assert_true(keymap_help_parity_view(toggled).contains("Selection"))
}
