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
test "table wraps wide grapheme at odd width without dropping it" {
  let actual = new().row(["ab你z"]).width(5).render()
  assert_eq(
    actual,
    "┌───┐\n" + "│ab │\n" + "│你z│\n" + "└───┘",
  )
}

///|
test "table wraps all-wide graphemes at odd width without splits" {
  let actual = new().row(["你好世界"]).width(5).render()
  assert_eq(
    actual,
    "┌───┐\n" +
    "│你 │\n" +
    "│好 │\n" +
    "│世 │\n" +
    "│界 │\n" +
    "└───┘",
  )
  assert_eq(@pippa.max_line_width(actual), 5)
}

///|
test "table truncates whole wide grapheme in under-width column" {
  let actual = new().row(["你"]).width(3).render()
  assert_eq(actual, "┌─┐\n│ │\n└─┘")
}

///|
test "table wraps ansi cell content without splitting escapes" {
  let styled = @pippa.fg_color(1) + "abcdefghij" + @pippa.reset()
  let actual = new().row([styled]).width(8).render()
  let expected = "┌──────┐\n" +
    "│" +
    @pippa.fg_color(1) +
    "abcdef" +
    @pippa.reset() +
    "│\n" +
    "│" +
    @pippa.fg_color(1) +
    "ghij  " +
    @pippa.reset() +
    "│\n" +
    "└──────┘"
  assert_eq(actual, expected)
  assert_eq(@pippa.max_line_width(actual), 8)
  assert_eq(
    @pippa.strip_ansi(actual),
    "┌──────┐\n│abcdef│\n│ghij  │\n└──────┘",
  )
}

///|
test "table closes styled wrapped cells before separator" {
  let actual = new()
    .row(["abcdefghij", "plain"])
    .style_func(fn(_row, col) {
      if col == 0 {
        @pippa.style().fg_color(2)
      } else {
        @pippa.style()
      }
    })
    .width(14)
    .render()
  let expected = "┌──────┬─────┐\n" +
    "│" +
    @pippa.fg_color(2) +
    "abcdef" +
    @pippa.reset() +
    "│plain│\n" +
    "│" +
    @pippa.fg_color(2) +
    "ghij  " +
    @pippa.reset() +
    "│     │\n" +
    "└──────┴─────┘"
  assert_eq(actual, expected)
}

///|
test "table closes first wrapped segment after mid-content restyle" {
  let styled = @pippa.fg_color(1) +
    "abcdef" +
    @pippa.reset() +
    @pippa.fg_color(2) +
    "ghij"
  let actual = new().row([styled, "plain"]).width(14).render()
  let expected = "┌──────┬─────┐\n" +
    "│" +
    @pippa.fg_color(1) +
    "abcdef" +
    @pippa.reset() +
    "│plain│\n" +
    "│" +
    @pippa.fg_color(2) +
    "ghij  " +
    @pippa.reset() +
    "│     │\n" +
    "└──────┴─────┘"
  assert_eq(actual, expected)
}

///|
test "table height caps rows while preserving bottom border" {
  let actual = new().row(["one"]).row(["two"]).row(["three"]).height(4).render()
  assert_eq(
    actual, "┌─────┐\n│one  │\n│…    │\n└─────┘",
  )
}

///|
test "table height renders overflow row while preserving borders" {
  let actual = new()
    .headers(["Item", "Qty"])
    .row(["one", "1"])
    .row(["two", "2"])
    .row(["three", "3"])
    .height(6)
    .render()
  assert_eq(@pippa.line_count(actual), 6)
  assert_eq(
    actual,
    "┌─────┬───┐\n" +
    "│Item │Qty│\n" +
    "├─────┼───┤\n" +
    "│one  │1  │\n" +
    "│…    │…  │\n" +
    "└─────┴───┘",
  )
}

///|
test "table tight headered height keeps overflow before cropped bottom border" {
  let actual = new()
    .headers(["Item", "Qty"])
    .row(["one", "1"])
    .row(["two", "2"])
    .row(["three", "3"])
    .height(4)
    .render()
  assert_eq(@pippa.line_count(actual), 4)
  assert_eq(
    actual,
    "┌─────┬───┐\n" +
    "│Item │Qty│\n" +
    "├─────┼───┤\n" +
    "│…    │…  │",
  )
}

///|
test "table height at least content height is no-op" {
  let table = new().headers(["Item"]).row(["one"]).row(["two"])
  assert_eq(table.height(99).render(), table.render())
}

///|
test "table height accounts for wrapped row height before overflow" {
  let actual = new()
    .row(["abcdefghij"])
    .row(["tail"])
    .row(["last"])
    .width(8)
    .height(5)
    .render()
  assert_eq(@pippa.line_count(actual), 5)
  assert_eq(
    actual,
    "┌──────┐\n" +
    "│abcdef│\n" +
    "│ghij  │\n" +
    "│…     │\n" +
    "└──────┘",
  )
}
