///|
/// Command constructors for the Pippa TUI framework.
///
/// Commands represent side-effects that the runtime should perform on behalf
/// of the application. When a command completes, it produces a `Msg` which
/// is fed back into the `update` function.

///|
/// Create a no-op command that does nothing.
pub fn[Msg] Cmd::none() -> Cmd[Msg] {
  { _phantom: [], interval_ms: 0 }
}

///|
/// Batch multiple commands into one.
pub fn[Msg] Cmd::batch(cmds : Array[Cmd[Msg]]) -> Cmd[Msg] {
  let mut interval_ms = 0
  for cmd in cmds {
    if cmd.interval_ms > 0 {
      if interval_ms == 0 || cmd.interval_ms < interval_ms {
        interval_ms = cmd.interval_ms
      }
    }
  }
  { _phantom: [], interval_ms }
}

///|
/// Request periodic tick wakeups at the given interval in milliseconds.
pub fn[Msg] Cmd::tick(interval_ms : Int) -> Cmd[Msg] {
  { _phantom: [], interval_ms: if interval_ms > 0 { interval_ms } else { 0 } }
}

///|
/// Map the result of a command producing `A` messages into one producing `B`
/// messages, using the provided function.
pub fn[A, B] Cmd::map(_f : (A) -> B, cmd : Cmd[A]) -> Cmd[B] {
  { _phantom: [], interval_ms: cmd.interval_ms }
}
