///|
fn timer_tick_msg(model : TimerModel) -> TimerMsg {
  Tick({ instance_id: model.instance_id, generation: model.tick_generation })
}

///|
test "timer counts down to zero" {
  let c = timer(duration_ms=250, interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start)
  let m1 = (c.update)(started.model, timer_tick_msg(started.model)).model
  let m2 = (c.update)(m1, timer_tick_msg(m1)).model
  let m3 = (c.update)(m2, timer_tick_msg(m2)).model
  assert_eq(m3.remaining_ms, 0)
  assert_eq(m3.finished, true)
  assert_eq(m3.running, false)
}

///|
test "timer reset restores full duration" {
  let c = timer(duration_ms=500, interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start)
  let m1 = (c.update)(started.model, timer_tick_msg(started.model)).model
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
  let stale_tick = timer_tick_msg(started)
  let paused = (c.update)(started, Pause).model
  let restarted = (c.update)(paused, Start).model
  let stale_result = (c.update)(restarted, stale_tick)
  @test.assert_eq(stale_result.model, restarted)
  assert_true(stale_result.cmd.is_none())
}

///|
test "timer ignores stale tick from reset run after restart" {
  let c = timer(duration_ms=500, interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start).model
  let stale_tick = timer_tick_msg(started)
  let reset = (c.update)(started, Reset).model
  let restarted = (c.update)(reset, Start).model
  let stale_result = (c.update)(restarted, stale_tick)
  @test.assert_eq(stale_result.model, restarted)
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
    timer_tick_msg(second_running),
  )
  let second_after_first_tick = (second.update)(
    second_running,
    timer_tick_msg(first_running),
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
