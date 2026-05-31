///|
/// Bubble Tea textarea parity fixture: multiline edits plus soft-wrap snapshots
/// with a prompt and line-number gutter.

///|
pub(all) struct Model {
  editor : @component.TextareaModel
  quitting : Bool
} derive(Debug)

///|
pub(all) enum Msg {
  EditorMsg(@component.TextareaMsg)
  Quit
} derive(Debug)

///|
let textarea_parity_editor : @component.Component[
  @component.TextareaModel,
  @component.TextareaMsg,
] = @component.textarea(
  width=8,
  height=3,
  min_height=1,
  placeholder="notes",
  prompt="> ",
  line_numbers=true,
)

///|
pub fn textarea_parity_init() -> @pippa.UpdateResult[Model, Msg] {
  @pippa.UpdateResult::new(
    model={ editor: (textarea_parity_editor.init)().model, quitting: false },
    cmd=@pippa.Cmd::none(),
  )
}

///|
pub fn textarea_parity_update(
  model : Model,
  msg : Msg,
) -> @pippa.UpdateResult[Model, Msg] {
  match msg {
    EditorMsg(editor_msg) =>
      @pippa.UpdateResult::new(
        model={
          ..model,
          editor: (textarea_parity_editor.update)(model.editor, editor_msg).model,
        },
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
pub fn textarea_parity_sub(event : @pippa.InputEvent) -> Msg? {
  match event {
    @pippa.Key(@pippa.Special("enter")) =>
      Some(EditorMsg(@component.InsertNewline))
    @pippa.Key(@pippa.Special("backspace")) =>
      Some(EditorMsg(@component.DeleteBefore))
    @pippa.Key(@pippa.Special("left")) =>
      Some(EditorMsg(@component.MoveCursorLeft))
    @pippa.Key(@pippa.Special("right")) =>
      Some(EditorMsg(@component.MoveCursorRight))
    @pippa.Key(@pippa.Special("up")) => Some(EditorMsg(@component.MoveCursorUp))
    @pippa.Key(@pippa.Special("down")) =>
      Some(EditorMsg(@component.MoveCursorDown))
    @pippa.Key(@pippa.Char('q')) | @pippa.Key(@pippa.Modified("ctrl", "c")) =>
      Some(Quit)
    @pippa.Key(@pippa.Char(ch)) => Some(EditorMsg(@component.InsertChar(ch)))
    @pippa.Key(@pippa.Text(text)) =>
      Some(EditorMsg(@component.InsertText(text)))
    _ => None
  }
}

///|
pub fn textarea_parity_editor_snapshot(model : Model) -> String {
  (textarea_parity_editor.view)(model.editor)
}

///|
pub fn textarea_parity_view(model : Model) -> String {
  if model.quitting {
    return "Goodbye\n"
  }
  "Textarea Parity\n" + textarea_parity_editor_snapshot(model) + "\n"
}

///|
pub fn textarea_parity_run_script(events : Array[@pippa.InputEvent]) -> Model {
  let mut model = textarea_parity_init().model
  for event in events {
    match textarea_parity_sub(event) {
      Some(msg) => model = textarea_parity_update(model, msg).model
      None => ()
    }
  }
  model
}

///|
fn main {
  let program = @pippa.Program::new(
    init=textarea_parity_init,
    update=textarea_parity_update,
    view=textarea_parity_view,
    sub=textarea_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  ignore(@pippa.Program::run(program))
}
