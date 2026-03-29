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
