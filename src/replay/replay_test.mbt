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
