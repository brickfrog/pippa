///|
test "viewport parity scripts vertical and horizontal scroll with gutter" {
  let model = viewport_parity_run_script([
    @pippa.Key(@pippa.Special("down")),
    @pippa.Key(@pippa.Special("right")),
  ])

  assert_eq(model.pager.offset, 1)
  assert_eq(model.pager.x_offset, 2)
  assert_eq(viewport_parity_snapshot(model), "2|ta-li\n3|arlie")
}

///|
test "viewport parity page navigation clamps through component helpers" {
  let { model, .. } = viewport_parity_init()
  let paged = viewport_parity_update(model, PagerMsg(@component.PageDown)).model
  let top = viewport_parity_update(paged, PagerMsg(@component.ScrollToTop)).model

  assert_eq(paged.pager.offset, 2)
  assert_true(@component.viewport_at_top(top.pager))
  assert_eq(top.pager.offset, 0)
}
