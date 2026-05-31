///|
/// Bubble Tea text input parity fixture: one plain field plus one validated
/// password field, driven through a tiny app-level update/sub/view surface.

///|
pub(all) struct Model {
  name : @component.TextInputModel
  password : @component.TextInputModel
  active : Int
  quitting : Bool
} derive(Debug)

///|
pub(all) enum Msg {
  Edit(@component.TextInputMsg)
  SwitchField
  Quit
} derive(Debug)

///|
let text_input_parity_name : @component.Component[
  @component.TextInputModel,
  @component.TextInputMsg,
] = @component.text_input(placeholder="name", prompt="", width=12)

///|
let text_input_parity_password : @component.Component[
  @component.TextInputModel,
  @component.TextInputMsg,
] = @component.text_input(
  placeholder="password",
  prompt="",
  width=12,
  echo_mode=@component.Password('*'),
  validator=fn(value) {
    if value.length() >= 4 {
      Ok(())
    } else {
      Err("at least 4 chars")
    }
  },
)

///|
fn text_input_parity_focus(model : Model, active : Int) -> Model {
  let name_msg = if active == 0 {
    @component.TextInputMsg::Focus
  } else {
    @component.TextInputMsg::Blur
  }
  let password_msg = if active == 1 {
    @component.TextInputMsg::Focus
  } else {
    @component.TextInputMsg::Blur
  }
  {
    ..model,
    active,
    name: (text_input_parity_name.update)(model.name, name_msg).model,
    password: (text_input_parity_password.update)(model.password, password_msg).model,
  }
}

///|
pub fn text_input_parity_init() -> @pippa.UpdateResult[Model, Msg] {
  let name = (text_input_parity_name.init)().model
  let password = (text_input_parity_password.init)().model
  let model = text_input_parity_focus(
    { name, password, active: 0, quitting: false },
    0,
  )
  @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
}

///|
pub fn text_input_parity_update(
  model : Model,
  msg : Msg,
) -> @pippa.UpdateResult[Model, Msg] {
  if model.quitting {
    return @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
  }
  match msg {
    Edit(input_msg) =>
      if model.active == 0 {
        @pippa.UpdateResult::new(
          model={
            ..model,
            name: (text_input_parity_name.update)(model.name, input_msg).model,
          },
          cmd=@pippa.Cmd::none(),
        )
      } else {
        @pippa.UpdateResult::new(
          model={
            ..model,
            password: (text_input_parity_password.update)(
              model.password,
              input_msg,
            ).model,
          },
          cmd=@pippa.Cmd::none(),
        )
      }
    SwitchField =>
      @pippa.UpdateResult::new(
        model=text_input_parity_focus(model, (model.active + 1) % 2),
        cmd=@pippa.Cmd::none(),
      )
    Quit =>
      @pippa.UpdateResult::new(
        model={ ..model, quitting: true },
        cmd=@pippa.Cmd::none(),
      )
  }
}

///|
pub fn text_input_parity_sub(event : @pippa.InputEvent) -> Msg? {
  match event {
    @pippa.Key(@pippa.Special("tab")) => Some(SwitchField)
    @pippa.Key(@pippa.Special("backspace")) =>
      Some(Edit(@component.TextInputMsg::DeleteBefore))
    @pippa.Key(@pippa.Special("left")) =>
      Some(Edit(@component.TextInputMsg::MoveCursorLeft))
    @pippa.Key(@pippa.Special("right")) =>
      Some(Edit(@component.TextInputMsg::MoveCursorRight))
    @pippa.Key(@pippa.Char('q')) | @pippa.Key(@pippa.Modified("ctrl", "c")) =>
      Some(Quit)
    @pippa.Key(@pippa.Char(ch)) =>
      Some(Edit(@component.TextInputMsg::InsertChar(ch)))
    @pippa.Key(@pippa.Text(text)) =>
      Some(Edit(@component.TextInputMsg::InsertText(text)))
    _ => None
  }
}

///|
fn text_input_parity_password_status(model : Model) -> String {
  match model.password.validation {
    @component.Valid => "password ok"
    @component.Invalid(message) => message
  }
}

///|
pub fn text_input_parity_view(model : Model) -> String {
  if model.quitting {
    return "Goodbye\n"
  }
  "Text Input Parity\n" +
  "Name: \{(text_input_parity_name.view)(model.name)}\n" +
  "Password: \{(text_input_parity_password.view)(model.password)}\n" +
  text_input_parity_password_status(model) +
  "\n"
}

///|
pub fn text_input_parity_run_script(events : Array[@pippa.InputEvent]) -> Model {
  let mut model = text_input_parity_init().model
  for event in events {
    match text_input_parity_sub(event) {
      Some(msg) => model = text_input_parity_update(model, msg).model
      None => ()
    }
  }
  model
}

///|
fn main {
  let program = @pippa.Program::new(
    init=text_input_parity_init,
    update=text_input_parity_update,
    view=text_input_parity_view,
    sub=text_input_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  ignore(@pippa.Program::run(program))
}
