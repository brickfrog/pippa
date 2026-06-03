///|
/// Core type aliases and scaffolding for the Pippa TUI framework.
///
/// Pippa follows the Elm Architecture (Model–Update–View):
///
/// - **Model**: application state stored in a plain struct.
/// - **Msg**: typed messages that describe events (key presses, resizes, etc.).
/// - **update**: a pure function that produces the next Model and optional Cmds.
/// - **view**: a pure function that renders the Model to a string of ANSI output.
///   Apps that need per-render terminal state can opt into `View` without
///   changing the common string-view shape.
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
pub(all) struct Nothing {} derive(Debug, Eq)

///|
/// Typed payload delivered to scheduler callbacks.
pub(all) struct TimerTick {
  /// Milliseconds elapsed since the command was scheduled.
  elapsed_ms : Int64
} derive(Debug, Eq)

///|
/// Lifecycle messages emitted by the runtime and lifecycle commands.
pub(all) enum LifecycleMsg {
  /// The program should quit cleanly.
  Quit
  /// The program was interrupted, typically by Ctrl+C / SIGINT.
  Interrupt
  /// The program is temporarily releasing the terminal for suspension.
  Suspend
  /// The program has resumed and re-acquired the terminal.
  Resume
} derive(Debug, Eq)

///|
/// External process request run by `Cmd::exec_process`.
pub(all) struct ExecProcess {
  /// Executable name or path passed to `execvp`.
  command : String
  /// Arguments passed after `command`.
  args : Array[String]
} derive(Debug, Eq)

///|
/// Create an external process request.
pub fn ExecProcess::new(
  command~ : String,
  args? : Array[String] = [],
) -> ExecProcess {
  { command, args }
}

///|
/// Result of an external process run.
pub(all) enum ExecResult {
  /// The child process exited and supplied an exit code.
  ExecCompleted(Int)
  /// The child process was cancelled before completion.
  ExecCancelled
  /// The child process was terminated by a signal.
  ExecSignaled(Int)
  /// The child process could not be started or failed at the runner boundary.
  ExecError(String)
} derive(Debug, Eq)

///|
/// Typed result returned by `Program::run`.
pub(all) enum RunResult[Model] {
  /// The program ended without a quit, interrupt, runtime error, or exec result.
  RunCompleted(Model)
  /// The program quit cleanly and carries the final model.
  RunQuit(Model)
  /// The program was interrupted and carries the final model.
  RunInterrupted(Model)
  /// The runtime stopped with an error.
  RunRuntimeError(String)
  /// The program quit in response to an external process result.
  RunExec(Model, ExecResult)
} derive(Debug)

///|
/// Cursor position requested by a structured `View`.
pub(all) struct ViewCursorPosition {
  /// 1-based terminal row.
  row : Int
  /// 1-based terminal column.
  col : Int
} derive(Debug, Eq)

///|
fn view_cursor_coordinate(value : Int) -> Int {
  if value < 1 {
    1
  } else {
    value
  }
}

///|
/// Create a 1-based cursor position, clamping invalid terminal coordinates to 1.
pub fn ViewCursorPosition::new(row~ : Int, col~ : Int) -> ViewCursorPosition {
  { row: view_cursor_coordinate(row), col: view_cursor_coordinate(col) }
}

///|
/// Per-render terminal progress state carried by a structured `View`.
pub(all) enum ViewProgress {
  /// Clear or suppress terminal progress reporting for this frame.
  ViewProgressNone
  /// Show an indeterminate progress indicator.
  ViewProgressIndeterminate
  /// Show progress as an integer percentage.
  ViewProgressPercent(Int)
  /// Show paused progress with an optional integer percentage.
  ViewProgressPaused(Int?)
  /// Show errored progress with an optional integer percentage.
  ViewProgressError(Int?)
} derive(Debug, Eq)

///|
/// Mouse reporting mode requested by a structured `View`.
pub(all) enum ViewMouseMode {
  /// Disable per-frame mouse reporting.
  ViewMouseOff
  /// Enable normal mouse press/release reporting.
  ViewMousePress
  /// Enable button-event mouse reporting, including button-held drag motion.
  ViewMouseCellMotion
  /// Enable full mouse motion reporting.
  ViewMouseAllMotion
} derive(Debug, Eq)

///|
/// Structured render output for a single frame.
///
/// `content` is rendered exactly like the string returned by a traditional
/// `view` function. The optional fields describe terminal state that should
/// travel with the frame; emitting escape sequences for those fields is handled
/// by later render plumbing.
pub(all) struct View {
  /// The frame content to diff and render.
  content : String
  /// Optional cursor position for this frame.
  cursor_position : ViewCursorPosition?
  /// Optional cursor visibility for this frame.
  cursor_visible : Bool?
  /// Optional terminal window title for this frame.
  window_title : String?
  /// Optional default foreground color for this frame.
  foreground_color : Color?
  /// Optional default background color for this frame.
  background_color : Color?
  /// Optional terminal progress state for this frame.
  progress : ViewProgress?
  /// Optional mouse reporting mode for this frame.
  mouse_mode : ViewMouseMode?
} derive(Debug, Eq)

///|
/// Create a structured `View` with explicit optional terminal state.
pub fn View::new(
  content~ : String,
  cursor_position? : ViewCursorPosition? = None,
  cursor_visible? : Bool? = None,
  window_title? : String? = None,
  foreground_color? : Color? = None,
  background_color? : Color? = None,
  progress? : ViewProgress? = None,
  mouse_mode? : ViewMouseMode? = None,
) -> View {
  let cursor_position = cursor_position.map(fn(pos) {
    ViewCursorPosition::new(row=pos.row, col=pos.col)
  })
  {
    content,
    cursor_position,
    cursor_visible,
    window_title,
    foreground_color,
    background_color,
    progress,
    mouse_mode,
  }
}

///|
/// Wrap plain string content as a structured `View`.
pub fn View::text(content : String) -> View {
  View::new(content~)
}

///|
/// Set the cursor position for this frame.
pub fn View::with_cursor_position(self : View, row~ : Int, col~ : Int) -> View {
  { ..self, cursor_position: Some(ViewCursorPosition::new(row~, col~)) }
}

///|
/// Set cursor visibility for this frame.
pub fn View::with_cursor_visible(self : View, visible : Bool) -> View {
  { ..self, cursor_visible: Some(visible) }
}

///|
/// Set the terminal window title for this frame.
pub fn View::with_window_title(self : View, title : String) -> View {
  { ..self, window_title: Some(title) }
}

///|
/// Set the default foreground color for this frame.
pub fn View::with_foreground_color(self : View, color : Color) -> View {
  { ..self, foreground_color: Some(color) }
}

///|
/// Set the default background color for this frame.
pub fn View::with_background_color(self : View, color : Color) -> View {
  { ..self, background_color: Some(color) }
}

///|
/// Set terminal progress state for this frame.
pub fn View::with_progress(self : View, progress : ViewProgress) -> View {
  { ..self, progress: Some(progress) }
}

///|
/// Set the mouse reporting mode for this frame.
pub fn View::with_mouse_mode(self : View, mouse_mode : ViewMouseMode) -> View {
  { ..self, mouse_mode: Some(mouse_mode) }
}

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
  // Schedule a one-shot callback aligned to `interval_ms`.
  Every(Int, (TimerTick) -> Msg)
  // Enter the alternate screen buffer.
  EnterAltScreen
  // Exit the alternate screen buffer.
  ExitAltScreen
  // Clear the screen and move the cursor home.
  ClearScreen
  // Invalidate the renderer cache and repaint on the next render pass.
  Repaint
  // Alias for `Repaint`, mirroring Bubble Tea's force redraw command.
  ForceRedraw
  // Hide the terminal cursor.
  HideCursor
  // Show the terminal cursor.
  ShowCursor
  // Ask the runtime to report the current terminal size.
  RequestWindowSize((WindowSize) -> Msg)
  // Request primary device attributes from the terminal.
  RequestDeviceAttributes
  // Request secondary device attributes / terminal version from the terminal.
  RequestSecondaryDeviceAttributes
  // Request the current cursor position from the terminal.
  RequestCursorPosition
  // Request the current default foreground color.
  RequestForegroundColor
  // Request the current default background color.
  RequestBackgroundColor
  // Request a terminal capability with XTGETTCAP.
  RequestCapability(String)
  // Request clipboard contents with OSC 52.
  RequestClipboard(ClipboardSelection)
  // Enable or disable focus reporting.
  SetFocusReporting(Bool)
  // Enable or disable bracketed paste mode.
  SetBracketedPaste(Bool)
  // Set terminal mouse reporting mode.
  SetMouseMode(ViewMouseMode)
  // Set the terminal window title.
  SetWindowTitle(String)
  // Deliver a typed lifecycle message through the runtime.
  LifecycleAction(LifecycleMsg)
  // Run an external process while the terminal is released.
  ExecProcessAction(ExecProcess, (ExecResult) -> Msg)
  // Stop the runtime with a typed error result.
  RuntimeErrorAction(String)
  // Run commands in order, waiting for immediate effects from each step to settle
  // before starting the next one.
  Sequence(Array[Cmd[Msg]])
}

///|
pub impl[Msg] Debug for Cmd[Msg] with fn to_repr(self) {
  let mut perform_count = 0
  let mut tick_count = 0
  let mut after_count = 0
  let mut every_count = 0
  let mut screen_count = 0
  let mut window_size_count = 0
  let mut terminal_count = 0
  let mut lifecycle_count = 0
  let mut exec_count = 0
  let mut error_count = 0
  let mut sequence_count = 0
  for action in self.actions {
    match action {
      Perform(_) => perform_count = perform_count + 1
      Tick(_) => tick_count = tick_count + 1
      After(_, _) => after_count = after_count + 1
      Every(_, _) => every_count = every_count + 1
      EnterAltScreen
      | ExitAltScreen
      | ClearScreen
      | Repaint
      | ForceRedraw
      | HideCursor
      | ShowCursor => screen_count = screen_count + 1
      RequestWindowSize(_) => window_size_count = window_size_count + 1
      RequestDeviceAttributes
      | RequestSecondaryDeviceAttributes
      | RequestCursorPosition
      | RequestForegroundColor
      | RequestBackgroundColor
      | RequestCapability(_)
      | RequestClipboard(_)
      | SetFocusReporting(_)
      | SetBracketedPaste(_)
      | SetMouseMode(_)
      | SetWindowTitle(_) => terminal_count = terminal_count + 1
      LifecycleAction(_) => lifecycle_count = lifecycle_count + 1
      ExecProcessAction(_, _) => exec_count = exec_count + 1
      RuntimeErrorAction(_) => error_count = error_count + 1
      Sequence(_) => sequence_count = sequence_count + 1
    }
  }
  let buf = StringBuilder::new()
  buf.write_string("Cmd(actions=")
  buf.write_string(self.actions.length().to_string())
  if perform_count > 0 {
    buf.write_string(", perform=")
    buf.write_string(perform_count.to_string())
  }
  if tick_count > 0 {
    buf.write_string(", tick=")
    buf.write_string(tick_count.to_string())
  }
  if after_count > 0 {
    buf.write_string(", after=")
    buf.write_string(after_count.to_string())
  }
  if every_count > 0 {
    buf.write_string(", every=")
    buf.write_string(every_count.to_string())
  }
  if screen_count > 0 {
    buf.write_string(", screen=")
    buf.write_string(screen_count.to_string())
  }
  if window_size_count > 0 {
    buf.write_string(", window_size=")
    buf.write_string(window_size_count.to_string())
  }
  if terminal_count > 0 {
    buf.write_string(", terminal=")
    buf.write_string(terminal_count.to_string())
  }
  if lifecycle_count > 0 {
    buf.write_string(", lifecycle=")
    buf.write_string(lifecycle_count.to_string())
  }
  if exec_count > 0 {
    buf.write_string(", exec=")
    buf.write_string(exec_count.to_string())
  }
  if error_count > 0 {
    buf.write_string(", error=")
    buf.write_string(error_count.to_string())
  }
  if sequence_count > 0 {
    buf.write_string(", sequence=")
    buf.write_string(sequence_count.to_string())
  }
  buf.write_string(")")
  Repr::literal(buf.to_string())
}

///|
/// The result of an `update` call: the new model and an optional command.
pub(all) struct UpdateResult[Model, Msg] {
  model : Model
  cmd : Cmd[Msg]
} derive(Debug)

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
} derive(Debug, Eq)

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
  /// A typed lifecycle event.
  Lifecycle(LifecycleMsg)
  /// An explicit quit request.
  QuitRequested
} derive(Debug, Eq)
