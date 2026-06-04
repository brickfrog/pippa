///|
test "tree renders flat children" {
  let actual = new()
    .child_leaf("Foo")
    .child_leaf("Bar")
    .child_leaf("Baz")
    .render()
  let expected = "├── Foo\n├── Bar\n└── Baz"
  assert_eq(actual, expected)
}

///|
test "tree renders root and nested children" {
  let actual = root("Root")
    .child_leaf("Foo")
    .child(
      root("Bar")
      .child_leaf("Qux")
      .child(root("Quux").child_leaf("Foo").child_leaf("Bar"))
      .child_leaf("Quuux"),
    )
    .child_leaf("Baz")
    .render()
  let expected = "Root\n" +
    "├── Foo\n" +
    "├── Bar\n" +
    "│   ├── Qux\n" +
    "│   ├── Quux\n" +
    "│   │   ├── Foo\n" +
    "│   │   └── Bar\n" +
    "│   └── Quuux\n" +
    "└── Baz"
  assert_eq(actual, expected)
}

///|
test "tree renders custom enumerator" {
  let arrows : Enumerator = {
    child_connector: "->",
    last_child_connector: "=>",
    vertical_pipe: "::",
    indent: "..",
    item_indent: " ",
  }
  let actual = new()
    .enumerator(arrows)
    .child_leaf("Foo")
    .child(root("Bar").child_leaf("Baz"))
    .render()
  let expected = "-> Foo\n=> Bar\n.. => Baz"
  assert_eq(actual, expected)
}

///|
test "tree renders styled nodes and enumerators" {
  let actual = root("Root")
    .root_style(@pippa.style().bold())
    .enumerator_style_func(fn(_children, i) {
      if i == 0 {
        @pippa.style().fg_color(2)
      } else {
        @pippa.style().fg_color(3)
      }
    })
    .item_style(@pippa.style().fg_color(4))
    .child_leaf("Foo")
    .child_leaf("Bar")
    .render()
  let expected = @pippa.bold() +
    "Root" +
    @pippa.reset() +
    "\n" +
    @pippa.fg_color(2) +
    "├──" +
    @pippa.reset() +
    " " +
    @pippa.fg_color(4) +
    "Foo" +
    @pippa.reset() +
    "\n" +
    @pippa.fg_color(3) +
    "└──" +
    @pippa.reset() +
    " " +
    @pippa.fg_color(4) +
    "Bar" +
    @pippa.reset()
  assert_eq(actual, expected)
}

///|
test "tree offset renders absolute child window" {
  let tree = new()
    .child_leaf("A")
    .child_leaf("B")
    .child_leaf("C")
    .child_leaf("D")
  assert_eq(tree.offset(1, 3).render(), "├── B\n└── C")
  assert_eq(
    tree.offset(0, 4).render(),
    "├── A\n├── B\n├── C\n└── D",
  )
}

///|
test "tree offset window stays stable after append" {
  let actual = new()
    .child_leaf("A")
    .child_leaf("B")
    .offset(0, 1)
    .child_leaf("C")
    .render()
  assert_eq(actual, "└── A")
}

///|
test "tree set_value preserves leaf behavior" {
  let actual = new()
    .child(leaf("Old").set_value("Parent"))
    .child(new().item_style(@pippa.style().fg_color(1)).child_leaf("Child"))
    .render()
  let expected = "└── Parent\n    └── " +
    @pippa.fg_color(1) +
    "Child" +
    @pippa.reset()
  assert_eq(actual, expected)
}

///|
test "tree multiline non-last child keeps branch pipe" {
  let actual = new().child_leaf("A\nA2").child_leaf("B").render()
  assert_eq(actual, "├── A\n│   A2\n└── B")
}

///|
test "tree block-joins multiline connector with single-line item" {
  let actual = new()
    .enumerator_func(fn(_children, _index) { "|\n|" })
    .child_leaf("Leaf")
    .render()
  assert_eq(actual, "| Leaf\n|")
}

///|
test "tree block-joins multiline connector with multiline item" {
  let actual = new()
    .enumerator_func(fn(_children, _index) { "|\n|" })
    .child_leaf("Top\nBottom")
    .render()
  assert_eq(actual, "| Top\n| Bottom")
}

///|
test "tree pads every line of multiline sibling connectors" {
  let actual = new()
    .enumerator_func(fn(_children, i) {
      if i == 0 {
        "|\n||"
      } else {
        "====\n==="
      }
    })
    .child_leaf("A")
    .child_leaf("B")
    .render()
  let expected = "   | A\n  ||\n==== B\n ==="
  assert_eq(actual, expected)
}

///|
test "tree trims join padding before styled multiline item resets" {
  let actual = new()
    .enumerator_func(fn(_children, _index) { "|\n|" })
    .item_style(@pippa.style().fg_color(2))
    .child_leaf("Long\nB")
    .render()
  let expected = "| " +
    @pippa.fg_color(2) +
    "Long" +
    @pippa.reset() +
    "\n| " +
    @pippa.fg_color(2) +
    "B" +
    @pippa.reset()
  assert_eq(actual, expected)
}

///|
test "tree styles multiline connector lines independently" {
  let actual = new()
    .enumerator_func(fn(_children, _index) { "|\n|" })
    .enumerator_style(@pippa.style().bg_color(5))
    .child_leaf("A")
    .render()
  let expected = @pippa.bg_color(5) +
    "|" +
    @pippa.reset() +
    " A\n" +
    @pippa.bg_color(5) +
    "|" +
    @pippa.reset()
  assert_eq(actual, expected)
}

///|
test "tree styles connector alignment padding" {
  let actual = new()
    .enumerator_func(fn(_children, i) { if i == 0 { ">" } else { "====>" } })
    .enumerator_style(@pippa.style().bg_color(5))
    .child_leaf("Short")
    .child_leaf("Long")
    .render()
  let expected = @pippa.bg_color(5) +
    "    >" +
    @pippa.reset() +
    " Short\n" +
    @pippa.bg_color(5) +
    "====>" +
    @pippa.reset() +
    " Long"
  assert_eq(actual, expected)
}

///|
test "tree width pads root and child lines with active styles" {
  let actual = root("R")
    .root_style(@pippa.style().fg_color(1))
    .item_style(@pippa.style().fg_color(2))
    .width(6)
    .child_leaf("x")
    .render()
  let expected = @pippa.fg_color(1) +
    "R" +
    @pippa.reset() +
    @pippa.fg_color(1) +
    "     " +
    @pippa.reset() +
    "\n└── " +
    @pippa.fg_color(2) +
    "x" +
    @pippa.reset() +
    @pippa.fg_color(2) +
    " " +
    @pippa.reset()
  assert_eq(actual, expected)
}
