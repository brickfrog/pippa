///|
test "viewport init" {
  let vp = viewport(width=10, height=5)
  let res = (vp.init)()
  assert_eq(res.model.width, 10)
  assert_eq(res.model.height, 5)
  assert_eq(res.model.offset, 0)
  assert_eq(res.model.content, "")
}

///|
test "viewport scroll and clamp" {
  let vp = viewport(width=10, height=2)
  let mut m = (vp.init)().model

  // Set content to 4 lines
  m = (vp.update)(m, SetContent("1\n2\n3\n4")).model
  assert_eq(m.offset, 0)

  // Scroll down
  m = (vp.update)(m, ScrollDown).model
  assert_eq(m.offset, 1)

  // Scroll down more than max
  m = (vp.update)(m, ScrollDown).model
  m = (vp.update)(m, ScrollDown).model
  m = (vp.update)(m, ScrollDown).model
  assert_eq(m.offset, 2) // max_offset = 4 - 2 = 2

  // Scroll to top
  m = (vp.update)(m, ScrollToTop).model
  assert_eq(m.offset, 0)

  // Scroll up at top
  m = (vp.update)(m, ScrollUp).model
  assert_eq(m.offset, 0)

  // Page down
  m = (vp.update)(m, PageDown).model
  assert_eq(m.offset, 2)

  // Page up
  m = (vp.update)(m, PageUp).model
  assert_eq(m.offset, 0)

  // Scroll to bottom
  m = (vp.update)(m, ScrollToBottom).model
  assert_eq(m.offset, 2)

  // Resize
  m = (vp.update)(m, Resize(10, 5)).model
  assert_eq(m.height, 5)
  assert_eq(m.offset, 0) // clamped because 4 - 5 < 0 => max_offset = 0
}

///|
test "viewport view output" {
  let vp = viewport(width=5, height=3)
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("one\ntwo\nthree\nfour")).model

  let v1 = (vp.view)(m)
  assert_eq(v1, "one  \ntwo  \nthree")

  m = (vp.update)(m, ScrollDown).model
  let v2 = (vp.view)(m)
  assert_eq(v2, "two  \nthree\nfour ")
}

///|
test "viewport view padding when few lines" {
  let vp = viewport(width=4, height=3)
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("a\nb")).model
  let v = (vp.view)(m)
  assert_eq(v, "a   \nb   \n    ")
}

///|
test "viewport truncation" {
  let vp = viewport(width=3, height=1)
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("longline")).model
  let v = (vp.view)(m)
  assert_eq(v, "lon")
}
