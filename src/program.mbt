///|
/// Program configuration and entry-point for a Pippa TUI application.
///
/// A `Program[Model, Msg]` ties together the three core functions of the Elm
/// Architecture (init, update, view) and drives the main event loop.
///
/// Construct with `Program::new` and run with `Program::run`.

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
) -> Program[Model, Msg] {
  {
    init,
    update,
    view,
    sub,
    on_tick,
    mouse,
    alt_screen,
    focus_reporting,
    bracketed_paste,
    hide_cursor,
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
  }
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
    if cursor_hidden {
      buf.write_string(show_cursor())
    }
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
  if program.rendering && program.read_stdin && program.mouse {
    emit_output(program, disable_mouse())
  }
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
  if program.rendering && program.read_stdin && program.mouse {
    emit_output(program, disable_mouse())
  }
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
fn[Model, Msg] render_interval_ms(program : Program[Model, Msg]) -> Int64 {
  let fps = program.fps.max(1).min(120)
  let interval = (1000 + fps - 1) / fps
  interval.to_int64()
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
/// the main event loop. On other targets this is a no-op.
pub fn[Model, Msg] Program::run(program : Program[Model, Msg]) -> Unit {
  run_internal(program, fn(_handle) { () })
}

///|
/// Run the program and expose a handle that can inject messages while it is
/// running.
pub fn[Model, Msg] Program::run_with_handle(
  program : Program[Model, Msg],
  on_start : (ProgramHandle[Msg]) -> Unit,
) -> Unit {
  run_internal(program, on_start)
}

///|
#cfg(not(any(target="native", target="llvm")))
fn[Model, Msg] run_internal(
  _program : Program[Model, Msg],
  on_start : (ProgramHandle[Msg]) -> Unit,
) -> Unit {
  on_start(
    ProgramHandle::new(
      @queue.Queue::new(),
      @queue.Queue::new(),
      fn() { () },
      Ref::new(true),
    ),
  )
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
  last_render_ms : Int64
  render_due_at : Int64?
  force_full_repaint : Bool
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
    last_render_ms: 0L,
    render_due_at: None,
    force_full_repaint: false,
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
      { ..state, rendered: "", prev_line_count: 0, render_due_at: None }
    }
    RuntimeRepaint => { ..state, force_full_repaint: true, render_due_at: None }
    RuntimeForceRedraw =>
      { ..state, force_full_repaint: true, render_due_at: None }
    RuntimeHideCursor =>
      if state.cursor_hidden {
        state
      } else {
        if state.terminal_active && program.rendering {
          emit_output(program, hide_cursor())
        }
        { ..state, cursor_hidden: true }
      }
    RuntimeShowCursor =>
      if !state.cursor_hidden {
        state
      } else {
        if state.terminal_active && program.rendering {
          emit_output(program, show_cursor())
        }
        { ..state, cursor_hidden: false }
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
      let remaining = deadline - pippa_now_ms()
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
fn[Model, Msg] runtime_timeout_ms(
  program : Program[Model, Msg],
  timers : Array[RuntimeTimer[Msg]],
  render_due_at : Int64?,
) -> Int {
  let mut timeout = timers_timeout(timers)
  match render_due_at {
    Some(deadline) => {
      let remaining = (deadline - pippa_now_ms()).max(0L).to_int()
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
) -> (Model, Bool, Bool) {
  let mut current_model = model
  let mut quit = false
  let mut updated = false
  match (program.on_window_size)(size) {
    Some(msg) => {
      let (next_model, should_quit, cmd) = apply_msg(
        program, current_model, msg,
      )
      current_model = next_model
      queue_cmd_effects(cmd, pippa_now_ms(), pending, timers, sequences)
      updated = true
      if should_quit {
        quit = true
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
      queue_cmd_effects(cmd, pippa_now_ms(), pending, timers, sequences)
      updated = true
      if should_quit {
        quit = true
      }
    }
    None => ()
  }
  (current_model, quit, updated)
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] apply_initial_window_size(
  program : Program[Model, Msg],
  model : Model,
  pending : @queue.Queue[RuntimeEffect[Msg]],
  timers : Array[RuntimeTimer[Msg]],
  sequences : @deque.Deque[Array[Cmd[Msg]]],
) -> (Model, Bool, Bool) {
  match maybe_initial_window_size(program) {
    Some(size) =>
      apply_window_size(program, model, size, pending, timers, sequences)
    None => (model, false, false)
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
fn[Model, Msg] apply_input_events(
  program : Program[Model, Msg],
  model : Model,
  events : Array[InputEvent],
  pending : @queue.Queue[RuntimeEffect[Msg]],
  timers : Array[RuntimeTimer[Msg]],
  sequences : @deque.Deque[Array[Cmd[Msg]]],
) -> (Model, Bool, Bool) {
  let mut current_model = model
  let mut quit = false
  let mut updated = false
  for evt in events {
    if program.catch_interrupt {
      match evt {
        Key(Modified("ctrl", "c")) => quit = true
        _ => ()
      }
    }
    match (program.sub)(evt) {
      Some(msg) => {
        let (next_model, should_quit, cmd) = apply_msg(
          program, current_model, msg,
        )
        current_model = next_model
        queue_cmd_effects(cmd, pippa_now_ms(), pending, timers, sequences)
        updated = true
        if should_quit {
          quit = true
        }
      }
      None => ()
    }
    if quit {
      break
    }
  }
  (current_model, quit, updated)
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] drain_controls(
  program : Program[Model, Msg],
  pending_controls : @queue.Queue[RuntimeControl],
  state : RuntimeRenderState,
  current_view : String,
) -> RuntimeRenderState {
  let mut next_state = state
  while !pending_controls.is_empty() {
    match pending_controls.pop() {
      Some(ReleaseTerminal) =>
        if next_state.terminal_active {
          if next_state.alt_screen == program.alt_screen &&
            next_state.cursor_hidden == program.hide_cursor &&
            next_state.focus_reporting ==
            (program.read_stdin && program.focus_reporting) &&
            next_state.bracketed_paste ==
            (program.read_stdin && program.bracketed_paste) {
            deactivate_terminal(program)
          } else {
            deactivate_terminal_with_modes(
              program,
              next_state.alt_screen,
              next_state.cursor_hidden,
              next_state.focus_reporting,
              next_state.bracketed_paste,
            )
          }
          next_state = {
            ..next_state,
            terminal_active: false,
            rendered: "",
            prev_line_count: 0,
            render_due_at: None,
            force_full_repaint: false,
          }
        }
      Some(RestoreTerminal) =>
        if !next_state.terminal_active {
          if next_state.alt_screen == program.alt_screen &&
            next_state.cursor_hidden == program.hide_cursor &&
            next_state.focus_reporting ==
            (program.read_stdin && program.focus_reporting) &&
            next_state.bracketed_paste ==
            (program.read_stdin && program.bracketed_paste) {
            activate_terminal(program)
          } else {
            activate_terminal_with_modes(
              program,
              next_state.alt_screen,
              next_state.cursor_hidden,
              next_state.focus_reporting,
              next_state.bracketed_paste,
            )
          }
          next_state = { ..next_state, terminal_active: true }
          if program.rendering {
            emit_output(program, render_full(current_view, 0))
            next_state = {
              ..next_state,
              rendered: current_view,
              prev_line_count: line_count(current_view),
              last_render_ms: pippa_now_ms(),
              render_due_at: None,
              force_full_repaint: false,
            }
          }
        }
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
) -> String {
  if program.rendering {
    (program.view)(model)
  } else {
    ""
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] flush_view(
  program : Program[Model, Msg],
  rendered_view : String,
  next_view : String,
  prev_line_count : Int,
  terminal_active : Bool,
  last_render_ms : Int64,
  force : Bool,
  full_repaint : Bool,
) -> (String, Int, Int64, Int64?) {
  if !program.rendering ||
    !terminal_active ||
    (!full_repaint && next_view == rendered_view) {
    (rendered_view, prev_line_count, last_render_ms, None)
  } else {
    let now = pippa_now_ms()
    if force || now - last_render_ms >= render_interval_ms(program) {
      let ops = diff_views(rendered_view, next_view)
      let output = if full_repaint || ops.is_empty() {
        render_full(next_view, prev_line_count)
      } else {
        render_patch(ops)
      }
      emit_output(program, output)
      (next_view, line_count(next_view), now, None)
    } else {
      (
        rendered_view,
        prev_line_count,
        last_render_ms,
        Some(last_render_ms + render_interval_ms(program)),
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
) -> (Model, Bool, Bool, RuntimeRenderState) {
  let mut current_model = model
  let mut current_state = state
  let mut quit = false
  let mut updated = false
  while !quit {
    let mut progressed = false

    while !quit && !sent_msgs.is_empty() {
      let msg = sent_msgs.pop().unwrap()
      let (next_model, should_quit, cmd) = apply_msg(
        program, current_model, msg,
      )
      current_model = next_model
      updated = true
      progressed = true
      queue_cmd_effects(cmd, pippa_now_ms(), pending, timers, sequences)
      if should_quit {
        quit = true
      }
    }

    while !quit && !pending.is_empty() {
      let effect = pending.pop().unwrap()
      progressed = true
      match effect {
        RuntimeTask(task) =>
          match task() {
            Some(msg) => {
              let (next_model, should_quit, cmd) = apply_msg(
                program, current_model, msg,
              )
              current_model = next_model
              updated = true
              queue_cmd_effects(cmd, pippa_now_ms(), pending, timers, sequences)
              if should_quit {
                quit = true
              }
            }
            None => ()
          }
        RuntimeScreen(command) =>
          current_state = apply_screen_command(program, current_state, command)
        RuntimeTerminal(command) =>
          current_state = apply_terminal_command(
            program, current_state, command,
          )
      }
    }

    if quit {
      break
    }

    if pending.is_empty() && sent_msgs.is_empty() {
      match sequences.pop_front() {
        Some([head, .. tail]) => {
          queue_cmd_effects(head, pippa_now_ms(), pending, timers, sequences)
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
  (current_model, quit, updated, current_state)
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] run_internal(
  program : Program[Model, Msg],
  on_start : (ProgramHandle[Msg]) -> Unit,
) -> Unit {
  pippa_init_wakeup()
  defer pippa_close_wakeup()

  let init_res = (program.init)()
  let mut model = init_res.model
  let sent_msgs = @queue.Queue::new()
  let pending_controls = @queue.Queue::new()
  let handle_closed = Ref::new(false)
  let handle = ProgramHandle::new(
    sent_msgs, pending_controls, pippa_signal_wakeup, handle_closed,
  )
  let pending = @queue.Queue::new()
  let sequences = @deque.Deque::new()
  let mut timers : Array[RuntimeTimer[Msg]] = []
  queue_cmd_effects(init_res.cmd, pippa_now_ms(), pending, timers, sequences)

  let terminal_active = program.rendering || program.read_stdin
  let mut render_state = initial_render_state(program, terminal_active)
  if render_state.terminal_active {
    activate_terminal(program)
  }

  let (initial_model, initial_quit, _initial_updated) = apply_initial_window_size(
    program, model, pending, timers, sequences,
  )
  model = initial_model
  let (boot_model, boot_quit, _boot_updated, boot_state) = drain_runtime(
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
  ) = flush_view(
    program,
    render_state.rendered,
    desired,
    render_state.prev_line_count,
    render_state.terminal_active,
    render_state.last_render_ms,
    true,
    true,
  )
  render_state = {
    ..render_state,
    rendered: initial_rendered,
    prev_line_count: initial_line_count,
    last_render_ms: initial_last_render_ms,
    render_due_at: initial_render_due_at,
    force_full_repaint: false,
  }
  on_start(handle)

  let mut stdin_buf : Array[Byte] = []
  let mut raw_buf : Array[Byte] = []
  let mut quit = initial_quit || boot_quit

  while !quit {
    render_state = drain_controls(
      program, pending_controls, render_state, desired,
    )
    if is_cancelled(program) {
      quit = true
      break
    }

    let (drained_model, drained_quit, drained_updated, drained_render_state) = drain_runtime(
      program, model, render_state, sent_msgs, pending, timers, sequences,
    )
    model = drained_model
    render_state = drained_render_state
    if drained_quit {
      quit = true
    }
    if drained_updated || render_state.force_full_repaint {
      desired = desired_view(program, model)
      let (
        next_rendered,
        next_line_count,
        next_last_render_ms,
        next_render_due_at,
      ) = flush_view(
        program,
        render_state.rendered,
        desired,
        render_state.prev_line_count,
        render_state.terminal_active,
        render_state.last_render_ms,
        quit || render_state.force_full_repaint,
        render_state.force_full_repaint,
      )
      render_state = {
        ..render_state,
        rendered: next_rendered,
        prev_line_count: next_line_count,
        last_render_ms: next_last_render_ms,
        render_due_at: next_render_due_at,
        force_full_repaint: false,
      }
    }
    if quit {
      break
    }

    let mut updated = false
    let (input_model, input_quit, input_updated) = apply_input_events(
      program,
      model,
      poll_input_events(program),
      pending,
      timers,
      sequences,
    )
    model = input_model
    if input_quit {
      quit = true
    }
    if input_updated {
      updated = true
    }
    let (raw_events, next_raw_buf) = poll_raw_input_events(program, raw_buf)
    raw_buf = next_raw_buf
    let (raw_model, raw_quit, raw_updated) = apply_input_events(
      program, model, raw_events, pending, timers, sequences,
    )
    model = raw_model
    if raw_quit {
      quit = true
    }
    if raw_updated {
      updated = true
    }
    if quit {
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
        break
      }

      if poll_result == 0 {
        let now = pippa_now_ms()
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
        timers = remaining
      } else {
        if (poll_result & 4) != 0 {
          pippa_drain_wakeup()
        }
        if (poll_result & 1) != 0 &&
          render_state.terminal_active &&
          program.read_stdin {
          let b = pippa_read_byte()
          if b < 0 {
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

          let (next_model, should_quit, input_updated) = apply_input_events(
            program, model, events, pending, timers, sequences,
          )
          model = next_model
          if should_quit {
            quit = true
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
      updated = true
      let (resize_model, resize_quit, _resize_updated) = apply_window_size(
        program, model, size, pending, timers, sequences,
      )
      model = resize_model
      if resize_quit {
        quit = true
      }
    }

    let (final_model, final_quit, final_updated, final_render_state) = drain_runtime(
      program, model, render_state, sent_msgs, pending, timers, sequences,
    )
    model = final_model
    render_state = final_render_state
    if final_quit {
      quit = true
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
          render_state.terminal_active && pippa_now_ms() >= deadline
        None => false
      })
    if should_flush_view {
      let (
        next_rendered,
        next_line_count,
        next_last_render_ms,
        next_render_due_at,
      ) = flush_view(
        program,
        render_state.rendered,
        desired,
        render_state.prev_line_count,
        render_state.terminal_active,
        render_state.last_render_ms,
        quit || render_state.force_full_repaint,
        render_state.force_full_repaint,
      )
      render_state = {
        ..render_state,
        rendered: next_rendered,
        prev_line_count: next_line_count,
        last_render_ms: next_last_render_ms,
        render_due_at: next_render_due_at,
        force_full_repaint: false,
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
}
