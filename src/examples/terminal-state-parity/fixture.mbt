///|
/// Bubble Tea terminal state parity fixture: request terminal size via Cmd and
/// render stateful terminal requests through the structured View hook.

///|
pub(all) struct Model {
  window_size : @pippa.WindowSize?
  cursor_visible : Bool
  quitting : Bool
} derive(Debug, Eq)

///|
pub(all) enum Msg {
  WindowMeasured(@pippa.WindowSize)
  ToggleCursor
  Quit
} derive(Debug, Eq)

///|
pub fn terminal_state_parity_init() -> @pippa.UpdateResult[Model, Msg] {
  @pippa.UpdateResult::new(
    model={ window_size: None, cursor_visible: false, quitting: false },
    cmd=@pippa.Cmd::request_window_size(fn(size) { WindowMeasured(size) }),
  )
}

///|
pub fn terminal_state_parity_update(
  model : Model,
  msg : Msg,
) -> @pippa.UpdateResult[Model, Msg] {
  match msg {
    WindowMeasured(size) =>
      @pippa.UpdateResult::new(
        model={ ..model, window_size: Some(size) },
        cmd=@pippa.Cmd::none(),
      )
    ToggleCursor =>
      @pippa.UpdateResult::new(
        model={ ..model, cursor_visible: !model.cursor_visible },
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
pub fn terminal_state_parity_sub(event : @pippa.InputEvent) -> Msg? {
  match event {
    @pippa.Key(@pippa.Char('c')) => Some(ToggleCursor)
    @pippa.Key(@pippa.Char('q')) | @pippa.Key(@pippa.Modified("ctrl", "c")) =>
      Some(Quit)
    _ => None
  }
}

///|
fn terminal_state_parity_size_text(model : Model) -> String {
  match model.window_size {
    Some(size) => "\{size.width}x\{size.height}"
    None => "pending"
  }
}

///|
pub fn terminal_state_parity_view(model : Model) -> String {
  if model.quitting {
    return "Goodbye\n"
  }
  "Terminal State Parity\n" +
  "Size: \{terminal_state_parity_size_text(model)}\n" +
  "Cursor visible: \{model.cursor_visible}\n"
}

///|
pub fn terminal_state_parity_structured_view(model : Model) -> @pippa.View {
  @pippa.View::text(terminal_state_parity_view(model))
  .with_window_title("Pippa terminal state")
  .with_cursor_position(row=2, col=4)
  .with_cursor_visible(model.cursor_visible)
  .with_progress(@pippa.ViewProgressIndeterminate)
  .with_mouse_mode(@pippa.ViewMousePress)
}

///|
pub fn terminal_state_parity_run_script(
  events : Array[@pippa.InputEvent],
) -> Model {
  let mut model = terminal_state_parity_init().model
  for event in events {
    match terminal_state_parity_sub(event) {
      Some(msg) => model = terminal_state_parity_update(model, msg).model
      None => ()
    }
  }
  model
}
