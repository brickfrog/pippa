///|
test "table parity scripts focus paging and selection" {
  let model = table_parity_run_script([
    @pippa.Key(@pippa.Special("down")),
    @pippa.Key(@pippa.Special("pagedown")),
    @pippa.Key(@pippa.Special("enter")),
  ])

  assert_eq(@component.table_cursor(model.table), 4)
  @test.assert_eq(
    @component.table_selected_row(model.table),
    Some(["E", "echo"]),
  )
  assert_true(
    @pippa.strip_ansi(table_parity_view(model)).contains("E  │ echo"),
  )
}

///|
test "table parity blur gates key navigation" {
  let { model, .. } = table_parity_init()
  let blurred = table_parity_update(model, TableMsg(@component.Blur)).model
  let ignored = table_parity_update(
      blurred,
      TableMsg(@component.HandleInput(@pippa.Key(@pippa.Special("down")))),
    ).model

  assert_eq(@component.table_cursor(ignored.table), 0)
}
