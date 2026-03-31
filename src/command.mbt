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
      Sequence(cmds) =>
        actions.push(Sequence(cmds.map(fn(inner) { Cmd::map(f, inner) })))
    }
  }
  { _phantom: [], actions }
}
