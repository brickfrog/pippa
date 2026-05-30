///|
test "timer counts down to zero" {
  let c = timer(duration_ms=250, interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start)
  let m1 = (c.update)(
      started.model,
      Tick(started.model.instance_id, started.model.tick_generation),
    ).model
  let m2 = (c.update)(m1, Tick(m1.instance_id, m1.tick_generation)).model
  let m3 = (c.update)(m2, Tick(m2.instance_id, m2.tick_generation)).model
  assert_eq(m3.remaining_ms, 0)
  assert_eq(m3.finished, true)
  assert_eq(m3.running, false)
}

///|
test "timer reset restores full duration" {
  let c = timer(duration_ms=500, interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start)
  let m1 = (c.update)(
      started.model,
      Tick(started.model.instance_id, started.model.tick_generation),
    ).model
  let m2 = (c.update)(m1, Reset).model
  assert_eq(m2.remaining_ms, 500)
  assert_eq(m2.finished, false)
  assert_eq((c.view)(m2), "0:00.5")
}

///|
test "timer ignores stale tick from paused run after restart" {
  let c = timer(duration_ms=500, interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start).model
  let stale_tick : TimerMsg = Tick(started.instance_id, started.tick_generation)
  let paused = (c.update)(started, Pause).model
  let restarted = (c.update)(paused, Start).model
  let stale_result = (c.update)(restarted, stale_tick)
  let after_stale_tick = stale_result.model
  assert_eq(after_stale_tick.remaining_ms, restarted.remaining_ms)
  assert_eq(after_stale_tick.running, true)
  assert_true(stale_result.cmd.is_none())
}

///|
test "timer ignores ticks from another instance" {
  let first = timer(duration_ms=500, interval_ms=100)
  let second = timer(duration_ms=500, interval_ms=100)
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
  assert_eq(
    first_after_second_tick.model.remaining_ms,
    first_running.remaining_ms,
  )
  assert_eq(
    second_after_first_tick.model.remaining_ms,
    second_running.remaining_ms,
  )
  assert_true(first_after_second_tick.cmd.is_none())
  assert_true(second_after_first_tick.cmd.is_none())
}
