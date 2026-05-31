///|
test "timer stopwatch parity starts and ticks both clocks" {
  let { model, .. } = timer_stopwatch_parity_init()
  let started = timer_stopwatch_parity_update(model, StartBoth).model
  let ticked = timer_stopwatch_parity_tick_both(started)

  assert_eq(ticked.timer.remaining_ms, 200)
  assert_eq(ticked.stopwatch.elapsed_ms, 100)
  assert_true(timer_stopwatch_parity_view(ticked).contains("Timer: 0:00.2"))
  assert_true(timer_stopwatch_parity_view(ticked).contains("Stopwatch: 0:00.1"))
}

///|
test "timer stopwatch parity reset restores both components" {
  let { model, .. } = timer_stopwatch_parity_init()
  let started = timer_stopwatch_parity_update(model, StartBoth).model
  let ticked = timer_stopwatch_parity_tick_both(started)
  let reset = timer_stopwatch_parity_update(ticked, ResetBoth).model

  assert_eq(reset.timer.remaining_ms, 300)
  assert_eq(reset.stopwatch.elapsed_ms, 0)
  assert_false(reset.timer.running)
  assert_false(reset.stopwatch.running)
}
