///|
/// Interactive counter demo demonstrating the Pippa TUI framework.
///
/// This example showcases a counter with keybinds for incrementing, decrementing,
/// and resetting the count. It also demonstrates how to use the `Program::run`
/// entry point and input subscriptions.
///
/// Run with: `moon run src/examples/hello`

///|
/// The application model — a counter app.
struct Model {
  count : Int
  quitting : Bool
} derive(Debug)

///|
/// Application messages.
enum Msg {
  Increment
  Decrement
  Reset
  Quit
} derive(Debug)

///|
/// Initialise the model.
fn hello_init() -> @pippa.UpdateResult[Model, Msg] {
  @pippa.UpdateResult::new(
    model={ count: 0, quitting: false },
    cmd=@pippa.Cmd::none(),
  )
}

///|
/// Update the model in response to a message.
fn hello_update(model : Model, msg : Msg) -> @pippa.UpdateResult[Model, Msg] {
  if model.quitting {
    return @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
  }
  let mut next_count = model.count
  let mut quitting = false
  match msg {
    Increment => next_count = model.count + 1
    Decrement => next_count = model.count - 1
    Reset => next_count = 0
    Quit => quitting = true
  }
  @pippa.UpdateResult::new(
    model={ count: next_count, quitting },
    cmd=@pippa.Cmd::none(),
  )
}

///|
/// Map input events to messages.
fn hello_sub(event : @pippa.InputEvent) -> Msg? {
  match event {
    @pippa.Key(@pippa.Char('+')) | @pippa.Key(@pippa.Special("up")) =>
      Some(Increment)
    @pippa.Key(@pippa.Char('-')) | @pippa.Key(@pippa.Special("down")) =>
      Some(Decrement)
    @pippa.Key(@pippa.Char('r')) => Some(Reset)
    @pippa.Key(@pippa.Char('q')) | @pippa.Key(@pippa.Modified("ctrl", "c")) =>
      Some(Quit)
    _ => None
  }
}

///|
/// Render the model to a string of ANSI-formatted output.
fn hello_view(model : Model) -> String {
  if model.quitting {
    return "\n  Goodbye!\n\n"
  }
  let bold = @pippa.bold()
  let dim = @pippa.dim()
  let reset = @pippa.reset()
  "\n  Pippa Counter Demo\n\n  Count: \{bold}\{model.count}\{reset}\n\n  \{dim}+ increment  - decrement  r reset  q quit\{reset}\n"
}

///|
/// Entry point — create the program and run it.
fn main {
  let program = @pippa.Program::new(
    init=hello_init,
    update=hello_update,
    view=hello_view,
    sub=hello_sub,
    should_quit=fn(model) { model.quitting },
  )
  @pippa.Program::run(program)
}
