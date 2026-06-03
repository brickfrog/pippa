///|
fn padded_table_style(_row : Int, _col : Int) -> @pippa.Style {
  @pippa.style().padding(0, 1, 0, 1)
}

///|
test "table renders headers rows and border" {
  let actual = new()
    .headers(["Name", "Age"])
    .row(["Kini", "4"])
    .row(["Eli", "1"])
    .style_func(padded_table_style)
    .render()
  let expected = "┌──────┬─────┐\n" +
    "│ Name │ Age │\n" +
    "├──────┼─────┤\n" +
    "│ Kini │ 4   │\n" +
    "│ Eli  │ 1   │\n" +
    "└──────┴─────┘"
  assert_eq(actual, expected)
}

///|
test "table renders styled cells" {
  let actual = new()
    .headers(["Name", "Kind"])
    .row(["Pippa", "TUI"])
    .style_func(fn(row, col) {
      if row == HEADER_ROW {
        @pippa.style().bold()
      } else if col == 1 {
        @pippa.style().fg_color(2)
      } else {
        @pippa.style()
      }
    })
    .render()
  let expected = "┌─────┬────┐\n" +
    "│" +
    @pippa.bold() +
    "Name " +
    @pippa.reset() +
    "│" +
    @pippa.bold() +
    "Kind" +
    @pippa.reset() +
    "│\n" +
    "├─────┼────┤\n" +
    "│Pippa│" +
    @pippa.fg_color(2) +
    "TUI " +
    @pippa.reset() +
    "│\n" +
    "└─────┴────┘"
  assert_eq(actual, expected)
}

///|
test "table width resizes columns" {
  let actual = new()
    .headers(["Name", "Location"])
    .row(["Iris", "New York"])
    .row(["Eli", "London"])
    .width(20)
    .render()
  assert_eq(@pippa.max_line_width(actual), 20)
  assert_eq(
    actual,
    "┌─────────┬────────┐\n" +
    "│Name     │Location│\n" +
    "├─────────┼────────┤\n" +
    "│Iris     │New York│\n" +
    "│Eli      │London  │\n" +
    "└─────────┴────────┘",
  )
}

///|
test "table normalizes multi-width custom border pieces" {
  let border : @pippa.Border = {
    top_left: "tl",
    top_right: "tr",
    bottom_left: "bl",
    bottom_right: "br",
    horizontal: "==",
    vertical: "||",
  }
  let actual = new().headers(["A"]).row(["B"]).border(border).render()
  assert_eq(@pippa.max_line_width(actual), 3)
  assert_eq(actual, "***\n*A*\n├*┤\n*B*\n***")
}

///|
test "table width leaves fixed-width columns unchanged" {
  let actual = new()
    .headers(["ID", "Name"])
    .row(["01", "Ada"])
    .style_func(fn(_row, col) {
      if col == 0 {
        @pippa.style().width(2)
      } else {
        @pippa.style()
      }
    })
    .width(20)
    .render()
  assert_eq(@pippa.max_line_width(actual), 20)
  assert_eq(
    actual,
    "┌──┬───────────────┐\n" +
    "│ID│Name           │\n" +
    "├──┼───────────────┤\n" +
    "│01│Ada            │\n" +
    "└──┴───────────────┘",
  )
}

///|
test "table wraps cells by default without dropping content" {
  let actual = new().row(["abcdefghij"]).width(8).render()
  assert_eq(
    actual,
    "┌──────┐\n" +
    "│abcdef│\n" +
    "│ghij  │\n" +
    "└──────┘",
  )
}

///|
test "table height caps rows while preserving bottom border" {
  let actual = new().row(["one"]).row(["two"]).row(["three"]).height(4).render()
  assert_eq(
    actual, "┌─────┐\n│one  │\n│two  │\n└─────┘",
  )
}
