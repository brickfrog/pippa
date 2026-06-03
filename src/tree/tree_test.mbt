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
