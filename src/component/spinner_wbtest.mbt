///|
fn spinner_expected_timed_tick(model : SpinnerModel) -> SpinnerMsg {
  TimedTick(spinner_current_tick_token(model))
}

///|
test "spinner schedule task emits current tick token" {
  let s = spinner(interval_ms=37)
  let started = (s.update)((s.init)().model, Start)
  assert_true(!started.cmd.is_none())
  let schedule = spinner_next_tick_schedule(
    started.model.interval_ms,
    spinner_current_tick_token(started.model),
  )
  assert_eq(schedule.interval_ms, 37)
  @test.assert_eq((schedule.task)(), spinner_expected_timed_tick(started.model))
}

///|
test "spinner stale timed tick is ignored after stop and restart" {
  let s = spinner(preset=Line, interval_ms=10)
  let initial = (s.init)().model
  let started = (s.update)(initial, Start)
  let stale = spinner_current_tick_token(started.model)
  let stopped = (s.update)(started.model, Stop)
  let restarted = (s.update)(stopped.model, Start)
  let stale_result = (s.update)(restarted.model, TimedTick(stale))
  assert_eq(stale_result.model.current, restarted.model.current)
  assert_true(stale_result.cmd.is_none())
  let current_result = (s.update)(
    restarted.model,
    spinner_expected_timed_tick(restarted.model),
  )
  assert_eq(current_result.model.current, 1)
  assert_true(!current_result.cmd.is_none())
}
