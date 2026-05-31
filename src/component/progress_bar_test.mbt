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
  assert_true(!cmd.is_none())
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
  assert_true(cmd.is_none())
}

///|
test "Tick snaps to exact target when animation settles" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let almost_settled = {
    ..model,
    target_percent: 1.0,
    displayed_percent: 0.9998,
    velocity: 0.005,
  }
  let { model: settled, cmd } = (comp.update)(almost_settled, Tick)
  assert_eq(settled.displayed_percent, 1.0)
  assert_eq(settled.velocity, 0.0)
  assert_true(cmd.is_none())
}

///|
test "Tick returns tick cmd when animating" {
  let comp = progress_bar()
  let { model, .. } = (comp.init)()
  let { model: m1, .. } = (comp.update)(model, SetPercent(1.0))
  let { cmd, .. } = (comp.update)(m1, Tick)
  assert_true(!cmd.is_none())
}

///|
test "Tick converges displayed_percent to target over repeated ticks" {
  let comp = progress_bar(show_percentage=false)
  let { model, .. } = (comp.init)()
  let mut m = (comp.update)(model, SetPercent(0.75)).model
  for _ in 0..<80 {
    m = (comp.update)(m, Tick).model
  }
  assert_eq(m.target_percent, 0.75)
  assert_true((m.displayed_percent - 0.75).abs() < 0.001)
  assert_eq(m.velocity, 0.0)
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
test "view renders custom chars percentage format and percentage style" {
  let comp = progress_bar(
    width=8,
    show_percentage=true,
    fill_char="#",
    empty_char="-",
    palette=ProgressNoColor,
    percentage_format=fn(pct) { "\{(pct * 100.0).to_int()}/100" },
    percentage_style=fn(text) { "[" + text + "]" },
  )
  let { model, .. } = (comp.init)()
  let m1 = { ..model, displayed_percent: 0.375, target_percent: 0.375 }
  assert_eq((comp.view)(m1), "###----- [37/100]")
}

///|
test "view applies solid palette to filled cells" {
  let comp = progress_bar(
    width=2,
    show_percentage=false,
    fill_char="#",
    empty_char="-",
    palette=ProgressSolid((1, 2, 3)),
    empty_color=(4, 5, 6),
  )
  let { model, .. } = (comp.init)()
  let m1 = { ..model, displayed_percent: 0.5, target_percent: 0.5 }
  assert_eq(
    (comp.view)(m1),
    "\u001b[38;2;1;2;3m#\u001b[0m\u001b[38;2;4;5;6m-\u001b[0m",
  )
}

///|
test "view scaled mode spreads gradient across visible fill" {
  let comp = progress_bar(
    width=4,
    show_percentage=false,
    fill_char="#",
    empty_char="-",
    blend_start=(0, 0, 0),
    blend_end=(100, 0, 0),
    scaled=true,
  )
  let { model, .. } = (comp.init)()
  let m1 = { ..model, displayed_percent: 0.5, target_percent: 0.5 }
  let view = (comp.view)(m1)
  assert_true(view.contains("\u001b[38;2;50;0;0m"))
  assert_false(view.contains("\u001b[38;2;25;0;0m"))
}

///|
test "SetWidth updates render width" {
  let comp = progress_bar(
    width=2,
    show_percentage=false,
    empty_char="-",
    palette=ProgressNoColor,
  )
  let { model, .. } = (comp.init)()
  let { model: wider, .. } = (comp.update)(model, SetWidth(6))
  assert_eq(wider.width, 6)
  assert_eq((comp.view)(wider), "------")
  let { model: zero, .. } = (comp.update)(wider, SetWidth(-1))
  assert_eq(zero.width, 0)
  assert_eq((comp.view)(zero), "")
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
test "view rounds near-full fill consistently with percentage label" {
  let comp = progress_bar(width=10, show_percentage=true)
  let { model, .. } = (comp.init)()
  let near_full = { ..model, displayed_percent: 0.9998, target_percent: 1.0 }
  let view = (comp.view)(near_full)
  assert_true(view.has_suffix(" 100%"))
  assert_false(view.contains("░"))
}

///|
test "view negative width does not panic" {
  let comp = progress_bar(width=-5, show_percentage=false)
  let { model, .. } = (comp.init)()
  let view = (comp.view)(model)
  assert_eq(view, "")
}
