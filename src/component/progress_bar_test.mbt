///|
/// Tests for the ProgressBar component.

///|
test "progress_bar at 0%" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let view = (comp.view)(model)
  assert_eq(
    view, "[\u{1b}[38;5;2m\u{1b}[0m░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0%",
  )
}

///|
test "progress_bar at 50%" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let { model: m2, .. } = (comp.update)(model, SetPercent(50.0))
  let view = (comp.view)(m2)
  assert_eq(
    view, "[\u{1b}[38;5;2m████████████████████\u{1b}[0m░░░░░░░░░░░░░░░░░░░░] 50%",
  )
}

///|
test "progress_bar at 100%" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let { model: m2, .. } = (comp.update)(model, SetPercent(100.0))
  let view = (comp.view)(m2)
  assert_eq(
    view, "[\u{1b}[38;5;2m████████████████████████████████████████\u{1b}[0m] 100%",
  )
}

///|
test "progress_bar with label" {
  let comp = progress_bar(label="Loading...")
  let { model, .. } = (comp.init)()
  let { model: m2, .. } = (comp.update)(model, SetPercent(42.0))
  let view = (comp.view)(m2)
  // 42% of 40 = 16 filled, 24 empty
  assert_eq(
    view, "Loading... [\u{1b}[38;5;2m████████████████\u{1b}[0m░░░░░░░░░░░░░░░░░░░░░░░░] 42%",
  )
}

///|
test "progress_bar SetLabel updates label" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let { model: m2, .. } = (comp.update)(model, SetLabel("Done"))
  let view = (comp.view)(m2)
  assert_true(view.has_prefix("Done "))
}

///|
test "progress_bar clamping: below 0" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let { model: m2, .. } = (comp.update)(model, SetPercent(-10.0))
  assert_eq(m2.percent, 0.0)
}

///|
test "progress_bar clamping: above 100" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let { model: m2, .. } = (comp.update)(model, SetPercent(150.0))
  assert_eq(m2.percent, 100.0)
}
