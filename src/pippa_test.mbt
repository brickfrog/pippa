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
test "pippa ansi disable mouse" {
  inspect(disable_mouse(), content="\u001b[?1000l\u001b[?1003l")
}

///|
test "pippa ansi exit alternate screen" {
  inspect(exit_alt_screen(), content="\u001b[?1049l")
}
