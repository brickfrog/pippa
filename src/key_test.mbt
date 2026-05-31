///|
test "Binding::matches" {
  let q = quit_binding()
  assert_eq(matches(q, Char('q')), true)
  assert_eq(matches(q, Modified("ctrl", "c")), true)
  assert_eq(matches(q, Char('x')), false)

  let u = up_binding()
  assert_eq(matches(u, Special("up")), true)
  assert_eq(matches(u, Char('k')), true)
  assert_eq(matches(u, Char('j')), false)
}

///|
test "Binding disabled and unbind stay out of matches and help" {
  let disabled = set_disabled(
    binding(keys=["x"], help_key="x", help="disabled"),
    true,
  )
  assert_eq(matches(disabled, Char('x')), false)
  let unbound = unbind(quit_binding())
  assert_true(unbound.keys.is_empty())
  assert_eq(unbound.enabled, false)
  assert_eq(matches(unbound, Char('q')), false)
  let model = HelpModel::{
    keymap: keymap([up_binding(), disabled, unbound]),
    show_full: false,
    width: 0,
  }
  assert_eq(help_view(model), "↑/k up")
}

///|
test "Binding help label is independent from activation keys" {
  let b = binding(keys=["ctrl+n", "down"], help_key="n", help="next")
  assert_eq(matches(b, Modified("ctrl", "n")), true)
  assert_eq(matches(b, Special("down")), true)
  let model = HelpModel::{ keymap: keymap([b]), show_full: false, width: 0 }
  assert_eq(help_view(model), "n next")
}

///|
test "Binding builder-style setters update keys help and enabled state" {
  let b = binding()
  let configured = set_disabled(
    set_help(set_keys(b, ["g", "enter"]), "g", "go"),
    false,
  )
  assert_eq(configured.keys, ["g", "enter"])
  assert_eq(configured.help_key, "g")
  assert_eq(configured.help, "go")
  assert_eq(configured.enabled, true)
  assert_eq(matches(configured, Char('g')), true)
}

///|
test "help_view short renders enabled bindings on one width-aware line" {
  let model = HelpModel::{
    keymap: keymap([up_binding(), down_binding(), quit_binding()]),
    show_full: false,
    width: 0,
  }
  let out = help_view(model)
  let expected = "↑/k up • ↓/j down • q quit"
  assert_eq(out, expected)
}

///|
test "help_view full renders grouped key and description columns" {
  let model = HelpModel::{
    keymap: keymap_from_groups([
      keymap_group("Movement", [up_binding(), down_binding()]),
      keymap_group("Global", [quit_binding(), help_binding()]),
    ]),
    show_full: true,
    width: 0,
  }
  let out = help_view(model)
  let expected = "Movement\n  ↑/k  up\n  ↓/j  down\n\nGlobal\n  q  quit\n  ?  help"
  assert_eq(out, expected)
}

///|
test "help_view can toggle between short and full" {
  let short = HelpModel::{
    keymap: keymap([quit_binding()]),
    show_full: false,
    width: 0,
  }
  let full = toggle_help(short)
  assert_eq(help_view(short), "q quit")
  assert_eq(help_view(full), "q  quit")
  assert_eq(toggle_help(full), short)
}

///|
test "help_view truncates wide and ANSI content without splitting clusters" {
  let accented = String::from_array(['e', '\u{0301}'])
  let b = binding(
    keys=["wide"],
    help_key="界",
    help="\{dim()}\{accented} trail\{reset()}",
  )
  let model = HelpModel::{ keymap: keymap([b]), show_full: false, width: 5 }
  let out = help_view(model)
  assert_eq(@internal.display_width(out), 5)
  assert_eq(out, "界 \{dim()}\{accented}\{reset()}…")
}
