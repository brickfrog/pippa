///|
test "terminal state parity requests size and renders structured state" {
  let initialized = terminal_state_parity_init()
  assert_false(initialized.cmd.is_none())

  let measured = terminal_state_parity_update(
      initialized.model,
      WindowMeasured({ width: 100, height: 30 }),
    ).model
  let view = terminal_state_parity_structured_view(measured)

  match measured.window_size {
    Some(size) => {
      assert_eq(size.width, 100)
      assert_eq(size.height, 30)
    }
    None => fail("expected measured window size")
  }
  @test.assert_eq(view.window_title, Some("Pippa terminal state"))
  match view.cursor_position {
    Some(position) => {
      assert_eq(position.row, 2)
      assert_eq(position.col, 4)
    }
    None => fail("expected cursor position")
  }
  @test.assert_eq(view.cursor_visible, Some(false))
}

///|
test "terminal state parity toggles cursor with scripted input" {
  let model = terminal_state_parity_run_script([@pippa.Key(@pippa.Char('c'))])
  let view = terminal_state_parity_structured_view(model)

  assert_true(model.cursor_visible)
  @test.assert_eq(view.cursor_visible, Some(true))
}
