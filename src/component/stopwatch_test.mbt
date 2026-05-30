///|
fn stopwatch_tick_msg(model : StopwatchModel) -> StopwatchMsg {
  Tick({ instance_id: model.instance_id, generation: model.tick_generation })
}

///|
test "stopwatch accumulates elapsed time" {
  let c = stopwatch(interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start)
  let m1 = (c.update)(started.model, stopwatch_tick_msg(started.model)).model
  let m2 = (c.update)(m1, stopwatch_tick_msg(m1)).model
  assert_eq(m2.elapsed_ms, 200)
  assert_eq((c.view)(m2), "0:00.2")
}

///|
test "stopwatch pause stops accumulation" {
  let c = stopwatch(interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start)
  let m1 = (c.update)(started.model, stopwatch_tick_msg(started.model)).model
  let paused = (c.update)(m1, Pause).model
  let m2 = (c.update)(paused, stopwatch_tick_msg(m1)).model
  assert_eq(m2.elapsed_ms, 100)
  assert_eq(m2.running, false)
}

///|
test "stopwatch ignores stale tick from paused run after restart" {
  let c = stopwatch(interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start).model
  let stale_tick = stopwatch_tick_msg(started)
  let paused = (c.update)(started, Pause).model
  let restarted = (c.update)(paused, Start).model
  let stale_result = (c.update)(restarted, stale_tick)
  @test.assert_eq(stale_result.model, restarted)
  assert_true(stale_result.cmd.is_none())
}

///|
test "stopwatch ignores stale tick from reset run after restart" {
  let c = stopwatch(interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start).model
  let stale_tick = stopwatch_tick_msg(started)
  let reset = (c.update)(started, Reset).model
  let restarted = (c.update)(reset, Start).model
  let stale_result = (c.update)(restarted, stale_tick)
  @test.assert_eq(stale_result.model, restarted)
  assert_true(stale_result.cmd.is_none())
}

///|
test "stopwatch ignores ticks from another instance" {
  let first = stopwatch(interval_ms=100)
  let second = stopwatch(interval_ms=100)
  let first_running = (first.update)((first.init)().model, Start).model
  let second_running = (second.update)((second.init)().model, Start).model
  let first_after_second_tick = (first.update)(
    first_running,
    stopwatch_tick_msg(second_running),
  )
  let second_after_first_tick = (second.update)(
    second_running,
    stopwatch_tick_msg(first_running),
  )
  assert_eq(first_after_second_tick.model.elapsed_ms, first_running.elapsed_ms)
  assert_eq(second_after_first_tick.model.elapsed_ms, second_running.elapsed_ms)
  assert_true(first_after_second_tick.cmd.is_none())
  assert_true(second_after_first_tick.cmd.is_none())
}
