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

///|
fn showcase_apply_input_event(
  model : Model,
  event : @pippa.InputEvent,
) -> Model raise {
  match showcase_sub(event) {
    Some(msg) => showcase_update(model, msg).model
    None => {
      assert_true(false)
      model
    }
  }
}

///|
test "showcase maps Key(Text) clusters into text input insertion" {
  let accented = String::from_array(['e', '\u{0301}'])
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let { model, .. } = showcase_init()
  let active_input = { ..model, tab: 1 }
  let m1 = showcase_apply_input_event(
    active_input,
    @pippa.Key(@pippa.Text(accented)),
  )
  let m2 = showcase_apply_input_event(m1, @pippa.Key(@pippa.Text(technologist)))
  let moved = showcase_update(m2, TextInputMsg(@component.MoveCursorLeft)).model
  assert_eq(m1.text_input.value, accented)
  assert_eq(m1.text_input.cursor, accented.to_array().length())
  assert_eq(m2.text_input.value, "\{accented}\{technologist}")
  assert_eq(
    m2.text_input.cursor,
    accented.to_array().length() + technologist.to_array().length(),
  )
  assert_eq(moved.text_input.cursor, accented.to_array().length())
}
