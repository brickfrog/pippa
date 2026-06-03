///|
/// Command constructors for the Pippa TUI framework.

///|
pub fn[Msg] Cmd::none() -> Cmd[Msg] {
  { _phantom: [], actions: [] }
}

///|
/// Enqueue a message to be delivered immediately by the runtime.
pub fn[Msg] Cmd::msg(msg : Msg) -> Cmd[Msg] {
  Cmd::perform(fn() { Some(msg) })
}

///|
/// Ask the runtime to quit cleanly.
pub fn[Msg] Cmd::quit() -> Cmd[Msg] {
  { _phantom: [], actions: [LifecycleAction(Quit)] }
}

///|
/// Ask the runtime to stop as interrupted.
pub fn[Msg] Cmd::interrupt() -> Cmd[Msg] {
  { _phantom: [], actions: [LifecycleAction(Interrupt)] }
}

///|
/// Ask the runtime to release and then re-acquire the terminal.
pub fn[Msg] Cmd::suspend() -> Cmd[Msg] {
  { _phantom: [], actions: [LifecycleAction(Suspend)] }
}

///|
/// Ask the runtime to deliver a resume lifecycle message.
pub fn[Msg] Cmd::resume_program() -> Cmd[Msg] {
  { _phantom: [], actions: [LifecycleAction(Resume)] }
}

///|
/// Stop the runtime with a typed runtime error result.
pub fn[Msg] Cmd::runtime_error(message : String) -> Cmd[Msg] {
  { _phantom: [], actions: [RuntimeErrorAction(message)] }
}

///|
/// Print unmanaged text above the program in inline terminal mode.
///
/// The printed text is not part of the managed view and may persist in terminal
/// scrollback across later renders. The runtime prints each newline-delimited
/// line on its own terminal line, then repaints the current view below it. When
/// the alternate screen is active the request is discarded, matching Bubble Tea's
/// `Println` / `Printf` behavior.
pub fn[Msg] Cmd::print_above(message : String) -> Cmd[Msg] {
  {
    _phantom: [],
    actions: [
      Perform(fn() {
        runtime_enqueue_print_above({ message_body: message })
        None
      }),
    ],
  }
}

///|
/// Print unmanaged text above the program in inline terminal mode.
///
/// This is the Pippa equivalent of Bubble Tea's `Println`: unlike writing from a
/// view, the line is outside the managed render area and is ignored while the
/// alternate screen is active.
pub fn[Msg] Cmd::println(message : String) -> Cmd[Msg] {
  Cmd::print_above(message)
}

///|
fn print_above_format(template : String, args : Array[String]) -> String {
  let buf = StringBuilder::new(size_hint=template.length())
  let chars : Array[Char] = []
  for ch in template {
    chars.push(ch)
  }
  let mut arg_index = 0
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '%' && i + 1 < chars.length() {
      let next = chars[i + 1]
      if next == '%' {
        buf.write_char('%')
        i = i + 2
        continue
      } else if next == 's' {
        if arg_index < args.length() {
          buf.write_string(args[arg_index])
          arg_index = arg_index + 1
        } else {
          buf.write_string("%s")
        }
        i = i + 2
        continue
      }
    }
    buf.write_char(ch)
    i = i + 1
  }
  buf.to_string()
}

///|
/// Format unmanaged text and print it above the program in inline terminal mode.
///
/// Pippa accepts pre-rendered string arguments and replaces `%s` placeholders in
/// `template` from left to right; `%%` emits a literal percent sign. The result is
/// then handled like `Cmd::println`, including the alt-screen no-op behavior.
pub fn[Msg] Cmd::printf(
  template : String,
  args? : Array[String] = [],
) -> Cmd[Msg] {
  Cmd::print_above(print_above_format(template, args))
}

///|
/// Run an external process while the runtime releases the terminal.
pub fn[Msg] Cmd::exec_process(
  process : ExecProcess,
  to_msg : (ExecResult) -> Msg,
) -> Cmd[Msg] {
  { _phantom: [], actions: [ExecProcessAction(process, to_msg)] }
}

///|
/// Execute a runtime effect immediately after the current update cycle.
///
/// The runtime runs `f` on the event loop thread and feeds the resulting
/// message back into `update` when `Some(msg)` is returned.
pub fn[Msg] Cmd::perform(f : () -> Msg?) -> Cmd[Msg] {
  { _phantom: [], actions: [Perform(f)] }
}

///|
/// Schedule a one-shot tick — runtime calls `on_tick` when the timer fires.
///
/// Prefer `Cmd::after` when the timer should directly produce a specific
/// message. `Cmd::tick` is mainly for app-wide compatibility with `Program`'s
/// `on_tick` hook.
pub fn[Msg] Cmd::tick(interval_ms : Int) -> Cmd[Msg] {
  if interval_ms > 0 {
    { _phantom: [], actions: [Tick(interval_ms)] }
  } else {
    { _phantom: [], actions: [] }
  }
}

///|
/// Schedule `f()` after `interval_ms` milliseconds.
/// The runtime evaluates `f` when the timer fires, not when the command is
/// created.
pub fn[Msg] Cmd::after(interval_ms : Int, f : () -> Msg) -> Cmd[Msg] {
  let ms = if interval_ms > 0 { interval_ms } else { 1 }
  { _phantom: [], actions: [After(ms, f)] }
}

///|
/// Schedule `f` once on the next aligned interval boundary.
///
/// Alignment is measured against the runtime's monotonic millisecond clock:
/// the deadline is the next strict multiple of `interval_ms`. The callback
/// receives a typed elapsed-time payload, and apps that want recurrence should
/// return another `Cmd::every` from `update`.
pub fn[Msg] Cmd::every(interval_ms : Int, f : (TimerTick) -> Msg) -> Cmd[Msg] {
  let ms = if interval_ms > 0 { interval_ms } else { 1 }
  { _phantom: [], actions: [Every(ms, f)] }
}

///|
/// Enter the terminal alternate screen buffer at runtime.
pub fn[Msg] Cmd::enter_alt_screen() -> Cmd[Msg] {
  { _phantom: [], actions: [EnterAltScreen] }
}

///|
/// Exit the terminal alternate screen buffer at runtime.
pub fn[Msg] Cmd::exit_alt_screen() -> Cmd[Msg] {
  { _phantom: [], actions: [ExitAltScreen] }
}

///|
/// Clear the screen and move the cursor to the home position.
pub fn[Msg] Cmd::clear_screen() -> Cmd[Msg] {
  { _phantom: [], actions: [ClearScreen] }
}

///|
/// Invalidate the renderer cache so the next render fully repaints.
pub fn[Msg] Cmd::repaint() -> Cmd[Msg] {
  { _phantom: [], actions: [Repaint] }
}

///|
/// Invalidate the renderer cache so the next render fully repaints.
pub fn[Msg] Cmd::force_redraw() -> Cmd[Msg] {
  { _phantom: [], actions: [ForceRedraw] }
}

///|
/// Hide the terminal cursor at runtime.
pub fn[Msg] Cmd::hide_cursor() -> Cmd[Msg] {
  { _phantom: [], actions: [HideCursor] }
}

///|
/// Show the terminal cursor at runtime.
pub fn[Msg] Cmd::show_cursor() -> Cmd[Msg] {
  { _phantom: [], actions: [ShowCursor] }
}

///|
/// Ask the runtime to deliver the current terminal size as a typed message.
pub fn[Msg] Cmd::request_window_size(f : (WindowSize) -> Msg) -> Cmd[Msg] {
  { _phantom: [], actions: [RequestWindowSize(f)] }
}

///|
/// Request primary device attributes (DA1) from the terminal.
pub fn[Msg] Cmd::request_device_attributes() -> Cmd[Msg] {
  { _phantom: [], actions: [RequestDeviceAttributes] }
}

///|
/// Request secondary device attributes / terminal version (DA2).
pub fn[Msg] Cmd::request_secondary_device_attributes() -> Cmd[Msg] {
  { _phantom: [], actions: [RequestSecondaryDeviceAttributes] }
}

///|
/// Request the current cursor position (DSR CPR) from the terminal.
pub fn[Msg] Cmd::request_cursor_position() -> Cmd[Msg] {
  { _phantom: [], actions: [RequestCursorPosition] }
}

///|
/// Request the current default foreground color (OSC 10).
pub fn[Msg] Cmd::request_foreground_color() -> Cmd[Msg] {
  { _phantom: [], actions: [RequestForegroundColor] }
}

///|
/// Request the current default background color (OSC 11).
pub fn[Msg] Cmd::request_background_color() -> Cmd[Msg] {
  { _phantom: [], actions: [RequestBackgroundColor] }
}

///|
/// Request a terminal capability with XTGETTCAP.
pub fn[Msg] Cmd::request_capability(name : String) -> Cmd[Msg] {
  { _phantom: [], actions: [RequestCapability(name)] }
}

///|
/// Request clipboard contents with OSC 52.
pub fn[Msg] Cmd::request_clipboard(selection : ClipboardSelection) -> Cmd[Msg] {
  { _phantom: [], actions: [RequestClipboard(selection)] }
}

///|
/// Enable terminal focus reporting at runtime.
pub fn[Msg] Cmd::enable_focus_reporting() -> Cmd[Msg] {
  { _phantom: [], actions: [SetFocusReporting(true)] }
}

///|
/// Disable terminal focus reporting at runtime.
pub fn[Msg] Cmd::disable_focus_reporting() -> Cmd[Msg] {
  { _phantom: [], actions: [SetFocusReporting(false)] }
}

///|
/// Enable terminal bracketed paste mode at runtime.
pub fn[Msg] Cmd::enable_bracketed_paste() -> Cmd[Msg] {
  { _phantom: [], actions: [SetBracketedPaste(true)] }
}

///|
/// Disable terminal bracketed paste mode at runtime.
pub fn[Msg] Cmd::disable_bracketed_paste() -> Cmd[Msg] {
  { _phantom: [], actions: [SetBracketedPaste(false)] }
}

///|
/// Enable terminal mouse press, release, wheel, and button-held drag reporting at runtime.
pub fn[Msg] Cmd::enable_mouse_cell_motion() -> Cmd[Msg] {
  { _phantom: [], actions: [SetMouseMode(ViewMouseCellMotion)] }
}

///|
/// Enable all terminal mouse motion reporting at runtime.
pub fn[Msg] Cmd::enable_mouse_all_motion() -> Cmd[Msg] {
  { _phantom: [], actions: [SetMouseMode(ViewMouseAllMotion)] }
}

///|
/// Disable terminal mouse reporting at runtime.
pub fn[Msg] Cmd::disable_mouse() -> Cmd[Msg] {
  { _phantom: [], actions: [SetMouseMode(ViewMouseOff)] }
}

///|
/// Run commands in order.
///
/// Each command starts only after the prior command's immediate effects have
/// been drained by the runtime. Delayed timers from earlier steps continue to
/// run independently once scheduled.
pub fn[Msg] Cmd::sequence(cmds : Array[Cmd[Msg]]) -> Cmd[Msg] {
  let non_empty = cmds.filter(fn(cmd) { !cmd.is_none() })
  match non_empty {
    [] => Cmd::none()
    [cmd] => cmd
    _ => { _phantom: [], actions: [Sequence(non_empty)] }
  }
}

///|
/// Batch multiple commands so each effect is enqueued independently.
pub fn[Msg] Cmd::batch(cmds : Array[Cmd[Msg]]) -> Cmd[Msg] {
  let actions = cmds.iter().flat_map(fn(cmd) { cmd.actions.iter() }).to_array()
  { _phantom: [], actions }
}

///|
/// Returns true when the command carries no actions (equivalent to `Cmd::none()`).
pub fn[Msg] Cmd::is_none(self : Cmd[Msg]) -> Bool {
  self.actions.is_empty()
}

///|
/// Map the message type of a command, transforming runtime-produced messages.
pub fn[A, B] Cmd::map(f : (A) -> B, cmd : Cmd[A]) -> Cmd[B] {
  let actions : Array[CmdAction[B]] = []
  for action in cmd.actions {
    match action {
      Perform(task) => actions.push(Perform(fn() { task().map(f) }))
      Tick(interval_ms) => actions.push(Tick(interval_ms))
      After(interval_ms, task) =>
        actions.push(After(interval_ms, fn() { f(task()) }))
      Every(interval_ms, task) =>
        actions.push(Every(interval_ms, fn(tick) { f(task(tick)) }))
      EnterAltScreen => actions.push(EnterAltScreen)
      ExitAltScreen => actions.push(ExitAltScreen)
      ClearScreen => actions.push(ClearScreen)
      Repaint => actions.push(Repaint)
      ForceRedraw => actions.push(ForceRedraw)
      HideCursor => actions.push(HideCursor)
      ShowCursor => actions.push(ShowCursor)
      RequestWindowSize(task) =>
        actions.push(RequestWindowSize(fn(size) { f(task(size)) }))
      RequestDeviceAttributes => actions.push(RequestDeviceAttributes)
      RequestSecondaryDeviceAttributes =>
        actions.push(RequestSecondaryDeviceAttributes)
      RequestCursorPosition => actions.push(RequestCursorPosition)
      RequestForegroundColor => actions.push(RequestForegroundColor)
      RequestBackgroundColor => actions.push(RequestBackgroundColor)
      RequestCapability(name) => actions.push(RequestCapability(name))
      RequestClipboard(selection) => actions.push(RequestClipboard(selection))
      SetFocusReporting(enabled) => actions.push(SetFocusReporting(enabled))
      SetBracketedPaste(enabled) => actions.push(SetBracketedPaste(enabled))
      SetMouseMode(mode) => actions.push(SetMouseMode(mode))
      LifecycleAction(msg) => actions.push(LifecycleAction(msg))
      ExecProcessAction(process, task) =>
        actions.push(ExecProcessAction(process, fn(result) { f(task(result)) }))
      RuntimeErrorAction(message) => actions.push(RuntimeErrorAction(message))
      Sequence(cmds) =>
        actions.push(Sequence(cmds.map(fn(inner) { Cmd::map(f, inner) })))
    }
  }
  { _phantom: [], actions }
}
