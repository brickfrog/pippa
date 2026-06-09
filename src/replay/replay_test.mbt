///|
priv enum TestMsg {
  Add(Int)
  Set(Int)
}

///|
fn test_init() -> @pippa.UpdateResult[Int, TestMsg] {
  @pippa.UpdateResult::new(model=0, cmd=@pippa.Cmd::none())
}

///|
fn test_update(model : Int, msg : TestMsg) -> @pippa.UpdateResult[Int, TestMsg] {
  match msg {
    Add(delta) =>
      @pippa.UpdateResult::new(model=model + delta, cmd=@pippa.Cmd::none())
    Set(value) => @pippa.UpdateResult::new(model=value, cmd=@pippa.Cmd::none())
  }
}

///|
fn test_sub(evt : @pippa.InputEvent) -> TestMsg? {
  match evt {
    @pippa.Key(@pippa.Char('+')) => Some(Add(1))
    @pippa.Key(@pippa.Char('x')) => Some(Set(1))
    _ => None
  }
}

///|
fn test_view(model : Int) -> String {
  @pippa.style().foreground_rgb(10, 20, 30).render("count=\{model}")
}

///|
test "replay_frames renders initial input and direct message frames in truecolor" {
  let ambient = @profile.RenderContext::default().with_color_profile(
    @profile.NoColor,
  )
  let previous = @profile.ambient_context()
  defer @profile.set_render_context(previous)
  @profile.set_render_context(ambient)

  let frames = replay_frames(
    init=test_init,
    update=test_update,
    view=test_view,
    sub=test_sub,
    script=[Input(@pippa.Key(@pippa.Char('+'))), Message(Add(10))],
  )

  assert_eq(frames.length(), 3)
  assert_true(frames[0].contains("\u001b[38;2;10;20;30mcount=0"))
  assert_true(frames[1].contains("count=1"))
  assert_true(frames[2].contains("count=11"))
  assert_eq(@profile.ambient_context(), ambient)
}

///|
test "replay_frames accepts an explicit render context override" {
  let frames = replay_frames(
    init=test_init,
    update=test_update,
    view=test_view,
    script=[Message(Add(1))],
    ctx=@profile.RenderContext::default().with_color_profile(@profile.NoColor),
  )

  assert_eq(frames.length(), 2)
  assert_eq(frames[0], "count=0")
  assert_eq(frames[1], "count=1")
}

///|
test "encode maps replay tokens to terminal input bytes" {
  let encoded = encode(
    "a enter tab space backspace up down left right ctrl+c esc",
  )
  @test.assert_eq(encoded.to_array(), [
    b'a', b'\r', b'\t', b' ', b'\x7F', b'\x1B', b'[', b'A', b'\x1B', b'[', b'B',
    b'\x1B', b'[', b'D', b'\x1B', b'[', b'C', b'\x03', b'\x1B', b'\x1B',
  ])
}

///|
test "encode special-key tokens round-trip through the input parser" {
  let (events, rest) = @pippa.parse_all(
    encode("pageup pagedown home end delete")[:],
  )
  assert_eq(rest.length(), 0)
  assert_eq(events.length(), 5)
  assert_true(events[0] is @pippa.Key(@pippa.Special("pageup")))
  assert_true(events[1] is @pippa.Key(@pippa.Special("pagedown")))
  assert_true(events[2] is @pippa.Key(@pippa.Special("home")))
  assert_true(events[3] is @pippa.Key(@pippa.Special("end")))
  assert_true(events[4] is @pippa.Key(@pippa.Special("delete")))
}

///|
test "encode aliases round-trip to the same parser keys" {
  let (events, rest) = @pippa.parse_all(encode("pgup pgdn del")[:])
  assert_eq(rest.length(), 0)
  assert_eq(events.length(), 3)
  assert_true(events[0] is @pippa.Key(@pippa.Special("pageup")))
  assert_true(events[1] is @pippa.Key(@pippa.Special("pagedown")))
  assert_true(events[2] is @pippa.Key(@pippa.Special("delete")))
}

///|
test "encode esc round-trips only as the final token" {
  // `esc`/`escape` is only safe as the FINAL token: it encodes ESC ESC so the
  // first ESC parses as a definite standalone escape key. As the final token it
  // round-trips to a single `escape` event; the trailing ESC stays an
  // incomplete leftover byte, exactly as a real terminal would buffer a lone
  // ESC (which is otherwise ambiguous with a CSI start).
  let (events, rest) = @pippa.parse_all(encode("esc")[:])
  assert_eq(events.length(), 1)
  assert_true(events[0] is @pippa.Key(@pippa.Special("escape")))
  assert_eq(rest.length(), 1)
  // The `escape` alias and a trailing `esc` after other tokens are fine too.
  assert_true((try? encode("escape")) is Ok(_))
  assert_true((try? encode("x escape")) is Ok(_))
  // A mid-script `esc` would corrupt the following token (the 2nd ESC binds to
  // the next byte as Alt+key or injects an extra escape), so encode raises
  // rather than silently mis-encoding — consistent with the unknown-token path.
  assert_true((try? encode("esc x")) is Err(_))
  assert_true((try? encode("esc enter")) is Err(_))
  assert_true((try? encode("escape x")) is Err(_))
}

///|
test "encode types literal text via single-character and text: tokens" {
  // Single-character tokens type literal characters; `space` types a space.
  @test.assert_eq(encode("a space b").to_array(), [b'a', b' ', b'b'])
  // `text:` types a multi-character run verbatim, including key-name collisions.
  @test.assert_eq(encode("text:up").to_array(), [b'u', b'p'])
  // Embedded spaces (F2) are written with the `space` token between runs.
  @test.assert_eq(encode("text:alpha space text:beta").to_array(), [
    b'a', b'l', b'p', b'h', b'a', b' ', b'b', b'e', b't', b'a',
  ])
}

///|
test "encode rejects unknown multi-character tokens loudly" {
  // `pgdown` is a misspelling of `pgdn`/`pagedown`; encode must raise rather
  // than silently type the letters (the pre-fix behavior).
  assert_true((try? encode("pgdown")) is Err(_))
  assert_true((try? encode("not_a_key")) is Err(_))
  // Recognized tokens, single characters, and `text:` escapes still succeed.
  assert_true((try? encode("pagedown")) is Ok(_))
  assert_true((try? encode("f")) is Ok(_))
  assert_true((try? encode("text:pgdown")) is Ok(_))
}

///|
test "normalize strips runtime controls but keeps SGR and text" {
  let raw = @pippa.begin_sync_update() +
    @pippa.clear_screen() +
    @pippa.move_cursor(2, 4) +
    "\u001b[38;2;1;2;3mhi" +
    @pippa.reset() +
    @pippa.end_sync_update()

  assert_eq(normalize(raw), "\u001b[38;2;1;2;3mhi\u001b[0m")
}

///|
#cfg(any(target="native", target="llvm"))
test "runtime replay terminates finite scripts and is deterministic" {
  let make_clock = fn() {
    let now = Ref(0L)
    fn() {
      now.val = now.val + 20L
      now.val
    }
  }
  let make_program = fn() {
    @pippa.Program::new(
      init=test_init,
      update=test_update,
      view=fn(model) { "count=\{model}" },
      sub=test_sub,
    )
  }
  let opts = ReplayOptions::default()
    .with_window_size(20, 5)
    .with_clock(make_clock())
  let first = replay(make_program(), "x", opts)
  let opts = ReplayOptions::default()
    .with_window_size(20, 5)
    .with_clock(make_clock())
  let second = replay(make_program(), "x", opts)

  assert_eq(first.final_model, 1)
  @test.assert_eq(first.frames, second.frames)
  let joined = first.frames.join("")
  assert_true(joined.contains("count=0"))
  assert_true(joined.contains("count=1"))
  assert_false(joined.contains(@pippa.move_cursor(1, 1)))
  assert_false(joined.contains(@pippa.clear_screen()))
  assert_false(joined.contains(@pippa.begin_sync_update()))

  let raw_opts = ReplayOptions::default()
    .with_raw_ansi(true)
    .with_window_size(20, 5)
    .with_clock(make_clock())
  let raw = replay(make_program(), "x", raw_opts)
  let raw_joined = raw.frames.join("")
  assert_true(raw_joined.contains(@pippa.move_cursor(1, 1)))
  assert_true(raw_joined.contains(@pippa.begin_sync_update()))
}

///|
#cfg(any(target="native", target="llvm"))
test "replay with a bypassed zero drain still processes scripted input" {
  let make_clock = fn() {
    let now = Ref(0L)
    fn() {
      now.val = now.val + 20L
      now.val
    }
  }
  let make_program = fn() {
    @pippa.Program::new(
      init=test_init,
      update=test_update,
      view=fn(model) { "count=\{model}" },
      sub=test_sub,
    )
  }
  // `ReplayOptions` is `pub(all)`, so a record update can bypass the builders and
  // set `drain_empty_polls: 0`. The use-site clamp must keep this behaving like
  // the safe default rather than cancelling early and truncating frames.
  let safe_opts = ReplayOptions::default()
    .with_window_size(20, 5)
    .with_clock(make_clock())
  let zero_opts = {
    ..ReplayOptions::default().with_window_size(20, 5).with_clock(make_clock()),
    drain_empty_polls: 0,
  }
  let safe = replay(make_program(), "x", safe_opts)
  let zero = replay(make_program(), "x", zero_opts)
  assert_eq(zero.final_model, 1)
  assert_eq(zero.final_model, safe.final_model)
  @test.assert_eq(zero.frames, safe.frames)
  assert_true(zero.frames.join("").contains("count=1"))
}

///|
test "normalize strips the trailing program-exit teardown reset-SGR" {
  // The runtime's view-reset teardown emits reset-foreground then
  // reset-background at program exit, which `normalize` would otherwise keep as
  // SGR and leave tailing every captured stream. Strip only that trailing
  // teardown barnacle; the view's own `reset()` is kept.
  let raw = @pippa.style().foreground_rgb(1, 2, 3).render("hi") +
    @pippa.reset_foreground_color() +
    @pippa.reset_background_color()
  assert_eq(normalize(raw), @pippa.style().foreground_rgb(1, 2, 3).render("hi"))
}

///|
test "normalize keeps a mid-stream 39m/49m that is not the trailing teardown" {
  // The strip is a trailing-suffix heuristic, not a semantic one: a
  // reset-foreground/background pair is preserved here ONLY because printable
  // text follows it, so the pair is not the stream's suffix. A frame ending
  // exactly on the pair WOULD be stripped — a boundary that is unreachable in
  // practice because the runtime's teardown reset is always the final bytes.
  let raw = @pippa.reset_foreground_color() +
    @pippa.reset_background_color() +
    "tail"
  assert_eq(
    normalize(raw),
    @pippa.reset_foreground_color() + @pippa.reset_background_color() + "tail",
  )
}

///|
test "with_drain_empty_polls clamps non-positive values and keeps larger windows" {
  // The re-added builder clamps a 0/negative drain to the >=1 floor while a larger
  // window passes through unchanged, giving callers an ergonomic way to widen the
  // drain instead of a raw record update (the use-site clamp keeps that safe too).
  assert_eq(
    ReplayOptions::default().with_drain_empty_polls(0).drain_empty_polls,
    1,
  )
  assert_eq(
    ReplayOptions::default().with_drain_empty_polls(-3).drain_empty_polls,
    1,
  )
  assert_eq(
    ReplayOptions::default().with_drain_empty_polls(9).drain_empty_polls,
    9,
  )
}

///|
test "normalize strips the trailing reset-SGR from a realistic full teardown sequence" {
  // Tripwire: pin `normalize` against the EXACT byte order that program.mbt's
  // `terminal_view_reset_sequence` emits at program exit — show-cursor,
  // cursor-style, window-title, fg-reset (ESC[39m), bg-reset (ESC[49m),
  // clear-progress, mouse-disable. Once the cursor/OSC/mouse controls are dropped,
  // the reset-SGR pair is the trailing content, so it is stripped. If the runtime
  // ever reorders this teardown so the reset-SGR is no longer trailing, this test
  // fails loudly instead of the barnacle silently reappearing in captured frames.
  let content = @pippa.style().foreground_rgb(1, 2, 3).render("hi")
  let teardown = @pippa.show_cursor() +
    @pippa.set_cursor_style(@pippa.Default) +
    @pippa.clear_window_title() +
    @pippa.reset_foreground_color() +
    @pippa.reset_background_color() +
    @pippa.clear_terminal_progress() +
    @pippa.disable_mouse()
  assert_eq(normalize(content + teardown), content)
}

///|
#cfg(any(target="native", target="llvm"))
test "replay polls the configured drain window: a larger drain polls strictly more" {
  // Exercise the with_drain_empty_polls builder's reason to exist — widening the
  // post-script drain. The deterministic replay clock is read once per runtime
  // loop tick, so counting clock calls observes how long the loop kept polling
  // for empty input before the cancellation predicate fired. A larger drain ⇒
  // more drain ticks ⇒ strictly more clock calls.
  fn ticks_for_drain(drain : Int) -> Int {
    let calls = Ref(0)
    let now = Ref(0L)
    let clock = fn() {
      calls.val = calls.val + 1
      now.val = now.val + 20L
      now.val
    }
    let program = @pippa.Program::new(
      init=test_init,
      update=test_update,
      view=fn(model) { "count=\{model}" },
      sub=test_sub,
    )
    let opts = ReplayOptions::default()
      .with_window_size(20, 5)
      .with_drain_empty_polls(drain)
      .with_clock(clock)
    let _ = replay(program, "x", opts)
    calls.val
  }

  let small = ticks_for_drain(1)
  let large = ticks_for_drain(12)
  assert_true(large > small)
}
