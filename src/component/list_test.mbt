///|
test "list filters items" {
  let c = list(items=["alpha", "beta", "gamma"], page_size=5)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetFilter("ga")).model
  assert_eq(m1.filter, "ga")
  let view = (c.view)(m1)
  assert_true(view.contains("gamma"))
  assert_true(!view.contains("alpha"))
}

///|
test "list tracks cursor across pages" {
  let c = list(items=["a", "b", "c", "d", "e"], page_size=2)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, PageDown).model
  let m2 = (c.update)(m1, CursorDown).model
  assert_eq(m2.cursor, 3)
  let view = (c.view)(m2)
  assert_true(view.contains("d"))
  assert_true(view.contains("Page 2/3"))
}

///|
test "list select stores original index" {
  let c = list(items=["alpha", "beta", "gamma"], page_size=5)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetFilter("ga")).model
  let m2 = (c.update)(m1, Select).model
  assert_eq(m2.selected, 2)
}

///|
test "list filter typing appends and backspaces" {
  let c = list(items=["alpha"], page_size=5)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, FilterInsertChar('a')).model
  let m2 = (c.update)(m1, FilterInsertChar('l')).model
  let m3 = (c.update)(m2, FilterBackspace).model
  assert_eq(m2.filter, "al")
  assert_eq(m3.filter, "a")
}
