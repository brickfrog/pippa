///|
/// Tests for the Cursor component.

///|
fn cursor_tick_msg(model : CursorModel) -> CursorMsg {
  TimedTick({
    instance_id: model.instance_id,
    generation: model.tick_generation,
  })
}

///|
fn visible_cursor(char : String) -> String {
  @pippa.style().reverse().render(char)
}

///|
test "cursor init matches bubbles defaults" {
  let c = cursor()
  let m0 = (c.init)().model
  assert_true(m0.mode == CursorBlink)
  assert_eq(m0.char, "")
  assert_eq(m0.interval_ms, 530)
  assert_eq(m0.is_blinked, true)
  assert_eq(m0.focused, false)
  assert_eq((c.view)(m0), "")
}

///|
test "cursor focus and blur gate blinking" {
  let c = cursor(char="x", interval_ms=37)
  let m0 = (c.init)().model
  let focused = (c.update)(m0, Focus)
  assert_eq(focused.model.focused, true)
  assert_eq(focused.model.is_blinked, false)
  assert_true(!focused.cmd.is_none())
  assert_eq((c.view)(focused.model), visible_cursor("x"))

  let blurred = (c.update)(focused.model, Blur)
  assert_eq(blurred.model.focused, false)
  assert_eq(blurred.model.is_blinked, true)
  assert_true(blurred.cmd.is_none())
  assert_eq((c.view)(blurred.model), "x")
}

///|
test "cursor blink toggles on current timed tick" {
  let c = cursor(char="x")
  let focused = (c.update)((c.init)().model, Focus).model
  let hidden = (c.update)(focused, cursor_tick_msg(focused))
  assert_eq(hidden.model.is_blinked, true)
  assert_eq((c.view)(hidden.model), "x")
  assert_true(!hidden.cmd.is_none())

  let shown = (c.update)(hidden.model, cursor_tick_msg(hidden.model))
  assert_eq(shown.model.is_blinked, false)
  assert_eq((c.view)(shown.model), visible_cursor("x"))
  assert_true(!shown.cmd.is_none())
}

///|
test "cursor ignores stale ticks and ticks from other instances" {
  let first = cursor(char="a")
  let second = cursor(char="b")
  let first_focused = (first.update)((first.init)().model, Focus).model
  let second_focused = (second.update)((second.init)().model, Focus).model
  let stale_tick = cursor_tick_msg(first_focused)
  let first_after_refocus = (first.update)(
      (first.update)(first_focused, Blur).model,
      Focus,
    ).model
  let stale_result = (first.update)(first_after_refocus, stale_tick)
  assert_eq(stale_result.model.is_blinked, first_after_refocus.is_blinked)
  assert_true(stale_result.cmd.is_none())

  let cross_result = (first.update)(
    first_after_refocus,
    cursor_tick_msg(second_focused),
  )
  assert_eq(cross_result.model.is_blinked, first_after_refocus.is_blinked)
  assert_true(cross_result.cmd.is_none())
}

///|
test "cursor mode transitions control view and scheduling" {
  let c = cursor(char="x", mode=CursorStatic)
  let static0 = (c.init)().model
  assert_true(static0.mode == CursorStatic)
  assert_eq(static0.is_blinked, true)
  assert_eq((c.view)(static0), "x")

  let static_focus = (c.update)(static0, Focus)
  assert_true(static_focus.cmd.is_none())
  assert_eq(static_focus.model.is_blinked, false)
  assert_eq((c.view)(static_focus.model), visible_cursor("x"))

  let hidden = (c.update)(static_focus.model, SetMode(CursorHide))
  assert_true(hidden.model.mode == CursorHide)
  assert_eq(hidden.model.is_blinked, true)
  assert_true(hidden.cmd.is_none())
  assert_eq((c.view)(hidden.model), "x")

  let blinking = (c.update)(hidden.model, SetMode(CursorBlink))
  assert_true(blinking.model.mode == CursorBlink)
  assert_eq(blinking.model.is_blinked, false)
  assert_true(!blinking.cmd.is_none())
  assert_eq((c.view)(blinking.model), visible_cursor("x"))
}

///|
test "cursor set char updates the rendered cell" {
  let c = cursor()
  let focused = (c.update)((c.init)().model, Focus).model
  let changed = (c.update)(focused, SetChar("z"))
  assert_eq(changed.model.char, "z")
  assert_eq((c.view)(changed.model), visible_cursor("z"))
  assert_true(changed.cmd.is_none())
}
