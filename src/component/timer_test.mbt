///|
test "timer counts down to zero" {
  let c = timer(duration_ms=250, interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start)
  let m1 = (c.update)(started.model, Tick).model
  let m2 = (c.update)(m1, Tick).model
  let m3 = (c.update)(m2, Tick).model
  assert_eq(m3.remaining_ms, 0)
  assert_eq(m3.finished, true)
  assert_eq(m3.running, false)
}

///|
test "timer reset restores full duration" {
  let c = timer(duration_ms=500, interval_ms=100)
  let m0 = (c.init)().model
  let started = (c.update)(m0, Start)
  let m1 = (c.update)(started.model, Tick).model
  let m2 = (c.update)(m1, Reset).model
  assert_eq(m2.remaining_ms, 500)
  assert_eq(m2.finished, false)
  assert_eq((c.view)(m2), "0:00.5")
}
