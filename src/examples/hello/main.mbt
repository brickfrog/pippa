///|
/// Minimal "hello world" example demonstrating the Pippa TUI framework.
///
/// Run with: `moon run src/examples/hello`

///|
/// The application model — just a counter and a greeting.
struct Model {
  greeting : String
  count : Int
} derive(Show)

///|
/// Application messages.
enum Msg {
  Increment
  Decrement
  Quit
} derive(Show)

///|
/// Initialise the model.
fn hello_init() -> @pippa.UpdateResult[Model, Msg] {
  @pippa.UpdateResult::new(
    model={ greeting: "Hello from Pippa!", count: 0 },
    cmd=@pippa.Cmd::none(),
  )
}

///|
/// Update the model in response to a message.
fn hello_update(model : Model, _msg : Msg) -> @pippa.UpdateResult[Model, Msg] {
  @pippa.UpdateResult::new(
    model={ greeting: model.greeting, count: model.count + 1 },
    cmd=@pippa.Cmd::none(),
  )
}

///|
/// Render the model to a string of ANSI-formatted output.
fn hello_view(model : Model) -> String {
  let counter_style = @pippa.bold()
  let reset = @pippa.reset()
  "\{counter_style}\{model.greeting}\{reset}\nCounter: \{model.count}\n"
}

///|
/// Entry point — create the program and run it.
fn main {
  let _program = @pippa.Program::new(
    init=hello_init,
    update=hello_update,
    view=hello_view,
  )
  // Program::run is not yet implemented; print a demo view instead.
  let model : Model = { greeting: "Hello from Pippa!", count: 0 }
  println(hello_view(model))
}
