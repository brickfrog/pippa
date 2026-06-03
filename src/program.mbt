///|
/// Program configuration and entry-point for a Pippa TUI application.
///
/// A `Program[Model, Msg]` ties together the three core functions of the Elm
/// Architecture (init, update, view) and drives the main event loop.
///
/// Construct with `Program::new` and run with `Program::run`.
///
/// The common `view~ : Model -> String` shape is still the default. Apps that
/// need per-render terminal state can call `Program::with_structured_view`; when
/// present, the runtime prefers it and renders its `content`.

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
  /// Optional structured view function carrying content plus per-frame terminal
  /// state. When set, it is preferred over `view`.
  structured_view : ((Model) -> View)?
  /// Map input events to messages. Return None to ignore an event.
  sub : (InputEvent) -> Msg?
  /// Produce a message when a tick command fires. Prefer `Cmd::after` for
  /// component-local clocks; `on_tick` is a compatibility hook for app-wide
  /// timers.
  on_tick : () -> Msg?
  /// Enable terminal mouse reporting while the program runs.
  mouse : Bool
  /// Enter the terminal alternate screen buffer while the program runs.
  alt_screen : Bool
  /// Enable terminal focus reporting while the program runs.
  focus_reporting : Bool
  /// Enable bracketed paste while the program runs.
  bracketed_paste : Bool
  /// Hide the terminal cursor while the program runs.
  hide_cursor : Bool
  /// Wrap each rendered frame in synchronized output mode.
  synchronized_output : Bool
  /// Render view output and screen control sequences.
  rendering : Bool
  /// Read input events from stdin and enable terminal input modes.
  read_stdin : Bool
  /// Optional non-blocking input source polled by the runtime before waiting
  /// on stdin/timers. Return currently available events and never block.
  input : (() -> Array[InputEvent])?
  /// Optional non-blocking raw byte source polled before waiting on stdin/timers.
  /// Return currently available bytes and never block.
  raw_input : (() -> Bytes)?
  /// Optional cancellation predicate polled by the runtime between waits.
  cancelled : (() -> Bool)?
  /// Maximum renderer FPS. Values outside 1..120 are clamped by the runtime.
  fps : Int
  /// Optional initial window width used to seed `on_resize`.
  window_width : Int
  /// Optional initial window height used to seed `on_resize`.
  window_height : Int
  /// Write rendered output and terminal control sequences.
  output : (String) -> Unit
  /// Produce a message when the terminal size changes using a typed payload.
  on_window_size : (WindowSize) -> Msg?
  /// Produce a message when the terminal size changes. Return None to ignore it.
  on_resize : (Int, Int) -> Msg?
  /// Return true to exit the event loop after an update.
  should_quit : (Model) -> Bool
  /// Intercept Ctrl+C and force-quit before delivering the event to `sub`.
  /// Set to false if the application wants to handle Ctrl+C itself (e.g. copy
  /// mode, graceful cancel). Defaults to true.
  catch_interrupt : Bool
  /// Produce a message for runtime lifecycle events.
  on_lifecycle : (LifecycleMsg) -> Msg?
  /// Run an external process while Pippa has released the terminal.
  exec_runner : (ExecProcess) -> ExecResult
  /// Stop the process for terminal suspension and return after continue.
  suspend_runner : () -> Unit
}

///|
/// Terminal control requests that can be sent through `ProgramHandle`.
#warnings("-unused_constructor")
priv enum RuntimeControl {
  ReleaseTerminal
  RestoreTerminal
}

///|
/// Handle for sending messages to a running program.
///
/// `send` is intended for the same MoonBit runtime thread. Native cross-thread
/// delivery of generic MoonBit values is not supported by the runtime today.
struct ProgramHandle[Msg] {
  pending_msgs : @queue.Queue[Msg]
  pending_controls : @queue.Queue[RuntimeControl]
  wake : () -> Unit
  closed : Ref[Bool]
}

///|
fn[Msg] ProgramHandle::new(
  pending_msgs : @queue.Queue[Msg],
  pending_controls : @queue.Queue[RuntimeControl],
  wake : () -> Unit,
  closed : Ref[Bool],
) -> ProgramHandle[Msg] {
  { pending_msgs, pending_controls, wake, closed }
}

///|
/// Enqueue a message for delivery to the running program.
pub fn[Msg] ProgramHandle::send(self : ProgramHandle[Msg], msg : Msg) -> Bool {
  if self.closed.val {
    false
  } else {
    self.pending_msgs.push(msg)
    (self.wake)()
    true
  }
}

///|
/// Returns true after the program has exited and the handle can no longer send.
pub fn[Msg] ProgramHandle::is_closed(self : ProgramHandle[Msg]) -> Bool {
  self.closed.val
}

///|
/// Temporarily restore the terminal to its outer shell state.
pub fn[Msg] ProgramHandle::release_terminal(self : ProgramHandle[Msg]) -> Bool {
  if self.closed.val {
    false
  } else {
    self.pending_controls.push(ReleaseTerminal)
    (self.wake)()
    true
  }
}

///|
/// Re-enter Pippa's managed terminal state after `release_terminal`.
pub fn[Msg] ProgramHandle::restore_terminal(self : ProgramHandle[Msg]) -> Bool {
  if self.closed.val {
    false
  } else {
    self.pending_controls.push(RestoreTerminal)
    (self.wake)()
    true
  }
}

///|
/// Create a new Program from init, update, and view functions.
pub fn[Model, Msg] Program::new(
  init~ : () -> UpdateResult[Model, Msg],
  update~ : (Model, Msg) -> UpdateResult[Model, Msg],
  view~ : (Model) -> String,
  sub? : (InputEvent) -> Msg? = fn(_evt) { None },
  on_tick? : () -> Msg? = fn() { None },
  mouse? : Bool = false,
  alt_screen? : Bool = true,
  focus_reporting? : Bool = true,
  bracketed_paste? : Bool = true,
  hide_cursor? : Bool = true,
  synchronized_output? : Bool = true,
  rendering? : Bool = true,
  read_stdin? : Bool = true,
  input? : (() -> Array[InputEvent])? = None,
  raw_input? : (() -> Bytes)? = None,
  cancelled? : (() -> Bool)? = None,
  fps? : Int = 60,
  window_width? : Int = 0,
  window_height? : Int = 0,
  output? : (String) -> Unit = default_output,
  on_resize? : (Int, Int) -> Msg? = fn(_cols, _rows) { None },
  should_quit? : (Model) -> Bool = fn(_model) { false },
  catch_interrupt? : Bool = true,
  on_window_size? : (WindowSize) -> Msg? = fn(_size) { None },
  on_lifecycle? : (LifecycleMsg) -> Msg? = fn(_msg) { None },
  exec_runner? : (ExecProcess) -> ExecResult = default_exec_runner,
  suspend_runner? : () -> Unit = default_suspend_runner,
) -> Program[Model, Msg] {
  {
    init,
    update,
    view,
    structured_view: None,
    sub,
    on_tick,
    mouse,
    alt_screen,
    focus_reporting,
    bracketed_paste,
    hide_cursor,
    synchronized_output,
    rendering,
    read_stdin,
    input,
    raw_input,
    cancelled,
    fps,
    window_width,
    window_height,
    output,
    on_window_size,
    on_resize,
    should_quit,
    catch_interrupt,
    on_lifecycle,
    exec_runner,
    suspend_runner,
  }
}

///|
/// Install an opt-in structured view while preserving the plain string view as
/// a fallback for callers that do not need per-frame terminal state.
pub fn[Model, Msg] Program::with_structured_view(
  self : Program[Model, Msg],
  structured_view : (Model) -> View,
) -> Program[Model, Msg] {
  { ..self, structured_view: Some(structured_view) }
}

///|
pub fn[Model, Msg] Program::with_alt_screen(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, alt_screen: enabled }
}

///|
pub fn[Model, Msg] Program::with_focus_reporting(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, focus_reporting: enabled }
}

///|
pub fn[Model, Msg] Program::with_bracketed_paste(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, bracketed_paste: enabled }
}

///|
pub fn[Model, Msg] Program::with_hide_cursor(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, hide_cursor: enabled }
}

///|
pub fn[Model, Msg] Program::with_synchronized_output(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, synchronized_output: enabled }
}

///|
pub fn[Model, Msg] Program::with_rendering(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, rendering: enabled }
}

///|
pub fn[Model, Msg] Program::with_stdin(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, read_stdin: enabled }
}

///|
pub fn[Model, Msg] Program::with_input(
  self : Program[Model, Msg],
  input : () -> Array[InputEvent],
) -> Program[Model, Msg] {
  { ..self, input: Some(input), read_stdin: false }
}

///|
pub fn[Model, Msg] Program::with_raw_input(
  self : Program[Model, Msg],
  raw_input : () -> Bytes,
) -> Program[Model, Msg] {
  { ..self, raw_input: Some(raw_input), read_stdin: false }
}

///|
pub fn[Model, Msg] Program::with_cancelled(
  self : Program[Model, Msg],
  cancelled : () -> Bool,
) -> Program[Model, Msg] {
  { ..self, cancelled: Some(cancelled) }
}

///|
pub fn[Model, Msg] Program::with_fps(
  self : Program[Model, Msg],
  fps : Int,
) -> Program[Model, Msg] {
  { ..self, fps, }
}

///|
pub fn[Model, Msg] Program::with_window_size(
  self : Program[Model, Msg],
  width : Int,
  height : Int,
) -> Program[Model, Msg] {
  {
    ..self,
    window_width: @internal.clamp_non_negative(width),
    window_height: @internal.clamp_non_negative(height),
  }
}

///|
pub fn[Model, Msg] Program::with_output(
  self : Program[Model, Msg],
  output : (String) -> Unit,
) -> Program[Model, Msg] {
  { ..self, output, }
}

///|
pub fn[Model, Msg] Program::headless(
  self : Program[Model, Msg],
) -> Program[Model, Msg] {
  {
    ..self,
    mouse: false,
    alt_screen: false,
    focus_reporting: false,
    bracketed_paste: false,
    hide_cursor: false,
    rendering: false,
    read_stdin: false,
  }
}

///|
pub fn[Model, Msg] Program::with_catch_interrupt(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, catch_interrupt: enabled }
}

///|
pub fn[Model, Msg] Program::with_lifecycle(
  self : Program[Model, Msg],
  on_lifecycle : (LifecycleMsg) -> Msg?,
) -> Program[Model, Msg] {
  { ..self, on_lifecycle, }
}

///|
pub fn[Model, Msg] Program::with_exec_runner(
  self : Program[Model, Msg],
  exec_runner : (ExecProcess) -> ExecResult,
) -> Program[Model, Msg] {
  { ..self, exec_runner, }
}

///|
pub fn[Model, Msg] Program::with_suspend_runner(
  self : Program[Model, Msg],
  suspend_runner : () -> Unit,
) -> Program[Model, Msg] {
  { ..self, suspend_runner, }
}

///|
#cfg(any(target="native", target="llvm"))
fn append_exec_arg(argv : Array[Byte], value : String) -> Bool {
  let bytes = @utf8.encode(value)
  for byte in bytes.to_array() {
    if byte == b'\x00' {
      return false
    }
    argv.push(byte)
  }
  argv.push(b'\x00')
  true
}

///|
#cfg(any(target="native", target="llvm"))
fn default_exec_runner(process : ExecProcess) -> ExecResult {
  if process.command == "" {
    return ExecError("empty command")
  }
  let argv : Array[Byte] = []
  if !append_exec_arg(argv, process.command) {
    return ExecError("command contains NUL byte")
  }
  for arg in process.args {
    if !append_exec_arg(argv, arg) {
      return ExecError("argument contains NUL byte")
    }
  }
  let buf = Bytes::from_array(argv)
  let code = pippa_exec_process(buf, buf.length(), process.args.length() + 1)
  if code >= 0 {
    ExecCompleted(code)
  } else if code == -2 {
    ExecCancelled
  } else if code <= -2000 {
    ExecSignaled(-2000 - code)
  } else if code <= -1000 {
    ExecError("failed to exec " + process.command)
  } else {
    ExecError("failed to run process: " + process.command)
  }
}

///|
#cfg(not(any(target="native", target="llvm")))
fn default_exec_runner(process : ExecProcess) -> ExecResult {
  ExecError("external process execution is unavailable: " + process.command)
}

///|
#cfg(any(target="native", target="llvm"))
fn default_suspend_runner() -> Unit {
  pippa_suspend_process()
}

///|
#cfg(not(any(target="native", target="llvm")))
fn default_suspend_runner() -> Unit {

}

///|
#cfg(any(target="native", target="llvm"))
fn default_output(output : String) -> Unit {
  if output != "" {
    let bytes = @utf8.encode(output)
    pippa_write_bytes(bytes, bytes.length())
  }
}

///|
#cfg(not(any(target="native", target="llvm")))
fn default_output(_output : String) -> Unit {

}

///|
#cfg(any(target="native", target="llvm"))
let runtime_clock_override : Ref[(() -> Int64)?] = Ref(None)

///|
#cfg(any(target="native", target="llvm"))
#warnings("-unused_value")
fn restore_runtime_clock(previous : (() -> Int64)?) -> Unit {
  runtime_clock_override.val = previous
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_now_ms() -> Int64 {
  match runtime_clock_override.val {
    Some(now) => now()
    None => pippa_now_ms()
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] emit_output(
  program : Program[Model, Msg],
  output : String,
) -> Unit {
  if output != "" {
    (program.output)(output)
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] program_enter_sequence(program : Program[Model, Msg]) -> String {
  program_enter_sequence_with_modes(
    program,
    program.alt_screen,
    program.hide_cursor,
    program.read_stdin && program.focus_reporting,
    program.read_stdin && program.bracketed_paste,
  )
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] program_enter_sequence_with_modes(
  program : Program[Model, Msg],
  alt_screen : Bool,
  cursor_hidden : Bool,
  focus_reporting : Bool,
  bracketed_paste : Bool,
) -> String {
  let buf = StringBuilder::new()
  if program.rendering {
    if alt_screen {
      buf.write_string(enter_alt_screen())
    }
    if cursor_hidden {
      buf.write_string(hide_cursor())
    }
    buf.write_string(clear_screen())
    buf.write_string(move_cursor(1, 1))
  }
  if focus_reporting {
    buf.write_string(enable_focus_reporting())
  }
  if bracketed_paste {
    buf.write_string(enable_bracketed_paste())
  }
  buf.to_string()
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] program_exit_sequence(program : Program[Model, Msg]) -> String {
  program_exit_sequence_with_modes(
    program,
    program.alt_screen,
    program.hide_cursor,
    program.read_stdin && program.focus_reporting,
    program.read_stdin && program.bracketed_paste,
  )
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] program_exit_sequence_with_modes(
  program : Program[Model, Msg],
  alt_screen : Bool,
  cursor_hidden : Bool,
  focus_reporting : Bool,
  bracketed_paste : Bool,
) -> String {
  let buf = StringBuilder::new()
  if focus_reporting {
    buf.write_string(disable_focus_reporting())
  }
  if bracketed_paste {
    buf.write_string(disable_bracketed_paste())
  }
  if program.rendering {
    if alt_screen {
      buf.write_string(exit_alt_screen())
    }
    ignore(cursor_hidden)
    buf.write_string(terminal_view_reset_sequence())
  }
  buf.to_string()
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] activate_terminal(program : Program[Model, Msg]) -> Unit {
  if program.read_stdin {
    pippa_enter_raw_mode()
  }
  let enter_seq = program_enter_sequence(program)
  emit_output(program, enter_seq)
  if program.rendering && program.read_stdin && program.mouse {
    emit_output(program, enable_mouse())
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] activate_terminal_with_modes(
  program : Program[Model, Msg],
  alt_screen : Bool,
  cursor_hidden : Bool,
  focus_reporting : Bool,
  bracketed_paste : Bool,
) -> Unit {
  if program.read_stdin {
    pippa_enter_raw_mode()
  }
  let enter_seq = program_enter_sequence_with_modes(
    program, alt_screen, cursor_hidden, focus_reporting, bracketed_paste,
  )
  emit_output(program, enter_seq)
  if program.rendering && program.read_stdin && program.mouse {
    emit_output(program, enable_mouse())
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] deactivate_terminal(program : Program[Model, Msg]) -> Unit {
  let exit_seq = program_exit_sequence(program)
  emit_output(program, exit_seq)
  if program.read_stdin {
    pippa_exit_raw_mode()
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] deactivate_terminal_with_modes(
  program : Program[Model, Msg],
  alt_screen : Bool,
  cursor_hidden : Bool,
  focus_reporting : Bool,
  bracketed_paste : Bool,
) -> Unit {
  let exit_seq = program_exit_sequence_with_modes(
    program, alt_screen, cursor_hidden, focus_reporting, bracketed_paste,
  )
  emit_output(program, exit_seq)
  if program.read_stdin {
    pippa_exit_raw_mode()
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] render_fps(program : Program[Model, Msg]) -> Int64 {
  program.fps.max(1).min(120).to_int64()
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] render_frame_deadline_ms(
  program : Program[Model, Msg],
  frame_index : Int64,
) -> Int64 {
  let fps = render_fps(program)
  (frame_index * 1000L + fps - 1L) / fps
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] render_frame_index_at_or_before(
  program : Program[Model, Msg],
  timestamp_ms : Int64,
) -> Int64 {
  timestamp_ms.max(0L) * render_fps(program) / 1000L
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] render_cadence_mark_at_or_before(
  program : Program[Model, Msg],
  timestamp_ms : Int64,
) -> Int64 {
  render_frame_deadline_ms(
    program,
    render_frame_index_at_or_before(program, timestamp_ms),
  )
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] next_render_deadline_after(
  program : Program[Model, Msg],
  last_render_ms : Int64,
) -> Int64 {
  let mut frame_index = render_frame_index_at_or_before(program, last_render_ms) +
    1L
  let mut deadline = render_frame_deadline_ms(program, frame_index)
  while deadline <= last_render_ms {
    frame_index = frame_index + 1L
    deadline = render_frame_deadline_ms(program, frame_index)
  }
  deadline
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] maybe_initial_window_size(
  program : Program[Model, Msg],
) -> WindowSize? {
  if program.window_width <= 0 && program.window_height <= 0 {
    None
  } else {
    Some({
      width: if program.window_width > 0 {
        program.window_width
      } else {
        pippa_get_cols()
      },
      height: if program.window_height > 0 {
        program.window_height
      } else {
        pippa_get_rows()
      },
    })
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn current_window_size() -> WindowSize {
  { width: pippa_get_cols(), height: pippa_get_rows() }
}

///|
/// Run the program.
///
/// On `native` and `llvm` targets this enters raw terminal mode and drives
/// the main event loop. On other targets this initializes the model, exposes
/// an already-closed handle to `run_with_handle`, and returns `RunCompleted`.
pub fn[Model, Msg] Program::run(
  program : Program[Model, Msg],
) -> RunResult[Model] {
  run_internal(program, fn(_handle) { () })
}

///|
/// Run the program and expose a handle that can inject messages while it is
/// running.
pub fn[Model, Msg] Program::run_with_handle(
  program : Program[Model, Msg],
  on_start : (ProgramHandle[Msg]) -> Unit,
) -> RunResult[Model] {
  run_internal(program, on_start)
}

///|
#cfg(not(any(target="native", target="llvm")))
fn[Model, Msg] run_internal(
  program : Program[Model, Msg],
  on_start : (ProgramHandle[Msg]) -> Unit,
) -> RunResult[Model] {
  let init_res = (program.init)()
  on_start(
    ProgramHandle::new(
      @queue.Queue([]),
      @queue.Queue([]),
      fn() { () },
      Ref(true),
    ),
  )
  RunCompleted(init_res.model)
}

///|
/// Active one-shot timer managed by the runtime.
#cfg(any(target="native", target="llvm"))
priv enum RuntimeTimer[Msg] {
  TickAt(Int64)
  AfterAt(Int64, () -> Msg?)
  EveryAt(Int64, Int64, (TimerTick) -> Msg)
}

///|
#cfg(any(target="native", target="llvm"))
priv enum RuntimeScreenCommand {
  RuntimeEnterAltScreen
  RuntimeExitAltScreen
  RuntimeClearScreen
  RuntimeRepaint
  RuntimeForceRedraw
  RuntimeHideCursor
  RuntimeShowCursor
}

///|
#cfg(any(target="native", target="llvm"))
priv enum RuntimeTerminalCommand {
  RuntimeRequestDeviceAttributes
  RuntimeRequestSecondaryDeviceAttributes
  RuntimeRequestCursorPosition
  RuntimeRequestForegroundColor
  RuntimeRequestBackgroundColor
  RuntimeRequestCapability(String)
  RuntimeRequestClipboard(ClipboardSelection)
  RuntimeSetFocusReporting(Bool)
  RuntimeSetBracketedPaste(Bool)
}

///|
#cfg(any(target="native", target="llvm"))
priv enum RuntimeEffect[Msg] {
  RuntimeTask(() -> Msg?)
  RuntimeScreen(RuntimeScreenCommand)
  RuntimeTerminal(RuntimeTerminalCommand)
  RuntimeLifecycle(LifecycleMsg)
  RuntimeExec(ExecProcess, (ExecResult) -> Msg)
  RuntimeError(String)
}

///|
#cfg(any(target="native", target="llvm"))
let runtime_print_above_messages : Ref[Array[PrintAboveMessage]] = Ref([])

///|
#cfg(any(target="native", target="llvm"))
fn runtime_enqueue_print_above(message : PrintAboveMessage) -> Unit {
  runtime_print_above_messages.val.push(message)
}

///|
#cfg(not(any(target="native", target="llvm")))
fn runtime_enqueue_print_above(message : PrintAboveMessage) -> Unit {
  ignore(message.message_body)
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_take_print_above_messages() -> Array[PrintAboveMessage] {
  let messages = runtime_print_above_messages.val
  runtime_print_above_messages.val = []
  messages
}

///|
#cfg(any(target="native", target="llvm"))
priv enum RuntimeExitReason {
  RuntimeExitCompleted
  RuntimeExitQuit
  RuntimeExitInterrupted
  RuntimeExitError(String)
  RuntimeExitExec(ExecResult)
}

///|
#cfg(any(target="native", target="llvm"))
priv struct RuntimeRenderState {
  terminal_active : Bool
  alt_screen : Bool
  cursor_hidden : Bool
  focus_reporting : Bool
  bracketed_paste : Bool
  rendered : String
  prev_line_count : Int
  terminal_height : Int
  last_render_ms : Int64
  render_due_at : Int64?
  force_full_repaint : Bool
  render_context : @profile.RenderContext
  view_terminal_state : RuntimeViewTerminalState
}

///|
#cfg(any(target="native", target="llvm"))
priv struct RuntimeTerminalProgress {
  state : Int
  value : Int
} derive(Eq)

///|
#cfg(any(target="native", target="llvm"))
priv struct RuntimeViewTerminalState {
  cursor_position : ViewCursorPosition?
  cursor_visible : Bool?
  window_title : String?
  foreground_color : Color?
  background_color : Color?
  render_context : @profile.RenderContext
  progress : RuntimeTerminalProgress?
  mouse_mode : ViewMouseMode?
} derive(Eq)

///|
#cfg(any(target="native", target="llvm"))
fn runtime_view_terminal_state_empty() -> RuntimeViewTerminalState {
  {
    cursor_position: None,
    cursor_visible: None,
    window_title: None,
    foreground_color: None,
    background_color: None,
    render_context: @profile.RenderContext::default(),
    progress: None,
    mouse_mode: None,
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] runtime_view_terminal_state_for_program(
  program : Program[Model, Msg],
  terminal_active : Bool,
  ctx : @profile.RenderContext,
) -> RuntimeViewTerminalState {
  let state = { ..runtime_view_terminal_state_empty(), render_context: ctx }
  {
    ..state,
    cursor_visible: if terminal_active &&
      program.rendering &&
      program.hide_cursor {
      Some(false)
    } else {
      None
    },
    mouse_mode: if terminal_active &&
      program.rendering &&
      program.read_stdin &&
      program.mouse {
      Some(ViewMousePress)
    } else {
      None
    },
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Msg] timer_deadline(timer : RuntimeTimer[Msg]) -> Int64 {
  match timer {
    TickAt(deadline) => deadline
    AfterAt(deadline, _) => deadline
    EveryAt(deadline, _, _) => deadline
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] initial_render_state(
  program : Program[Model, Msg],
  terminal_active : Bool,
) -> RuntimeRenderState {
  let render_context = @profile.RenderContext::detect()
  @profile.set_render_context(render_context)
  {
    terminal_active,
    alt_screen: program.alt_screen,
    cursor_hidden: program.hide_cursor,
    focus_reporting: terminal_active &&
    program.read_stdin &&
    program.focus_reporting,
    bracketed_paste: terminal_active &&
    program.read_stdin &&
    program.bracketed_paste,
    rendered: "",
    prev_line_count: 0,
    terminal_height: current_window_size().height.max(1),
    last_render_ms: 0L,
    render_due_at: None,
    force_full_repaint: false,
    render_context,
    view_terminal_state: runtime_view_terminal_state_for_program(
      program, terminal_active, render_context,
    ),
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] apply_screen_command(
  program : Program[Model, Msg],
  state : RuntimeRenderState,
  command : RuntimeScreenCommand,
) -> RuntimeRenderState {
  match command {
    RuntimeEnterAltScreen =>
      if state.alt_screen {
        state
      } else {
        if state.terminal_active && program.rendering {
          emit_output(program, enter_alt_screen())
        }
        {
          ..state,
          alt_screen: true,
          rendered: "",
          prev_line_count: 0,
          render_due_at: None,
        }
      }
    RuntimeExitAltScreen =>
      if !state.alt_screen {
        state
      } else {
        if state.terminal_active && program.rendering {
          emit_output(program, exit_alt_screen())
        }
        {
          ..state,
          alt_screen: false,
          rendered: "",
          prev_line_count: 0,
          render_due_at: None,
        }
      }
    RuntimeClearScreen => {
      if state.terminal_active && program.rendering {
        emit_output(program, clear_screen() + move_cursor(1, 1))
      }
      {
        ..state,
        rendered: "",
        prev_line_count: 0,
        render_due_at: None,
        view_terminal_state: {
          ..state.view_terminal_state,
          cursor_position: None,
        },
      }
    }
    RuntimeRepaint =>
      {
        ..state,
        force_full_repaint: true,
        render_due_at: None,
        view_terminal_state: {
          ..state.view_terminal_state,
          cursor_position: None,
        },
      }
    RuntimeForceRedraw =>
      {
        ..state,
        force_full_repaint: true,
        render_due_at: None,
        view_terminal_state: {
          ..state.view_terminal_state,
          cursor_position: None,
        },
      }
    RuntimeHideCursor =>
      if state.cursor_hidden {
        {
          ..state,
          view_terminal_state: {
            ..state.view_terminal_state,
            cursor_visible: Some(false),
          },
        }
      } else {
        if state.terminal_active && program.rendering {
          emit_output(program, hide_cursor())
        }
        {
          ..state,
          cursor_hidden: true,
          view_terminal_state: {
            ..state.view_terminal_state,
            cursor_visible: Some(false),
          },
        }
      }
    RuntimeShowCursor =>
      if !state.cursor_hidden {
        {
          ..state,
          view_terminal_state: {
            ..state.view_terminal_state,
            cursor_visible: Some(true),
          },
        }
      } else {
        if state.terminal_active && program.rendering {
          emit_output(program, show_cursor())
        }
        {
          ..state,
          cursor_hidden: false,
          view_terminal_state: {
            ..state.view_terminal_state,
            cursor_visible: Some(true),
          },
        }
      }
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn terminal_command_sequence(command : RuntimeTerminalCommand) -> String {
  match command {
    RuntimeRequestDeviceAttributes => request_device_attributes()
    RuntimeRequestSecondaryDeviceAttributes =>
      request_secondary_device_attributes()
    RuntimeRequestCursorPosition => request_cursor_position()
    RuntimeRequestForegroundColor => request_foreground_color()
    RuntimeRequestBackgroundColor => request_background_color()
    RuntimeRequestCapability(name) => request_capability(name)
    RuntimeRequestClipboard(selection) => request_clipboard(selection)
    RuntimeSetFocusReporting(true) => enable_focus_reporting()
    RuntimeSetFocusReporting(false) => disable_focus_reporting()
    RuntimeSetBracketedPaste(true) => enable_bracketed_paste()
    RuntimeSetBracketedPaste(false) => disable_bracketed_paste()
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] apply_terminal_command(
  program : Program[Model, Msg],
  state : RuntimeRenderState,
  command : RuntimeTerminalCommand,
) -> RuntimeRenderState {
  if state.terminal_active {
    emit_output(program, terminal_command_sequence(command))
  }
  match command {
    RuntimeSetFocusReporting(enabled) => { ..state, focus_reporting: enabled }
    RuntimeSetBracketedPaste(enabled) => { ..state, bracketed_paste: enabled }
    _ => state
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_hex_value(ch : Char) -> Int? {
  if ch >= '0' && ch <= '9' {
    Some(ch.to_int() - '0'.to_int())
  } else if ch >= 'a' && ch <= 'f' {
    Some(ch.to_int() - 'a'.to_int() + 10)
  } else if ch >= 'A' && ch <= 'F' {
    Some(ch.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_parse_rgb_component(part : StringView) -> Int? {
  let width = part.length()
  if width < 1 || width > 4 {
    return None
  }
  let mut value = 0
  for ch in part {
    match runtime_hex_value(ch) {
      Some(digit) => value = value * 16 + digit
      None => return None
    }
  }
  let max_value = (1 << (width * 4)) - 1
  Some(value * 255 / max_value)
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_background_from_osc11(payload : String) -> @profile.Background? {
  if !payload.has_prefix("rgb:") {
    return None
  }
  let parts : Array[StringView] = payload[:][4:].split("/").collect()
  if parts.length() != 3 {
    return None
  }
  let r = match runtime_parse_rgb_component(parts[0]) {
    Some(value) => value
    None => return None
  }
  let g = match runtime_parse_rgb_component(parts[1]) {
    Some(value) => value
    None => return None
  }
  let b = match runtime_parse_rgb_component(parts[2]) {
    Some(value) => value
    None => return None
  }
  let luminance = 0.2126 * (r.to_double() / 255.0) +
    0.7152 * (g.to_double() / 255.0) +
    0.0722 * (b.to_double() / 255.0)
  if luminance > 0.5 {
    Some(@profile.Light)
  } else {
    Some(@profile.Dark)
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_profile_rank(profile : @profile.ColorProfile) -> Int {
  match profile {
    NoColor => 0
    Ansi16 => 1
    Ansi256 => 2
    TrueColor => 3
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_max_profile(
  current : @profile.ColorProfile,
  floor : @profile.ColorProfile,
) -> @profile.ColorProfile {
  if runtime_profile_rank(current) >= runtime_profile_rank(floor) {
    current
  } else {
    floor
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_context_apply_capability(
  ctx : @profile.RenderContext,
  reply : CapabilityReply,
) -> @profile.RenderContext {
  if !reply.valid {
    return ctx
  }
  match reply.name {
    "Tc" | "RGB" => ctx.with_color_profile(@profile.TrueColor)
    "Co" =>
      match reply.value {
        Some(value) => {
          let colors = @string.parse_int(value[:], base=10) catch {
            _ => return ctx
          }
          if colors >= 256 {
            ctx.with_color_profile(
              runtime_max_profile(ctx.color_profile, @profile.Ansi256),
            )
          } else if colors >= 8 {
            ctx.with_color_profile(
              runtime_max_profile(ctx.color_profile, @profile.Ansi16),
            )
          } else {
            ctx
          }
        }
        None => ctx
      }
    _ => ctx
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_context_apply_event(
  ctx : @profile.RenderContext,
  event : InputEvent,
) -> @profile.RenderContext {
  match event {
    TerminalReply(Color(BackgroundColor(payload))) =>
      match runtime_background_from_osc11(payload) {
        Some(background) => ctx.with_background(background)
        None => ctx
      }
    TerminalReply(Capability(reply)) =>
      runtime_context_apply_capability(ctx, reply)
    _ => ctx
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_apply_render_context_events(
  state : RuntimeRenderState,
  events : Array[InputEvent],
) -> (RuntimeRenderState, Bool) {
  let original = state.render_context
  let mut ctx = original
  for event in events {
    ctx = runtime_context_apply_event(ctx, event)
  }
  if ctx == original {
    (state, false)
  } else {
    @profile.set_render_context(ctx)
    ({ ..state, render_context: ctx, force_full_repaint: true }, true)
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn progress_value(value : Int?) -> Int {
  match value {
    Some(n) => n.max(0).min(100)
    None => 0
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn view_progress_state(progress : ViewProgress?) -> RuntimeTerminalProgress? {
  match progress {
    None | Some(ViewProgressNone) => None
    Some(ViewProgressIndeterminate) => Some({ state: 3, value: 0 })
    Some(ViewProgressPercent(value)) =>
      Some({ state: 1, value: progress_value(Some(value)) })
    Some(ViewProgressPaused(value)) =>
      Some({ state: 4, value: progress_value(value) })
    Some(ViewProgressError(value)) =>
      Some({ state: 2, value: progress_value(value) })
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn view_progress_sequence(progress : RuntimeTerminalProgress) -> String {
  set_terminal_progress(progress.state, progress.value)
}

///|
#cfg(any(target="native", target="llvm"))
fn view_mouse_state(mouse_mode : ViewMouseMode?) -> ViewMouseMode? {
  match mouse_mode {
    Some(ViewMousePress) => Some(ViewMousePress)
    Some(ViewMouseAllMotion) => Some(ViewMouseAllMotion)
    Some(ViewMouseOff) | None => None
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn mouse_mode_transition(
  previous : ViewMouseMode?,
  next : ViewMouseMode?,
) -> String {
  match next {
    None => disable_mouse()
    Some(ViewMouseOff) => disable_mouse()
    Some(ViewMousePress) =>
      match previous {
        Some(ViewMouseAllMotion) => "\{CSI}?1003l" + enable_mouse()
        _ => enable_mouse()
      }
    Some(ViewMouseAllMotion) =>
      match previous {
        Some(ViewMousePress) => "\{CSI}?1000l" + enable_mouse_motion()
        _ => enable_mouse_motion()
      }
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn view_terminal_state_from_view(
  view : View,
  ctx : @profile.RenderContext,
) -> RuntimeViewTerminalState {
  {
    cursor_position: view.cursor_position,
    cursor_visible: view.cursor_visible,
    window_title: view.window_title,
    foreground_color: view.foreground_color,
    background_color: view.background_color,
    render_context: ctx,
    progress: view_progress_state(view.progress),
    mouse_mode: view_mouse_state(view.mouse_mode),
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn view_terminal_state_delta(
  applied : RuntimeViewTerminalState,
  view : View,
  ctx : @profile.RenderContext,
) -> (String, RuntimeViewTerminalState) {
  let next = view_terminal_state_from_view(view, ctx)
  let context_changed = ctx != applied.render_context
  let prefix = StringBuilder::new()
  if next.window_title != applied.window_title {
    match next.window_title {
      Some(title) => prefix.write_string(set_window_title(title))
      None =>
        if applied.window_title is Some(_) {
          prefix.write_string(clear_window_title())
        }
    }
  }
  if next.foreground_color != applied.foreground_color ||
    (context_changed && next.foreground_color is Some(_)) {
    match next.foreground_color {
      Some(color) => prefix.write_string(foreground_sequence(ctx, color))
      None =>
        if applied.foreground_color is Some(_) {
          prefix.write_string(reset_foreground_color())
        }
    }
  }
  if next.background_color != applied.background_color ||
    (context_changed && next.background_color is Some(_)) {
    match next.background_color {
      Some(color) => prefix.write_string(background_sequence(ctx, color))
      None =>
        if applied.background_color is Some(_) {
          prefix.write_string(reset_background_color())
        }
    }
  }
  if next.progress != applied.progress {
    match next.progress {
      Some(progress) => prefix.write_string(view_progress_sequence(progress))
      None =>
        if applied.progress is Some(_) {
          prefix.write_string(clear_terminal_progress())
        }
    }
  }
  if next.mouse_mode != applied.mouse_mode {
    prefix.write_string(
      mouse_mode_transition(applied.mouse_mode, next.mouse_mode),
    )
  }
  if next.cursor_visible != applied.cursor_visible {
    match next.cursor_visible {
      Some(true) => prefix.write_string(show_cursor())
      Some(false) => prefix.write_string(hide_cursor())
      None => ()
    }
  }
  (prefix.to_string(), next)
}

///|
#cfg(any(target="native", target="llvm"))
fn view_cursor_position_suffix(
  applied : RuntimeViewTerminalState,
  next : RuntimeViewTerminalState,
  content_painted : Bool,
) -> String {
  if next.cursor_position != applied.cursor_position {
    match next.cursor_position {
      Some(pos) => move_cursor(pos.row, pos.col)
      None => ""
    }
  } else if content_painted {
    match next.cursor_position {
      Some(pos) => move_cursor(pos.row, pos.col)
      None => ""
    }
  } else {
    ""
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn terminal_view_reset_sequence() -> String {
  show_cursor() +
  clear_window_title() +
  reset_foreground_color() +
  reset_background_color() +
  clear_terminal_progress() +
  disable_mouse()
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_print_above_lines(
  messages : Array[PrintAboveMessage],
) -> Array[String] {
  let lines : Array[String] = []
  for message in messages {
    if message.message_body != "" {
      for line in split_lines(message.message_body) {
        lines.push(line)
      }
    }
  }
  lines
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_print_above_frame_output(
  lines : Array[String],
  prev_line_count : Int,
  current_content : String,
  terminal_height : Int,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string(render_full("", prev_line_count))
  buf.write_string(move_cursor(terminal_height.max(1), 1))
  for line in lines {
    buf.write_string(line)
    buf.write_string(clear_line())
    buf.write_string("\r\n")
  }
  buf.write_string(render_full(current_content, 0))
  buf.to_string()
}

///|
#cfg(any(target="native", target="llvm"))
fn runtime_render_state_with_window_size(
  state : RuntimeRenderState,
  size : WindowSize,
) -> RuntimeRenderState {
  { ..state, terminal_height: size.height.max(1) }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] apply_print_above_messages(
  program : Program[Model, Msg],
  state : RuntimeRenderState,
  model : Model,
) -> RuntimeRenderState {
  let lines = runtime_print_above_lines(runtime_take_print_above_messages())
  if lines.is_empty() ||
    !state.terminal_active ||
    !program.rendering ||
    state.alt_screen {
    state
  } else {
    let current_view = desired_view(program, model)
    let (terminal_prefix, next_terminal_state) = view_terminal_state_delta(
      state.view_terminal_state,
      current_view,
      state.render_context,
    )
    let frame_output = runtime_print_above_frame_output(
      lines,
      state.prev_line_count,
      current_view.content,
      state.terminal_height,
    )
    let terminal_suffix = view_cursor_position_suffix(
      state.view_terminal_state,
      next_terminal_state,
      true,
    )
    let output = terminal_prefix + frame_output + terminal_suffix
    let output = if program.synchronized_output && output != "" {
      begin_sync_update() + output + end_sync_update()
    } else {
      output
    }
    emit_output(program, output)
    let now = runtime_now_ms()
    {
      ..state,
      rendered: current_view.content,
      prev_line_count: line_count(current_view.content),
      last_render_ms: render_cadence_mark_at_or_before(program, now),
      render_due_at: None,
      force_full_repaint: false,
      view_terminal_state: next_terminal_state,
    }
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn next_aligned_every_deadline(now : Int64, interval_ms : Int) -> Int64 {
  let interval = interval_ms.to_int64()
  let elapsed = now.max(0L)
  (elapsed / interval + 1L) * interval
}

///|
#cfg(any(target="native", target="llvm"))
fn[Msg] queue_cmd_effects(
  cmd : Cmd[Msg],
  now : Int64,
  pending : @queue.Queue[RuntimeEffect[Msg]],
  timers : Array[RuntimeTimer[Msg]],
  sequences : @deque.Deque[Array[Cmd[Msg]]],
) -> Unit {
  for action in cmd.actions {
    match action {
      Perform(task) => pending.push(RuntimeTask(task))
      Tick(interval_ms) =>
        if interval_ms > 0 {
          timers.push(TickAt(now + interval_ms.to_int64()))
        }
      After(interval_ms, task) => {
        let ms = if interval_ms > 0 { interval_ms } else { 1 }
        timers.push(AfterAt(now + ms.to_int64(), fn() { Some(task()) }))
      }
      Every(interval_ms, task) => {
        let ms = if interval_ms > 0 { interval_ms } else { 1 }
        timers.push(EveryAt(next_aligned_every_deadline(now, ms), now, task))
      }
      EnterAltScreen => pending.push(RuntimeScreen(RuntimeEnterAltScreen))
      ExitAltScreen => pending.push(RuntimeScreen(RuntimeExitAltScreen))
      ClearScreen => pending.push(RuntimeScreen(RuntimeClearScreen))
      Repaint => pending.push(RuntimeScreen(RuntimeRepaint))
      ForceRedraw => pending.push(RuntimeScreen(RuntimeForceRedraw))
      HideCursor => pending.push(RuntimeScreen(RuntimeHideCursor))
      ShowCursor => pending.push(RuntimeScreen(RuntimeShowCursor))
      RequestWindowSize(task) =>
        pending.push(RuntimeTask(fn() { Some(task(current_window_size())) }))
      RequestDeviceAttributes =>
        pending.push(RuntimeTerminal(RuntimeRequestDeviceAttributes))
      RequestSecondaryDeviceAttributes =>
        pending.push(RuntimeTerminal(RuntimeRequestSecondaryDeviceAttributes))
      RequestCursorPosition =>
        pending.push(RuntimeTerminal(RuntimeRequestCursorPosition))
      RequestForegroundColor =>
        pending.push(RuntimeTerminal(RuntimeRequestForegroundColor))
      RequestBackgroundColor =>
        pending.push(RuntimeTerminal(RuntimeRequestBackgroundColor))
      RequestCapability(name) =>
        pending.push(RuntimeTerminal(RuntimeRequestCapability(name)))
      RequestClipboard(selection) =>
        pending.push(RuntimeTerminal(RuntimeRequestClipboard(selection)))
      SetFocusReporting(enabled) =>
        pending.push(RuntimeTerminal(RuntimeSetFocusReporting(enabled)))
      SetBracketedPaste(enabled) =>
        pending.push(RuntimeTerminal(RuntimeSetBracketedPaste(enabled)))
      LifecycleAction(msg) => pending.push(RuntimeLifecycle(msg))
      ExecProcessAction(process, to_msg) =>
        pending.push(RuntimeExec(process, to_msg))
      RuntimeErrorAction(message) => pending.push(RuntimeError(message))
      Sequence(cmds) =>
        match cmds {
          [] => ()
          [head, .. tail] => {
            queue_cmd_effects(head, now, pending, timers, sequences)
            if !tail.is_empty() {
              sequences.push_back(tail.to_owned())
            }
          }
        }
    }
  }
}

///|
/// Compute the poll timeout from the earliest timer deadline. Returns -1 if
/// no timers are active (block indefinitely).
#cfg(any(target="native", target="llvm"))
fn[Msg] timers_timeout(timers : Array[RuntimeTimer[Msg]]) -> Int {
  let mut min_deadline : Int64? = None
  for timer in timers {
    match min_deadline {
      None => min_deadline = Some(timer_deadline(timer))
      Some(m) => {
        let deadline = timer_deadline(timer)
        if deadline < m {
          min_deadline = Some(deadline)
        }
      }
    }
  }
  match min_deadline {
    Some(deadline) => {
      let remaining = deadline - runtime_now_ms()
      if remaining < 0L {
        0
      } else {
        remaining.to_int()
      }
    }
    None => -1
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] queue_due_timers(
  program : Program[Model, Msg],
  now : Int64,
  timers : Array[RuntimeTimer[Msg]],
  pending : @queue.Queue[RuntimeEffect[Msg]],
) -> Array[RuntimeTimer[Msg]] {
  let remaining : Array[RuntimeTimer[Msg]] = []
  for timer in timers {
    if timer_deadline(timer) <= now {
      match timer {
        TickAt(_) => pending.push(RuntimeTask(program.on_tick))
        AfterAt(_, task) => pending.push(RuntimeTask(task))
        EveryAt(_, scheduled_at, task) => {
          let elapsed = now - scheduled_at
          pending.push(
            RuntimeTask(fn() { Some(task({ elapsed_ms: elapsed })) }),
          )
        }
      }
    } else {
      remaining.push(timer)
    }
  }
  remaining
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] runtime_timeout_ms(
  program : Program[Model, Msg],
  timers : Array[RuntimeTimer[Msg]],
  render_due_at : Int64?,
) -> Int {
  let mut timeout = timers_timeout(timers)
  match render_due_at {
    Some(deadline) => {
      let remaining = (deadline - runtime_now_ms()).max(0L).to_int()
      if timeout < 0 || remaining < timeout {
        timeout = remaining
      }
    }
    None => ()
  }
  let needs_polling = program.input is Some(_) ||
    program.raw_input is Some(_) ||
    program.cancelled is Some(_)
  if needs_polling && (timeout < 0 || timeout > 16) {
    16
  } else {
    timeout
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] poll_input_events(
  program : Program[Model, Msg],
) -> Array[InputEvent] {
  match program.input {
    Some(input) => input()
    None => []
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] poll_raw_input_events(
  program : Program[Model, Msg],
  leftover : Array[Byte],
) -> (Array[InputEvent], Array[Byte]) {
  match program.raw_input {
    Some(raw_input) => {
      let raw = raw_input()
      if raw.length() == 0 && leftover.is_empty() {
        ([], leftover)
      } else {
        let combined = if leftover.is_empty() {
          raw.to_array()
        } else {
          [..leftover, ..raw.to_array()]
        }
        let bytes = Bytes::from_array(combined)
        let (events, next_leftover) = parse_all(bytes[:])
        (events, next_leftover.to_array())
      }
    }
    None => ([], leftover)
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] is_cancelled(program : Program[Model, Msg]) -> Bool {
  match program.cancelled {
    Some(cancelled) => cancelled()
    None => false
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] apply_window_size(
  program : Program[Model, Msg],
  model : Model,
  size : WindowSize,
  pending : @queue.Queue[RuntimeEffect[Msg]],
  timers : Array[RuntimeTimer[Msg]],
  sequences : @deque.Deque[Array[Cmd[Msg]]],
) -> (Model, RuntimeExitReason?, Bool) {
  let mut current_model = model
  let mut reason : RuntimeExitReason? = None
  let mut updated = false
  match (program.on_window_size)(size) {
    Some(msg) => {
      let (next_model, should_quit, cmd) = apply_msg(
        program, current_model, msg,
      )
      current_model = next_model
      queue_cmd_effects(cmd, runtime_now_ms(), pending, timers, sequences)
      updated = true
      if should_quit {
        reason = Some(RuntimeExitQuit)
      }
    }
    None => ()
  }
  match (program.on_resize)(size.width, size.height) {
    Some(msg) => {
      let (next_model, should_quit, cmd) = apply_msg(
        program, current_model, msg,
      )
      current_model = next_model
      queue_cmd_effects(cmd, runtime_now_ms(), pending, timers, sequences)
      updated = true
      if should_quit {
        reason = Some(RuntimeExitQuit)
      }
    }
    None => ()
  }
  (current_model, reason, updated)
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] apply_initial_window_size(
  program : Program[Model, Msg],
  model : Model,
  pending : @queue.Queue[RuntimeEffect[Msg]],
  timers : Array[RuntimeTimer[Msg]],
  sequences : @deque.Deque[Array[Cmd[Msg]]],
) -> (Model, RuntimeExitReason?, Bool) {
  match maybe_initial_window_size(program) {
    Some(size) =>
      apply_window_size(program, model, size, pending, timers, sequences)
    None => (model, None, false)
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] apply_msg(
  program : Program[Model, Msg],
  model : Model,
  msg : Msg,
) -> (Model, Bool, Cmd[Msg]) {
  let res = (program.update)(model, msg)
  (res.model, (program.should_quit)(res.model), res.cmd)
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] apply_lifecycle_msg(
  program : Program[Model, Msg],
  model : Model,
  msg : LifecycleMsg,
) -> (Model, Bool, Cmd[Msg], Bool) {
  match (program.on_lifecycle)(msg) {
    Some(app_msg) => {
      let (next_model, should_quit, cmd) = apply_msg(program, model, app_msg)
      (next_model, should_quit, cmd, true)
    }
    None => (model, false, Cmd::none(), false)
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Msg] queue_startup_color_detection(
  pending : @queue.Queue[RuntimeEffect[Msg]],
) -> Unit {
  pending.push(RuntimeTerminal(RuntimeRequestBackgroundColor))
  pending.push(RuntimeTerminal(RuntimeRequestCapability("Co")))
  pending.push(RuntimeTerminal(RuntimeRequestCapability("RGB")))
  pending.push(RuntimeTerminal(RuntimeRequestCapability("Tc")))
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model] run_result_from_reason(
  model : Model,
  reason : RuntimeExitReason,
) -> RunResult[Model] {
  match reason {
    RuntimeExitCompleted => RunCompleted(model)
    RuntimeExitQuit => RunQuit(model)
    RuntimeExitInterrupted => RunInterrupted(model)
    RuntimeExitError(message) => RunRuntimeError(message)
    RuntimeExitExec(result) => RunExec(model, result)
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] apply_input_events(
  program : Program[Model, Msg],
  model : Model,
  events : Array[InputEvent],
  pending : @queue.Queue[RuntimeEffect[Msg]],
  timers : Array[RuntimeTimer[Msg]],
  sequences : @deque.Deque[Array[Cmd[Msg]]],
) -> (Model, RuntimeExitReason?, Bool) {
  let mut current_model = model
  let mut reason : RuntimeExitReason? = None
  let mut updated = false
  for evt in events {
    let mut deliver_to_sub = true
    let mut stop_input = false
    match evt {
      Key(Modified("ctrl", "z")) => {
        pending.push(RuntimeLifecycle(Suspend))
        deliver_to_sub = false
        stop_input = true
      }
      _ => ()
    }
    if program.catch_interrupt {
      match evt {
        Key(Modified("ctrl", "c")) => {
          let (next_model, should_quit, cmd, lifecycle_updated) = apply_lifecycle_msg(
            program,
            current_model,
            Interrupt,
          )
          current_model = next_model
          queue_cmd_effects(cmd, runtime_now_ms(), pending, timers, sequences)
          if lifecycle_updated {
            updated = true
          }
          ignore(should_quit)
          reason = Some(RuntimeExitInterrupted)
          deliver_to_sub = false
        }
        _ => ()
      }
    }
    if deliver_to_sub {
      match (program.sub)(evt) {
        Some(msg) => {
          let (next_model, should_quit, cmd) = apply_msg(
            program, current_model, msg,
          )
          current_model = next_model
          queue_cmd_effects(cmd, runtime_now_ms(), pending, timers, sequences)
          updated = true
          if should_quit && reason is None {
            reason = Some(RuntimeExitQuit)
          }
        }
        None => ()
      }
    }
    if reason is Some(_) || stop_input {
      break
    }
  }
  (current_model, reason, updated)
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] release_terminal_state(
  program : Program[Model, Msg],
  state : RuntimeRenderState,
) -> RuntimeRenderState {
  if state.terminal_active {
    if state.alt_screen == program.alt_screen &&
      state.cursor_hidden == program.hide_cursor &&
      state.focus_reporting == (program.read_stdin && program.focus_reporting) &&
      state.bracketed_paste == (program.read_stdin && program.bracketed_paste) {
      deactivate_terminal(program)
    } else {
      deactivate_terminal_with_modes(
        program,
        state.alt_screen,
        state.cursor_hidden,
        state.focus_reporting,
        state.bracketed_paste,
      )
    }
    {
      ..state,
      terminal_active: false,
      rendered: "",
      prev_line_count: 0,
      render_due_at: None,
      force_full_repaint: false,
      view_terminal_state: {
        ..runtime_view_terminal_state_empty(),
        render_context: state.render_context,
      },
    }
  } else {
    state
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] restore_terminal_state(
  program : Program[Model, Msg],
  state : RuntimeRenderState,
  current_view : View,
) -> RuntimeRenderState {
  if !state.terminal_active {
    let mut next_state = state
    if state.alt_screen == program.alt_screen &&
      state.cursor_hidden == program.hide_cursor &&
      state.focus_reporting == (program.read_stdin && program.focus_reporting) &&
      state.bracketed_paste == (program.read_stdin && program.bracketed_paste) {
      activate_terminal(program)
    } else {
      activate_terminal_with_modes(
        program,
        state.alt_screen,
        state.cursor_hidden,
        state.focus_reporting,
        state.bracketed_paste,
      )
    }
    next_state = { ..next_state, terminal_active: true }
    if program.rendering {
      let (
        next_rendered,
        next_line_count,
        next_last_render_ms,
        next_render_due_at,
        next_view_terminal_state,
      ) = flush_view(
        program,
        "",
        current_view,
        0,
        runtime_view_terminal_state_for_program(
          program,
          true,
          state.render_context,
        ),
        true,
        0L,
        true,
        true,
        render_context=state.render_context,
      )
      next_state = {
        ..next_state,
        rendered: next_rendered,
        prev_line_count: next_line_count,
        last_render_ms: next_last_render_ms,
        render_due_at: next_render_due_at,
        force_full_repaint: false,
        view_terminal_state: next_view_terminal_state,
      }
    }
    next_state
  } else {
    state
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] drain_controls(
  program : Program[Model, Msg],
  pending_controls : @queue.Queue[RuntimeControl],
  state : RuntimeRenderState,
  current_view : View,
) -> RuntimeRenderState {
  let mut next_state = state
  while !pending_controls.is_empty() {
    match pending_controls.pop() {
      Some(ReleaseTerminal) =>
        next_state = release_terminal_state(program, next_state)
      Some(RestoreTerminal) =>
        next_state = restore_terminal_state(program, next_state, current_view)
      None => ()
    }
  }
  next_state
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] desired_view(
  program : Program[Model, Msg],
  model : Model,
) -> View {
  if program.rendering {
    match program.structured_view {
      Some(structured_view) => structured_view(model)
      None => View::text((program.view)(model))
    }
  } else {
    View::text("")
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] flush_view(
  program : Program[Model, Msg],
  rendered_view : String,
  next_view : View,
  prev_line_count : Int,
  applied_terminal_state : RuntimeViewTerminalState,
  terminal_active : Bool,
  last_render_ms : Int64,
  force : Bool,
  full_repaint : Bool,
  render_context? : @profile.RenderContext = applied_terminal_state.render_context,
) -> (String, Int, Int64, Int64?, RuntimeViewTerminalState) {
  let next_content = next_view.content
  if !program.rendering || !terminal_active {
    (
      rendered_view,
      prev_line_count,
      last_render_ms,
      None,
      applied_terminal_state,
    )
  } else {
    let (terminal_prefix, next_terminal_state) = view_terminal_state_delta(
      applied_terminal_state, next_view, render_context,
    )
    let terminal_changed = next_terminal_state != applied_terminal_state
    let content_changed = full_repaint || next_content != rendered_view
    if !content_changed && !terminal_changed {
      return (
        rendered_view,
        prev_line_count,
        last_render_ms,
        None,
        applied_terminal_state,
      )
    }
    let now = runtime_now_ms()
    let next_render_deadline = next_render_deadline_after(
      program, last_render_ms,
    )
    if force || terminal_changed || now >= next_render_deadline {
      let content_output = if content_changed {
        let ops = diff_views(rendered_view, next_content)
        if full_repaint || ops.is_empty() {
          render_full(next_content, prev_line_count)
        } else {
          render_patch(ops)
        }
      } else {
        ""
      }
      let terminal_suffix = view_cursor_position_suffix(
        applied_terminal_state,
        next_terminal_state,
        content_output != "",
      )
      let output = terminal_prefix + content_output + terminal_suffix
      let output = if program.synchronized_output && output != "" {
        begin_sync_update() + output + end_sync_update()
      } else {
        output
      }
      emit_output(program, output)
      (
        if content_changed {
          next_content
        } else {
          rendered_view
        },
        if content_changed {
          line_count(next_content)
        } else {
          prev_line_count
        },
        if content_changed {
          render_cadence_mark_at_or_before(program, now)
        } else {
          last_render_ms
        },
        None,
        next_terminal_state,
      )
    } else {
      (
        rendered_view,
        prev_line_count,
        last_render_ms,
        Some(next_render_deadline),
        applied_terminal_state,
      )
    }
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] drain_runtime(
  program : Program[Model, Msg],
  model : Model,
  state : RuntimeRenderState,
  sent_msgs : @queue.Queue[Msg],
  pending : @queue.Queue[RuntimeEffect[Msg]],
  timers : Array[RuntimeTimer[Msg]],
  sequences : @deque.Deque[Array[Cmd[Msg]]],
) -> (Model, RuntimeExitReason?, Bool, RuntimeRenderState) {
  let mut current_model = model
  let mut current_state = state
  let mut reason : RuntimeExitReason? = None
  let mut updated = false
  while reason is None {
    let mut progressed = false

    while reason is None && !sent_msgs.is_empty() {
      let msg = sent_msgs.pop().unwrap()
      let (next_model, should_quit, cmd) = apply_msg(
        program, current_model, msg,
      )
      current_model = next_model
      updated = true
      progressed = true
      queue_cmd_effects(cmd, runtime_now_ms(), pending, timers, sequences)
      if should_quit {
        reason = Some(RuntimeExitQuit)
      }
    }

    while reason is None && !pending.is_empty() {
      let effect = pending.pop().unwrap()
      progressed = true
      match effect {
        RuntimeTask(task) => {
          match task() {
            Some(msg) => {
              let (next_model, should_quit, cmd) = apply_msg(
                program, current_model, msg,
              )
              current_model = next_model
              updated = true
              queue_cmd_effects(
                cmd,
                runtime_now_ms(),
                pending,
                timers,
                sequences,
              )
              if should_quit {
                reason = Some(RuntimeExitQuit)
              }
            }
            None => ()
          }
          current_state = apply_print_above_messages(
            program, current_state, current_model,
          )
        }
        RuntimeScreen(command) =>
          current_state = apply_screen_command(program, current_state, command)
        RuntimeTerminal(command) =>
          current_state = apply_terminal_command(
            program, current_state, command,
          )
        RuntimeLifecycle(msg) =>
          match msg {
            Quit => {
              let (next_model, _should_quit, cmd, lifecycle_updated) = apply_lifecycle_msg(
                program,
                current_model,
                Quit,
              )
              current_model = next_model
              if lifecycle_updated {
                updated = true
              }
              queue_cmd_effects(
                cmd,
                runtime_now_ms(),
                pending,
                timers,
                sequences,
              )
              reason = Some(RuntimeExitQuit)
            }
            Interrupt => {
              let (next_model, _should_quit, cmd, lifecycle_updated) = apply_lifecycle_msg(
                program,
                current_model,
                Interrupt,
              )
              current_model = next_model
              if lifecycle_updated {
                updated = true
              }
              queue_cmd_effects(
                cmd,
                runtime_now_ms(),
                pending,
                timers,
                sequences,
              )
              reason = Some(RuntimeExitInterrupted)
            }
            Suspend => {
              let (suspend_model, suspend_quit, suspend_cmd, suspend_updated) = apply_lifecycle_msg(
                program,
                current_model,
                Suspend,
              )
              current_model = suspend_model
              if suspend_updated {
                updated = true
              }
              queue_cmd_effects(
                suspend_cmd,
                runtime_now_ms(),
                pending,
                timers,
                sequences,
              )
              if suspend_quit {
                reason = Some(RuntimeExitQuit)
              } else {
                let current_view = desired_view(program, current_model)
                current_state = release_terminal_state(program, current_state)
                (program.suspend_runner)()
                current_state = restore_terminal_state(
                  program, current_state, current_view,
                )
                let (resume_model, resume_quit, resume_cmd, resume_updated) = apply_lifecycle_msg(
                  program,
                  current_model,
                  Resume,
                )
                current_model = resume_model
                if resume_updated {
                  updated = true
                }
                queue_cmd_effects(
                  resume_cmd,
                  runtime_now_ms(),
                  pending,
                  timers,
                  sequences,
                )
                if resume_quit {
                  reason = Some(RuntimeExitQuit)
                }
              }
            }
            Resume => {
              let (next_model, should_quit, cmd, lifecycle_updated) = apply_lifecycle_msg(
                program,
                current_model,
                Resume,
              )
              current_model = next_model
              if lifecycle_updated {
                updated = true
              }
              queue_cmd_effects(
                cmd,
                runtime_now_ms(),
                pending,
                timers,
                sequences,
              )
              if should_quit {
                reason = Some(RuntimeExitQuit)
              }
            }
          }
        RuntimeExec(process, to_msg) => {
          let current_view = desired_view(program, current_model)
          let was_active = current_state.terminal_active
          if was_active {
            current_state = release_terminal_state(program, current_state)
          }
          let exec_result = (program.exec_runner)(process)
          if was_active {
            current_state = restore_terminal_state(
              program, current_state, current_view,
            )
          }
          let (next_model, should_quit, cmd) = apply_msg(
            program,
            current_model,
            to_msg(exec_result),
          )
          current_model = next_model
          updated = true
          queue_cmd_effects(cmd, runtime_now_ms(), pending, timers, sequences)
          if should_quit {
            reason = Some(RuntimeExitExec(exec_result))
          }
        }
        RuntimeError(message) => reason = Some(RuntimeExitError(message))
      }
    }

    if reason is Some(_) {
      break
    }

    if pending.is_empty() && sent_msgs.is_empty() {
      match sequences.pop_front() {
        Some([head, .. tail]) => {
          queue_cmd_effects(head, runtime_now_ms(), pending, timers, sequences)
          if !tail.is_empty() {
            sequences.push_back(tail.to_owned())
          }
          progressed = true
        }
        Some([]) => progressed = true
        None => ()
      }
    }

    if !progressed {
      break
    }
  }
  (current_model, reason, updated, current_state)
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] run_internal(
  program : Program[Model, Msg],
  on_start : (ProgramHandle[Msg]) -> Unit,
) -> RunResult[Model] {
  pippa_init_wakeup()
  defer pippa_close_wakeup()

  let init_res = (program.init)()
  let mut model = init_res.model
  let sent_msgs = @queue.Queue([])
  let pending_controls = @queue.Queue([])
  let handle_closed = Ref(false)
  let handle = ProgramHandle::new(
    sent_msgs, pending_controls, pippa_signal_wakeup, handle_closed,
  )
  let pending = @queue.Queue([])
  let sequences = @deque.Deque([])
  let mut timers : Array[RuntimeTimer[Msg]] = []
  queue_cmd_effects(init_res.cmd, runtime_now_ms(), pending, timers, sequences)

  let terminal_active = program.rendering || program.read_stdin
  let mut render_state = initial_render_state(program, terminal_active)
  if render_state.terminal_active {
    activate_terminal(program)
  }
  if render_state.terminal_active && program.read_stdin {
    queue_startup_color_detection(pending)
  }

  let (initial_model, initial_reason, _initial_updated) = apply_initial_window_size(
    program, model, pending, timers, sequences,
  )
  model = initial_model
  let (boot_model, boot_reason, _boot_updated, boot_state) = drain_runtime(
    program, model, render_state, sent_msgs, pending, timers, sequences,
  )
  model = boot_model
  render_state = boot_state

  let mut desired = desired_view(program, model)
  render_state = drain_controls(
    program, pending_controls, render_state, desired,
  )
  let (
    initial_rendered,
    initial_line_count,
    initial_last_render_ms,
    initial_render_due_at,
    initial_view_terminal_state,
  ) = flush_view(
    program,
    render_state.rendered,
    desired,
    render_state.prev_line_count,
    render_state.view_terminal_state,
    render_state.terminal_active,
    render_state.last_render_ms,
    true,
    true,
    render_context=render_state.render_context,
  )
  render_state = {
    ..render_state,
    rendered: initial_rendered,
    prev_line_count: initial_line_count,
    last_render_ms: initial_last_render_ms,
    render_due_at: initial_render_due_at,
    force_full_repaint: false,
    view_terminal_state: initial_view_terminal_state,
  }
  on_start(handle)

  let mut stdin_buf : Array[Byte] = []
  let mut raw_buf : Array[Byte] = []
  let mut exit_reason = match initial_reason {
    Some(reason) => Some(reason)
    None => boot_reason
  }

  while exit_reason is None {
    render_state = drain_controls(
      program, pending_controls, render_state, desired,
    )
    if is_cancelled(program) {
      exit_reason = Some(RuntimeExitCompleted)
      break
    }

    let (drained_model, drained_reason, drained_updated, drained_render_state) = drain_runtime(
      program, model, render_state, sent_msgs, pending, timers, sequences,
    )
    model = drained_model
    render_state = drained_render_state
    match drained_reason {
      Some(reason) => exit_reason = Some(reason)
      None => ()
    }
    if drained_updated || render_state.force_full_repaint {
      desired = desired_view(program, model)
      let (
        next_rendered,
        next_line_count,
        next_last_render_ms,
        next_render_due_at,
        next_view_terminal_state,
      ) = flush_view(
        program,
        render_state.rendered,
        desired,
        render_state.prev_line_count,
        render_state.view_terminal_state,
        render_state.terminal_active,
        render_state.last_render_ms,
        exit_reason is Some(_) || render_state.force_full_repaint,
        render_state.force_full_repaint,
        render_context=render_state.render_context,
      )
      render_state = {
        ..render_state,
        rendered: next_rendered,
        prev_line_count: next_line_count,
        last_render_ms: next_last_render_ms,
        render_due_at: next_render_due_at,
        force_full_repaint: false,
        view_terminal_state: next_view_terminal_state,
      }
    }
    if exit_reason is Some(_) {
      break
    }

    let mut updated = false
    let polled_input_events = poll_input_events(program)
    let (input_context_state, input_context_updated) = runtime_apply_render_context_events(
      render_state, polled_input_events,
    )
    render_state = input_context_state
    if input_context_updated {
      updated = true
    }
    let (input_model, input_reason, input_updated) = apply_input_events(
      program, model, polled_input_events, pending, timers, sequences,
    )
    model = input_model
    match input_reason {
      Some(reason) => exit_reason = Some(reason)
      None => ()
    }
    if input_updated {
      updated = true
    }
    let (raw_events, next_raw_buf) = poll_raw_input_events(program, raw_buf)
    raw_buf = next_raw_buf
    let (raw_context_state, raw_context_updated) = runtime_apply_render_context_events(
      render_state, raw_events,
    )
    render_state = raw_context_state
    if raw_context_updated {
      updated = true
    }
    let (raw_model, raw_reason, raw_updated) = apply_input_events(
      program, model, raw_events, pending, timers, sequences,
    )
    model = raw_model
    match raw_reason {
      Some(reason) => exit_reason = Some(reason)
      None => ()
    }
    if raw_updated {
      updated = true
    }
    if exit_reason is Some(_) {
      break
    }

    if !updated {
      let poll_result = pippa_poll_events(
        runtime_timeout_ms(program, timers, render_state.render_due_at),
        if render_state.terminal_active && program.read_stdin {
          1
        } else {
          0
        },
      )
      if poll_result < 0 {
        exit_reason = Some(RuntimeExitError("poll failed"))
        break
      }

      if poll_result == 0 {
        let now = runtime_now_ms()
        timers = queue_due_timers(program, now, timers, pending)
      } else {
        if (poll_result & 4) != 0 {
          pippa_drain_wakeup()
        }
        if (poll_result & 1) != 0 &&
          render_state.terminal_active &&
          program.read_stdin {
          let b = pippa_read_byte()
          if b < 0 {
            exit_reason = Some(RuntimeExitError("failed to read stdin"))
            break
          }

          stdin_buf.push(b.to_byte())

          // Drain any immediately available bytes so we parse the whole burst
          // in one pass rather than re-scanning a growing buffer per byte.
          while (pippa_poll_events(0, 1) & 1) != 0 {
            let nb = pippa_read_byte()
            if nb < 0 {
              break
            }
            stdin_buf.push(nb.to_byte())
          }

          let bytes = Bytes::from_array(stdin_buf)
          let bv = bytes[:]
          let (events, leftover) = parse_all(bv)

          stdin_buf = leftover.to_array()
          let (stdin_context_state, stdin_context_updated) = runtime_apply_render_context_events(
            render_state, events,
          )
          render_state = stdin_context_state
          if stdin_context_updated {
            updated = true
          }

          let (next_model, input_reason, input_updated) = apply_input_events(
            program, model, events, pending, timers, sequences,
          )
          model = next_model
          match input_reason {
            Some(reason) => exit_reason = Some(reason)
            None => ()
          }
          if input_updated {
            updated = true
          }
        }
      }
    }

    if render_state.terminal_active &&
      program.read_stdin &&
      pippa_check_resize() != 0 {
      let size = current_window_size()
      render_state = runtime_render_state_with_window_size(render_state, size)
      updated = true
      let (resize_model, resize_reason, _resize_updated) = apply_window_size(
        program, model, size, pending, timers, sequences,
      )
      model = resize_model
      match resize_reason {
        Some(reason) => exit_reason = Some(reason)
        None => ()
      }
    }

    let (final_model, final_reason, final_updated, final_render_state) = drain_runtime(
      program, model, render_state, sent_msgs, pending, timers, sequences,
    )
    model = final_model
    render_state = final_render_state
    match final_reason {
      Some(reason) => exit_reason = Some(reason)
      None => ()
    }
    if final_updated {
      updated = true
    }

    if updated {
      desired = desired_view(program, model)
    }
    let should_flush_view = updated ||
      render_state.force_full_repaint ||
      (match render_state.render_due_at {
        Some(deadline) =>
          render_state.terminal_active && runtime_now_ms() >= deadline
        None => false
      })
    if should_flush_view {
      let (
        next_rendered,
        next_line_count,
        next_last_render_ms,
        next_render_due_at,
        next_view_terminal_state,
      ) = flush_view(
        program,
        render_state.rendered,
        desired,
        render_state.prev_line_count,
        render_state.view_terminal_state,
        render_state.terminal_active,
        render_state.last_render_ms,
        exit_reason is Some(_) || render_state.force_full_repaint,
        render_state.force_full_repaint,
        render_context=render_state.render_context,
      )
      render_state = {
        ..render_state,
        rendered: next_rendered,
        prev_line_count: next_line_count,
        last_render_ms: next_last_render_ms,
        render_due_at: next_render_due_at,
        force_full_repaint: false,
        view_terminal_state: next_view_terminal_state,
      }
    }
  }
  handle_closed.val = true

  if render_state.terminal_active {
    if render_state.alt_screen == program.alt_screen &&
      render_state.cursor_hidden == program.hide_cursor &&
      render_state.focus_reporting ==
      (program.read_stdin && program.focus_reporting) &&
      render_state.bracketed_paste ==
      (program.read_stdin && program.bracketed_paste) {
      deactivate_terminal(program)
    } else {
      deactivate_terminal_with_modes(
        program,
        render_state.alt_screen,
        render_state.cursor_hidden,
        render_state.focus_reporting,
        render_state.bracketed_paste,
      )
    }
  }
  match exit_reason {
    Some(reason) => run_result_from_reason(model, reason)
    None => RunCompleted(model)
  }
}
