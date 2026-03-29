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
test "help_view short" {
  let model = HelpModel::{
    bindings: [quit_binding(), up_binding(), down_binding()],
    show_full: false,
  }
  let out = help_view(model)
  let expected = "q/ctrl+c \{dim()}quit\{reset()}\{dim()} • \{reset()}↑/k \{dim()}up\{reset()}\{dim()} • \{reset()}↓/j \{dim()}down\{reset()}"
  assert_eq(out, expected)
}

///|
test "help_view full" {
  let model = HelpModel::{
    bindings: [quit_binding(), help_binding()],
    show_full: true,
  }
  let out = help_view(model)
  let expected = "q, ctrl+c\{dim()} quit\{reset()}\n?, h\{dim()} help\{reset()}"
  assert_eq(out, expected)
}
