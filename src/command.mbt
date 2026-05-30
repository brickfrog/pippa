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
      Sequence(cmds) =>
        actions.push(Sequence(cmds.map(fn(inner) { Cmd::map(f, inner) })))
    }
  }
  { _phantom: [], actions }
}
