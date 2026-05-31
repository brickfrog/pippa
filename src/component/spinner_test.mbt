///|
/// Tests for the Spinner component.

///|
test "spinner init produces frame 0" {
  let s = spinner()
  let { model, .. } = (s.init)()
  assert_eq(model.current, 0)
}

///|
test "spinner init uses provided label" {
  let s = spinner(label="Working...")
  let { model, .. } = (s.init)()
  assert_eq(model.label, "Working...")
}

///|
test "spinner named presets expose Bubbles parity frames" {
  let s = spinner(preset=Line, label="Loading")
  let { model, .. } = (s.init)()
  assert_eq(model.frames.length(), 4)
  assert_eq(model.frames[0], "|")
  assert_eq(model.frames[1], "/")
  assert_eq((s.view)(model), "| Loading")
}

///|
test "spinner preset table covers every named preset" {
  let presets : Array[SpinnerPreset] = [
    Line,
    Dot,
    MiniDot,
    Jump,
    Pulse,
    Points,
    Globe,
    Moon,
    Monkey,
    Meter,
    Hamburger,
    Ellipsis,
  ]
  for preset in presets {
    let frames = spinner_preset_frames(preset)
    assert_true(frames.length() > 0)
    assert_true(spinner_preset_interval_ms(preset) > 0)
    for frame in frames {
      assert_true(@pippa.visible_width(frame) >= 0)
    }
  }
}

///|
test "spinner preset table locks representative frame sets" {
  let dot = spinner_preset_frames(Dot)
  assert_eq(dot.length(), 8)
  assert_eq(dot[0], "⣾ ")
  assert_eq(dot[7], "⣷ ")

  let moon = spinner_preset_frames(Moon)
  assert_eq(moon.length(), 8)
  assert_eq(moon[0], "🌑")
  assert_eq(moon[4], "🌕")

  let ellipsis = spinner_preset_frames(Ellipsis)
  assert_eq(ellipsis.length(), 4)
  assert_eq(ellipsis[0], "")
  assert_eq(ellipsis[3], "...")
}

///|
test "spinner interval can be configured directly or from fps" {
  let direct = spinner(interval_ms=42)
  assert_eq((direct.init)().model.interval_ms, 42)
  let fps = spinner(fps=20.0)
  assert_eq((fps.init)().model.interval_ms, 50)
}

///|
test "spinner frame style hook decorates only the frame" {
  let s = spinner(preset=Line, label="Working", frame_style=fn(frame) {
    "<" + frame + ">"
  })
  let { model, .. } = (s.init)()
  assert_eq((s.view)(model), "<|> Working")
}

///|
test "spinner dot preset does not double-space before label" {
  let s = spinner(preset=Dot, label="Loading")
  let { model, .. } = (s.init)()
  assert_eq(model.frames[0], "⣾ ")
  assert_eq((s.view)(model), "⣾ Loading")
}

///|
test "spinner Tick advances frame" {
  let s = spinner()
  let { model: m0, .. } = (s.init)()
  let { model: m1, .. } = (s.update)(m0, Tick)
  assert_eq(m1.current, 1)
}

///|
test "spinner Tick wraps around" {
  let s = spinner()
  let { model: m0, .. } = (s.init)()
  let last = m0.frames.length() - 1
  let model_at_last = { ..m0, current: last }
  let { model: wrapped, .. } = (s.update)(model_at_last, Tick)
  assert_eq(wrapped.current, 0)
}

///|
test "spinner view renders frame and label" {
  let s = spinner(label="Loading...")
  let { model, .. } = (s.init)()
  let output = (s.view)(model)
  assert_eq(output, "⠋ Loading...")
}

///|
test "spinner view reflects current frame after tick" {
  let s = spinner(label="Go")
  let { model: m0, .. } = (s.init)()
  let { model: m1, .. } = (s.update)(m0, Tick)
  let output = (s.view)(m1)
  assert_eq(output, "⠙ Go")
}

///|
test "spinner view reports emoji labels in display cells" {
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let s = spinner(label=technologist)
  let { model, .. } = (s.init)()
  let output = (s.view)(model)
  assert_eq(@pippa.visible_width(output), 4)
}
