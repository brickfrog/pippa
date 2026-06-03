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
test "pippa print above printf formats string placeholders" {
  assert_eq(
    print_above_format("row %s is %s%% done", ["alpha", "90"]),
    "row alpha is 90% done",
  )
  assert_eq(print_above_format("missing %s", []), "missing %s")
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
    Cmd::resume_program(),
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
      ExecSignaled(signal) => "signaled:" + signal.to_string()
      ExecError(message) => "error:" + message
    }
  })
  assert_eq(cmd.actions.length(), 1)
  match cmd.actions[0] {
    ExecProcessAction(stored, to_msg) => {
      @test.assert_eq(stored, process)
      assert_eq(to_msg(ExecCompleted(7)), "completed:7")
      assert_eq(to_msg(ExecCancelled), "cancelled")
      assert_eq(to_msg(ExecSignaled(15)), "signaled:15")
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
test "pippa synchronized output helpers use DEC private mode 2026" {
  assert_eq(begin_sync_update(), "\u001b[?2026h")
  assert_eq(end_sync_update(), "\u001b[?2026l")
}

///|
#cfg(any(target="native", target="llvm"))
fn assert_terminal_cmd_emits(cmd : Cmd[Int], expected : String) -> Unit raise {
  let chunks : Ref[Array[String]] = Ref([])
  let program : Program[Int, Int] = Program::new(
    init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
    update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
    view=fn(_model) { "" },
    output=fn(output) { chunks.val = [..chunks.val, output] },
  )
  let sent_msgs = @queue.Queue([])
  let pending = @queue.Queue([])
  let sequences = @deque.Deque([])
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
test "runtime color profile parses OSC 11 and merges capabilities monotonically" {
  assert_true(
    runtime_background_from_osc11("rgb:ffff/ffff/ffff") is Some(@profile.Light),
  )
  assert_true(
    runtime_background_from_osc11("rgb:0000/0000/0000") is Some(@profile.Dark),
  )
  assert_true(
    runtime_background_from_osc11("rgb:ff/ff/ff") is Some(@profile.Light),
  )

  let env_truecolor = @profile.RenderContext::default()
  let invalid = { name: "Tc", value: None, valid: false }
  assert_eq(
    runtime_context_apply_capability(env_truecolor, invalid),
    env_truecolor,
  )

  let low = @profile.RenderContext::default().with_color_profile(
    @profile.NoColor,
  )
  let co16 = { name: "Co", value: Some("16"), valid: true }
  assert_eq(
    runtime_context_apply_capability(low, co16).color_profile,
    @profile.Ansi16,
  )
  let co256 = { name: "Co", value: Some("256"), valid: true }
  assert_eq(
    runtime_context_apply_capability(low, co256).color_profile,
    @profile.Ansi256,
  )
  let tc = { name: "Tc", value: Some(""), valid: true }
  assert_eq(
    runtime_context_apply_capability(low, tc).color_profile,
    @profile.TrueColor,
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
  let pending_msgs = @queue.Queue([])
  let pending_controls = @queue.Queue([])
  let closed = Ref(false)
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
  let sent_msgs = @queue.Queue([])
  let pending = @queue.Queue([])
  let sequences = @deque.Deque([])
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
  @test.assert_eq(model, [1, 10, 2])
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

  let pending = @queue.Queue([])
  let sequences = @deque.Deque([])
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
  let seen : Ref[Array[Int64]] = Ref([])
  let started_at = Ref(0L)
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
  let seen : Ref[Array[Int64]] = Ref([])
  let started_at = Ref(0L)
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
  let chunks : Ref[Array[String]] = Ref([])
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
  let chunks : Ref[Array[String]] = Ref([])
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
  let chunks : Ref[Array[String]] = Ref([])
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
  let chunks : Ref[Array[String]] = Ref([])
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
fn test_render_program(chunks : Ref[Array[String]]) -> Program[Int, Int] {
  Program::new(
    init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
    update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
    view=fn(model) { "plain \{model}" },
    output=fn(output) { chunks.val = [..chunks.val, output] },
  )
}

///|
#cfg(any(target="native", target="llvm"))
fn count_sequence(haystack : String, needle : String) -> Int {
  let source = @utf8.encode(haystack)
  let target = @utf8.encode(needle)
  if target.length() == 0 {
    0
  } else {
    let mut count = 0
    let mut i = 0
    while i + target.length() <= source.length() {
      let mut matched = true
      let mut j = 0
      while j < target.length() {
        if source[i + j] != target[j] {
          matched = false
          break
        }
        j = j + 1
      }
      if matched {
        count = count + 1
        i = i + target.length()
      } else {
        i = i + 1
      }
    }
    count
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn sync_frame(output : String) -> String {
  begin_sync_update() + output + end_sync_update()
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa desired_view wraps plain string views and flushes the same frame" {
  let chunks : Ref[Array[String]] = Ref([])
  let program = test_render_program(chunks)
  let next = desired_view(program, 7)
  @test.assert_eq(next, View::text("plain 7"))
  let (rendered, lines, _last_render_ms, due_at, _terminal_state) = flush_view(
    program,
    "",
    next,
    0,
    runtime_view_terminal_state_empty(),
    true,
    0L,
    true,
    true,
  )
  assert_eq(rendered, "plain 7")
  assert_eq(lines, 1)
  assert_true(due_at is None)
  assert_eq(chunks.val.join(""), sync_frame("\u001b[1;1H\u001b[Kplain 7"))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa flush_view synchronizes content frames without wrapping no-ops or disabled programs" {
  let chunks : Ref[Array[String]] = Ref([])
  let program = test_render_program(chunks)
  let (rendered, lines, last_render_ms, due_at, terminal_state) = flush_view(
    program,
    "",
    View::text("frame"),
    0,
    runtime_view_terminal_state_empty(),
    true,
    0L,
    true,
    true,
  )
  assert_true(due_at is None)
  let captured = chunks.val.join("")
  assert_true(captured.has_prefix(begin_sync_update()))
  assert_true(captured.has_suffix(end_sync_update()))
  assert_eq(captured, sync_frame("\u001b[1;1H\u001b[Kframe"))

  chunks.val = []
  ignore(
    flush_view(
      program,
      rendered,
      View::text("frame"),
      lines,
      terminal_state,
      true,
      last_render_ms,
      true,
      false,
    ),
  )
  assert_eq(chunks.val.join(""), "")

  chunks.val = []
  let unwrapped_program = program.with_synchronized_output(false)
  ignore(
    flush_view(
      unwrapped_program,
      "",
      View::text("legacy"),
      0,
      runtime_view_terminal_state_empty(),
      true,
      0L,
      true,
      true,
    ),
  )
  assert_eq(chunks.val.join(""), "\u001b[1;1H\u001b[Klegacy")
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa print above command emits scrollback line and repaints current view" {
  let chunks : Ref[Array[String]] = Ref([])
  let program = test_render_program(chunks)
    .with_alt_screen(false)
    .with_window_size(80, 5)
  let view = desired_view(program, 3)
  let (rendered, lines, last_render_ms, _due_at, terminal_state) = flush_view(
    program,
    "",
    view,
    0,
    runtime_view_terminal_state_empty(),
    true,
    0L,
    true,
    true,
  )
  assert_eq(rendered, "plain 3")
  assert_eq(lines, 1)

  chunks.val = []
  let sent_msgs = @queue.Queue([])
  let pending = @queue.Queue([])
  let sequences = @deque.Deque([])
  let timers = []
  let state = {
    ..initial_render_state(program, true),
    rendered,
    prev_line_count: lines,
    last_render_ms,
    view_terminal_state: terminal_state,
  }
  queue_cmd_effects(Cmd::println("scrollback"), 0L, pending, timers, sequences)
  let (_model, reason, updated, next_state) = drain_runtime(
    program, 3, state, sent_msgs, pending, timers, sequences,
  )
  assert_true(reason is None)
  assert_false(updated)
  assert_eq(next_state.rendered, "plain 3")
  assert_eq(next_state.prev_line_count, 1)
  let print_above_output = move_cursor(1, 1) +
    clear_line() +
    move_cursor(5, 1) +
    "scrollback" +
    clear_line() +
    "\r\n" +
    move_cursor(1, 1) +
    clear_line() +
    "plain 3"
  assert_eq(chunks.val.join(""), sync_frame(print_above_output))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa print above command is ignored in alt screen mode" {
  let chunks : Ref[Array[String]] = Ref([])
  let program = test_render_program(chunks)
    .with_alt_screen(true)
    .with_synchronized_output(false)
  let sent_msgs = @queue.Queue([])
  let pending = @queue.Queue([])
  let sequences = @deque.Deque([])
  let timers = []
  let state = {
    ..initial_render_state(program, true),
    rendered: "plain 4",
    prev_line_count: 1,
  }
  queue_cmd_effects(Cmd::println("hidden"), 0L, pending, timers, sequences)
  let (_model, reason, updated, next_state) = drain_runtime(
    program, 4, state, sent_msgs, pending, timers, sequences,
  )
  assert_true(reason is None)
  assert_false(updated)
  assert_eq(next_state.rendered, "plain 4")
  assert_eq(chunks.val.join(""), "")
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa structured_view carries state while rendering content unchanged" {
  let chunks : Ref[Array[String]] = Ref([])
  let program = test_render_program(chunks).with_structured_view(fn(model) {
    View::text("structured \{model}")
    .with_cursor_position(row=2, col=4)
    .with_cursor_visible(true)
    .with_window_title("Structured")
    .with_progress(ViewProgressIndeterminate)
    .with_mouse_mode(ViewMousePress)
  })
  let next = desired_view(program, 5)
  assert_eq(next.content, "structured 5")
  @test.assert_eq(next.cursor_position, Some({ row: 2, col: 4 }))
  @test.assert_eq(next.cursor_visible, Some(true))
  @test.assert_eq(next.window_title, Some("Structured"))
  @test.assert_eq(next.progress, Some(ViewProgressIndeterminate))
  @test.assert_eq(next.mouse_mode, Some(ViewMousePress))
  let (rendered, lines, _last_render_ms, due_at, _terminal_state) = flush_view(
    program,
    "",
    next,
    0,
    runtime_view_terminal_state_empty(),
    true,
    0L,
    true,
    true,
  )
  assert_eq(rendered, "structured 5")
  assert_eq(lines, 1)
  assert_true(due_at is None)
  let captured = chunks.val.join("")
  assert_true(captured.contains("\u001b]2;Structured\u001b\\"))
  assert_true(captured.contains("\u001b]9;4;3;0\u001b\\"))
  assert_true(captured.contains(enable_mouse()))
  assert_true(captured.contains(show_cursor()))
  assert_true(captured.contains(move_cursor(2, 4)))
  assert_true(captured.contains("\u001b[1;1H\u001b[Kstructured 5"))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa flush_view emits cursor state once and reconciles unchanged frames" {
  let chunks : Ref[Array[String]] = Ref([])
  let program = test_render_program(chunks)
  let view = View::text("one")
    .with_cursor_position(row=4, col=7)
    .with_cursor_visible(false)
  let (rendered, lines, last_render_ms, due_at, terminal_state) = flush_view(
    program,
    "",
    view,
    0,
    runtime_view_terminal_state_empty(),
    true,
    0L,
    true,
    false,
  )
  assert_eq(rendered, "one")
  assert_eq(lines, 1)
  assert_true(due_at is None)
  let first = chunks.val.join("")
  assert_true(first.contains(move_cursor(4, 7)))
  assert_true(first.contains(hide_cursor()))

  chunks.val = []
  let changed_view = View::text("two")
    .with_cursor_position(row=4, col=7)
    .with_cursor_visible(false)
  let (rendered2, lines2, last2, due2, terminal_state2) = flush_view(
    program, rendered, changed_view, lines, terminal_state, true, last_render_ms,
    true, false,
  )
  assert_true(due2 is None)
  assert_eq(
    chunks.val.join(""),
    sync_frame("\u001b[1;1H\u001b[Ktwo\u001b[4;7H"),
  )

  chunks.val = []
  let (_rendered3, _lines3, _last3, due3, _terminal_state3) = flush_view(
    program, rendered2, changed_view, lines2, terminal_state2, true, last2, true,
    false,
  )
  assert_true(due3 is None)
  assert_eq(chunks.val.join(""), "")
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa flush_view sets changes and clears window title" {
  let chunks : Ref[Array[String]] = Ref([])
  let program = test_render_program(chunks)
  let state0 = runtime_view_terminal_state_empty()
  let (rendered1, lines1, last1, _d1, state1) = flush_view(
    program,
    "",
    View::text("").with_window_title("Alpha"),
    0,
    state0,
    true,
    0L,
    true,
    false,
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b]2;Alpha\u001b\\"))

  chunks.val = []
  let (rendered_same, lines_same, last_same, _d_same, state_same) = flush_view(
    program,
    rendered1,
    View::text("same").with_window_title("Alpha"),
    lines1,
    state1,
    true,
    last1,
    true,
    false,
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b[1;1H\u001b[Ksame"))

  chunks.val = []
  let (_r2, _l2, last2, _d2, state2) = flush_view(
    program,
    rendered_same,
    View::text("").with_window_title("Beta"),
    lines_same,
    state_same,
    true,
    last_same,
    true,
    false,
  )
  assert_eq(
    chunks.val.join(""),
    sync_frame("\u001b]2;Beta\u001b\\\u001b[1;1H\u001b[K"),
  )

  chunks.val = []
  ignore(
    flush_view(program, "", View::text(""), 0, state2, true, last2, true, false),
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b]2;\u001b\\"))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa flush_view applies and resets default foreground and background colors" {
  let chunks : Ref[Array[String]] = Ref([])
  let program = test_render_program(chunks)
  let (rendered1, lines1, last1, _d1, state1) = flush_view(
    program,
    "",
    View::text("")
    .with_foreground_color(color_ansi(2))
    .with_background_color(color_rgb(1, 2, 3)),
    0,
    runtime_view_terminal_state_empty(),
    true,
    0L,
    true,
    false,
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b[38;5;2m\u001b[48;2;1;2;3m"))

  chunks.val = []
  let (rendered_same, lines_same, last_same, _d_same, state_same) = flush_view(
    program,
    rendered1,
    View::text("same")
    .with_foreground_color(color_ansi(2))
    .with_background_color(color_rgb(1, 2, 3)),
    lines1,
    state1,
    true,
    last1,
    true,
    false,
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b[1;1H\u001b[Ksame"))

  chunks.val = []
  ignore(
    flush_view(
      program,
      rendered_same,
      View::text(""),
      lines_same,
      state_same,
      true,
      last_same,
      true,
      false,
    ),
  )
  assert_eq(
    chunks.val.join(""),
    sync_frame("\u001b[39m\u001b[49m\u001b[1;1H\u001b[K"),
  )
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa flush_view maps every ViewProgress variant to OSC 9;4" {
  let chunks : Ref[Array[String]] = Ref([])
  let program = test_render_program(chunks)
  let state0 = runtime_view_terminal_state_empty()

  ignore(
    flush_view(
      program,
      "",
      View::text("").with_progress(ViewProgressIndeterminate),
      0,
      state0,
      true,
      0L,
      true,
      false,
    ),
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b]9;4;3;0\u001b\\"))

  chunks.val = []
  let (rendered_percent, lines_percent, last_percent, _d_percent, state_percent) = flush_view(
    program,
    "",
    View::text("").with_progress(ViewProgressPercent(42)),
    0,
    state0,
    true,
    0L,
    true,
    false,
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b]9;4;1;42\u001b\\"))

  chunks.val = []
  let (_r_same, _l_same, _last_same, _d_same, state_same) = flush_view(
    program,
    rendered_percent,
    View::text("same").with_progress(ViewProgressPercent(42)),
    lines_percent,
    state_percent,
    true,
    last_percent,
    true,
    false,
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b[1;1H\u001b[Ksame"))

  chunks.val = []
  let (_r_clear, _l_clear, _last_clear, _d_clear, state_clear) = flush_view(
    program,
    "",
    View::text("").with_progress(ViewProgressNone),
    0,
    state_same,
    true,
    0L,
    true,
    false,
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b]9;4;0;0\u001b\\"))

  chunks.val = []
  ignore(
    flush_view(
      program,
      "",
      View::text("cleared"),
      0,
      state_clear,
      true,
      0L,
      true,
      false,
    ),
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b[1;1H\u001b[Kcleared"))

  chunks.val = []
  ignore(
    flush_view(
      program,
      "",
      View::text("").with_progress(ViewProgressPaused(Some(77))),
      0,
      state0,
      true,
      0L,
      true,
      false,
    ),
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b]9;4;4;77\u001b\\"))

  chunks.val = []
  ignore(
    flush_view(
      program,
      "",
      View::text("").with_progress(ViewProgressError(None)),
      0,
      state0,
      true,
      0L,
      true,
      false,
    ),
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b]9;4;2;0\u001b\\"))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa flush_view reconciles mouse mode transitions" {
  let chunks : Ref[Array[String]] = Ref([])
  let program = test_render_program(chunks)
  let (rendered1, lines1, last1, _d1, state1) = flush_view(
    program,
    "",
    View::text("").with_mouse_mode(ViewMousePress),
    0,
    runtime_view_terminal_state_empty(),
    true,
    0L,
    true,
    false,
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b[?1000h\u001b[?1006h"))

  chunks.val = []
  let (rendered_same, lines_same, last_same, _d_same, state_same) = flush_view(
    program,
    rendered1,
    View::text("same").with_mouse_mode(ViewMousePress),
    lines1,
    state1,
    true,
    last1,
    true,
    false,
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b[1;1H\u001b[Ksame"))

  chunks.val = []
  let (_r2, _l2, last2, _d2, state2) = flush_view(
    program,
    rendered_same,
    View::text("").with_mouse_mode(ViewMouseAllMotion),
    lines_same,
    state_same,
    true,
    last_same,
    true,
    false,
  )
  assert_eq(
    chunks.val.join(""),
    sync_frame("\u001b[?1000l\u001b[?1003h\u001b[?1006h\u001b[1;1H\u001b[K"),
  )

  chunks.val = []
  let (_r3, _l3, last3, _d3, state3) = flush_view(
    program,
    "",
    View::text("").with_mouse_mode(ViewMousePress),
    0,
    state2,
    true,
    last2,
    true,
    false,
  )
  assert_eq(
    chunks.val.join(""),
    sync_frame("\u001b[?1003l\u001b[?1000h\u001b[?1006h"),
  )

  chunks.val = []
  let (_r_off, _l_off, last_off, _d_off, state_off) = flush_view(
    program,
    "",
    View::text("").with_mouse_mode(ViewMouseOff),
    0,
    state3,
    true,
    last3,
    true,
    false,
  )
  assert_eq(
    chunks.val.join(""),
    sync_frame("\u001b[?1000l\u001b[?1003l\u001b[?1006l"),
  )

  chunks.val = []
  ignore(
    flush_view(
      program,
      "",
      View::text("off"),
      0,
      state_off,
      true,
      last_off,
      true,
      false,
    ),
  )
  assert_eq(chunks.val.join(""), sync_frame("\u001b[1;1H\u001b[Koff"))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa initial view terminal cache reflects program-managed cursor and mouse" {
  let chunks : Ref[Array[String]] = Ref([])
  let program : Program[Int, Int] = Program::new(
    init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
    update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
    view=fn(_model) { "" },
    mouse=true,
    output=fn(output) { chunks.val = [..chunks.val, output] },
  )
  let render_state = initial_render_state(program, true)
  @test.assert_eq(render_state.view_terminal_state.cursor_visible, Some(false))
  @test.assert_eq(
    render_state.view_terminal_state.mouse_mode,
    Some(ViewMousePress),
  )
  ignore(
    flush_view(
      program,
      "",
      View::text("").with_cursor_visible(false).with_mouse_mode(ViewMousePress),
      0,
      render_state.view_terminal_state,
      true,
      0L,
      true,
      false,
    ),
  )
  assert_eq(chunks.val.join(""), "")
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa runtime screen commands keep structured cursor cache honest" {
  let chunks : Ref[Array[String]] = Ref([])
  let program = test_render_program(chunks)
    .with_alt_screen(false)
    .with_hide_cursor(false)
  let state = {
    ..initial_render_state(program, true),
    cursor_hidden: true,
    view_terminal_state: {
      ..runtime_view_terminal_state_empty(),
      cursor_position: Some({ row: 4, col: 7 }),
      cursor_visible: Some(false),
    },
  }

  let shown = apply_screen_command(program, state, RuntimeShowCursor)
  @test.assert_eq(shown.view_terminal_state.cursor_visible, Some(true))
  chunks.val = []
  let (_r1, _l1, _last1, _d1, _state1) = flush_view(
    program,
    "",
    View::text("").with_cursor_visible(false),
    0,
    shown.view_terminal_state,
    true,
    0L,
    true,
    false,
  )
  assert_eq(chunks.val.join(""), sync_frame(hide_cursor()))

  chunks.val = []
  let cleared = apply_screen_command(program, state, RuntimeClearScreen)
  @test.assert_eq(cleared.view_terminal_state.cursor_position, None)
  chunks.val = []
  ignore(
    flush_view(
      program,
      "",
      View::text("").with_cursor_position(row=4, col=7),
      0,
      cleared.view_terminal_state,
      true,
      0L,
      true,
      false,
    ),
  )
  assert_eq(chunks.val.join(""), sync_frame(move_cursor(4, 7)))

  let repainted = apply_screen_command(program, state, RuntimeRepaint)
  @test.assert_eq(repainted.view_terminal_state.cursor_position, None)
  let forced = apply_screen_command(program, state, RuntimeForceRedraw)
  @test.assert_eq(forced.view_terminal_state.cursor_position, None)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa runtime hide cursor command updates structured cursor cache" {
  let chunks : Ref[Array[String]] = Ref([])
  let program = test_render_program(chunks)
    .with_alt_screen(false)
    .with_hide_cursor(false)
  let state = {
    ..initial_render_state(program, true),
    cursor_hidden: false,
    view_terminal_state: {
      ..runtime_view_terminal_state_empty(),
      cursor_visible: Some(true),
    },
  }

  let hidden = apply_screen_command(program, state, RuntimeHideCursor)
  @test.assert_eq(hidden.cursor_hidden, true)
  @test.assert_eq(hidden.view_terminal_state.cursor_visible, Some(false))
  chunks.val = []
  ignore(
    flush_view(
      program,
      "",
      View::text("").with_cursor_visible(true),
      0,
      hidden.view_terminal_state,
      true,
      0L,
      true,
      false,
    ),
  )
  assert_eq(chunks.val.join(""), sync_frame(show_cursor()))
}

///|
#cfg(any(target="native", target="llvm"))
fn wbtest_restore_env_var(key : String, value : String?) -> Unit {
  match value {
    Some(v) => @env.set_env_var(key, v)
    None => @env.unset_env_var(key)
  }
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa interrupt cleanup resets structured terminal state at runtime" {
  let previous_colorterm = @env.get_env_var("COLORTERM")
  let previous_term = @env.get_env_var("TERM")
  let previous_no_color = @env.get_env_var("NO_COLOR")
  let previous_clicolor_force = @env.get_env_var("CLICOLOR_FORCE")
  let previous_clicolor = @env.get_env_var("CLICOLOR")
  @env.unset_env_var("NO_COLOR")
  @env.unset_env_var("CLICOLOR_FORCE")
  @env.set_env_var("CLICOLOR", "1")
  @env.set_env_var("COLORTERM", "truecolor")
  @env.set_env_var("TERM", "xterm-256color")
  defer wbtest_restore_env_var("NO_COLOR", previous_no_color)
  defer wbtest_restore_env_var("CLICOLOR_FORCE", previous_clicolor_force)
  defer wbtest_restore_env_var("CLICOLOR", previous_clicolor)
  defer wbtest_restore_env_var("COLORTERM", previous_colorterm)
  defer wbtest_restore_env_var("TERM", previous_term)

  let chunks : Ref[Array[String]] = Ref([])
  let polled = Ref(false)
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(model, _msg) { UpdateResult::new(model~, cmd=Cmd::none()) },
      view=fn(_model) { "" },
    )
    .with_structured_view(fn(_model) {
      View::text("live")
      .with_cursor_visible(false)
      .with_window_title("Runtime")
      .with_foreground_color(color_ansi(3))
      .with_background_color(color_rgb(4, 5, 6))
      .with_progress(ViewProgressPercent(33))
      .with_mouse_mode(ViewMousePress)
    })
    .with_input(fn() {
      if polled.val {
        []
      } else {
        polled.val = true
        [Key(Modified("ctrl", "c"))]
      }
    })
    .with_alt_screen(false)
    .with_hide_cursor(false)
    .with_output(fn(output) { chunks.val = [..chunks.val, output] })
  match program.run() {
    RunInterrupted(_) => ()
    _ => fail("expected RunInterrupted")
  }
  let captured = chunks.val.join("")
  assert_true(captured.contains(hide_cursor()))
  assert_true(captured.contains(set_window_title("Runtime")))
  assert_true(captured.contains(fg_color(3)))
  assert_true(captured.contains(bg_rgb(4, 5, 6)))
  assert_true(captured.contains(set_terminal_progress(1, 33)))
  assert_true(captured.contains(enable_mouse()))
  assert_true(captured.contains(terminal_view_reset_sequence()))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa request window size delivers a typed message" {
  let seen : Ref[WindowSize?] = Ref(None)
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
  let typed_seen : Ref[WindowSize?] = Ref(None)
  let legacy_seen = Ref(0)
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
  assert_true(program.synchronized_output)
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
  assert_eq(next_render_deadline_after(program, 0L), 9L)
  assert_eq(runtime_timeout_ms(program, [], None), 16)
}

///|
#cfg(any(target="native", target="llvm"))
priv enum RuntimePacingMsg {
  RuntimePacingTick
}

///|
#cfg(any(target="native", target="llvm"))
priv struct RuntimePacingStats {
  rendered_frames : Int
  interval_count : Int
  min_interval_ms : Int64
  max_interval_ms : Int64
  mean_interval_micros : Int64
  jitter_ms : Int64
  last_frame_ms : Int64
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_pacing_next_deadline(
  timers : Array[RuntimeTimer[RuntimePacingMsg]],
  render_due_at : Int64?,
  limit_ms : Int64,
) -> Int64? {
  let mut next : Int64? = None
  for timer in timers {
    let deadline = timer_deadline(timer)
    if deadline <= limit_ms {
      match next {
        Some(current) => if deadline < current { next = Some(deadline) }
        None => next = Some(deadline)
      }
    }
  }
  match render_due_at {
    Some(deadline) =>
      if deadline <= limit_ms {
        match next {
          Some(current) =>
            if deadline < current {
              Some(deadline)
            } else {
              next
            }
          None => Some(deadline)
        }
      } else {
        next
      }
    None => next
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_pacing_frame_times() -> Array[Int64] raise {
  let now = Ref(0L)
  let previous_clock = runtime_clock_override.val
  runtime_clock_override.val = Some(fn() { now.val })
  defer restore_runtime_clock(previous_clock)

  let frame_times : Ref[Array[Int64]] = Ref([])
  let program : Program[Int, RuntimePacingMsg] = Program::new(
      init=fn() {
        UpdateResult::new(
          model=0,
          cmd=Cmd::after(16, fn() { RuntimePacingTick }),
        )
      },
      update=fn(model, _msg) {
        let next = model + 1
        let cmd = if now.val + 16L <= 1000L {
          Cmd::after(16, fn() { RuntimePacingTick })
        } else {
          Cmd::none()
        }
        UpdateResult::new(model=next, cmd~)
      },
      view=fn(model) { "frame \{model}" },
      output=fn(_output) { frame_times.val = [..frame_times.val, now.val] },
    )
    .with_stdin(false)
    .with_alt_screen(false)
    .with_hide_cursor(false)
    .with_fps(60)

  let init_res = (program.init)()
  let mut model = init_res.model
  let sent_msgs = @queue.Queue([])
  let pending = @queue.Queue([])
  let sequences = @deque.Deque([])
  let mut timers : Array[RuntimeTimer[RuntimePacingMsg]] = []
  queue_cmd_effects(init_res.cmd, runtime_now_ms(), pending, timers, sequences)

  let mut render_state = initial_render_state(program, true)
  let mut desired = desired_view(program, model)
  let (
    initial_rendered,
    initial_line_count,
    initial_last_render_ms,
    initial_render_due_at,
    initial_view_terminal_state,
  ) = flush_view(
    program,
    render_state.rendered,
    desired,
    render_state.prev_line_count,
    render_state.view_terminal_state,
    render_state.terminal_active,
    render_state.last_render_ms,
    true,
    true,
  )
  render_state = {
    ..render_state,
    rendered: initial_rendered,
    prev_line_count: initial_line_count,
    last_render_ms: initial_last_render_ms,
    render_due_at: initial_render_due_at,
    force_full_repaint: false,
    view_terminal_state: initial_view_terminal_state,
  }

  while true {
    match
      runtime_pacing_next_deadline(timers, render_state.render_due_at, 1000L) {
      Some(deadline) => now.val = deadline
      None => break
    }

    timers = queue_due_timers(program, now.val, timers, pending)
    let (next_model, reason, updated, next_render_state) = drain_runtime(
      program, model, render_state, sent_msgs, pending, timers, sequences,
    )
    model = next_model
    render_state = next_render_state
    assert_true(reason is None)
    if updated {
      desired = desired_view(program, model)
    }

    let should_flush_view = updated ||
      (match render_state.render_due_at {
        Some(deadline) => now.val >= deadline
        None => false
      })
    if should_flush_view {
      let (
        next_rendered,
        next_line_count,
        next_last_render_ms,
        next_render_due_at,
        next_view_terminal_state,
      ) = flush_view(
        program,
        render_state.rendered,
        desired,
        render_state.prev_line_count,
        render_state.view_terminal_state,
        render_state.terminal_active,
        render_state.last_render_ms,
        false,
        render_state.force_full_repaint,
      )
      render_state = {
        ..render_state,
        rendered: next_rendered,
        prev_line_count: next_line_count,
        last_render_ms: next_last_render_ms,
        render_due_at: next_render_due_at,
        force_full_repaint: false,
        view_terminal_state: next_view_terminal_state,
      }
    }
  }
  frame_times.val
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_pacing_stats(frames : Array[Int64]) -> RuntimePacingStats raise {
  if frames.length() < 2 {
    fail("expected at least two rendered frames")
  }
  let mut min_interval = frames[1] - frames[0]
  let mut max_interval = min_interval
  let mut total = 0L
  let mut index = 1
  while index < frames.length() {
    let interval = frames[index] - frames[index - 1]
    if interval < min_interval {
      min_interval = interval
    }
    if interval > max_interval {
      max_interval = interval
    }
    total = total + interval
    index = index + 1
  }
  let interval_count = frames.length() - 1
  {
    rendered_frames: interval_count,
    interval_count,
    min_interval_ms: min_interval,
    max_interval_ms: max_interval,
    mean_interval_micros: total * 1000L / interval_count.to_int64(),
    jitter_ms: max_interval - min_interval,
    last_frame_ms: frames[frames.length() - 1],
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_pacing_stats_summary(stats : RuntimePacingStats) -> String {
  "renders=\{stats.rendered_frames}, intervals=\{stats.interval_count}, mean_us=\{stats.mean_interval_micros}, jitter_ms=\{stats.jitter_ms}, min_ms=\{stats.min_interval_ms}, max_ms=\{stats.max_interval_ms}, last_ms=\{stats.last_frame_ms}"
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa 16ms after animation paces to 60 evenly spaced fps-capped frames" {
  let stats = runtime_pacing_stats(runtime_pacing_frame_times())
  let summary = runtime_pacing_stats_summary(stats)
  let expected = "renders=60, intervals=60, mean_us=16666, " +
    "jitter_ms=1, min_ms=16, max_ms=17, last_ms=1000"
  if summary != expected {
    fail("expected 60 fps-capped frames over 1000ms; got " + summary)
  }
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa custom output captures rendered views" {
  let captured = Ref("")
  let sent = Ref(false)
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
  let polled = Ref(false)
  let seen : Ref[Array[Int]] = Ref([])
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
  @test.assert_eq(seen.val, [1, 2])
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa custom input can render updates without stdin" {
  let polled = Ref(false)
  let captured = Ref("")
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
  let polled = Ref(false)
  let seen : Ref[Array[Int]] = Ref([])
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
  @test.assert_eq(seen.val, [1, 2])
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa window size option seeds initial resize message" {
  let seen = Ref(None)
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
  let polls = Ref(0)
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
  let handle_ref : Ref[ProgramHandle[Int]?] = Ref(None)
  let polled = Ref(false)
  let captured = Ref("")
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
test "pippa restore seeds structured cache from program cursor and mouse flags" {
  let ran = Ref(false)
  let restore_chunks : Ref[Array[String]] = Ref([])
  let program : Program[Int, Int] = Program::new(
      init=fn() { UpdateResult::new(model=0, cmd=Cmd::none()) },
      update=fn(_model, msg) {
        let cmd = if msg == 1 {
          Cmd::exec_process(ExecProcess::new(command="fake", args=[]), fn(
            _result,
          ) {
            2
          })
        } else {
          Cmd::none()
        }
        UpdateResult::new(model=msg, cmd~)
      },
      view=fn(_model) { "" },
      mouse=true,
      alt_screen=false,
      focus_reporting=false,
      bracketed_paste=false,
      should_quit=fn(model) { model == 2 },
    )
    .with_structured_view(fn(_model) {
      View::text("restored")
      .with_cursor_visible(false)
      .with_mouse_mode(ViewMousePress)
    })
    .with_output(fn(output) {
      if ran.val {
        restore_chunks.val = [..restore_chunks.val, output]
      }
    })
    .with_exec_runner(fn(_process) {
      ran.val = true
      ExecCompleted(0)
    })
  match program.run_with_handle(handle => ignore(handle.send(1))) {
    RunExec(model, ExecCompleted(0)) => assert_eq(model, 2)
    _ => fail("expected successful RunExec")
  }
  let restored = restore_chunks.val.join("")
  assert_true(restored.contains("restored"))
  assert_eq(count_sequence(restored, hide_cursor()), 1)
  assert_eq(count_sequence(restored, enable_mouse()), 1)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa headless run_with_handle can quit from injected message" {
  let seen = Ref(0)
  let sent = Ref(false)
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
  let polled = Ref(false)
  let seen : Ref[Array[String]] = Ref([])
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
  @test.assert_eq(seen.val, ["ctrl-c", "q"])
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa catch_interrupt true force-quits on ctrl-c before sub sees it" {
  let polled = Ref(false)
  let seen : Ref[Array[String]] = Ref([])
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
  // With catch_interrupt=true the runtime intercepts Ctrl+C before `sub`;
  // 'q' is never reached because we already broke out.
  @test.assert_eq(seen.val, [])
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa catch_interrupt skips sub even when ctrl-c sub would quit" {
  let polled = Ref(false)
  let sub_seen = Ref(false)
  let program : Program[String, String] = Program::new(
      init=fn() { UpdateResult::new(model="", cmd=Cmd::none()) },
      update=fn(_model, msg) { UpdateResult::new(model=msg, cmd=Cmd::none()) },
      view=fn(_model) { "" },
      sub=fn(evt) {
        match evt {
          Key(Modified("ctrl", "c")) => {
            sub_seen.val = true
            Some("quit")
          }
          _ => None
        }
      },
      should_quit=fn(model) { model == "quit" },
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
    RunInterrupted(model) => assert_eq(model, "")
    _ => fail("expected RunInterrupted")
  }
  assert_false(sub_seen.val)
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
  let polled = Ref(false)
  let seen : Ref[Array[LifecycleMsg]] = Ref([])
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
  let seen : Ref[Array[LifecycleMsg]] = Ref([])
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
    )
    .headless()
    .with_suspend_runner(fn() { () })
  match program.run() {
    RunQuit(model) => @test.assert_eq(model, [Suspend, Resume, Quit])
    _ => fail("expected RunQuit")
  }
  @test.assert_eq(seen.val, [Suspend, Resume, Quit])
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa ctrl-z triggers lifecycle suspend before sub" {
  let polled = Ref(false)
  let sub_seen = Ref(false)
  let suspended = Ref(false)
  let program : Program[Array[LifecycleMsg], LifecycleMsg] = Program::new(
      init=fn() { UpdateResult::new(model=[], cmd=Cmd::none()) },
      update=fn(model, msg) {
        let next = [..model, msg]
        let cmd = if msg == Resume { Cmd::quit() } else { Cmd::none() }
        UpdateResult::new(model=next, cmd~)
      },
      view=fn(_model) { "" },
      sub=fn(evt) {
        match evt {
          Key(Modified("ctrl", "z")) => {
            sub_seen.val = true
            Some(Suspend)
          }
          _ => None
        }
      },
      on_lifecycle=fn(msg) { Some(msg) },
    )
    .headless()
    .with_suspend_runner(fn() { suspended.val = true })
    .with_input(fn() {
      if polled.val {
        []
      } else {
        polled.val = true
        [Key(Modified("ctrl", "z"))]
      }
    })
  match program.run() {
    RunQuit(model) => @test.assert_eq(model, [Suspend, Resume, Quit])
    _ => fail("expected RunQuit")
  }
  assert_true(suspended.val)
  assert_false(sub_seen.val)
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
  let seen : Ref[ExecResult?] = Ref(None)
  let ran_process : Ref[ExecProcess?] = Ref(None)
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
  assert_exec_runner_result(ExecSignaled(15), ExecSignaled(15))
  assert_exec_runner_result(ExecError("nope"), ExecError("nope"))
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa default exec runner reports exit exec failure and signals" {
  match default_exec_runner(ExecProcess::new(command="false", args=[])) {
    ExecCompleted(code) => assert_eq(code, 1)
    _ => fail("expected false to exit with status 1")
  }
  match
    default_exec_runner(
      ExecProcess::new(command="pippa-command-that-should-not-exist", args=[]),
    ) {
    ExecError(message) =>
      assert_eq(message, "failed to exec pippa-command-that-should-not-exist")
    _ => fail("expected missing command to report exec failure")
  }
  match
    default_exec_runner(
      ExecProcess::new(command="sh", args=["-c", "kill -TERM $$"]),
    ) {
    ExecSignaled(signal) => assert_eq(signal, 15)
    _ => fail("expected signal termination")
  }
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa default exec runner restores terminal after missing command error" {
  let missing = "/nonexistent/pippa-d1s-no-such-binary"
  let captured = Ref("")
  let program : Program[Int, ExecResult] = Program::new(
      init=fn() {
        UpdateResult::new(
          model=0,
          cmd=Cmd::exec_process(ExecProcess::new(command=missing, args=[]), fn(
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
    .with_output(fn(output) { captured.val = captured.val + output })
  match program.run() {
    RunExec(model, ExecError(message)) => {
      assert_eq(model, 1)
      assert_eq(message, "failed to exec " + missing)
    }
    _ => fail("expected missing command ExecError")
  }
  assert_eq(count_sequence(captured.val, enter_alt_screen()), 2)
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa default exec runner rejects embedded nul bytes" {
  match
    default_exec_runner(ExecProcess::new(command="fake\u0000split", args=[])) {
    ExecError(message) => assert_eq(message, "command contains NUL byte")
    _ => fail("expected command NUL error")
  }
  match
    default_exec_runner(
      ExecProcess::new(command="fake", args=["ok\u0000split"]),
    ) {
    ExecError(message) => assert_eq(message, "argument contains NUL byte")
    _ => fail("expected argument NUL error")
  }
}

///|
#cfg(any(target="native", target="llvm"))
test "pippa exec releases terminal before runner and restores after" {
  let release_before_run = Ref(false)
  let release_seen_by_runner = Ref(false)
  let restore_after_run = Ref(false)
  let ran = Ref(false)
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

///|
#cfg(any(target="native", target="llvm"))
test "pippa exec restores terminal after runner error" {
  let restored = Ref(false)
  let ran = Ref(false)
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
      if output.contains(enter_alt_screen()) && ran.val {
        restored.val = true
      }
    })
    .with_exec_runner(fn(_process) {
      ran.val = true
      ExecError("nope")
    })
  match program.run() {
    RunExec(model, ExecError("nope")) => assert_eq(model, 1)
    _ => fail("expected error RunExec")
  }
  assert_true(restored.val)
}
