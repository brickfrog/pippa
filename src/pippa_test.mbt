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
  inspect(enable_mouse(), content="\u001b[?1000h")
}

///|
test "pippa ansi enable mouse motion" {
  inspect(enable_mouse_motion(), content="\u001b[?1003h")
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
  inspect(disable_mouse(), content="\u001b[?1000l\u001b[?1003l")
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
