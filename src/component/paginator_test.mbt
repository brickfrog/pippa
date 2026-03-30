///|
test "paginator clamps page and tracks totals" {
  let c = paginator(per_page=5)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetTotalItems(12)).model
  let m2 = (c.update)(m1, NextPage).model
  let m3 = (c.update)(m2, NextPage).model
  let m4 = (c.update)(m3, NextPage).model
  assert_eq(m4.page, 2)
  assert_eq((c.view)(m4), "Page 3/3")
}

///|
test "paginator clamps when page size changes" {
  let c = paginator(per_page=2)
  let m0 = (c.init)().model
  let m1 = (c.update)(m0, SetTotalItems(9)).model
  let m2 = (c.update)(m1, SetPage(4)).model
  let m3 = (c.update)(m2, SetPerPage(5)).model
  assert_eq(m3.page, 1)
  assert_eq((c.view)(m3), "Page 2/2")
}
