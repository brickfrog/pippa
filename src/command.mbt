///|
/// Command constructors for the Pippa TUI framework.
///
/// Commands represent side-effects that the runtime should perform on behalf
/// of the application. When a command completes, it produces a `Msg` which
/// is fed back into the `update` function.

///|
/// Create a no-op command that does nothing.
pub fn[Msg] Cmd::none() -> Cmd[Msg] {
  { _phantom: [] }
}

///|
/// Batch multiple commands into one.
pub fn[Msg] Cmd::batch(_cmds : Array[Cmd[Msg]]) -> Cmd[Msg] {
  Cmd::none()
}

///|
/// Map the result of a command producing `A` messages into one producing `B`
/// messages, using the provided function.
pub fn[A, B] Cmd::map(_f : (A) -> B, _cmd : Cmd[A]) -> Cmd[B] {
  Cmd::none()
}