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
    Perform(task) => assert_eq(task(), Some(2))
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
    Perform(task) => assert_eq(task(), Some("9"))
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
    Perform(task) => assert_eq(task(), Some(1))
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
        Perform(task) => assert_eq(task(), Some("8"))
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
#cfg(any(target="native", target="llvm"))
test "pippa program handle send queues messages until closed" {
  let pending_msgs = @queue.Queue::new()
  let closed = Ref::new(false)
  let handle : ProgramHandle[Int] = { pending_msgs, wake: fn() { () }, closed }
  assert_true(handle.send(7))
  assert_eq(pending_msgs.pop(), Some(7))
  closed.val = true
  assert_false(handle.send(8))
  assert_eq(pending_msgs.pop(), None)
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
  queue_cmd_effects(
    Cmd::sequence([Cmd::msg(1), Cmd::msg(2)]),
    0L,
    pending,
    timers,
    sequences,
  )
  let (model, quit, updated) = drain_runtime(
    program,
    [],
    sent_msgs,
    pending,
    timers,
    sequences,
  )
  assert_eq(model, [1, 10, 2])
  assert_eq(quit, false)
  assert_eq(updated, true)
  assert_true(pending.is_empty())
  assert_true(sequences.is_empty())
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
  program.run_with_handle(handle => sent.val = handle.send(1))
  assert_true(sent.val)
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
  program.run_with_handle(handle => sent.val = handle.send(7))
  assert_true(sent.val)
  assert_eq(seen.val, 7)
}
