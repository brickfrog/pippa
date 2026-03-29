///|
/// Program configuration and entry-point for a Pippa TUI application.
///
/// A `Program[Model, Msg]` ties together the three core functions of the Elm
/// Architecture (init, update, view) and drives the main event loop.
///
/// Construct with `Program::new` and run with `Program::run` (not yet
/// implemented).

///|
/// Configuration for a Pippa application.
pub(all) struct Program[Model, Msg] {
  /// Initial state and optional initial command.
  init : () -> UpdateResult[Model, Msg]
  /// Pure update function: given the current model and a message, produce
  /// the next model and an optional command.
  update : (Model, Msg) -> UpdateResult[Model, Msg]
  /// Pure view function: render the current model to a string.
  view : (Model) -> String
} derive(Show)

///|
/// Create a new Program from init, update, and view functions.
pub fn[Model, Msg] Program::new(
  init~ : () -> UpdateResult[Model, Msg],
  update~ : (Model, Msg) -> UpdateResult[Model, Msg],
  view~ : (Model) -> String,
) -> Program[Model, Msg] {
  { init, update, view }
}

///|
/// Run the program (placeholder — will enter raw terminal mode and drive the
/// event loop).
pub fn[Model, Msg] Program::run(_program : Program[Model, Msg]) -> Unit {
  // TODO: enter raw mode, drive event loop, diff & re-render
  let _ = _program
  ()
}
