///|
test "stopwatch accumulates elapsed time" {
  let c = stopwatch(interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start)
  let m1 = (c.update)(started.model, Tick).model
  let m2 = (c.update)(m1, Tick).model
  assert_eq(m2.elapsed_ms, 200)
  assert_eq((c.view)(m2), "0:00.2")
}

///|
test "stopwatch pause stops accumulation" {
  let c = stopwatch(interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start)
  let m1 = (c.update)(started.model, Tick).model
  let paused = (c.update)(m1, Pause).model
  let m2 = (c.update)(paused, Tick).model
  assert_eq(m2.elapsed_ms, 100)
  assert_eq(m2.running, false)
}
