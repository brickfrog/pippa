///|
test "list renders bullet items" {
  let actual = new()
    .item_text("Tea")
    .item_text("Coffee")
    .item_text("Water")
    .render()
  assert_eq(actual, "• Tea\n• Coffee\n• Water")
}

///|
test "list renders arabic items" {
  let actual = new()
    .enumerator(arabic)
    .item_text("Tea")
    .item_text("Coffee")
    .item_text("Water")
    .render()
  assert_eq(actual, "1. Tea\n2. Coffee\n3. Water")
}

///|
test "list renders nested sublists through tree wrapping" {
  let dairy = new()
    .enumerator(dash)
    .item_text("Almond milk")
    .item_text("Oat milk")
  let actual = new()
    .item_text("Produce")
    .item_text("Milk")
    .item_list(dairy)
    .item_text("Eggs")
    .render()
  assert_eq(
    actual,
    "• Produce\n" +
    "• Milk\n" +
    "  - Almond milk\n" +
    "  - Oat milk\n" +
    "• Eggs",
  )
}

///|
test "list renders styled enumerators and items" {
  let actual = new()
    .enumerator(arabic)
    .enumerator_style(@pippa.style().fg_color(3))
    .item_style_func(fn(_items, index) {
      if index == 1 {
        @pippa.style().bold()
      } else {
        @pippa.style()
      }
    })
    .item_text("Plain")
    .item_text("Bold")
    .render()
  let expected = @pippa.fg_color(3) +
    "1." +
    @pippa.reset() +
    " Plain\n" +
    @pippa.fg_color(3) +
    "2." +
    @pippa.reset() +
    " " +
    @pippa.bold() +
    "Bold" +
    @pippa.reset()
  assert_eq(actual, expected)
}
