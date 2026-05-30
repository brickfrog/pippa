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
/// Numeric key identity reported by enhanced terminal keyboard protocols.
pub(all) enum EnhancedKeyCode {
  /// A Unicode code point key number.
  UnicodeKey(Int)
  /// A functional key number from the protocol's private key range.
  FunctionalKey(Int)
} derive(Debug, Eq)

///|
/// Canonical modifiers reported by enhanced terminal keyboard protocols.
pub(all) enum EnhancedKeyModifier {
  KeyShift
  KeyAlt
  KeyCtrl
  KeySuper
  KeyHyper
  KeyMeta
  KeyCapsLock
  KeyNumLock
} derive(Debug, Eq)

///|
/// Press, repeat, or release phase for an enhanced keyboard event.
pub(all) enum EnhancedKeyEventType {
  KeyPress
  KeyRepeat
  KeyRelease
} derive(Debug, Eq)

///|
/// Keyboard event data from Kitty / CSI-u enhanced keyboard reports.
pub(all) struct EnhancedKeyMsg {
  /// The primary numeric key identity.
  code : EnhancedKeyCode
  /// Shifted-key alternate from the code:shifted:base triple, when present.
  shifted : EnhancedKeyCode?
  /// Base-layout alternate from the code:shifted:base triple, when present.
  base_layout : EnhancedKeyCode?
  /// Decoded canonical modifiers from the protocol's bitfield-plus-one value.
  modifiers : Array[EnhancedKeyModifier]
  /// Whether this is a key press, repeat, or release event.
  event_type : EnhancedKeyEventType
  /// Associated text from the trailing codepoint list.
  text_codepoints : Array[Int]
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
/// Mouse button, no-button motion sentinel, or wheel scroll direction.
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
