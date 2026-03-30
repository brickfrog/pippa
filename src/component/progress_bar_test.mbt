///|
/// Tests for the spring-physics gradient ProgressBar component.

///|
test "progress_bar initial state" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  assert_eq(model.displayed_percent, 0.0)
  assert_eq(model.target_percent, 0.0)
  assert_eq(model.velocity, 0.0)
}

///|
test "SetPercent sets target and not displayed_percent" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let { model: m2, .. } = (comp.update)(model, SetPercent(0.5))
  assert_eq(m2.target_percent, 0.5)
  assert_eq(m2.displayed_percent, 0.0)
}

///|
test "SetPercent returns a tick cmd" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let { cmd, .. } = (comp.update)(model, SetPercent(0.5))
  inspect(cmd, content="{_phantom: [], interval_ms: 16}")
}

///|
test "SetPercent clamps below 0" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let { model: m2, .. } = (comp.update)(model, SetPercent(-0.5))
  assert_eq(m2.target_percent, 0.0)
}

///|
test "SetPercent clamps above 1" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let { model: m2, .. } = (comp.update)(model, SetPercent(1.5))
  assert_eq(m2.target_percent, 1.0)
}

///|
test "Tick advances displayed_percent toward target" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let { model: m1, .. } = (comp.update)(model, SetPercent(1.0))
  let { model: m2, .. } = (comp.update)(m1, Tick)
  assert_true(m2.displayed_percent > 0.0)
  assert_true(m2.displayed_percent < 1.0)
}

///|
test "Tick returns no-op cmd when already settled" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  // Both at 0.0, velocity 0 — already settled
  let { cmd, .. } = (comp.update)(model, Tick)
  inspect(cmd, content="{_phantom: [], interval_ms: 0}")
}

///|
test "Tick returns tick cmd when animating" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let { model: m1, .. } = (comp.update)(model, SetPercent(1.0))
  let { cmd, .. } = (comp.update)(m1, Tick)
  inspect(cmd, content="{_phantom: [], interval_ms: 16}")
}

///|
test "spring_step critically damped moves toward target" {
  let (new_pos, _) = spring_step(0.0, 0.0, 1.0, 18.0, 1.0, 1.0 / 60.0)
  assert_true(new_pos > 0.0)
  assert_true(new_pos < 1.0)
}

///|
test "spring_step underdamped moves toward target" {
  let (new_pos, _) = spring_step(0.0, 0.0, 1.0, 18.0, 0.5, 1.0 / 60.0)
  assert_true(new_pos > 0.0)
  assert_true(new_pos < 1.0)
}

///|
test "spring_step overdamped moves toward target" {
  let (new_pos, _) = spring_step(0.0, 0.0, 1.0, 18.0, 2.0, 1.0 / 60.0)
  assert_true(new_pos > 0.0)
  assert_true(new_pos < 1.0)
}

///|
test "view empty bar at 0 percent" {
  let comp = progress_bar(width=10, show_percentage=false)
  let { model, .. } = (comp.init)()
  let view = (comp.view)(model)
  inspect(
    view,
    content="\u001b[38;2;96;96;96m░░░░░░░░░░\u001b[0m",
  )
}

///|
test "view shows percentage label" {
  let comp = progress_bar(width=10, show_percentage=true)
  let { model, .. } = (comp.init)()
  let m1 = { ..model, displayed_percent: 0.5, target_percent: 0.5 }
  let view = (comp.view)(m1)
  assert_true(view.has_suffix(" 50%"))
}

///|
test "view negative width does not panic" {
  let comp = progress_bar(width=-5, show_percentage=false)
  let { model, .. } = (comp.init)()
  let view = (comp.view)(model)
  assert_eq(view, "")
}
