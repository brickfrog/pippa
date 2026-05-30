///|
fn stopwatch_expected_tick(model : StopwatchModel) -> StopwatchMsg {
  Tick(stopwatch_current_tick_token(model))
}

///|
test "stopwatch start schedule task emits current tick token" {
  let c = stopwatch(interval_ms=100)
  let started = (c.update)((c.init)().model, Start)
  assert_true(!started.cmd.is_none())
  let schedule = stopwatch_next_tick_schedule(
    started.model.interval_ms,
    stopwatch_current_tick_token(started.model),
  )
  assert_eq(schedule.interval_ms, 100)
  @test.assert_eq((schedule.task)(), stopwatch_expected_tick(started.model))
}

///|
test "stopwatch post-tick schedule task emits updated tick token" {
  let c = stopwatch(interval_ms=100)
  let started = (c.update)((c.init)().model, Start)
  let ticked = (c.update)(started.model, stopwatch_expected_tick(started.model))
  assert_true(!ticked.cmd.is_none())
  let schedule = stopwatch_next_tick_schedule(
    ticked.model.interval_ms,
    stopwatch_current_tick_token(ticked.model),
  )
  assert_eq(schedule.interval_ms, 100)
  @test.assert_eq((schedule.task)(), stopwatch_expected_tick(ticked.model))
}
