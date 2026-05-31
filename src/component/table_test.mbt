///|
fn table_test_rows(count : Int) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  for i in 0..<count {
    rows.push([i.to_string(), "row\{i}"])
  }
  rows
}

///|
fn table_test_assert_lines_fit_width(out : String, width : Int) -> Unit raise {
  for line in @pippa.split_lines(out) {
    if line != "" {
      assert_true(@internal.display_width(@pippa.strip_ansi(line)) <= width)
    }
  }
}

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

///|
test "Table negative column width is clamped to zero" {
  let columns : Array[Column] = [
    { header: "Bad", width: -5 },
    { header: "OK", width: 2 },
  ]
  let tbl = table(columns~)
  let mut res = (tbl.init)()
  res = (tbl.update)(res.model, SetRows([["x", "ab"]]))
  let out = (tbl.view)(res.model)
  let bold = @pippa.bold()
  let reset = @pippa.reset()
  let expected = " │ OK\n" +
    "─────\n" +
    bold +
    " │ ab" +
    reset +
    "\n"
  assert_eq(out, expected)
}

///|
test "Table truncates and pads cells by display width" {
  let accented = String::from_array(['e', '\u{0301}'])
  let columns : Array[Column] = [
    { header: "名", width: 4 },
    { header: "Accent", width: 3 },
  ]
  let tbl = table(columns~)
  let mut res = (tbl.init)()
  res = (tbl.update)(res.model, SetRows([["你好x", "\{accented}bc"]]))
  let out = (tbl.view)(res.model)
  let bold = @pippa.bold()
  let reset = @pippa.reset()
  let expected = "名   │ Acc\n" +
    "──────────\n" +
    bold +
    "你好 │ \{accented}bc" +
    reset +
    "\n"
  assert_eq(@pippa.strip_ansi(out), @pippa.strip_ansi(expected))
  assert_true(out == expected)
}

///|
test "Table pads ANSI-styled cells before trailing reset" {
  let columns : Array[Column] = [{ header: "Wide", width: 4 }]
  let tbl = table(columns~)
  let mut res = (tbl.init)()
  res = (tbl.update)(res.model, SetRows([["\u001b[31m界\u001b[0m"]]))
  let out = (tbl.view)(res.model)
  let bold = @pippa.bold()
  let reset = @pippa.reset()
  let expected = "Wide\n" +
    "────\n" +
    bold +
    "\u001b[31m界  \u001b[0m" +
    reset +
    "\n"
  assert_true(out == expected)
}

///|
test "Table viewport clips body and scrolls cursor into view" {
  let columns : Array[Column] = [
    { header: "ID", width: 2 },
    { header: "Name", width: 5 },
  ]
  let tbl = table(columns~, height=3)
  let mut model = (tbl.init)().model
  model = (tbl.update)(model, SetRows(table_test_rows(8))).model
  assert_eq(model.viewport.height, 3)

  let top = @pippa.strip_ansi((tbl.view)(model))
  assert_true(top.contains("row0"))
  assert_true(top.contains("row2"))
  assert_true(!top.contains("row3"))

  model = (tbl.update)(model, SetCursor(5)).model
  assert_eq(model.cursor, 5)
  assert_eq(model.viewport.offset, 3)
  let scrolled = (tbl.view)(model)
  let stripped = @pippa.strip_ansi(scrolled)
  assert_true(!stripped.contains("row2"))
  assert_true(stripped.contains("row3"))
  assert_true(stripped.contains("row5"))
  assert_true(scrolled.contains(@pippa.bold() + "5 "))
}

///|
test "Table focus and blur gate key navigation and cursor highlight" {
  let columns : Array[Column] = [{ header: "Name", width: 5 }]
  let tbl = table(columns~, height=3)
  let mut model = (tbl.init)().model
  model = (tbl.update)(model, SetRows([["one"], ["two"], ["three"]])).model

  model = (tbl.update)(model, Blur).model
  assert_eq(model.focused, false)
  assert_true(!(tbl.view)(model).contains(@pippa.bold()))
  model = (tbl.update)(model, HandleInput(@pippa.Key(@pippa.Special("down")))).model
  assert_eq(model.cursor, 0)

  model = (tbl.update)(model, Focus).model
  model = (tbl.update)(model, HandleInput(@pippa.Key(@pippa.Special("down")))).model
  assert_eq(model.cursor, 1)
  assert_true((tbl.view)(model).contains(@pippa.bold() + "two"))
}

///|
test "Table keymap override disable and help rendering" {
  let columns : Array[Column] = [{ header: "Name", width: 5 }]
  let custom = table_keymap_override(
    default_table_keymap(),
    TableActionCursorDown,
    @pippa.binding(keys=["n"], help_key="n", help="next row"),
  )
  let tbl = table(columns~, keymap=custom)
  let mut model = (tbl.init)().model
  model = (tbl.update)(model, SetRows([["one"], ["two"]])).model
  model = (tbl.update)(model, HandleInput(@pippa.Key(@pippa.Char('j')))).model
  assert_eq(model.cursor, 0)
  model = (tbl.update)(model, HandleInput(@pippa.Key(@pippa.Char('n')))).model
  assert_eq(model.cursor, 1)

  let disabled = table_keymap_disable(custom, TableActionSelect)
  let short_help = table_help_view(keymap=disabled, show_full=false, width=0)
  assert_true(short_help.contains("n next row"))
  assert_true(!short_help.contains("select"))
  let full_help = table_help_view(keymap=custom, show_full=true, width=0)
  assert_true(full_help.contains("Movement"))
  assert_true(full_help.contains("Selection"))
}

///|
test "Table page half-page top and bottom navigation clamp" {
  let columns : Array[Column] = [{ header: "Name", width: 5 }]
  let tbl = table(columns~, height=4)
  let mut model = (tbl.init)().model
  model = (tbl.update)(model, SetRows(table_test_rows(10))).model

  model = (tbl.update)(model, PageDown).model
  assert_eq(model.cursor, 4)
  model = (tbl.update)(model, PageDown).model
  assert_eq(model.cursor, 8)
  model = (tbl.update)(model, PageDown).model
  assert_eq(model.cursor, 9)
  model = (tbl.update)(model, PageUp).model
  assert_eq(model.cursor, 5)
  model = (tbl.update)(model, HalfPageUp).model
  assert_eq(model.cursor, 3)
  model = (tbl.update)(model, HalfPageDown).model
  assert_eq(model.cursor, 5)
  model = (tbl.update)(model, MoveToTop).model
  assert_eq(model.cursor, 0)
  model = (tbl.update)(model, MoveToBottom).model
  assert_eq(model.cursor, 9)
}

///|
test "Table width height columns rows and cursor setters" {
  let columns : Array[Column] = [
    { header: "ID", width: 4 },
    { header: "Name", width: 8 },
  ]
  let tbl = table(columns~, width=8, height=1)
  let mut model = (tbl.init)().model
  model = (tbl.update)(model, SetRows([["1", "Alice"], ["2", "Bob"]])).model
  model = (tbl.update)(model, SetCursor(1)).model
  model = (tbl.update)(model, Select).model
  assert_eq(model.selected, 1)

  model = (tbl.update)(model, SetColumns([{ header: "Only", width: 4 }])).model
  assert_eq(model.columns.length(), 1)
  model = (tbl.update)(model, SetWidth(6)).model
  model = (tbl.update)(model, SetHeight(2)).model
  assert_eq(model.width, 6)
  assert_eq(model.height, 2)
  table_test_assert_lines_fit_width((tbl.view)(model), 6)

  model = (tbl.update)(model, SetRows([["x"], ["y"], ["z"]])).model
  assert_eq(model.cursor, 0)
  assert_eq(model.selected, -1)
  model = (tbl.update)(model, SetCursor(99)).model
  assert_eq(model.cursor, 2)
  model = (tbl.update)(model, SetCursor(-3)).model
  assert_eq(model.cursor, 0)
}

///|
test "Table renders wide graphemes and ANSI cells without splitting columns" {
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let columns : Array[Column] = [
    { header: "Glyph", width: 2 },
    { header: "Wide", width: 3 },
  ]
  let tbl = table(columns~)
  let mut model = (tbl.init)().model
  model = (tbl.update)(
      model,
      SetRows([["\u001b[31m\{technologist}x\u001b[0m", "界ab"]]),
    ).model
  let out = (tbl.view)(model)
  assert_true(out.contains(technologist))
  assert_true(!@pippa.strip_ansi(out).contains("x"))
  table_test_assert_lines_fit_width(out, 8)
}

///|
test "Table selected row and cursor helpers follow model state" {
  let columns : Array[Column] = [{ header: "Name", width: 5 }]
  let tbl = table(columns~)
  let mut model = (tbl.init)().model
  model = (tbl.update)(model, SetRows(table_test_rows(3))).model
  assert_eq(table_cursor(model), 0)
  assert_true(table_selected_row(model) is None)

  model = (tbl.update)(model, SetCursor(2)).model
  assert_eq(table_cursor(model), 2)
  model = (tbl.update)(model, Select).model
  match table_selected_row(model) {
    Some(row) => {
      assert_eq(row.length(), 2)
      assert_eq(row[0], "2")
      assert_eq(row[1], "row2")
    }
    None => assert_true(false)
  }
}
