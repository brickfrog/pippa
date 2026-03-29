///|
/// Core type aliases and scaffolding for the Pippa TUI framework.
///
/// Pippa follows the Elm Architecture (Model–Update–View):
///
/// - **Model**: application state stored in a plain struct.
/// - **Msg**: typed messages that describe events (key presses, resizes, etc.).
/// - **update**: a pure function that produces the next Model and optional Cmds.
/// - **view**: a pure function that renders the Model to a string of ANSI output.
///
/// The runtime (Program) handles raw terminal mode, input parsing, and
/// efficient diffing / re-rendering.
///
/// # Example
/// ```moonbit
/// let _batch : Cmd[Nothing] = Cmd::batch([])
/// let _none : Cmd[Nothing] = Cmd::none()
/// let _tick : Cmd[Nothing] = Cmd::tick(100)
/// ```

///|
/// Sentinel type for commands that carry no payload.
pub(all) struct Nothing {} derive(Show, Eq)

///|
/// A batch of I/O commands to be performed by the runtime.
///
/// `Cmd[Msg]` represents side-effects (timers, async I/O, etc.) that, when
/// completed, will produce a message of type `Msg` and feed it back into the
/// update loop. Use `Cmd::none()` for no-ops and `Cmd::batch` to combine
/// multiple commands.
struct Cmd[Msg] {
  // Phantom field — carries no data, ensures the type parameter is consumed.
  _phantom : Array[Msg]
  // Periodic tick interval in milliseconds. `0` disables ticking.
  interval_ms : Int
} derive(Show)

///|
/// The result of an `update` call: the new model and an optional command.
pub(all) struct UpdateResult[Model, Msg] {
  model : Model
  cmd : Cmd[Msg]
} derive(Show)

///|
/// Create an `UpdateResult` from a model and a command.
pub fn[Model, Msg] UpdateResult::new(
  model~ : Model,
  cmd~ : Cmd[Msg],
) -> UpdateResult[Model, Msg] {
  { model, cmd }
}

///|
/// A window resize event payload.
pub(all) struct WindowSize {
  width : Int
  height : Int
} derive(Show, Eq)

///|
/// Built-in messages that the Pippa runtime can emit.
///
/// Users extend their own `Msg` enum to wrap `InternalMsg` when they need
/// to react to terminal events.
pub(all) enum InternalMsg {
  /// A keyboard event (raw bytes pending further parsing).
  KeyPress(Array[Byte])
  /// The terminal was resized.
  WindowResize(WindowSize)
  /// An explicit quit request.
  QuitRequested
} derive(Show, Eq)
