///|
/// A named key binding with activation keys, display help, and enabled state.
pub(all) struct Binding {
  keys : Array[String]
  help_key : String
  help : String
  enabled : Bool
} derive(Debug, Eq)

///|
/// A named group of bindings, rendered as a section in full help.
pub(all) struct KeyMapGroup {
  title : String
  bindings : Array[Binding]
} derive(Debug, Eq)

///|
/// Ordered groups of key bindings for matching and help rendering.
pub(all) struct KeyMap {
  groups : Array[KeyMapGroup]
} derive(Debug, Eq)

///|
/// A help model for rendering keybinding hints at the bottom of a view.
pub(all) struct HelpModel {
  keymap : KeyMap
  show_full : Bool
  width : Int
} derive(Debug, Eq)

///|
fn key_help_label(key : String) -> String {
  match key {
    "up" => "↑"
    "down" => "↓"
    "left" => "←"
    "right" => "→"
    "escape" => "esc"
    "backspace" => "⌫"
    "delete" => "⌦"
    _ => key
  }
}

///|
fn key_help_label_from_keys(keys : Array[String]) -> String {
  let parts : Array[String] = []
  for key in keys {
    parts.push(key_help_label(key))
  }
  parts.join("/")
}

///|
pub fn binding(
  keys? : Array[String] = [],
  help_key? : String = "",
  help? : String = "",
) -> Binding {
  {
    keys,
    help_key: if help_key == "" {
      key_help_label_from_keys(keys)
    } else {
      help_key
    },
    help,
    enabled: true,
  }
}

///|
pub fn set_keys(binding : Binding, keys : Array[String]) -> Binding {
  { ..binding, keys, }
}

///|
pub fn set_help(binding : Binding, help_key : String, help : String) -> Binding {
  { ..binding, help_key, help }
}

///|
pub fn set_disabled(binding : Binding, disabled : Bool) -> Binding {
  { ..binding, enabled: !disabled }
}

///|
pub fn unbind(binding : Binding) -> Binding {
  { ..binding, keys: [], enabled: false }
}

///|
pub fn keymap(bindings : Array[Binding]) -> KeyMap {
  { groups: [{ title: "", bindings }] }
}

///|
pub fn keymap_group(title : String, bindings : Array[Binding]) -> KeyMapGroup {
  { title, bindings }
}

///|
pub fn keymap_from_groups(groups : Array[KeyMapGroup]) -> KeyMap {
  { groups, }
}

///|
pub fn keymap_bindings(keymap : KeyMap) -> Array[Binding] {
  let bindings : Array[Binding] = []
  for group in keymap.groups {
    for binding in group.bindings {
      bindings.push(binding)
    }
  }
  bindings
}

///|
/// Check if a KeyMsg matches an enabled Binding.
pub fn matches(binding : Binding, key : KeyMsg) -> Bool {
  if !binding.enabled {
    return false
  }
  let key_str = match key {
    Char(c) => c.to_string()
    Text(s) => s
    Special(s) => s
    Modified(mod, k) => mod + "+" + k
  }
  binding.keys.contains(key_str)
}

///|
pub fn quit_binding() -> Binding {
  binding(keys=["q", "ctrl+c"], help_key="q", help="quit")
}

///|
pub fn up_binding() -> Binding {
  binding(keys=["up", "k"], help_key="↑/k", help="up")
}

///|
pub fn down_binding() -> Binding {
  binding(keys=["down", "j"], help_key="↓/j", help="down")
}

///|
pub fn left_binding() -> Binding {
  binding(keys=["left", "h"], help_key="←/h", help="left")
}

///|
pub fn right_binding() -> Binding {
  binding(keys=["right", "l"], help_key="→/l", help="right")
}

///|
pub fn enter_binding() -> Binding {
  binding(keys=["enter"], help_key="enter", help="enter")
}

///|
pub fn escape_binding() -> Binding {
  binding(keys=["escape"], help_key="esc", help="escape")
}

///|
pub fn help_binding() -> Binding {
  binding(keys=["?", "h"], help_key="?", help="help")
}

///|
pub fn toggle_help(model : HelpModel) -> HelpModel {
  { ..model, show_full: !model.show_full }
}

///|
fn help_visible(binding : Binding) -> Bool {
  binding.enabled && (binding.help_key != "" || binding.help != "")
}

///|
fn help_truncate(text : String, width : Int) -> String {
  if width <= 0 || @internal.display_width(text) <= width {
    return text
  }
  let ellipsis = "…"
  let ellipsis_width = @internal.display_width(ellipsis)
  if width <= ellipsis_width {
    return @internal.truncate_width(ellipsis, width)
  }
  @internal.truncate_width(text, width - ellipsis_width) + ellipsis
}

///|
fn help_short_binding(binding : Binding) -> String {
  if binding.help == "" {
    binding.help_key
  } else if binding.help_key == "" {
    binding.help
  } else {
    binding.help_key + " " + binding.help
  }
}

///|
fn help_view_short(model : HelpModel) -> String {
  let parts : Array[String] = []
  for binding in keymap_bindings(model.keymap) {
    if help_visible(binding) {
      parts.push(help_short_binding(binding))
    }
  }
  help_truncate(parts.join(" • "), model.width)
}

///|
fn help_group_key_width(bindings : Array[Binding]) -> Int {
  let mut width = 0
  for binding in bindings {
    if help_visible(binding) {
      width = width.max(@internal.display_width(binding.help_key))
    }
  }
  width
}

///|
fn help_view_group(group : KeyMapGroup, width : Int) -> String {
  let visible : Array[Binding] = []
  for binding in group.bindings {
    if help_visible(binding) {
      visible.push(binding)
    }
  }
  if visible.is_empty() {
    return ""
  }
  let lines : Array[String] = []
  if group.title != "" {
    lines.push(help_truncate(group.title, width))
  }
  let indent = if group.title == "" { "" } else { "  " }
  let key_width = help_group_key_width(visible)
  for binding in visible {
    let line = indent +
      @internal.pad_right_width(binding.help_key, key_width) +
      "  " +
      binding.help
    lines.push(help_truncate(line, width))
  }
  lines.join("\n")
}

///|
fn help_view_full(model : HelpModel) -> String {
  let sections : Array[String] = []
  for group in model.keymap.groups {
    let section = help_view_group(group, model.width)
    if section != "" {
      sections.push(section)
    }
  }
  sections.join("\n\n")
}

///|
pub fn help_view(model : HelpModel) -> String {
  if model.show_full {
    help_view_full(model)
  } else {
    help_view_short(model)
  }
}
