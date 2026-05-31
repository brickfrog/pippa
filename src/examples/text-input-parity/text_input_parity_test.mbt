///|
test "text input parity scripts basic and password editing" {
  let model = text_input_parity_run_script([
    @pippa.Key(@pippa.Text("Ada")),
    @pippa.Key(@pippa.Special("tab")),
    @pippa.Key(@pippa.Text("moon")),
  ])

  assert_eq(model.name.value, "Ada")
  assert_eq(model.password.value, "moon")
  assert_true(model.password.validation is @component.Valid)

  let view = @pippa.strip_ansi(text_input_parity_view(model))
  assert_true(view.contains("Name: Ada"))
  assert_true(view.contains("Password: ****"))
  assert_true(view.contains("password ok"))
}

///|
test "text input parity keeps invalid password state visible" {
  let model = text_input_parity_run_script([
    @pippa.Key(@pippa.Special("tab")),
    @pippa.Key(@pippa.Text("go")),
  ])

  assert_eq(model.password.value, "go")
  assert_true(
    model.password.validation is @component.Invalid("at least 4 chars"),
  )
  assert_true(
    @pippa.strip_ansi(text_input_parity_view(model)).contains(
      "at least 4 chars",
    ),
  )
}
