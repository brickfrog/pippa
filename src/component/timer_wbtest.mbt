///|
fn timer_expected_tick(model : TimerModel) -> TimerMsg {
  Tick(timer_current_tick_token(model))
}

///|
test "timer start schedule task emits current tick token" {
  let c = timer(duration_ms=300, interval_ms=100)
  let started = (c.update)((c.init)().model, Start)
  assert_true(!started.cmd.is_none())
  let schedule = timer_next_tick_schedule(
    started.model.interval_ms,
    timer_current_tick_token(started.model),
  )
  assert_eq(schedule.interval_ms, 100)
  @test.assert_eq((schedule.task)(), timer_expected_tick(started.model))
}

///|
test "timer post-tick schedule task emits updated tick token" {
  let c = timer(duration_ms=300, interval_ms=100)
  let started = (c.update)((c.init)().model, Start)
  let ticked = (c.update)(started.model, timer_expected_tick(started.model))
  assert_true(!ticked.cmd.is_none())
  let schedule = timer_next_tick_schedule(
    ticked.model.interval_ms,
    timer_current_tick_token(ticked.model),
  )
  assert_eq(schedule.interval_ms, 100)
  @test.assert_eq((schedule.task)(), timer_expected_tick(ticked.model))
}
