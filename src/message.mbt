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
/// 1-based cursor location reported by a terminal CPR reply.
pub(all) struct CursorPositionReply {
  /// 1-based terminal row.
  row : Int
  /// 1-based terminal column.
  col : Int
} derive(Debug, Eq)

///|
/// Color value reported by OSC terminal color queries.
pub(all) enum TerminalColorReply {
  /// OSC 10 foreground color reply payload.
  ForegroundColor(String)
  /// OSC 11 background color reply payload.
  BackgroundColor(String)
  /// OSC 4 palette color reply payload for the given palette index.
  PaletteColor(Int, String)
} derive(Debug, Eq)

///|
/// Selection target used by OSC 52 clipboard queries and replies.
pub(all) enum ClipboardSelection {
  /// The terminal's system clipboard selection (`c`).
  SystemClipboard
  /// The primary selection (`p`).
  PrimarySelection
  /// The secondary selection (`s`).
  SecondarySelection
  /// Numbered cut buffer selection (`0` through `7` in xterm).
  CutBuffer(Int)
  /// A terminal-specific selection code.
  NamedSelection(String)
} derive(Debug, Eq)

///|
/// Payload returned by an OSC 52 clipboard reply.
pub(all) enum ClipboardPayload {
  /// Base64 decoded text payload.
  DecodedClipboardText(String)
  /// Payload kept as raw base64 text because it was malformed.
  RawClipboardData(String)
} derive(Debug, Eq)

///|
/// OSC 52 clipboard reply payload.
pub(all) struct ClipboardReply {
  /// Clipboard selection reported by the terminal.
  selection : ClipboardSelection
  /// Decoded text when possible, otherwise the raw base64 payload.
  payload : ClipboardPayload
} derive(Debug, Eq)

///|
/// XTGETTCAP terminal capability reply payload.
pub(all) struct CapabilityReply {
  /// Capability name returned by the terminal.
  name : String
  /// Capability value when the terminal returned one.
  value : String?
  /// Whether the terminal marked the capability lookup as valid.
  valid : Bool
} derive(Debug, Eq)

///|
/// Replies emitted by terminal query sequences.
pub(all) enum TerminalReplyMsg {
  /// Cursor position report: CSI row ; col R.
  CursorPosition(CursorPositionReply)
  /// Primary device attributes: CSI ? params c.
  DeviceAttributes(Array[Int])
  /// Secondary device attributes / terminal version: CSI > params c.
  SecondaryDeviceAttributes(Array[Int])
  /// OSC color query reply.
  Color(TerminalColorReply)
  /// XTGETTCAP DCS capability reply.
  Capability(CapabilityReply)
  /// OSC 52 clipboard reply.
  Clipboard(ClipboardReply)
  /// A structurally complete reply that Pippa does not decode yet.
  UnknownReply(Bytes)
} derive(Debug, Eq)

///|
fn clipboard_selection_code(selection : ClipboardSelection) -> String {
  match selection {
    SystemClipboard => "c"
    PrimarySelection => "p"
    SecondarySelection => "s"
    CutBuffer(index) => index.to_string()
    NamedSelection(name) => name
  }
}

///|
fn parse_clipboard_selection_code(code : String) -> ClipboardSelection {
  match code {
    "c" => SystemClipboard
    "p" => PrimarySelection
    "s" => SecondarySelection
    _ =>
      if code.length() == 1 {
        let b = code[:][0].to_int()
        if b >= 0x30 && b <= 0x37 {
          CutBuffer(b - 0x30)
        } else {
          NamedSelection(code)
        }
      } else {
        NamedSelection(code)
      }
  }
}

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
