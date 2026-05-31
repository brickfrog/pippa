///|
/// Structured View example for per-render terminal state.
///
/// The string `view` remains the fallback. The structured hook carries the same
/// content plus terminal-state requests for future renderer plumbing.

///|
struct Model {
  cursor_visible : Bool
  quitting : Bool
} derive(Debug)

///|
enum Msg {
  ToggleCursor
  Quit
} derive(Debug)

///|
fn structured_init() -> @pippa.UpdateResult[Model, Msg] {
  @pippa.UpdateResult::new(
    model={ cursor_visible: true, quitting: false },
    cmd=@pippa.Cmd::none(),
  )
}

///|
fn structured_update(
  model : Model,
  msg : Msg,
) -> @pippa.UpdateResult[Model, Msg] {
  match msg {
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
fn structured_sub(event : @pippa.InputEvent) -> Msg? {
  match event {
    @pippa.Key(@pippa.Char('c')) => Some(ToggleCursor)
    @pippa.Key(@pippa.Char('q')) | @pippa.Key(@pippa.Modified("ctrl", "c")) =>
      Some(Quit)
    _ => None
  }
}

///|
fn structured_content(model : Model) -> String {
  if model.quitting {
    return "\n  Goodbye from structured View.\n"
  }
  let cursor_state = if model.cursor_visible { "visible" } else { "hidden" }
  "\n  Pippa Structured View\n\n  Content still renders as a string.\n  Per-frame state requests travel beside it.\n\n  Cursor request: \{cursor_state} at row 3, col 3\n\n  c toggle cursor state  q quit\n"
}

///|
fn structured_plain_view(model : Model) -> String {
  structured_content(model)
}

///|
fn structured_view(model : Model) -> @pippa.View {
  let progress = if model.cursor_visible {
    @pippa.ViewProgressPercent(65)
  } else {
    @pippa.ViewProgressIndeterminate
  }
  @pippa.View::text(structured_content(model))
  .with_cursor_position(row=3, col=3)
  .with_cursor_visible(model.cursor_visible)
  .with_window_title("Pippa Structured View")
  .with_foreground_color(@pippa.color_rgb(199, 38, 138))
  .with_background_color(@pippa.color_ansi(0))
  .with_progress(progress)
  .with_mouse_mode(@pippa.ViewMousePress)
}

///|
fn main {
  let program = @pippa.Program::new(
    init=structured_init,
    update=structured_update,
    view=structured_plain_view,
    sub=structured_sub,
    should_quit=fn(model) { model.quitting },
  ).with_structured_view(structured_view)
  ignore(@pippa.Program::run(program))
}
