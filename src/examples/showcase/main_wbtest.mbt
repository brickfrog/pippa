///|
fn showcase_step_progress_result(
  model : Model,
) -> @pippa.UpdateResult[Model, Msg] {
  showcase_update(model, ProgressTick)
}

///|
fn showcase_step_progress(model : Model) -> Model {
  showcase_step_progress_result(model).model
}

///|
fn assert_showcase_steady_tick_cmd(cmd : @pippa.Cmd[Msg]) -> Unit raise {
  @debug.debug_inspect(cmd, content="Cmd(actions=1, every=1)")
}

///|
test "showcase progress starts by filling on a steady clock" {
  let initialized = showcase_init()
  assert_eq(showcase_tick_ms, 16)
  assert_eq(initialized.model.progress.target_percent, 1.0)
  assert_eq(initialized.model.progress.displayed_percent, 0.0)
  assert_eq(initialized.model.spinner_ticks, 0)
  assert_showcase_steady_tick_cmd(initialized.cmd)
}

///|
test "showcase progress reissues the steady tick on every animation update" {
  let { model, .. } = showcase_init()
  let ticked = showcase_step_progress_result(model)
  assert_showcase_steady_tick_cmd(ticked.cmd)

  let settled_at_full = {
    ..ticked.model,
    progress: {
      ..ticked.model.progress,
      target_percent: 1.0,
      displayed_percent: 1.0,
      velocity: 0.0,
    },
  }
  let still_ticking = showcase_step_progress_result(settled_at_full)
  assert_showcase_steady_tick_cmd(still_ticking.cmd)
}

///|
test "showcase progress flips target at the full and empty bounds" {
  let { model, .. } = showcase_init()
  let near_full = {
    ..model,
    progress: {
      ..model.progress,
      target_percent: 1.0,
      displayed_percent: 0.991,
      velocity: 0.2,
    },
  }
  let draining = showcase_step_progress_result(near_full)
  assert_eq(draining.model.progress.target_percent, 0.0)
  assert_true(draining.model.progress.displayed_percent > 0.98)
  assert_showcase_steady_tick_cmd(draining.cmd)

  let near_empty = {
    ..model,
    progress: {
      ..model.progress,
      target_percent: 0.0,
      displayed_percent: 0.009,
      velocity: -0.2,
    },
  }
  let filling = showcase_step_progress_result(near_empty)
  assert_eq(filling.model.progress.target_percent, 1.0)
  assert_true(filling.model.progress.displayed_percent < 0.02)
  assert_showcase_steady_tick_cmd(filling.cmd)
}

///|
test "showcase progress keeps a calm elastic pace" {
  let { model, .. } = showcase_init()
  let mut current = model
  let mut ticks_to_full = 0
  while current.progress.target_percent == 1.0 && ticks_to_full < 260 {
    current = showcase_step_progress(current)
    ticks_to_full = ticks_to_full + 1
  }
  assert_true(ticks_to_full >= 90)
  assert_true(ticks_to_full <= 140)
  assert_eq(current.progress.target_percent, 0.0)
}

///|
test "showcase spinner advances on the same steady clock" {
  let { model, .. } = showcase_init()
  let mut current = model
  let ticks_before_spinner = showcase_spinner_stride - 1
  for _ in 0..<ticks_before_spinner {
    current = showcase_step_progress(current)
  }
  assert_eq(current.spinner.current, model.spinner.current)

  current = showcase_step_progress(current)
  let expected = (model.spinner.current + 1) % model.spinner.frames.length()
  assert_eq(current.spinner.current, expected)
  assert_eq(current.spinner_ticks, showcase_spinner_stride)
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
