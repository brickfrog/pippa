///|
test "stopwatch accumulates elapsed time" {
  let c = stopwatch(interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start)
  let m1 = (c.update)(
      started.model,
      Tick(started.model.instance_id, started.model.tick_generation),
    ).model
  let m2 = (c.update)(m1, Tick(m1.instance_id, m1.tick_generation)).model
  assert_eq(m2.elapsed_ms, 200)
  assert_eq((c.view)(m2), "0:00.2")
}

///|
test "stopwatch pause stops accumulation" {
  let c = stopwatch(interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start)
  let m1 = (c.update)(
      started.model,
      Tick(started.model.instance_id, started.model.tick_generation),
    ).model
  let paused = (c.update)(m1, Pause).model
  let m2 = (c.update)(paused, Tick(m1.instance_id, m1.tick_generation)).model
  assert_eq(m2.elapsed_ms, 100)
  assert_eq(m2.running, false)
}

///|
test "stopwatch ignores stale tick from paused run after restart" {
  let c = stopwatch(interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start).model
  let stale_tick : StopwatchMsg = Tick(
    started.instance_id,
    started.tick_generation,
  )
  let paused = (c.update)(started, Pause).model
  let restarted = (c.update)(paused, Start).model
  let stale_result = (c.update)(restarted, stale_tick)
  let after_stale_tick = stale_result.model
  assert_eq(after_stale_tick.elapsed_ms, restarted.elapsed_ms)
  assert_eq(after_stale_tick.running, true)
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
    Tick(second_running.instance_id, second_running.tick_generation),
  )
  let second_after_first_tick = (second.update)(
    second_running,
    Tick(first_running.instance_id, first_running.tick_generation),
  )
  assert_eq(first_after_second_tick.model.elapsed_ms, first_running.elapsed_ms)
  assert_eq(second_after_first_tick.model.elapsed_ms, second_running.elapsed_ms)
  assert_true(first_after_second_tick.cmd.is_none())
  assert_true(second_after_first_tick.cmd.is_none())
}
