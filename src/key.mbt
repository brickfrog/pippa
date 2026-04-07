///|
/// A named key binding with one or more key combos that trigger it.
pub(all) struct Binding {
  keys : Array[String]
  help : String
} derive(Debug, Eq)

///|
/// Check if a KeyMsg matches a Binding.
pub fn matches(binding : Binding, key : KeyMsg) -> Bool {
  let key_str = match key {
    Char(c) => c.to_string()
    Special(s) => s
    Modified(mod, k) => mod + "+" + k
  }
  binding.keys.contains(key_str)
}

///|
pub fn quit_binding() -> Binding {
  { keys: ["q", "ctrl+c"], help: "quit" }
}

///|
pub fn up_binding() -> Binding {
  { keys: ["up", "k"], help: "up" }
}

///|
pub fn down_binding() -> Binding {
  { keys: ["down", "j"], help: "down" }
}

///|
pub fn left_binding() -> Binding {
  { keys: ["left", "h"], help: "left" }
}

///|
pub fn right_binding() -> Binding {
  { keys: ["right", "l"], help: "right" }
}

///|
pub fn enter_binding() -> Binding {
  { keys: ["enter"], help: "enter" }
}

///|
pub fn escape_binding() -> Binding {
  { keys: ["escape"], help: "escape" }
}

///|
pub fn help_binding() -> Binding {
  { keys: ["?", "h"], help: "help" }
}

///|
/// A help model for rendering keybinding hints at the bottom of a view.
pub(all) struct HelpModel {
  bindings : Array[Binding]
  show_full : Bool
} derive(Debug, Eq)

///|
pub fn help_view(model : HelpModel) -> String {
  let buf = StringBuilder::new()
  if model.show_full {
    for i, b in model.bindings {
      if i > 0 {
        buf.write_string("\n")
      }
      for j, k in b.keys {
        if j > 0 {
          buf.write_string(", ")
        }
        buf.write_string(k)
      }
      buf.write_string(dim())
      buf.write_string(" ")
      buf.write_string(b.help)
      buf.write_string(reset())
    }
  } else {
    for i, b in model.bindings {
      if i > 0 {
        buf.write_string(dim())
        buf.write_string(" • ")
        buf.write_string(reset())
      }
      for j, k in b.keys {
        if j > 0 {
          buf.write_string("/")
        }
        let fk = match k {
          "up" => "↑"
          "down" => "↓"
          "left" => "←"
          "right" => "→"
          _ => k
        }
        buf.write_string(fk)
      }
      buf.write_string(" ")
      buf.write_string(dim())
      buf.write_string(b.help)
      buf.write_string(reset())
    }
  }
  buf.to_string()
}
