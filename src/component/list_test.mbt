///|
fn list_test_item(
  id : String,
  title : String,
  filter_value : String,
) -> ListItem[Int] {
  {
    id,
    filter_value,
    title,
    description: Some("description " + id),
    payload: Some(id.length()),
  }
}

///|
fn list_test_items() -> Array[ListItem[Int]] {
  [
    list_test_item("alpha", "Alpha", "alpha"),
    list_test_item("beta", "Beta", "beta"),
    list_test_item("gamma", "Gamma", "gamma"),
    list_test_item("delta", "Delta", "delta"),
  ]
}

///|
fn list_test_join_ints(values : Array[Int]) -> String {
  let parts : Array[String] = []
  for value in values {
    parts.push(value.to_string())
  }
  parts.join(",")
}

///|
test "list fuzzy ranks results and exposes matched indexes" {
  let items : Array[ListItem[Int]] = [
    list_test_item("tight", "ABC", "abc"),
    list_test_item("spread", "A B C", "a-b-c"),
    list_test_item("far", "A far B far C", "a------b------c"),
    list_test_item("miss", "ACB", "acb"),
  ]
  let c = list(items~, page_size=10)
  let model = (c.update)((c.init)().model, SetFilter("abc")).model
  assert_true(model.filter_state == FilterApplied)
  let visible = list_visible_items(model)
  assert_eq(visible.length(), 3)
  assert_eq(visible[0].item.id, "tight")
  assert_eq(visible[1].item.id, "spread")
  assert_eq(visible[2].item.id, "far")
  @test.assert_eq(visible[0].matched_indexes, [0, 1, 2])
  @test.assert_eq(visible[1].matched_indexes, [0, 2, 4])
  assert_true(visible[0].score > visible[1].score)
  assert_true(visible[1].score > visible[2].score)
}

///|
test "list filter state transitions live filter accept and cancel" {
  let c = list(items=list_test_items(), page_size=10)
  let mut model = (c.init)().model
  assert_true(model.filter_state == Unfiltered)

  model = (c.update)(model, StartFilter).model
  assert_true(model.filter_state == Filtering)
  assert_eq(model.filter_input.focused, true)

  model = (c.update)(model, Blur).model
  assert_eq(model.focused, false)
  assert_eq(model.filter_input.focused, false)
  model = (c.update)(model, HandleInput(@pippa.Key(@pippa.Char('x')))).model
  assert_eq(list_filter_query(model), "")
  model = (c.update)(model, Focus).model
  assert_eq(model.focused, true)
  assert_eq(model.filter_input.focused, true)

  model = (c.update)(model, HandleInput(@pippa.Key(@pippa.Char('g')))).model
  model = (c.update)(model, HandleInput(@pippa.Key(@pippa.Char('m')))).model
  assert_eq(list_filter_query(model), "gm")
  let live = list_visible_items(model)
  assert_eq(live.length(), 1)
  assert_eq(live[0].item.id, "gamma")

  model = (c.update)(model, HandleInput(@pippa.Key(@pippa.Special("enter")))).model
  assert_true(model.filter_state == FilterApplied)
  assert_eq(model.filter_input.focused, false)
  assert_eq(list_filter_query(model), "gm")

  model = (c.update)(model, StartFilter).model
  model = (c.update)(model, FilterInsertChar('z')).model
  assert_eq(list_filter_query(model), "gmz")
  assert_eq(list_visible_items(model).length(), 0)

  model = (c.update)(model, CancelFilter).model
  assert_true(model.filter_state == FilterApplied)
  assert_eq(list_filter_query(model), "gm")
  assert_eq(list_visible_items(model)[0].item.id, "gamma")

  model = (c.update)(model, ClearFilter).model
  assert_true(model.filter_state == Unfiltered)
  assert_eq(list_filter_query(model), "")
  assert_eq(list_visible_items(model).length(), 4)
}

///|
test "list selection remains stable by item identity across filters and SetItems" {
  let c = list(items=list_test_items(), page_size=10)
  let mut model = (c.init)().model
  model = (c.update)(model, CursorDown).model
  model = (c.update)(model, Select).model
  @test.assert_eq(model.selected_id, Some("beta"))

  model = (c.update)(model, SetFilter("gm")).model
  assert_eq(list_visible_items(model).length(), 1)
  match list_selected_item(model) {
    Some(item) => assert_eq(item.id, "beta")
    None => fail("expected selected beta to stay selected while hidden")
  }

  let reordered : Array[ListItem[Int]] = [
    list_test_item("gamma", "Gamma", "gamma"),
    list_test_item("alpha", "Alpha", "alpha"),
    list_test_item("beta", "Beta v2", "beta"),
  ]
  model = (c.update)(model, SetItems(reordered)).model
  match list_selected_item(model) {
    Some(item) => {
      assert_eq(item.id, "beta")
      assert_eq(item.title, "Beta v2")
    }
    None => fail("expected selected beta to survive SetItems")
  }
}

///|
test "list delegate controls item rendering with match metadata" {
  let delegate : ListDelegate[Int] = {
    render: fn(ctx) {
      let cursor = if ctx.cursor { "cursor" } else { "idle" }
      let selected = if ctx.selected { "selected" } else { "plain" }
      "\{ctx.index}:\{ctx.item.title}:\{cursor}:\{selected}:\{list_test_join_ints(ctx.matched_indexes)}"
    },
    update: None,
  }
  let c = list(items=list_test_items(), page_size=10, delegate~)
  let mut model = (c.init)().model
  model = (c.update)(model, SetFilter("gm")).model
  let view = (c.view)(model)
  assert_true(view.contains("0:Gamma:cursor:plain:0,2"))
}

///|
test "list status messages expire by generation and reject stale ticks" {
  let c = list(items=list_test_items(), page_size=10, status_duration_ms=50)
  let mut model = (c.init)().model
  model = (c.update)(model, SetStatus("first", 50)).model
  let stale : ListStatusToken = {
    instance_id: model.status_instance_id,
    generation: model.status_generation,
  }
  @test.assert_eq(model.status_message, Some("first"))

  model = (c.update)(model, ResetStatus).model
  @test.assert_eq(model.status_message, None)
  model = (c.update)(model, SetStatus("second", 50)).model
  let current : ListStatusToken = {
    instance_id: model.status_instance_id,
    generation: model.status_generation,
  }
  model = (c.update)(model, StatusExpired(stale)).model
  @test.assert_eq(model.status_message, Some("second"))
  model = (c.update)(model, StatusExpired(current)).model
  @test.assert_eq(model.status_message, None)
}

///|
test "list paginates filtered results through paginator model" {
  let items : Array[ListItem[Int]] = [
    list_test_item("a0", "AA 0", "aa0"),
    list_test_item("a1", "AA 1", "aa1"),
    list_test_item("a2", "AA 2", "aa2"),
    list_test_item("a3", "AA 3", "aa3"),
    list_test_item("a4", "AA 4", "aa4"),
  ]
  let c = list(items~, page_size=2)
  let mut model = (c.init)().model
  model = (c.update)(model, SetFilter("aa")).model
  assert_eq(model.paginator.total_items, 5)
  model = (c.update)(model, PageDown).model
  assert_eq(model.cursor, 2)
  assert_eq(model.paginator.page, 1)
  assert_eq((c.view)(model).contains("Page 2/3"), true)
}

///|
test "list keymap override disable and help rendering" {
  let custom = list_keymap_override(
    default_list_keymap(),
    ListActionCursorDown,
    @pippa.binding(keys=["n"], help_key="n", help="next item"),
  )
  let c = list(items=list_test_items(), page_size=10, keymap=custom)
  let mut model = (c.init)().model
  model = (c.update)(model, HandleInput(@pippa.Key(@pippa.Char('j')))).model
  assert_eq(model.cursor, 0)
  model = (c.update)(model, HandleInput(@pippa.Key(@pippa.Char('n')))).model
  assert_eq(model.cursor, 1)

  let disabled = list_keymap_disable(custom, ListActionClearFilter)
  let short_help = list_help_view(keymap=disabled, show_full=false, width=0)
  assert_true(short_help.contains("n next item"))
  assert_true(!short_help.contains("clear filter"))
  let full_help = list_help_view(keymap=custom, show_full=true, width=0)
  assert_true(full_help.contains("Navigation"))
  assert_true(full_help.contains("Filtering"))
}
