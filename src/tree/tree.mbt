///|
/// A static tree renderer inspired by lipgloss/tree.

///|
pub(all) struct Enumerator {
  child_connector : String
  last_child_connector : String
  vertical_pipe : String
  indent : String
  item_indent : String
} derive(Debug, Eq)

///|
priv struct TreeRenderer {
  enumerator : (Array[Tree], Int) -> String
  indenter : (Array[Tree], Int) -> String
  enumerator_style : (Array[Tree], Int) -> @pippa.Style
  indenter_style : (Array[Tree], Int) -> @pippa.Style
  item_style : (Array[Tree], Int) -> @pippa.Style
  root_style : @pippa.Style
  item_indent : String
  width : Int
}

///|
struct Tree {
  value : String
  hidden : Bool
  children : Array[Tree]
  offset_start : Int
  offset_end : Int
  leaf : Bool
  renderer : TreeRenderer?
}

///|
pub fn default_enumerator() -> Enumerator {
  {
    child_connector: "├──",
    last_child_connector: "└──",
    vertical_pipe: "│  ",
    indent: "   ",
    item_indent: " ",
  }
}

///|
pub fn rounded_enumerator() -> Enumerator {
  { ..default_enumerator(), last_child_connector: "╰──" }
}

///|
fn default_connector(children : Array[Tree], index : Int) -> String {
  if children.length() - 1 == index {
    "└──"
  } else {
    "├──"
  }
}

///|
fn default_indent(children : Array[Tree], index : Int) -> String {
  if children.length() - 1 == index {
    "   "
  } else {
    "│  "
  }
}

///|
fn no_style(_children : Array[Tree], _index : Int) -> @pippa.Style {
  @pippa.style()
}

///|
fn default_renderer() -> TreeRenderer {
  {
    enumerator: default_connector,
    indenter: default_indent,
    enumerator_style: no_style,
    indenter_style: no_style,
    item_style: no_style,
    root_style: @pippa.style(),
    item_indent: " ",
    width: 0,
  }
}

///|
fn renderer_for(tree : Tree) -> TreeRenderer {
  match tree.renderer {
    Some(renderer) => renderer
    None => default_renderer()
  }
}

///|
fn with_renderer(tree : Tree, update : (TreeRenderer) -> TreeRenderer) -> Tree {
  { ..tree, renderer: Some(update(renderer_for(tree))) }
}

///|
pub fn new() -> Tree {
  {
    value: "",
    hidden: false,
    children: [],
    offset_start: 0,
    offset_end: 0,
    leaf: false,
    renderer: None,
  }
}

///|
pub fn root(value : String) -> Tree {
  new().root(value)
}

///|
pub fn leaf(value : String, hidden? : Bool = false) -> Tree {
  {
    value,
    hidden,
    children: [],
    offset_start: 0,
    offset_end: 0,
    leaf: true,
    renderer: None,
  }
}

///|
pub fn Tree::root(self : Tree, value : String) -> Tree {
  { ..self, value, leaf: false }
}

///|
pub fn Tree::value(self : Tree) -> String {
  self.value
}

///|
pub fn Tree::set_value(self : Tree, value : String) -> Tree {
  self.root(value)
}

///|
pub fn Tree::hidden(self : Tree) -> Bool {
  self.hidden
}

///|
pub fn Tree::hide(self : Tree, hidden : Bool) -> Tree {
  { ..self, hidden, }
}

///|
pub fn Tree::set_hidden(self : Tree, hidden : Bool) -> Tree {
  self.hide(hidden)
}

///|
pub fn Tree::children(self : Tree) -> Array[Tree] {
  let safe_start = self.offset_start.max(0).min(self.children.length())
  let safe_end = self.offset_end.max(0).min(self.children.length() - safe_start)
  let stop = self.children.length() - safe_end
  let out : Array[Tree] = []
  for i in safe_start..<stop {
    out.push(self.children[i])
  }
  out
}

///|
pub fn Tree::offset(self : Tree, start : Int, end : Int) -> Tree {
  let (start, end) = if start > end { (end, start) } else { (start, end) }
  let start = start.max(0)
  let end = if end < 0 || end > self.children.length() {
    self.children.length()
  } else {
    end
  }
  { ..self, offset_start: start, offset_end: end }
}

///|
fn append_child(children : Array[Tree], child : Tree) -> Array[Tree] {
  let next = children.copy()
  next.push(child)
  next
}

///|
fn append_children(
  children : Array[Tree],
  new_children : Array[Tree],
) -> Array[Tree] {
  let next = children.copy()
  for child in new_children {
    next.push(child)
  }
  next
}

///|
fn replace_last(children : Array[Tree], child : Tree) -> Array[Tree] {
  let next = children.copy()
  next[next.length() - 1] = child
  next
}

///|
fn without_last(children : Array[Tree]) -> Array[Tree] {
  let next : Array[Tree] = []
  for i in 0..<(children.length() - 1) {
    next.push(children[i])
  }
  next
}

///|
fn parent_rootless_child(children : Array[Tree], child : Tree) -> Array[Tree] {
  if child.value != "" || children.is_empty() {
    return append_child(children, child)
  }
  let last = children[children.length() - 1]
  if last.leaf {
    append_child(without_last(children), {
      ..child,
      value: last.value,
      leaf: false,
    })
  } else {
    let parent = {
      ..last,
      children: append_children(last.children, child.children),
    }
    replace_last(children, parent)
  }
}

///|
pub fn Tree::child(self : Tree, child : Tree) -> Tree {
  { ..self, children: parent_rootless_child(self.children, child), leaf: false }
}

///|
pub fn Tree::child_leaf(
  self : Tree,
  value : String,
  hidden? : Bool = false,
) -> Tree {
  self.child(leaf(value, hidden~))
}

///|
pub fn Tree::append_children(self : Tree, children : Array[Tree]) -> Tree {
  let mut tree = self
  for child in children {
    tree = tree.child(child)
  }
  tree
}

///|
pub fn Tree::enumerator(self : Tree, enumerator : Enumerator) -> Tree {
  with_renderer(self, fn(renderer) {
    {
      ..renderer,
      enumerator: fn(children, index) {
        if children.length() - 1 == index {
          enumerator.last_child_connector
        } else {
          enumerator.child_connector
        }
      },
      indenter: fn(children, index) {
        if children.length() - 1 == index {
          enumerator.indent
        } else {
          enumerator.vertical_pipe
        }
      },
      item_indent: enumerator.item_indent,
    }
  })
}

///|
pub fn Tree::enumerator_func(
  self : Tree,
  enumerator : (Array[Tree], Int) -> String,
) -> Tree {
  with_renderer(self, fn(renderer) { { ..renderer, enumerator, } })
}

///|
pub fn Tree::indenter_func(
  self : Tree,
  indenter : (Array[Tree], Int) -> String,
) -> Tree {
  with_renderer(self, fn(renderer) { { ..renderer, indenter, } })
}

///|
pub fn Tree::item_indent(self : Tree, item_indent : String) -> Tree {
  with_renderer(self, fn(renderer) { { ..renderer, item_indent, } })
}

///|
pub fn Tree::enumerator_style(self : Tree, style : @pippa.Style) -> Tree {
  with_renderer(self, fn(renderer) {
    { ..renderer, enumerator_style: fn(_children, _index) { style } }
  })
}

///|
pub fn Tree::enumerator_style_func(
  self : Tree,
  style_func : (Array[Tree], Int) -> @pippa.Style,
) -> Tree {
  with_renderer(self, fn(renderer) {
    { ..renderer, enumerator_style: style_func }
  })
}

///|
pub fn Tree::indenter_style(self : Tree, style : @pippa.Style) -> Tree {
  with_renderer(self, fn(renderer) {
    { ..renderer, indenter_style: fn(_children, _index) { style } }
  })
}

///|
pub fn Tree::indenter_style_func(
  self : Tree,
  style_func : (Array[Tree], Int) -> @pippa.Style,
) -> Tree {
  with_renderer(self, fn(renderer) {
    { ..renderer, indenter_style: style_func }
  })
}

///|
pub fn Tree::item_style(self : Tree, style : @pippa.Style) -> Tree {
  with_renderer(self, fn(renderer) {
    { ..renderer, item_style: fn(_children, _index) { style } }
  })
}

///|
pub fn Tree::item_style_func(
  self : Tree,
  style_func : (Array[Tree], Int) -> @pippa.Style,
) -> Tree {
  with_renderer(self, fn(renderer) { { ..renderer, item_style: style_func } })
}

///|
pub fn Tree::root_style(self : Tree, style : @pippa.Style) -> Tree {
  with_renderer(self, fn(renderer) { { ..renderer, root_style: style } })
}

///|
pub fn Tree::width(self : Tree, width : Int) -> Tree {
  with_renderer(self, fn(renderer) {
    { ..renderer, width: @internal.clamp_non_negative(width) }
  })
}

///|
fn visible_children(children : Array[Tree]) -> Array[Tree] {
  let out : Array[Tree] = []
  for child in children {
    if !child.hidden {
      out.push(child)
    }
  }
  out
}

///|
fn max_connector_width(renderer : TreeRenderer, children : Array[Tree]) -> Int {
  let mut max_width = 0
  for i in 0..<children.length() {
    let connector = (renderer.enumerator_style)(children, i).render(
      (renderer.enumerator)(children, i),
    )
    max_width = max_width.max(@pippa.visible_width(connector))
  }
  max_width
}

///|
fn pad_left_to_width(content : String, width : Int) -> String {
  let pad = width - @pippa.visible_width(content)
  if pad > 0 {
    String::make(pad, ' ') + content
  } else {
    content
  }
}

///|
fn pad_line_to_tree_width(
  line : String,
  width : Int,
  style : @pippa.Style,
) -> String {
  let pad = width - @pippa.visible_width(line)
  if pad > 0 {
    line + style.render(String::make(pad, ' '))
  } else {
    line
  }
}

///|
fn pad_block_to_tree_width(
  block : String,
  width : Int,
  style : @pippa.Style,
) -> String {
  if width <= 0 {
    return block
  }
  let rows : Array[String] = []
  for line in @pippa.split_lines(block) {
    rows.push(pad_line_to_tree_width(line, width, style))
  }
  @internal.join_lines(rows)
}

///|
fn render_item_line(
  parent_prefix : String,
  connector : String,
  item_indent : String,
  item : String,
) -> String {
  let item_lines = @pippa.split_lines(item)
  if item_lines.length() <= 1 {
    return parent_prefix + connector + item_indent + item
  }
  let rows : Array[String] = []
  let first_prefix = parent_prefix + connector + item_indent
  let continuation_width = @pippa.visible_width(connector + item_indent)
  let continuation = parent_prefix + String::make(continuation_width, ' ')
  for i, line in item_lines {
    if i == 0 {
      rows.push(first_prefix + line)
    } else {
      rows.push(continuation + line)
    }
  }
  @internal.join_lines(rows)
}

///|
fn render_tree(
  node : Tree,
  renderer : TreeRenderer,
  root : Bool,
  prefix : String,
) -> String {
  if node.hidden {
    return ""
  }
  let rows : Array[String] = []
  if root && node.value != "" {
    rows.push(
      pad_block_to_tree_width(
        renderer.root_style.render(node.value),
        renderer.width,
        renderer.root_style,
      ),
    )
  }
  let children = visible_children(node.children())
  let max_width = max_connector_width(renderer, children)
  for i in 0..<children.length() {
    let child = children[i]
    let enum_style = (renderer.enumerator_style)(children, i)
    let indent_style = (renderer.indenter_style)(children, i)
    let item_style = (renderer.item_style)(children, i)
    let connector = pad_left_to_width(
      enum_style.render((renderer.enumerator)(children, i)),
      max_width,
    )
    let item = item_style.render(child.value)
    rows.push(
      pad_block_to_tree_width(
        render_item_line(prefix, connector, renderer.item_indent, item),
        renderer.width,
        item_style,
      ),
    )
    let child_children = visible_children(child.children())
    if !child_children.is_empty() {
      let child_renderer = match child.renderer {
        Some(custom) => custom
        None => renderer
      }
      let indent = indent_style.render((renderer.indenter)(children, i)) +
        renderer.item_indent
      let rendered = render_tree(child, child_renderer, false, prefix + indent)
      if rendered != "" {
        rows.push(rendered)
      }
    }
  }
  @internal.join_lines(rows)
}

///|
pub fn Tree::render(self : Tree) -> String {
  render_tree(self, renderer_for(self), true, "")
}

///|
pub fn Tree::to_string(self : Tree) -> String {
  self.render()
}
