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
test "pippa ansi set clipboard base64 encodes UTF-8 vectors" {
  let vectors = [
    ("", ""),
    ("M", "TQ=="),
    ("Ma", "TWE="),
    ("Man", "TWFu"),
    ("hello", "aGVsbG8="),
    ("é", "w6k="),
  ]
  for vector in vectors {
    let (input, encoded) = vector
    assert_eq(
      set_clipboard(SystemClipboard, input),
      "\u001b]52;c;\{encoded}\u001b\\",
    )
  }
}

///|
test "pippa ansi set clipboard emits exact OSC 52 selection bytes" {
  assert_eq(
    set_clipboard(SystemClipboard, "hello"),
    "\u001b]52;c;aGVsbG8=\u001b\\",
  )
  assert_eq(
    set_clipboard(PrimarySelection, "hello"),
    "\u001b]52;p;aGVsbG8=\u001b\\",
  )
  assert_eq(set_clipboard(SecondarySelection, "M"), "\u001b]52;s;TQ==\u001b\\")
  assert_eq(set_clipboard(CutBuffer(3), "M"), "\u001b]52;3;TQ==\u001b\\")
  assert_eq(set_clipboard(NamedSelection("x"), "M"), "\u001b]52;x;TQ==\u001b\\")
}

///|
test "pippa ansi cursor style emits exact DECSCUSR bytes" {
  assert_eq(set_cursor_style(Default), "\u001b[0 q")
  assert_eq(set_cursor_style(BlinkBlock), "\u001b[1 q")
  assert_eq(set_cursor_style(SteadyBlock), "\u001b[2 q")
  assert_eq(set_cursor_style(BlinkUnderline), "\u001b[3 q")
  assert_eq(set_cursor_style(SteadyUnderline), "\u001b[4 q")
  assert_eq(set_cursor_style(BlinkBar), "\u001b[5 q")
  assert_eq(set_cursor_style(SteadyBar), "\u001b[6 q")
}

///|
#cfg(any(target="native", target="llvm"))
fn count_substring(haystack : String, needle : String) -> Int {
  if needle == "" {
    return 0
  }
  let mut count = 0
  let mut pos = 0
  while pos <= haystack.length() - needle.length() {
    if haystack[pos:pos + needle.length()] == needle {
      count = count + 1
      pos = pos + needle.length()
    } else {
      pos = pos + 1
    }
  }
  count
}

///|
#cfg(any(target="native", target="llvm"))
fn join_chunks_before_last(chunks : Array[String]) -> String {
  let mut joined = ""
  let mut i = 0
  while i + 1 < chunks.length() {
    joined = joined + chunks[i]
    i = i + 1
  }
  joined
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa cursor style command emits DECSCUSR at runtime" {
  let captured = Ref("")
  let program : Program[Int, Int] = Program::new(
      init=fn() {
        UpdateResult::new(
          model=0,
          cmd=Cmd::sequence([Cmd::set_cursor_style(SteadyBar), Cmd::quit()]),
        )
      },
      update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
      view=fn(_model) { "" },
    )
    .with_stdin(false)
    .with_alt_screen(false)
    .with_hide_cursor(false)
    .with_output(fn(output) { captured.val = captured.val + output })
  match program.run() {
    RunQuit(_) => ()
    _ => fail("expected RunQuit")
  }
  assert_true(captured.val.contains(set_cursor_style(SteadyBar)))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa clipboard set command emits OSC 52 every time at runtime" {
  let captured = Ref("")
  let system_clipboard = set_clipboard(SystemClipboard, "runtime")
  let primary_clipboard = set_clipboard(PrimarySelection, "é")
  let program : Program[Int, Int] = Program::new(
      init=fn() {
        UpdateResult::new(
          model=0,
          cmd=Cmd::sequence([
            Cmd::set_clipboard("runtime"),
            Cmd::set_clipboard("runtime"),
            Cmd::set_clipboard_for(PrimarySelection, "é"),
            Cmd::quit(),
          ]),
        )
      },
      update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
      view=fn(_model) { "" },
    )
    .with_stdin(false)
    .with_alt_screen(false)
    .with_hide_cursor(false)
    .with_output(fn(output) { captured.val = captured.val + output })
  match program.run() {
    RunQuit(_) => ()
    _ => fail("expected RunQuit")
  }
  assert_eq(count_substring(captured.val, system_clipboard), 2)
  assert_eq(count_substring(captured.val, primary_clipboard), 1)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa structured cursor style is not re-emitted on unchanged render" {
  let captured = Ref("")
  let sent = Ref(false)
  let program : Program[Int, Int] = Program::new(
      init=fn() {
        UpdateResult::new(model=0, cmd=Cmd::set_cursor_style(BlinkBar))
      },
      update=fn(_model, msg) { UpdateResult::new(model=msg, cmd=Cmd::none()) },
      view=fn(_model) { "" },
      should_quit=fn(model) { model == 1 },
    )
    .with_structured_view(fn(_model) {
      View::text("").with_cursor_style(BlinkBar)
    })
    .with_stdin(false)
    .with_alt_screen(false)
    .with_hide_cursor(false)
    .with_output(fn(output) { captured.val = captured.val + output })
  match program.run_with_handle(handle => sent.val = handle.send(1)) {
    RunQuit(_) => ()
    _ => fail("expected RunQuit")
  }
  assert_true(sent.val)
  assert_eq(count_substring(captured.val, set_cursor_style(BlinkBar)), 1)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa structured cursor style reset is emitted when stale non-default style clears" {
  let chunks : Ref[Array[String]] = Ref([])
  let sent = Ref(false)
  let polled = Ref(false)
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(_model, msg) { UpdateResult::new(model=msg, cmd=Cmd::none()) },
      view=fn(_model) { "" },
      sub=fn(evt) {
        match evt {
          Key(Char('q')) => Some(2)
          _ => None
        }
      },
      should_quit=fn(model) { model == 2 },
    )
    .with_structured_view(fn(model) {
      if model == 0 {
        View::text("").with_cursor_style(BlinkBar)
      } else {
        View::text("")
      }
    })
    .with_input(fn() {
      if polled.val {
        []
      } else {
        polled.val = true
        [Key(Char('q'))]
      }
    })
    .with_alt_screen(false)
    .with_hide_cursor(false)
    .with_output(fn(output) { chunks.val = [..chunks.val, output] })
  match program.run_with_handle(handle => sent.val = handle.send(1)) {
    RunQuit(_) => ()
    _ => fail("expected RunQuit")
  }
  assert_true(sent.val)
  let before_teardown = join_chunks_before_last(chunks.val)
  assert_eq(count_substring(before_teardown, set_cursor_style(BlinkBar)), 1)
  assert_eq(count_substring(before_teardown, set_cursor_style(Default)), 1)
  assert_eq(count_substring(chunks.val.join(""), set_cursor_style(Default)), 2)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa structured cursor style default clears without duplicate reset" {
  let chunks : Ref[Array[String]] = Ref([])
  let sent = Ref(false)
  let polled = Ref(false)
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(_model, msg) { UpdateResult::new(model=msg, cmd=Cmd::none()) },
      view=fn(_model) { "" },
      sub=fn(evt) {
        match evt {
          Key(Char('q')) => Some(2)
          _ => None
        }
      },
      should_quit=fn(model) { model == 2 },
    )
    .with_structured_view(fn(model) {
      if model == 0 {
        View::text("").with_cursor_style(Default)
      } else {
        View::text("")
      }
    })
    .with_input(fn() {
      if polled.val {
        []
      } else {
        polled.val = true
        [Key(Char('q'))]
      }
    })
    .with_alt_screen(false)
    .with_hide_cursor(false)
    .with_output(fn(output) { chunks.val = [..chunks.val, output] })
  match program.run_with_handle(handle => sent.val = handle.send(1)) {
    RunQuit(_) => ()
    _ => fail("expected RunQuit")
  }
  assert_true(sent.val)
  let before_teardown = join_chunks_before_last(chunks.val)
  assert_eq(count_substring(before_teardown, set_cursor_style(Default)), 1)
  assert_eq(count_substring(chunks.val.join(""), set_cursor_style(Default)), 2)
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
  assert_true(view.cursor_style is None)
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
    .with_cursor_style(BlinkUnderline)
    .with_foreground_color(color_rgb(1, 2, 3))
    .with_background_color(color_ansi(4))
    .with_progress(ViewProgressPercent(42))
    .with_mouse_mode(ViewMouseAllMotion)
  assert_eq(view.content, "body")
  @test.assert_eq(view.cursor_position, Some({ row: 3, col: 9 }))
  @test.assert_eq(view.cursor_visible, Some(false))
  @test.assert_eq(view.window_title, Some("Pippa"))
  @test.assert_eq(view.cursor_style, Some(BlinkUnderline))
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
