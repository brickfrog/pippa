///|
test "Table init and view empty" {
  let columns : Array[Column] = [
    { header: "ID", width: 4 },
    { header: "Name", width: 10 },
  ]
  let tbl = table(columns~)
  let res = (tbl.init)()
  assert_eq(res.model.cursor, 0)
  assert_eq(res.model.selected, -1)

  let out = (tbl.view)(res.model)
  let expected = "ID   │ Name      \n" +
    "─────────────────\n" +
    "(no data)\n"
  assert_eq(out, expected)
}

///|
test "Table with data, cursor and select" {
  let columns : Array[Column] = [
    { header: "ID", width: 4 },
    { header: "Name", width: 10 },
  ]
  let tbl = table(columns~)
  let mut res = (tbl.init)()

  res = (tbl.update)(
    res.model,
    SetRows([["1", "Alice"], ["2", "Bob"], ["3", "Charlie"]]),
  )
  assert_eq(res.model.cursor, 0)

  res = (tbl.update)(res.model, CursorDown)
  assert_eq(res.model.cursor, 1)

  res = (tbl.update)(res.model, CursorDown)
  res = (tbl.update)(res.model, CursorDown)
  assert_eq(res.model.cursor, 2) // Clamped

  res = (tbl.update)(res.model, Select)
  assert_eq(res.model.selected, 2)

  res = (tbl.update)(res.model, CursorUp)
  assert_eq(res.model.cursor, 1)

  res = (tbl.update)(res.model, CursorUp)
  res = (tbl.update)(res.model, CursorUp)
  assert_eq(res.model.cursor, 0) // Clamped

  let out = (tbl.view)(res.model)
  let bold = @pippa.bold()
  let underline = @pippa.underline()
  let reset = @pippa.reset()

  let expected = "ID   │ Name      \n" +
    "─────────────────\n" +
    bold +
    "1    │ Alice     " +
    reset +
    "\n" +
    "2    │ Bob       \n" +
    underline +
    "3    │ Charlie   " +
    reset +
    "\n"

  assert_eq(out, expected)
}
