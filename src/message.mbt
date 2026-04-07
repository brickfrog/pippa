///|
/// Built-in message types for keyboard and terminal events.
///
/// These types describe the events that the Pippa runtime translates from
/// raw terminal input. Users match on them inside their `update` function.

///|
/// Represents a keyboard event.
pub(all) enum KeyMsg {
  /// A printable character was received.
  Char(Char)
  /// A control / special key (arrow keys, escape, enter, etc.).
  Special(String)
  /// A key with modifiers (Ctrl+key, Alt+key, etc.).
  Modified(String, String)
} derive(Debug, Eq)

///|
/// Represents a mouse event.
pub(all) enum MouseMsg {
  /// Mouse moved to (col, row).
  Motion(Int, Int)
  /// Mouse button pressed at (col, row).
  Press(Int, Int)
  /// Mouse button released at (col, row).
  Release(Int, Int)
} derive(Debug, Eq)
