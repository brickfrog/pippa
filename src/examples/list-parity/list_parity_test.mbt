///|
test "list parity scripts fuzzy filtering and delegate render" {
  let model = list_parity_run_script([
    @pippa.Key(@pippa.Char('/')),
    @pippa.Key(@pippa.Char('f')),
    @pippa.Key(@pippa.Char('z')),
    @pippa.Key(@pippa.Special("enter")),
  ])

  assert_eq(@component.list_filter_query(model.items), "fz")
  let visible = @component.list_visible_items(model.items)
  assert_eq(visible.length(), 1)
  assert_eq(visible[0].item.id, "fuzzy")
  assert_true(list_parity_view(model).contains("0:Fuzzy Finder:cursor:0,2"))
}

///|
test "list parity selection survives filtered view" {
  let { model, .. } = list_parity_init()
  let selected = list_parity_update(model, ListMsg(@component.CursorDown)).model
  let selected = list_parity_update(selected, ListMsg(@component.Select)).model
  let filtered = list_parity_update(
      selected,
      ListMsg(@component.SetFilter("vp")),
    ).model

  assert_eq(@component.list_filter_query(filtered.items), "vp")
  match @component.list_selected_item(filtered.items) {
    Some(item) => assert_eq(item.id, "viewport")
    None => fail("expected viewport selection")
  }
}
