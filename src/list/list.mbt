///|
/// Static list renderer inspired by lipgloss/list.
///
/// Lists are implemented as a thin wrapper around `@pippa/tree`, matching the
/// Lip Gloss design while exposing list-oriented item and enumerator helpers.

///|
pub(all) struct Items {
  values : Array[String]
} derive(Debug, Eq)

///|
pub(all) enum Item {
  Text(String)
  Nested(List)
}

///|
struct List {
  tree : @tree.Tree
}

///|
pub fn text(value : String) -> Item {
  Text(value)
}

///|
pub fn nested(list : List) -> Item {
  Nested(list)
}

///|
pub fn Items::length(self : Items) -> Int {
  self.values.length()
}

///|
pub fn Items::value(self : Items, index : Int) -> String {
  if index < 0 || index >= self.values.length() {
    ""
  } else {
    self.values[index]
  }
}

///|
fn items_from_trees(children : Array[@tree.Tree]) -> Items {
  let values : Array[String] = []
  for child in children {
    values.push(child.value())
  }
  { values, }
}

///|
pub fn bullet(_items : Items, _index : Int) -> String {
  "•"
}

///|
pub fn dash(_items : Items, _index : Int) -> String {
  "-"
}

///|
pub fn arabic(_items : Items, index : Int) -> String {
  (@internal.clamp_non_negative(index) + 1).to_string() + "."
}

///|
pub fn alphabet(_items : Items, index : Int) -> String {
  let digits : Array[Char] = []
  let mut n = @internal.clamp_non_negative(index)
  while true {
    let rem = n % 26
    digits.push((0x41 + rem).unsafe_to_char())
    n = n / 26 - 1
    if n < 0 {
      break
    }
  }
  let buf = StringBuilder::new()
  for i in 0..<digits.length() {
    buf.write_char(digits[digits.length() - i - 1])
  }
  buf.write_string(".")
  buf.to_string()
}

///|
pub fn roman(_items : Items, index : Int) -> String {
  let symbols = [
    "M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I",
  ]
  let values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
  let buf = StringBuilder::new()
  let mut n = @internal.clamp_non_negative(index) + 1
  for i in 0..<values.length() {
    while n >= values[i] {
      buf.write_string(symbols[i])
      n = n - values[i]
    }
  }
  buf.write_string(".")
  buf.to_string()
}

///|
fn list_tree() -> @tree.Tree {
  @tree.new()
  .enumerator_func(fn(children, index) {
    bullet(items_from_trees(children), index)
  })
  .indenter_func(fn(_children, _index) { " " })
  .item_indent(" ")
}

///|
pub fn new(items? : Array[Item] = []) -> List {
  { tree: list_tree() }.items(items)
}

///|
pub fn List::hidden(self : List) -> Bool {
  self.tree.hidden()
}

///|
pub fn List::hide(self : List, hidden : Bool) -> List {
  { tree: self.tree.hide(hidden) }
}

///|
pub fn List::set_hidden(self : List, hidden : Bool) -> List {
  self.hide(hidden)
}

///|
pub fn List::offset(self : List, start : Int, end : Int) -> List {
  { tree: self.tree.offset(start, end) }
}

///|
pub fn List::value(self : List) -> String {
  self.tree.value()
}

///|
pub fn List::item(self : List, item : Item) -> List {
  match item {
    Text(value) => self.item_text(value)
    Nested(list) => self.item_list(list)
  }
}

///|
pub fn List::item_text(self : List, value : String) -> List {
  { tree: self.tree.child_leaf(value) }
}

///|
pub fn List::item_list(self : List, list : List) -> List {
  { tree: self.tree.child(list.tree) }
}

///|
pub fn List::items(self : List, items : Array[Item]) -> List {
  let mut list = self
  for item in items {
    list = list.item(item)
  }
  list
}

///|
pub fn List::enumerator(
  self : List,
  enumerator : (Items, Int) -> String,
) -> List {
  {
    tree: self.tree.enumerator_func(fn(children, index) {
      enumerator(items_from_trees(children), index)
    }),
  }
}

///|
pub fn List::enumerator_func(
  self : List,
  enumerator : (Items, Int) -> String,
) -> List {
  self.enumerator(enumerator)
}

///|
pub fn List::indenter(self : List, indenter : (Items, Int) -> String) -> List {
  {
    tree: self.tree.indenter_func(fn(children, index) {
      indenter(items_from_trees(children), index)
    }),
  }
}

///|
pub fn List::indenter_func(
  self : List,
  indenter : (Items, Int) -> String,
) -> List {
  self.indenter(indenter)
}

///|
pub fn List::item_indent(self : List, item_indent : String) -> List {
  { tree: self.tree.item_indent(item_indent) }
}

///|
pub fn List::enumerator_style(self : List, style : @pippa.Style) -> List {
  { tree: self.tree.enumerator_style(style) }
}

///|
pub fn List::enumerator_style_func(
  self : List,
  style_func : (Items, Int) -> @pippa.Style,
) -> List {
  {
    tree: self.tree.enumerator_style_func(fn(children, index) {
      style_func(items_from_trees(children), index)
    }),
  }
}

///|
pub fn List::indenter_style(self : List, style : @pippa.Style) -> List {
  { tree: self.tree.indenter_style(style) }
}

///|
pub fn List::indenter_style_func(
  self : List,
  style_func : (Items, Int) -> @pippa.Style,
) -> List {
  {
    tree: self.tree.indenter_style_func(fn(children, index) {
      style_func(items_from_trees(children), index)
    }),
  }
}

///|
pub fn List::item_style(self : List, style : @pippa.Style) -> List {
  { tree: self.tree.item_style(style) }
}

///|
pub fn List::item_style_func(
  self : List,
  style_func : (Items, Int) -> @pippa.Style,
) -> List {
  {
    tree: self.tree.item_style_func(fn(children, index) {
      style_func(items_from_trees(children), index)
    }),
  }
}

///|
pub fn List::width(self : List, width : Int) -> List {
  { tree: self.tree.width(width) }
}

///|
pub fn List::render(self : List) -> String {
  self.tree.render()
}

///|
pub fn List::to_string(self : List) -> String {
  self.render()
}
