///|
/// Command constructors for the Pippa TUI framework.

///|
pub fn[Msg] Cmd::none() -> Cmd[Msg] {
  { _phantom: [], actions: [] }
}

///|
/// Periodic tick — runtime calls `on_tick` when the timer fires.
pub fn[Msg] Cmd::tick(interval_ms : Int) -> Cmd[Msg] {
  if interval_ms > 0 {
    { _phantom: [], actions: [(interval_ms, None)] }
  } else {
    { _phantom: [], actions: [] }
  }
}

///|
/// Schedule `f()` after `interval_ms` milliseconds.
/// The runtime delivers the resulting message directly, bypassing `on_tick`.
/// Components use this to self-drive animation frames.
pub fn[Msg] Cmd::after(interval_ms : Int, f : () -> Msg) -> Cmd[Msg] {
  let ms = if interval_ms > 0 { interval_ms } else { 1 }
  { _phantom: [], actions: [(ms, Some(f()))] }
}

///|
/// Batch multiple commands — concatenates all actions so each timer runs
/// independently in the runtime.
pub fn[Msg] Cmd::batch(cmds : Array[Cmd[Msg]]) -> Cmd[Msg] {
  let actions : Array[(Int, Msg?)] = []
  for cmd in cmds {
    for action in cmd.actions {
      actions.push(action)
    }
  }
  { _phantom: [], actions }
}

///|
/// Returns true when the command carries no actions (equivalent to `Cmd::none()`).
pub fn[Msg] Cmd::is_none(self : Cmd[Msg]) -> Bool {
  self.actions.is_empty()
}

///|
/// Map the message type of a command, transforming each stored msg if present.
pub fn[A, B] Cmd::map(f : (A) -> B, cmd : Cmd[A]) -> Cmd[B] {
  let actions : Array[(Int, B?)] = []
  for action in cmd.actions {
    actions.push((action.0, action.1.map(f)))
  }
  { _phantom: [], actions }
}
