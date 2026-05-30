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
  /// A printable grapheme cluster with multiple Unicode scalars was received.
  Text(String)
  /// A control / special key (arrow keys, escape, enter, etc.).
  Special(String)
  /// A key with modifiers (Ctrl+key, Alt+key, etc.).
  Modified(String, String)
} derive(Debug, Eq)

///|
/// Represents a mouse event.
pub(all) struct MouseMsg {
  /// The button or wheel direction reported by the terminal.
  button : MouseButton
  /// The kind of mouse event.
  action : MouseAction
  /// Active keyboard modifiers when the event was reported.
  modifiers : Array[MouseModifier]
  /// 1-based terminal column.
  col : Int
  /// 1-based terminal row.
  row : Int
} derive(Debug, Eq)

///|
/// Mouse button or wheel direction.
pub(all) enum MouseButton {
  MouseLeft
  MouseMiddle
  MouseRight
  MouseNoButton
  MouseWheelUp
  MouseWheelDown
  MouseWheelLeft
  MouseWheelRight
} derive(Debug, Eq)

///|
/// Mouse event action.
pub(all) enum MouseAction {
  MousePress
  MouseRelease
  MouseMotion
  MouseWheel
} derive(Debug, Eq)

///|
/// Keyboard modifiers attached to a mouse event.
pub(all) enum MouseModifier {
  MouseShift
  MouseAlt
  MouseCtrl
} derive(Debug, Eq)
