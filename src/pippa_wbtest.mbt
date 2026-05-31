///|
test "pippa cmd tick stores interval" {
  let cmd : Cmd[Int] = Cmd::tick(120)
  assert_eq(cmd.actions.length(), 1)
  match cmd.actions[0] {
    Tick(interval_ms) => assert_eq(interval_ms, 120)
    _ => fail("expected Tick action")
  }
}

///|
test "pippa cmd batch concatenates all actions" {
  let batched : Cmd[Int] = Cmd::batch([
    Cmd::none(),
    Cmd::tick(120),
    Cmd::tick(40),
  ])
  assert_eq(batched.actions.length(), 2)
  match batched.actions[0] {
    Tick(interval_ms) => assert_eq(interval_ms, 120)
    _ => fail("expected Tick action")
  }
  match batched.actions[1] {
    Tick(interval_ms) => assert_eq(interval_ms, 40)
    _ => fail("expected Tick action")
  }
}

///|
test "pippa cmd batch preserves all action kinds" {
  let a : Cmd[Int] = Cmd::after(16, fn() { 1 })
  let b : Cmd[Int] = Cmd::perform(fn() { Some(2) })
  let c : Cmd[Int] = Cmd::tick(100)
  let batched = Cmd::batch([a, b, c])
  assert_eq(batched.actions.length(), 3)
  match batched.actions[0] {
    After(interval_ms, task) => {
      assert_eq(interval_ms, 16)
      assert_eq(task(), 1)
    }
    _ => fail("expected After action")
  }
  match batched.actions[1] {
    Perform(task) => @test.assert_eq(task(), Some(2))
    _ => fail("expected Perform action")
  }
  match batched.actions[2] {
    Tick(interval_ms) => assert_eq(interval_ms, 100)
    _ => fail("expected Tick action")
  }
}

///|
test "pippa cmd after is lazy until the runtime executes it" {
  let mut value = 1
  let cmd : Cmd[Int] = Cmd::after(16, fn() { value })
  value = 7
  match cmd.actions[0] {
    After(_, task) => assert_eq(task(), 7)
    _ => fail("expected After action")
  }
}

///|
test "pippa cmd every stores a typed aligned callback" {
  let cmd : Cmd[Int] = Cmd::every(33, fn(tick) { tick.elapsed_ms.to_int() + 4 })
  assert_eq(cmd.actions.length(), 1)
  match cmd.actions[0] {
    Every(interval_ms, task) => {
      assert_eq(interval_ms, 33)
      assert_eq(task({ elapsed_ms: 12L }), 16)
    }
    _ => fail("expected Every action")
  }
}

///|
test "pippa lifecycle command constructors store typed actions" {
  let cmd : Cmd[Int] = Cmd::batch([
    Cmd::quit(),
    Cmd::interrupt(),
    Cmd::suspend(),
    Cmd::resume(),
  ])
  assert_eq(cmd.actions.length(), 4)
  match cmd.actions[0] {
    LifecycleAction(Quit) => ()
    _ => fail("expected Quit lifecycle action")
  }
  match cmd.actions[1] {
    LifecycleAction(Interrupt) => ()
    _ => fail("expected Interrupt lifecycle action")
  }
  match cmd.actions[2] {
    LifecycleAction(Suspend) => ()
    _ => fail("expected Suspend lifecycle action")
  }
  match cmd.actions[3] {
    LifecycleAction(Resume) => ()
    _ => fail("expected Resume lifecycle action")
  }
}

///|
test "pippa exec command stores process and typed result callback" {
  let process = ExecProcess::new(command="fake", args=["--flag"])
  let cmd : Cmd[String] = Cmd::exec_process(process, fn(result) {
    match result {
      ExecCompleted(code) => "completed:" + code.to_string()
      ExecCancelled => "cancelled"
      ExecError(message) => "error:" + message
    }
  })
  assert_eq(cmd.actions.length(), 1)
  match cmd.actions[0] {
    ExecProcessAction(stored, to_msg) => {
      @test.assert_eq(stored, process)
      assert_eq(to_msg(ExecCompleted(7)), "completed:7")
      assert_eq(to_msg(ExecCancelled), "cancelled")
      assert_eq(to_msg(ExecError("boom")), "error:boom")
    }
    _ => fail("expected ExecProcess action")
  }
}

///|
test "pippa screen command constructors store typed actions" {
  let cmd : Cmd[Int] = Cmd::batch([
    Cmd::enter_alt_screen(),
    Cmd::exit_alt_screen(),
    Cmd::clear_screen(),
    Cmd::repaint(),
    Cmd::force_redraw(),
    Cmd::hide_cursor(),
    Cmd::show_cursor(),
  ])
  assert_eq(cmd.actions.length(), 7)
  assert_true(cmd.actions[0] is EnterAltScreen)
  assert_true(cmd.actions[1] is ExitAltScreen)
  assert_true(cmd.actions[2] is ClearScreen)
  assert_true(cmd.actions[3] is Repaint)
  assert_true(cmd.actions[4] is ForceRedraw)
  assert_true(cmd.actions[5] is HideCursor)
  assert_true(cmd.actions[6] is ShowCursor)
}

///|
test "pippa request window size command stores typed callback" {
  let cmd : Cmd[Int] = Cmd::request_window_size(fn(size) {
    size.width * 1000 + size.height
  })
  assert_eq(cmd.actions.length(), 1)
  match cmd.actions[0] {
    RequestWindowSize(task) => assert_eq(task({ width: 80, height: 24 }), 80024)
    _ => fail("expected RequestWindowSize action")
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn assert_terminal_cmd_emits(cmd : Cmd[Int], expected : String) -> Unit raise {
  let chunks : Ref[Array[String]] = Ref::new([])
  let program : Program[Int, Int] = Program::new(
    init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
    update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
    view=fn(_model) { "" },
    output=fn(output) { chunks.val = [..chunks.val, output] },
  )
  let sent_msgs = @queue.Queue::new()
  let pending = @queue.Queue::new()
  let sequences = @deque.Deque::new()
  let timers = []
  let state = initial_render_state(program, true)
  queue_cmd_effects(cmd, 0L, pending, timers, sequences)
  ignore(
    drain_runtime(program, 0, state, sent_msgs, pending, timers, sequences),
  )
  assert_eq(chunks.val.join(""), expected)
}

///|
#cfg(any(target="native", target="llvm"))
fn assert_terminal_query_round_trip(
  cmd : Cmd[Int],
  expected_query : String,
  reply : String,
  expected_reply : TerminalReplyMsg,
) -> Unit raise {
  assert_terminal_cmd_emits(cmd, expected_query)
  let bytes = @utf8.encode(reply)
  @test.assert_eq(
    parse_input(bytes[:]),
    Ok(TerminalReply(expected_reply), bytes.length()),
  )
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa terminal query commands round-trip through typed replies" {
  assert_terminal_query_round_trip(
    Cmd::request_device_attributes(),
    "\u001b[c",
    "\u001b[?1;2c",
    DeviceAttributes([1, 2]),
  )
  assert_terminal_query_round_trip(
    Cmd::request_secondary_device_attributes(),
    "\u001b[>c",
    "\u001b[>0;95;0c",
    SecondaryDeviceAttributes([0, 95, 0]),
  )
  assert_terminal_query_round_trip(
    Cmd::request_cursor_position(),
    "\u001b[6n",
    "\u001b[12;34R",
    CursorPosition({ row: 12, col: 34 }),
  )
  assert_terminal_query_round_trip(
    Cmd::request_foreground_color(),
    "\u001b]10;?\u001b\\",
    "\u001b]10;rgb:ffff/eeee/dddd\u001b\\",
    Color(ForegroundColor("rgb:ffff/eeee/dddd")),
  )
  assert_terminal_query_round_trip(
    Cmd::request_background_color(),
    "\u001b]11;?\u001b\\",
    "\u001b]11;rgb:0000/1111/2222\u0007",
    Color(BackgroundColor("rgb:0000/1111/2222")),
  )
  assert_terminal_query_round_trip(
    Cmd::request_capability("Co"),
    "\u001bP+q436f\u001b\\",
    "\u001bP1+r436f=323536\u001b\\",
    Capability({ name: "Co", value: Some("256"), valid: true }),
  )
  assert_terminal_query_round_trip(
    Cmd::request_clipboard(SystemClipboard),
    "\u001b]52;c;?\u001b\\",
    "\u001b]52;c;aGk=\u001b\\",
    Clipboard({
      selection: SystemClipboard,
      payload: DecodedClipboardText("hi"),
    }),
  )
  assert_terminal_query_round_trip(
    Cmd::request_clipboard(SystemClipboard),
    "\u001b]52;c;?\u001b\\",
    "\u001b]52;c;aGk=\u0007",
    Clipboard({
      selection: SystemClipboard,
      payload: DecodedClipboardText("hi"),
    }),
  )
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa terminal mode commands emit focus and paste control sequences" {
  assert_terminal_cmd_emits(Cmd::enable_focus_reporting(), "\u001b[?1004h")
  assert_terminal_cmd_emits(Cmd::disable_focus_reporting(), "\u001b[?1004l")
  assert_terminal_cmd_emits(Cmd::enable_bracketed_paste(), "\u001b[?2004h")
  assert_terminal_cmd_emits(Cmd::disable_bracketed_paste(), "\u001b[?2004l")
}

///|
test "parse_input: capability replies handle invalid and partial payloads" {
  let invalid = @utf8.encode("\u001bP0+r436f\u001b\\")
  @test.assert_eq(
    parse_input(invalid[:]),
    Ok(
      TerminalReply(Capability({ name: "Co", value: None, valid: false })),
      invalid.length(),
    ),
  )
  let partial = @utf8.encode("\u001bP1+r436f=323536")
  @test.assert_eq(parse_input(partial[:]), Incomplete)
  let valid_without_value = @utf8.encode("\u001bP1+r436f\u001b\\")
  @test.assert_eq(
    parse_input(valid_without_value[:]),
    Ok(
      TerminalReply(UnknownReply(valid_without_value)),
      valid_without_value.length(),
    ),
  )
  let invalid_with_value = @utf8.encode("\u001bP0+r436f=323536\u001b\\")
  @test.assert_eq(
    parse_input(invalid_with_value[:]),
    Ok(
      TerminalReply(UnknownReply(invalid_with_value)),
      invalid_with_value.length(),
    ),
  )
  let valid_empty_value = @utf8.encode("\u001bP1+r436f=\u001b\\")
  @test.assert_eq(
    parse_input(valid_empty_value[:]),
    Ok(
      TerminalReply(UnknownReply(valid_empty_value)),
      valid_empty_value.length(),
    ),
  )
}

///|
test "parse_input: clipboard replies decode text and keep malformed payloads typed" {
  let raw = @utf8.encode("\u001b]52;c;not@@base64\u001b\\")
  @test.assert_eq(
    parse_input(raw[:]),
    Ok(
      TerminalReply(
        Clipboard({
          selection: SystemClipboard,
          payload: RawClipboardData("not@@base64"),
        }),
      ),
      raw.length(),
    ),
  )
  let binary = @utf8.encode("\u001b]52;c;/w==\u001b\\")
  @test.assert_eq(
    parse_input(binary[:]),
    Ok(
      TerminalReply(
        Clipboard({
          selection: SystemClipboard,
          payload: RawClipboardData("/w=="),
        }),
      ),
      binary.length(),
    ),
  )
  let partial = @utf8.encode("\u001b]52;c;aGk=")
  @test.assert_eq(parse_input(partial[:]), Incomplete)
  let malformed = @utf8.encode("\u001b]52;c\u001b\\")
  @test.assert_eq(
    parse_input(malformed[:]),
    Ok(TerminalReply(UnknownReply(malformed)), malformed.length()),
  )
}

///|
test "pippa cmd map transforms perform and after results lazily" {
  let mut value = 5
  let mapped = Cmd::map(
    fn(n : Int) { "\{n}" },
    Cmd::batch([
      Cmd::perform(fn() { Some(value) }),
      Cmd::after(10, fn() { value + 1 }),
    ]),
  )
  value = 9
  match mapped.actions[0] {
    Perform(task) => @test.assert_eq(task(), Some("9"))
    _ => fail("expected Perform action")
  }
  match mapped.actions[1] {
    After(interval_ms, task) => {
      assert_eq(interval_ms, 10)
      assert_eq(task(), "10")
    }
    _ => fail("expected After action")
  }
}

///|
test "pippa cmd sequence collapses empty commands" {
  let cmd : Cmd[Int] = Cmd::sequence([Cmd::none(), Cmd::msg(1), Cmd::none()])
  assert_eq(cmd.actions.length(), 1)
  match cmd.actions[0] {
    Perform(task) => @test.assert_eq(task(), Some(1))
    _ => fail("expected collapsed immediate command")
  }
}

///|
test "pippa cmd map transforms nested sequence lazily" {
  let mut value = 3
  let mapped = Cmd::map(
    fn(n : Int) { "\{n}" },
    Cmd::sequence([
      Cmd::perform(fn() { Some(value) }),
      Cmd::after(5, fn() { value + 1 }),
    ]),
  )
  value = 8
  assert_eq(mapped.actions.length(), 1)
  match mapped.actions[0] {
    Sequence([first, second]) => {
      match first.actions[0] {
        Perform(task) => @test.assert_eq(task(), Some("8"))
        _ => fail("expected Perform action")
      }
      match second.actions[0] {
        After(interval_ms, task) => {
          assert_eq(interval_ms, 5)
          assert_eq(task(), "9")
        }
        _ => fail("expected After action")
      }
    }
    _ => fail("expected Sequence action")
  }
}

///|
test "pippa cmd map transforms every and request window size callbacks lazily" {
  let mapped = Cmd::map(
    fn(n : Int) { "\{n}" },
    Cmd::batch([
      Cmd::every(20, fn(tick) { tick.elapsed_ms.to_int() + 1 }),
      Cmd::request_window_size(fn(size) { size.width + size.height }),
    ]),
  )
  match mapped.actions[0] {
    Every(interval_ms, task) => {
      assert_eq(interval_ms, 20)
      assert_eq(task({ elapsed_ms: 4L }), "5")
    }
    _ => fail("expected Every action")
  }
  match mapped.actions[1] {
    RequestWindowSize(task) => assert_eq(task({ width: 80, height: 24 }), "104")
    _ => fail("expected RequestWindowSize action")
  }
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa program handle send queues messages until closed" {
  let pending_msgs = @queue.Queue::new()
  let pending_controls = @queue.Queue::new()
  let closed = Ref::new(false)
  let handle : ProgramHandle[Int] = {
    pending_msgs,
    pending_controls,
    wake: fn() { () },
    closed,
  }
  assert_true(handle.send(7))
  @test.assert_eq(pending_msgs.pop(), Some(7))
  assert_true(handle.release_terminal())
  match pending_controls.pop() {
    Some(ReleaseTerminal) => ()
    _ => fail("expected ReleaseTerminal")
  }
  assert_true(handle.restore_terminal())
  match pending_controls.pop() {
    Some(RestoreTerminal) => ()
    _ => fail("expected RestoreTerminal")
  }
  closed.val = true
  assert_false(handle.send(8))
  assert_false(handle.release_terminal())
  @test.assert_eq(pending_msgs.pop(), None)
  assert_true(pending_controls.pop() is None)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa sequence waits for immediate effects to settle before next step" {
  let program : Program[Array[Int], Int] = Program::new(
    init=fn() { UpdateResult::new(model=[], cmd=Cmd::none()) },
    update=fn(model, msg) {
      let next = [..model, msg]
      let cmd = if msg == 1 { Cmd::msg(10) } else { Cmd::none() }
      UpdateResult::new(model=next, cmd~)
    },
    view=fn(_model) { "" },
  )
  let sent_msgs = @queue.Queue::new()
  let pending = @queue.Queue::new()
  let sequences = @deque.Deque::new()
  let timers = []
  let state = initial_render_state(program, false)
  queue_cmd_effects(
    Cmd::sequence([Cmd::msg(1), Cmd::msg(2)]),
    0L,
    pending,
    timers,
    sequences,
  )
  let (model, reason, updated, _state) = drain_runtime(
    program,
    [],
    state,
    sent_msgs,
    pending,
    timers,
    sequences,
  )
  assert_eq(model, [1, 10, 2])
  assert_true(reason is None)
  assert_eq(updated, true)
  assert_true(pending.is_empty())
  assert_true(sequences.is_empty())
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa every alignment snaps to the next strict interval boundary" {
  assert_eq(next_aligned_every_deadline(0L, 10), 10L)
  assert_eq(next_aligned_every_deadline(9L, 10), 10L)
  assert_eq(next_aligned_every_deadline(10L, 10), 20L)
  assert_eq(next_aligned_every_deadline(1011L, 10), 1020L)

  let pending = @queue.Queue::new()
  let sequences = @deque.Deque::new()
  let timers = []
  queue_cmd_effects(
    Cmd::every(10, fn(tick) { tick.elapsed_ms.to_int() }),
    1011L,
    pending,
    timers,
    sequences,
  )
  assert_eq(timers.length(), 1)
  match timers[0] {
    EveryAt(deadline, scheduled_at, task) => {
      assert_eq(deadline, 1020L)
      assert_eq(scheduled_at, 1011L)
      assert_eq(task({ elapsed_ms: 9L }), 9)
    }
    _ => fail("expected EveryAt timer")
  }
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa every command fires once without runtime recurrence" {
  let seen : Ref[Array[Int64]] = Ref::new([])
  let started_at = Ref::new(0L)
  let program : Program[Int, Int64] = Program::new(
      init=fn() {
        started_at.val = pippa_now_ms()
        UpdateResult::new(
          model=0,
          cmd=Cmd::every(5, fn(tick) { tick.elapsed_ms }),
        )
      },
      update=fn(model, msg) {
        seen.val = [..seen.val, msg]
        UpdateResult::new(model=model + 1, cmd=Cmd::none())
      },
      view=fn(_model) { "" },
      should_quit=fn(_model) { false },
    )
    .headless()
    .with_cancelled(fn() {
      let elapsed = pippa_now_ms() - started_at.val
      started_at.val > 0L &&
      (elapsed >= 200L || (seen.val.length() >= 1 && elapsed >= 40L))
    })
  ignore(program.run())
  assert_eq(seen.val.length(), 1)
  assert_true(seen.val[0] >= 1L)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa every recurrence is app driven by reissuing the command" {
  let seen : Ref[Array[Int64]] = Ref::new([])
  let started_at = Ref::new(0L)
  let program : Program[Int, Int64] = Program::new(
      init=fn() {
        started_at.val = pippa_now_ms()
        UpdateResult::new(
          model=0,
          cmd=Cmd::every(3, fn(tick) { tick.elapsed_ms }),
        )
      },
      update=fn(model, msg) {
        seen.val = [..seen.val, msg]
        let next = model + 1
        let cmd = if next < 3 {
          Cmd::every(3, fn(tick) { tick.elapsed_ms })
        } else {
          Cmd::none()
        }
        UpdateResult::new(model=next, cmd~)
      },
      view=fn(_model) { "" },
      should_quit=fn(model) { model >= 3 },
    )
    .headless()
    .with_cancelled(fn() {
      started_at.val > 0L && pippa_now_ms() - started_at.val >= 200L
    })
  ignore(program.run())
  assert_eq(seen.val.length(), 3)
  assert_true(seen.val[0] >= 1L)
  assert_true(seen.val[1] >= 1L)
  assert_true(seen.val[2] >= 1L)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa screen commands emit ANSI and update runtime shutdown state" {
  let chunks : Ref[Array[String]] = Ref::new([])
  let program : Program[Int, Int] = Program::new(
      init=fn() {
        UpdateResult::new(
          model=0,
          cmd=Cmd::batch([
            Cmd::enter_alt_screen(),
            Cmd::hide_cursor(),
            Cmd::clear_screen(),
            Cmd::msg(1),
          ]),
        )
      },
      update=fn(_model, msg) { UpdateResult::new(model=msg, cmd=Cmd::none()) },
      view=fn(_model) { "" },
      should_quit=fn(model) { model == 1 },
    )
    .with_stdin(false)
    .with_alt_screen(false)
    .with_hide_cursor(false)
    .with_output(fn(output) { chunks.val = [..chunks.val, output] })
  ignore(program.run())
  let captured = chunks.val.join("")
  assert_true(captured.contains(enter_alt_screen()))
  assert_true(captured.contains(hide_cursor()))
  assert_true(captured.contains(clear_screen() + move_cursor(1, 1)))
  assert_true(captured.contains(exit_alt_screen()))
  assert_true(captured.contains(show_cursor()))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa exit and show cursor commands update runtime state" {
  let chunks : Ref[Array[String]] = Ref::new([])
  let program : Program[Int, Int] = Program::new(
      init=fn() {
        UpdateResult::new(
          model=0,
          cmd=Cmd::batch([
            Cmd::exit_alt_screen(),
            Cmd::show_cursor(),
            Cmd::msg(1),
          ]),
        )
      },
      update=fn(_model, msg) { UpdateResult::new(model=msg, cmd=Cmd::none()) },
      view=fn(_model) { "" },
      should_quit=fn(model) { model == 1 },
    )
    .with_stdin(false)
    .with_output(fn(output) { chunks.val = [..chunks.val, output] })
  ignore(program.run())
  let captured = chunks.val.join("")
  assert_true(captured.contains(enter_alt_screen()))
  assert_true(captured.contains(hide_cursor()))
  assert_true(captured.contains(exit_alt_screen()))
  assert_true(captured.contains(show_cursor()))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa repaint command invalidates the render cache" {
  let chunks : Ref[Array[String]] = Ref::new([])
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(model, msg) {
        let cmd = if msg == 1 {
          Cmd::sequence([Cmd::repaint(), Cmd::msg(2)])
        } else {
          Cmd::none()
        }
        UpdateResult::new(model=if msg == 2 { 2 } else { model }, cmd~)
      },
      view=fn(_model) { "paint" },
      should_quit=fn(model) { model == 2 },
    )
    .with_stdin(false)
    .with_alt_screen(false)
    .with_hide_cursor(false)
    .with_output(fn(output) { chunks.val = [..chunks.val, output] })
  ignore(program.run_with_handle(handle => ignore(handle.send(1))))
  let mut paint_chunks = 0
  for chunk in chunks.val {
    if chunk.contains("paint") {
      paint_chunks = paint_chunks + 1
    }
  }
  assert_true(paint_chunks >= 2)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa force redraw command invalidates the render cache" {
  let chunks : Ref[Array[String]] = Ref::new([])
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(model, msg) {
        let cmd = if msg == 1 {
          Cmd::sequence([Cmd::force_redraw(), Cmd::msg(2)])
        } else {
          Cmd::none()
        }
        UpdateResult::new(model=if msg == 2 { 2 } else { model }, cmd~)
      },
      view=fn(_model) { "paint" },
      should_quit=fn(model) { model == 2 },
    )
    .with_stdin(false)
    .with_alt_screen(false)
    .with_hide_cursor(false)
    .with_output(fn(output) { chunks.val = [..chunks.val, output] })
  ignore(program.run_with_handle(handle => ignore(handle.send(1))))
  let mut paint_chunks = 0
  for chunk in chunks.val {
    if chunk.contains("paint") {
      paint_chunks = paint_chunks + 1
    }
  }
  assert_true(paint_chunks >= 2)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa request window size delivers a typed message" {
  let seen : Ref[WindowSize?] = Ref::new(None)
  let program : Program[Int, WindowSize] = Program::new(
    init=fn() {
      UpdateResult::new(
        model=0,
        cmd=Cmd::request_window_size(fn(size) { size }),
      )
    },
    update=fn(_model, msg) {
      seen.val = Some(msg)
      UpdateResult::new(model=1, cmd=Cmd::none())
    },
    view=fn(_model) { "" },
    should_quit=fn(model) { model == 1 },
  ).headless()
  ignore(program.run())
  match seen.val {
    Some(size) => {
      assert_true(size.width > 0)
      assert_true(size.height > 0)
    }
    None => fail("expected typed window size message")
  }
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa typed window size hook receives initial resize and on_resize still works" {
  let typed_seen : Ref[WindowSize?] = Ref::new(None)
  let legacy_seen = Ref::new(0)
  let program : Program[Int, WindowSize] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(_model, msg) {
        typed_seen.val = Some(msg)
        UpdateResult::new(model=1, cmd=Cmd::none())
      },
      view=fn(_model) { "" },
      on_window_size=fn(size) { Some(size) },
      on_resize=fn(cols, rows) {
        legacy_seen.val = cols * 1000 + rows
        None
      },
      should_quit=fn(model) { model == 1 },
    )
    .headless()
    .with_window_size(90, 31)
  ignore(program.run())
  @test.assert_eq(typed_seen.val, Some({ width: 90, height: 31 }))
  assert_eq(legacy_seen.val, 90031)
}

///|
test "pippa program defaults enable rendering and terminal niceties" {
  let program : Program[Int, Int] = Program::new(
    init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
    update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
    view=fn(_model) { "" },
  )
  assert_true(program.alt_screen)
  assert_true(program.focus_reporting)
  assert_true(program.bracketed_paste)
  assert_true(program.hide_cursor)
  assert_true(program.rendering)
  assert_true(program.read_stdin)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa program builder options control enter and exit sequences" {
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
      view=fn(_model) { "" },
    )
    .with_alt_screen(false)
    .with_hide_cursor(false)
    .with_rendering(false)
    .with_stdin(false)
  let enter_seq = program_enter_sequence(program)
  let exit_seq = program_exit_sequence(program)
  assert_eq(enter_seq, "")
  assert_eq(exit_seq, "")
}

///|
test "pippa headless builder disables terminal IO features" {
  let program : Program[Int, Int] = Program::new(
    init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
    update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
    view=fn(_model) { "" },
  ).headless()
  assert_false(program.mouse)
  assert_false(program.alt_screen)
  assert_false(program.focus_reporting)
  assert_false(program.bracketed_paste)
  assert_false(program.hide_cursor)
  assert_false(program.rendering)
  assert_false(program.read_stdin)
}

///|
test "pippa with_input disables stdin and installs custom input source" {
  let program : Program[Int, Int] = Program::new(
    init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
    update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
    view=fn(_model) { "" },
  ).with_input(fn() { [] })
  assert_false(program.read_stdin)
  assert_true(program.input is Some(_))
}

///|
test "pippa builder options install raw input cancellation fps and window size" {
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
      view=fn(_model) { "" },
    )
    .with_raw_input(fn() { Bytes::new(0) })
    .with_cancelled(fn() { false })
    .with_fps(144)
    .with_window_size(120, 40)
  assert_false(program.read_stdin)
  assert_true(program.raw_input is Some(_))
  assert_true(program.cancelled is Some(_))
  assert_eq(program.fps, 144)
  assert_eq(program.window_width, 120)
  assert_eq(program.window_height, 40)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa runtime timeout clamps custom polling and render fps" {
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
      view=fn(_model) { "" },
    )
    .with_input(fn() { [] })
    .with_fps(500)
  assert_eq(render_interval_ms(program), 9L)
  assert_eq(runtime_timeout_ms(program, [], None), 16)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa custom output captures rendered views" {
  let captured = Ref::new("")
  let sent = Ref::new(false)
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(_model, msg) { UpdateResult::new(model=msg, cmd=Cmd::none()) },
      view=fn(model) { if model == 0 { "zero" } else { "one" } },
      should_quit=fn(model) { model == 1 },
    )
    .with_stdin(false)
    .with_alt_screen(false)
    .with_hide_cursor(false)
    .with_output(fn(output) { captured.val = captured.val + output })
  ignore(program.run_with_handle(handle => sent.val = handle.send(1)))
  assert_true(sent.val)
  assert_true(captured.val.contains("zero"))
  assert_true(captured.val.contains("one"))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa custom input drives sub in headless mode" {
  let polled = Ref::new(false)
  let seen : Ref[Array[Int]] = Ref::new([])
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(_model, msg) {
        seen.val = [..seen.val, msg]
        UpdateResult::new(model=msg, cmd=Cmd::none())
      },
      view=fn(_model) { "" },
      sub=fn(evt) {
        match evt {
          Key(Char('a')) => Some(1)
          Key(Char('b')) => Some(2)
          _ => None
        }
      },
      should_quit=fn(model) { model == 2 },
    )
    .headless()
    .with_input(fn() {
      if polled.val {
        []
      } else {
        polled.val = true
        [Key(Char('a')), Key(Char('b'))]
      }
    })
  ignore(program.run())
  assert_eq(seen.val, [1, 2])
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa custom input can render updates without stdin" {
  let polled = Ref::new(false)
  let captured = Ref::new("")
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(_model, msg) {
        let cmd = if msg == 1 { Cmd::msg(99) } else { Cmd::none() }
        UpdateResult::new(model=msg, cmd~)
      },
      view=fn(model) { if model == 0 { "idle" } else { "typed" } },
      sub=fn(evt) {
        match evt {
          Key(Char('x')) => Some(1)
          _ => None
        }
      },
      should_quit=fn(model) { model == 99 },
    )
    .with_input(fn() {
      if polled.val {
        []
      } else {
        polled.val = true
        [Key(Char('x'))]
      }
    })
    .with_alt_screen(false)
    .with_hide_cursor(false)
    .with_output(fn(output) { captured.val = captured.val + output })
  ignore(program.run())
  assert_true(captured.val.contains("idle"))
  assert_true(captured.val.contains("typed"))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa raw input source drives parsing without stdin" {
  let polled = Ref::new(false)
  let seen : Ref[Array[Int]] = Ref::new([])
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(_model, msg) {
        seen.val = [..seen.val, msg]
        UpdateResult::new(model=msg, cmd=Cmd::none())
      },
      view=fn(_model) { "" },
      sub=fn(evt) {
        match evt {
          Key(Char('a')) => Some(1)
          Key(Char('b')) => Some(2)
          _ => None
        }
      },
      should_quit=fn(model) { model == 2 },
    )
    .headless()
    .with_raw_input(fn() {
      if polled.val {
        Bytes::new(0)
      } else {
        polled.val = true
        @utf8.encode("ab")
      }
    })
  ignore(program.run())
  assert_eq(seen.val, [1, 2])
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa window size option seeds initial resize message" {
  let seen = Ref::new(None)
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(_model, msg) {
        seen.val = Some(msg)
        UpdateResult::new(model=msg, cmd=Cmd::none())
      },
      view=fn(_model) { "" },
      on_resize=fn(cols, rows) { Some(cols * 1000 + rows) },
      should_quit=fn(model) { model == 80024 },
    )
    .headless()
    .with_window_size(80, 24)
  ignore(program.run())
  @test.assert_eq(seen.val, Some(80024))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa cancellation hook stops a headless program" {
  let polls = Ref::new(0)
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
      view=fn(_model) { "" },
    )
    .headless()
    .with_cancelled(fn() {
      polls.val = polls.val + 1
      polls.val >= 2
    })
  ignore(program.run())
  assert_true(polls.val >= 2)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa handle can release and restore terminal" {
  let handle_ref : Ref[ProgramHandle[Int]?] = Ref::new(None)
  let polled = Ref::new(false)
  let captured = Ref::new("")
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(_model, msg) {
        let cmd = if msg == 1 { Cmd::msg(2) } else { Cmd::none() }
        UpdateResult::new(model=msg, cmd~)
      },
      view=fn(model) { if model == 0 { "zero" } else { "one" } },
      sub=fn(evt) {
        match evt {
          Key(Char('x')) => Some(1)
          _ => None
        }
      },
      should_quit=fn(model) { model == 2 },
    )
    .with_raw_input(fn() {
      if polled.val {
        Bytes::new(0)
      } else {
        polled.val = true
        handle_ref.val
        .iter()
        .each(fn(handle) {
          ignore(handle.release_terminal())
          ignore(handle.restore_terminal())
        })
        @utf8.encode("x")
      }
    })
    .with_output(fn(output) { captured.val = captured.val + output })
  ignore(program.run_with_handle(handle => handle_ref.val = Some(handle)))
  assert_true(captured.val.contains(enter_alt_screen()))
  assert_true(captured.val.contains(exit_alt_screen()))
  assert_true(captured.val.contains("zero"))
  assert_true(captured.val.contains("one"))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa headless run_with_handle can quit from injected message" {
  let seen = Ref::new(0)
  let sent = Ref::new(false)
  let program : Program[Int, Int] = Program::new(
    init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
    update=fn(_model, msg) {
      seen.val = msg
      UpdateResult::new(model=msg, cmd=Cmd::none())
    },
    view=fn(_model) { "" },
    should_quit=fn(model) { model == 7 },
  ).headless()
  ignore(program.run_with_handle(handle => sent.val = handle.send(7)))
  assert_true(sent.val)
  assert_eq(seen.val, 7)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa catch_interrupt false delivers ctrl-c to sub" {
  let polled = Ref::new(false)
  let seen : Ref[Array[String]] = Ref::new([])
  let program : Program[String, String] = Program::new(
      init=fn() { UpdateResult::new(model="", cmd=Cmd::none()) },
      update=fn(_model, msg) {
        seen.val = [..seen.val, msg]
        UpdateResult::new(model=msg, cmd=Cmd::none())
      },
      view=fn(_model) { "" },
      sub=fn(evt) {
        match evt {
          Key(Modified("ctrl", "c")) => Some("ctrl-c")
          Key(Char('q')) => Some("q")
          _ => None
        }
      },
      should_quit=fn(model) { model == "q" },
      catch_interrupt=false,
    )
    .headless()
    .with_input(fn() {
      if polled.val {
        []
      } else {
        polled.val = true
        [Key(Modified("ctrl", "c")), Key(Char('q'))]
      }
    })
  ignore(program.run())
  // With catch_interrupt=false the runtime does NOT force-quit on Ctrl+C,
  // so both events reach sub and update sees them both.
  assert_eq(seen.val, ["ctrl-c", "q"])
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa catch_interrupt true force-quits on ctrl-c before sub sees it" {
  let polled = Ref::new(false)
  let seen : Ref[Array[String]] = Ref::new([])
  let program : Program[String, String] = Program::new(
      init=fn() { UpdateResult::new(model="", cmd=Cmd::none()) },
      update=fn(_model, msg) {
        seen.val = [..seen.val, msg]
        UpdateResult::new(model=msg, cmd=Cmd::none())
      },
      view=fn(_model) { "" },
      sub=fn(evt) {
        match evt {
          Key(Modified("ctrl", "c")) => Some("ctrl-c")
          Key(Char('q')) => Some("q")
          _ => None
        }
      },
      // catch_interrupt defaults to true
    )
    .headless()
    .with_input(fn() {
      if polled.val {
        []
      } else {
        polled.val = true
        [Key(Modified("ctrl", "c")), Key(Char('q'))]
      }
    })
  ignore(program.run())
  // With catch_interrupt=true the runtime force-quits on Ctrl+C.
  // sub still fires for the Ctrl+C event (it runs before the quit check breaks
  // the loop), but 'q' is never reached because we already broke out.
  assert_eq(seen.val, ["ctrl-c"])
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa run result returns final model for clean quit" {
  let program : Program[Int, Int] = Program::new(
    init=fn() { UpdateResult::new(model=0, cmd=Cmd::msg(3)) },
    update=fn(_model, msg) { UpdateResult::new(model=msg, cmd=Cmd::none()) },
    view=fn(_model) { "" },
    should_quit=fn(model) { model == 3 },
  ).headless()
  match program.run() {
    RunQuit(model) => assert_eq(model, 3)
    _ => fail("expected RunQuit")
  }
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa run result distinguishes interrupt and delivers lifecycle message" {
  let polled = Ref::new(false)
  let seen : Ref[Array[LifecycleMsg]] = Ref::new([])
  let program : Program[Array[LifecycleMsg], LifecycleMsg] = Program::new(
      init=fn() { UpdateResult::new(model=[], cmd=Cmd::none()) },
      update=fn(model, msg) {
        let next = [..model, msg]
        seen.val = next
        UpdateResult::new(model=next, cmd=Cmd::none())
      },
      view=fn(_model) { "" },
      on_lifecycle=fn(msg) { Some(msg) },
    )
    .headless()
    .with_input(fn() {
      if polled.val {
        []
      } else {
        polled.val = true
        [Key(Modified("ctrl", "c"))]
      }
    })
  match program.run() {
    RunInterrupted(model) => @test.assert_eq(model, [Interrupt])
    _ => fail("expected RunInterrupted")
  }
  @test.assert_eq(seen.val, [Interrupt])
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa lifecycle commands deliver suspend resume and quit messages" {
  let seen : Ref[Array[LifecycleMsg]] = Ref::new([])
  let program : Program[Array[LifecycleMsg], LifecycleMsg] = Program::new(
    init=fn() {
      UpdateResult::new(
        model=[],
        cmd=Cmd::sequence([Cmd::suspend(), Cmd::quit()]),
      )
    },
    update=fn(model, msg) {
      let next = [..model, msg]
      seen.val = next
      UpdateResult::new(model=next, cmd=Cmd::none())
    },
    view=fn(_model) { "" },
    on_lifecycle=fn(msg) { Some(msg) },
  ).headless()
  match program.run() {
    RunQuit(model) => @test.assert_eq(model, [Suspend, Resume, Quit])
    _ => fail("expected RunQuit")
  }
  @test.assert_eq(seen.val, [Suspend, Resume, Quit])
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa runtime error result carries typed message" {
  let program : Program[Int, Int] = Program::new(
    init=fn() { UpdateResult::new(model=0, cmd=Cmd::runtime_error("boom")) },
    update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
    view=fn(_model) { "" },
  ).headless()
  match program.run() {
    RunRuntimeError(message) => assert_eq(message, "boom")
    _ => fail("expected RunRuntimeError")
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn assert_exec_runner_result(
  fake_result : ExecResult,
  expected : ExecResult,
) -> Unit raise {
  let seen : Ref[ExecResult?] = Ref::new(None)
  let ran_process : Ref[ExecProcess?] = Ref::new(None)
  let program : Program[Int, ExecResult] = Program::new(
      init=fn() {
        UpdateResult::new(
          model=0,
          cmd=Cmd::exec_process(
            ExecProcess::new(command="fake", args=["arg"]),
            fn(result) { result },
          ),
        )
      },
      update=fn(_model, msg) {
        seen.val = Some(msg)
        UpdateResult::new(model=1, cmd=Cmd::none())
      },
      view=fn(_model) { "" },
      should_quit=fn(model) { model == 1 },
    )
    .headless()
    .with_exec_runner(fn(process) {
      ran_process.val = Some(process)
      fake_result
    })
  match program.run() {
    RunExec(model, result) => {
      assert_eq(model, 1)
      @test.assert_eq(result, expected)
    }
    _ => fail("expected RunExec")
  }
  @test.assert_eq(seen.val, Some(expected))
  @test.assert_eq(
    ran_process.val,
    Some(ExecProcess::new(command="fake", args=["arg"])),
  )
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa exec delivers success cancel and error results" {
  assert_exec_runner_result(ExecCompleted(0), ExecCompleted(0))
  assert_exec_runner_result(ExecCancelled, ExecCancelled)
  assert_exec_runner_result(ExecError("nope"), ExecError("nope"))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa exec releases terminal before runner and restores after" {
  let release_before_run = Ref::new(false)
  let release_seen_by_runner = Ref::new(false)
  let restore_after_run = Ref::new(false)
  let ran = Ref::new(false)
  let program : Program[Int, ExecResult] = Program::new(
      init=fn() {
        UpdateResult::new(
          model=0,
          cmd=Cmd::exec_process(ExecProcess::new(command="fake", args=[]), fn(
            result,
          ) {
            result
          }),
        )
      },
      update=fn(_model, _msg) { UpdateResult::new(model=1, cmd=Cmd::none()) },
      view=fn(_model) { "" },
      should_quit=fn(model) { model == 1 },
    )
    .with_stdin(false)
    .with_hide_cursor(false)
    .with_focus_reporting(false)
    .with_bracketed_paste(false)
    .with_output(fn(output) {
      if output.contains(exit_alt_screen()) && !ran.val {
        release_before_run.val = true
      }
      if output.contains(enter_alt_screen()) && ran.val {
        restore_after_run.val = true
      }
    })
    .with_exec_runner(fn(_process) {
      release_seen_by_runner.val = release_before_run.val
      ran.val = true
      ExecCompleted(0)
    })
  match program.run() {
    RunExec(model, ExecCompleted(0)) => assert_eq(model, 1)
    _ => fail("expected successful RunExec")
  }
  assert_true(release_seen_by_runner.val)
  assert_true(restore_after_run.val)
}
