///|
test "pippa ansi bold" {
  let styled = bold()
  let reset_str = reset()
  inspect(
    "\{styled}Hello from Pippa!\{reset_str}",
    content="\u001b[1mHello from Pippa!\u001b[0m",
  )
}

///|
test "pippa ansi hyperlink wraps label in OSC 8" {
  assert_eq(
    hyperlink("http://example.com", "label"),
    "\u001b]8;;http://example.com\u001b\\label\u001b]8;;\u001b\\",
  )
}

///|
test "pippa create program" {
  let program : Program[Int, Unit] = Program::new(
    init=fn() { UpdateResult::new(model=42, cmd=Cmd::none()) },
    update=fn(model : Int, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
    view=fn(model : Int) { "Count: \{model}" },
    mouse=true,
  )
  assert_eq(program.mouse, true)
}

///|
test "pippa create program with on_resize" {
  let _program : Program[Int, Unit] = Program::new(
    init=fn() { UpdateResult::new(model=42, cmd=Cmd::none()) },
    update=fn(model : Int, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
    view=fn(model : Int) { "Count: \{model}" },
    on_resize=fn(_cols : Int, _rows : Int) { None },
  )
}

///|
test "pippa View text carries content with empty terminal state" {
  let view = View::text("hello")
  assert_eq(view.content, "hello")
  assert_true(view.cursor_position is None)
  assert_true(view.cursor_visible is None)
  assert_true(view.window_title is None)
  assert_true(view.foreground_color is None)
  assert_true(view.background_color is None)
  assert_true(view.progress is None)
  assert_true(view.mouse_mode is None)
}

///|
test "pippa View round-trips optional terminal state fields" {
  let view = View::text("body")
    .with_cursor_position(row=3, col=9)
    .with_cursor_visible(false)
    .with_window_title("Pippa")
    .with_foreground_color(color_rgb(1, 2, 3))
    .with_background_color(color_ansi(4))
    .with_progress(ViewProgressPercent(42))
    .with_mouse_mode(ViewMouseAllMotion)
  assert_eq(view.content, "body")
  @test.assert_eq(view.cursor_position, Some({ row: 3, col: 9 }))
  @test.assert_eq(view.cursor_visible, Some(false))
  @test.assert_eq(view.window_title, Some("Pippa"))
  @test.assert_eq(view.foreground_color, Some(color_rgb(1, 2, 3)))
  @test.assert_eq(view.background_color, Some(color_ansi(4)))
  @test.assert_eq(view.progress, Some(ViewProgressPercent(42)))
  @test.assert_eq(view.mouse_mode, Some(ViewMouseAllMotion))
}

///|
test "pippa View cursor positions are clamped to terminal coordinates" {
  let from_builder = View::text("body").with_cursor_position(row=0, col=-4)
  @test.assert_eq(from_builder.cursor_position, Some({ row: 1, col: 1 }))

  let from_new = View::new(
    content="body",
    cursor_position=Some({ row: -8, col: 0 }),
  )
  @test.assert_eq(from_new.cursor_position, Some({ row: 1, col: 1 }))
}

///|
test "pippa update result" {
  let result : UpdateResult[Int, Unit] = UpdateResult::new(
    model=10,
    cmd=Cmd::none(),
  )
  assert_eq(result.model, 10)
}

///|
test "pippa ansi enter alternate screen" {
  inspect(enter_alt_screen(), content="\u001b[?1049h")
}

///|
test "pippa ansi enable mouse" {
  inspect(enable_mouse(), content="\u001b[?1000h\u001b[?1006h")
}

///|
test "pippa ansi enable mouse cell motion" {
  inspect(enable_mouse_cell_motion(), content="\u001b[?1002h\u001b[?1006h")
}

///|
test "pippa ansi enable mouse motion" {
  inspect(enable_mouse_motion(), content="\u001b[?1003h\u001b[?1006h")
}

///|
test "pippa ansi enable focus reporting" {
  inspect(enable_focus_reporting(), content="\u001b[?1004h")
}

///|
test "pippa ansi enable bracketed paste" {
  inspect(enable_bracketed_paste(), content="\u001b[?2004h")
}

///|
test "pippa ansi disable mouse" {
  inspect(
    disable_mouse(),
    content="\u001b[?1000l\u001b[?1002l\u001b[?1003l\u001b[?1006l",
  )
}

///|
test "pippa ansi disable focus reporting" {
  inspect(disable_focus_reporting(), content="\u001b[?1004l")
}

///|
test "pippa ansi disable bracketed paste" {
  inspect(disable_bracketed_paste(), content="\u001b[?2004l")
}

///|
test "pippa ansi exit alternate screen" {
  inspect(exit_alt_screen(), content="\u001b[?1049l")
}
