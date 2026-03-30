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
/// `Cmd[Msg]` represents one-shot runtime effects that may later produce a
/// message of type `Msg` and feed it back into the update loop.
///
/// Commands are additive: when several updates happen in one runtime turn, the
/// resulting commands are all enqueued rather than the "last" one replacing the
/// others. Use `Cmd::none()` for no-ops and `Cmd::batch` to combine several
/// commands.
/// A batch of one-shot runtime effects.
struct Cmd[Msg] {
  // Phantom field — carries no data, ensures the type parameter is consumed.
  _phantom : Array[Msg]
  // Runtime-managed one-shot actions.
  actions : Array[CmdAction[Msg]]
}

///|
priv enum CmdAction[Msg] {
  // Execute a runtime effect immediately after the current update cycle.
  Perform(() -> Msg?)
  // Schedule a one-shot `on_tick` callback after `interval_ms`.
  Tick(Int)
  // Schedule a one-shot runtime effect after `interval_ms`.
  After(Int, () -> Msg)
  // Run commands in order, waiting for immediate effects from each step to settle
  // before starting the next one.
  Sequence(Array[Cmd[Msg]])
}

///|
pub impl[Msg] Show for Cmd[Msg] with output(self, logger) {
  let mut perform_count = 0
  let mut tick_count = 0
  let mut after_count = 0
  let mut sequence_count = 0
  for action in self.actions {
    match action {
      Perform(_) => perform_count = perform_count + 1
      Tick(_) => tick_count = tick_count + 1
      After(_, _) => after_count = after_count + 1
      Sequence(_) => sequence_count = sequence_count + 1
    }
  }
  logger.write_string("Cmd(actions=")
  logger.write_string(self.actions.length().to_string())
  if perform_count > 0 {
    logger.write_string(", perform=")
    logger.write_string(perform_count.to_string())
  }
  if tick_count > 0 {
    logger.write_string(", tick=")
    logger.write_string(tick_count.to_string())
  }
  if after_count > 0 {
    logger.write_string(", after=")
    logger.write_string(after_count.to_string())
  }
  if sequence_count > 0 {
    logger.write_string(", sequence=")
    logger.write_string(sequence_count.to_string())
  }
  logger.write_string(")")
}

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
