///|
fn showcase_step_progress(model : Model) -> Model {
  showcase_update(model, ProgressMsg(@component.ProgressBarMsg::Tick)).model
}

///|
fn showcase_advance_until_phase(
  model : Model,
  phase : Int,
  max_ticks : Int,
) -> Model {
  let mut current = model
  for _ in 0..<max_ticks {
    if current.progress_phase == phase {
      return current
    }
    current = showcase_step_progress(current)
  }
  current
}

///|
test "showcase progress starts by filling to 100 percent" {
  let { model, .. } = showcase_init()
  assert_eq(model.progress.target_percent, 1.0)
  assert_eq(model.progress_phase, 0)
}

///|
test "showcase progress first rebound retargets to 75 percent" {
  let { model, .. } = showcase_init()
  let dipped = showcase_advance_until_phase(model, 1, 120)
  assert_eq(dipped.progress_phase, 1)
  assert_eq(dipped.progress.target_percent, 0.75)
}

///|
test "showcase progress rebounds back to 100 percent after the dip" {
  let { model, .. } = showcase_init()
  let recovered = showcase_advance_until_phase(model, 2, 180)
  assert_eq(recovered.progress_phase, 2)
  assert_eq(recovered.progress.target_percent, 1.0)
}

///|
test "showcase progress second rebound retargets to 90 percent" {
  let { model, .. } = showcase_init()
  let dipped = showcase_advance_until_phase(model, 3, 240)
  assert_eq(dipped.progress_phase, 3)
  assert_eq(dipped.progress.target_percent, 0.9)
}

///|
test "showcase progress settles back at 100 percent after rebounds" {
  let { model, .. } = showcase_init()
  let settled = showcase_advance_until_phase(model, 4, 300)
  assert_eq(settled.progress_phase, 4)
  assert_eq(settled.progress.target_percent, 1.0)
}

///|
test "showcase progress restarts after holding at 100 percent" {
  let { model, .. } = showcase_init()
  let settled = showcase_advance_until_phase(model, 4, 300)
  let restarted = showcase_advance_until_phase(settled, 0, 80)
  assert_eq(restarted.progress_phase, 0)
  assert_eq(restarted.progress.target_percent, 1.0)
  assert_eq(restarted.progress.displayed_percent, 0.0)
}

///|
test "showcase progress no longer waits for full settle before rebounding" {
  let { model, .. } = showcase_init()
  let dipped = showcase_advance_until_phase(model, 1, 120)
  assert_eq(dipped.progress_phase, 1)
  assert_true(dipped.progress.velocity > 0.0)
  assert_true(!progress_settled(dipped.progress))
}

///|
test "showcase non-progress UI events do not schedule extra progress ticks" {
  let { model, .. } = showcase_init()

  let tabbed = showcase_update(model, TabNext)
  assert_true(tabbed.cmd.is_none())

  let input_model = { ..model, tab: 1 }
  let edited = showcase_update(
    input_model,
    TextInputMsg(@component.InsertChar('x')),
  )
  assert_true(edited.cmd.is_none())

  let viewport_model = { ..model, tab: 2 }
  let scrolled = showcase_update(
    viewport_model,
    ViewportMsg(@component.ScrollDown),
  )
  assert_true(scrolled.cmd.is_none())
}
