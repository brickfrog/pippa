///|
test "spinner progress parity scripts activity ticks" {
  let { model, .. } = spinner_progress_parity_init()
  let started = spinner_progress_parity_update(model, SetProgress(0.5)).model
  let ticked = spinner_progress_parity_update(started, ActivityTick).model

  assert_eq(ticked.spinner.current, 1)
  assert_eq(ticked.progress.target_percent, 0.5)
  assert_true(ticked.progress.displayed_percent > 0.0)
  assert_true(spinner_progress_parity_view(ticked).contains("Syncing"))
}

///|
test "spinner progress parity clamps requested progress" {
  let { model, .. } = spinner_progress_parity_init()
  let over = spinner_progress_parity_update(model, SetProgress(2.0)).model

  assert_eq(over.progress.target_percent, 1.0)
}
