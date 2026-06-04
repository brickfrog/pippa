///|
struct Account {
  name : String
  password : String
  color : String
  accepted : Bool
} derive(Eq, Debug)

///|
fn name_id() -> FieldId {
  FieldId("name")
}

///|
fn password_id() -> FieldId {
  FieldId("password")
}

///|
fn confirm_password_id() -> FieldId {
  FieldId("confirm_password")
}

///|
fn color_id() -> FieldId {
  FieldId("color")
}

///|
fn accepted_id() -> FieldId {
  FieldId("accepted")
}

///|
fn account_decoder(
  values : FormValues,
) -> Result[Account, Array[ValidationError]] {
  let name = match values.required_text(name_id()) {
    Ok(value) => value
    Err(errors) => return Err(errors)
  }
  let password = match values.required_text(password_id()) {
    Ok(value) => value
    Err(errors) => return Err(errors)
  }
  let color = match values.one(color_id()) {
    Some(value) => value
    None =>
      return Err([
        ValidationError::{
          field: Some(color_id()),
          message: "choose a color",
          severity: Error,
        },
      ])
  }
  Ok({ name, password, color, accepted: values.bool_or(accepted_id(), false) })
}

///|
fn account_form() -> Form[Account] {
  Form::new(
    fields=[
      Field::text(id=name_id(), label="Name", help="Shown in your profile", validators=[
        Validators::required(),
      ]),
      Field::password(id=password_id(), label="Password", validators=[
        Validators::required(),
      ]),
      Field::password(id=confirm_password_id(), label="Confirm password", validators=[
        Validators::required(),
        Validators::matches(password_id(), "passwords differ"),
      ]),
      Field::select(id=color_id(), label="Favorite color", options=[
        "red", "blue",
      ]),
      Field::confirm(id=accepted_id(), label="Accept terms"),
    ],
    decode=account_decoder,
  )
}

///|
fn has_error(
  errors : Array[ValidationError],
  id : FieldId,
  message : String,
) -> Bool {
  let mut found = false
  for error in errors {
    if error.field == Some(id) && error.message == message {
      found = true
    }
  }
  found
}

///|
test "form values expose typed accessors" {
  let values = FormValues::new()
    .set(name_id(), Text("Ada"))
    .set(color_id(), One("blue"))
    .set(accepted_id(), Bool(true))
  @test.assert_eq(values.get(name_id()), Text("Ada"))
  @test.assert_eq(values.required_text(name_id()), Ok("Ada"))
  @test.assert_eq(values.one(color_id()), Some("blue"))
  @test.assert_eq(values.bool_or(accepted_id(), false), true)
  @test.assert_eq(values.bool_or(FieldId("missing"), true), true)
  @test.assert_eq(values.get(FieldId("missing")), Empty)
}

///|
test "form validation reports required empty and matches mismatch" {
  let form = account_form()
  let (with_password, _, _) = form.update(
    Field(password_id(), TextInput(@component.InsertText("secret"))),
  )
  let (with_mismatch, _, _) = with_password.update(
    Field(confirm_password_id(), TextInput(@component.InsertText("different"))),
  )
  let (blocked, cmd, event) = with_mismatch.update(Submit)
  assert_true(cmd.is_none())
  assert_true(event is None)
  match blocked.status {
    Blocked(errors) => {
      assert_true(has_error(errors, name_id(), "Required"))
      assert_true(has_error(errors, confirm_password_id(), "passwords differ"))
    }
    _ => fail("expected blocked form")
  }
}

///|
test "form focus skips hidden and disabled fields" {
  let hidden = Field::text(id=FieldId("hidden"), label="Hidden", visible=fn(
    _values,
  ) {
    false
  })
  let disabled = Field::text(
    id=FieldId("disabled"),
    label="Disabled",
    disabled=true,
  )
  let form : Form[Unit] = Form::new(
    fields=[
      Field::text(id=name_id(), label="Name"),
      hidden,
      disabled,
      Field::confirm(id=accepted_id(), label="Accept"),
    ],
    decode=fn(_values) { Ok(()) },
  )
  @test.assert_eq(form.focused_id(), Some(name_id()))
  let (next, _, _) = form.update(FocusNext)
  @test.assert_eq(next.focused_id(), Some(accepted_id()))
  let (prev, _, _) = next.update(FocusPrev)
  @test.assert_eq(prev.focused_id(), Some(name_id()))
  let (unchanged, _, _) = prev.update(Focus(FieldId("hidden")))
  @test.assert_eq(unchanged.focused_id(), Some(name_id()))
}

///|
test "field from_spec syncs embedded text model disabled and focused state" {
  let text = Field::text(id=name_id(), label="Name")
  let text_spec = text.to_spec()
  let text_kind = match text_spec.kind {
    Text(model) => FieldKind::Text({ ..model, disabled: false, focused: true })
    _ => fail("expected text kind")
  }
  let restored_text = Field::from_spec({
    ..text_spec,
    kind: text_kind,
    disabled: true,
  })
  assert_true(restored_text.disabled)
  match restored_text.kind {
    Text(model) => {
      assert_true(model.disabled)
      assert_true(!model.focused)
    }
    _ => fail("expected restored text kind")
  }

  let password = Field::password(id=password_id(), label="Password")
  let password_spec = password.to_spec()
  let password_kind = match password_spec.kind {
    Password(model) =>
      FieldKind::Password({ ..model, disabled: true, focused: true })
    _ => fail("expected password kind")
  }
  let restored_password = Field::from_spec({
    ..password_spec,
    kind: password_kind,
    disabled: false,
  })
  assert_true(!restored_password.disabled)
  match restored_password.kind {
    Password(model) => {
      assert_true(!model.disabled)
      assert_true(!model.focused)
    }
    _ => fail("expected restored password kind")
  }
}

///|
test "form set value empty clears select cursor and selection" {
  let select = Field::select(id=color_id(), label="Favorite color", options=[
    "red", "blue",
  ])
  let spec = select.to_spec()
  let skewed_kind = match spec.kind {
    Select(model) => FieldKind::Select({ ..model, cursor: 99, selected: 1 })
    _ => fail("expected select kind")
  }
  let skewed = Field::from_spec({ ..spec, kind: skewed_kind })
  let form : Form[Unit] = Form::new(fields=[skewed], decode=fn(_values) {
    Ok(())
  })
  let (cleared, _, _) = form.update(Field(color_id(), SetValue(Empty)))
  match cleared.fields[0].kind {
    Select(model) => {
      @test.assert_eq(model.cursor, 0)
      @test.assert_eq(model.selected, -1)
    }
    _ => fail("expected select kind")
  }
}

///|
test "form submit decodes valid values and updates status" {
  let (f1, _, _) = account_form().update(
    Field(name_id(), TextInput(@component.InsertText("Ada"))),
  )
  let (f2, _, _) = f1.update(
    Field(password_id(), TextInput(@component.InsertText("secret"))),
  )
  let (f3, _, _) = f2.update(
    Field(confirm_password_id(), TextInput(@component.InsertText("secret"))),
  )
  let (f4, _, _) = f3.update(
    Field(color_id(), SelectList(@component.CursorDown)),
  )
  let (f5, _, _) = f4.update(Field(color_id(), SelectList(@component.Select)))
  let (f6, _, _) = f5.update(Field(accepted_id(), ToggleConfirm))
  let (submitted, cmd, event) = f6.update(Submit)
  assert_true(cmd.is_none())
  match event {
    Submitted(account) => {
      @test.assert_eq(account.name, "Ada")
      @test.assert_eq(account.password, "secret")
      @test.assert_eq(account.color, "blue")
      @test.assert_eq(account.accepted, true)
    }
    _ => fail("expected submitted event")
  }
  match submitted.status {
    Submitted(account) => @test.assert_eq(account.name, "Ada")
    _ => fail("expected submitted status")
  }
}

///|
test "form submit blocks invalid decoder errors" {
  let (f1, _, _) = account_form().update(
    Field(name_id(), TextInput(@component.InsertText("Ada"))),
  )
  let (f2, _, _) = f1.update(
    Field(password_id(), TextInput(@component.InsertText("secret"))),
  )
  let (f3, _, _) = f2.update(
    Field(confirm_password_id(), TextInput(@component.InsertText("secret"))),
  )
  let (blocked, _, event) = f3.update(Submit)
  assert_true(event is None)
  match blocked.status {
    Blocked(errors) =>
      assert_true(has_error(errors, color_id(), "choose a color"))
    _ => fail("expected blocked decoder error")
  }
}

///|
test "form view renders labels help validation errors and focus styling" {
  let (blocked, _, _) = account_form().update(Submit)
  let ctx = @profile.RenderContext::default().with_background(@profile.Light)
  let view = blocked.view(@theme.default_theme(), ctx)
  let plain = @pippa.strip_ansi(view)
  assert_true(plain.contains("Name"))
  assert_true(plain.contains("Shown in your profile"))
  assert_true(plain.contains("Required"))
  assert_true(view.contains("\u001b[38;2;31;41;55m\u001b[1mName\u001b[0m"))
  assert_true(
    view.contains("\u001b[38;2;107;114;128mShown in your profile\u001b[0m"),
  )
  assert_true(view.contains("\u001b[38;2;185;28;28mRequired\u001b[0m"))
  assert_true(view.contains("\u001b["))
}
