///|
/// ANSI escape-sequence helpers for terminal rendering.
///
/// These helpers produce raw ANSI escape codes that can be embedded in the
/// string returned by a `view` function. The Pippa runtime writes the
/// resulting string directly to the terminal.

///|
/// Escape character.
pub const ESC : String = "\u001b"

///|
/// CSI prefix (`ESC [`).
pub const CSI : String = "\u001b["

///|
/// OSC prefix (`ESC ]`).
pub const OSC : String = "\u001b]"

///|
/// DCS prefix (`ESC P`).
pub const DCS : String = "\u001bP"

///|
/// String terminator (`ESC \`).
pub const ST : String = "\u001b\\"

///|
/// Reset all attributes (CSI 0 m).
pub fn reset() -> String {
  "\{CSI}0m"
}

///|
/// Bold text (CSI 1 m).
pub fn bold() -> String {
  "\{CSI}1m"
}

///|
/// Dim / faint text (CSI 2 m).
pub fn dim() -> String {
  "\{CSI}2m"
}

///|
/// Underlined text (CSI 4 m).
pub fn underline() -> String {
  "\{CSI}4m"
}

///|
/// Blinking text (CSI 5 m).
pub fn blink() -> String {
  "\{CSI}5m"
}

///|
/// Reverse video (CSI 7 m).
pub fn reverse() -> String {
  "\{CSI}7m"
}

///|
/// Hide the cursor (CSI ? 25 l).
pub fn hide_cursor() -> String {
  "\{CSI}?25l"
}

///|
/// Show the cursor (CSI ? 25 h).
pub fn show_cursor() -> String {
  "\{CSI}?25h"
}

///|
/// Enter the alternate screen buffer (CSI ? 1049 h).
pub fn enter_alt_screen() -> String {
  "\{CSI}?1049h"
}

///|
/// Enable normal mouse reporting with SGR coordinates (CSI ?1000h CSI ?1006h).
pub fn enable_mouse() -> String {
  "\{CSI}?1000h\{CSI}?1006h"
}

///|
/// Enable mouse motion reporting with SGR coordinates (CSI ?1003h CSI ?1006h).
pub fn enable_mouse_motion() -> String {
  "\{CSI}?1003h\{CSI}?1006h"
}

///|
/// Enable focus reporting (CSI ?1004h).
pub fn enable_focus_reporting() -> String {
  "\{CSI}?1004h"
}

///|
/// Enable bracketed paste mode (CSI ?2004h).
pub fn enable_bracketed_paste() -> String {
  "\{CSI}?2004h"
}

///|
/// Exit the alternate screen buffer and restore the primary screen (CSI ? 1049 l).
pub fn exit_alt_screen() -> String {
  "\{CSI}?1049l"
}

///|
/// Disable focus reporting (CSI ?1004l).
pub fn disable_focus_reporting() -> String {
  "\{CSI}?1004l"
}

///|
/// Disable bracketed paste mode (CSI ?2004l).
pub fn disable_bracketed_paste() -> String {
  "\{CSI}?2004l"
}

///|
/// Request primary device attributes (DA1).
pub fn request_device_attributes() -> String {
  "\{CSI}c"
}

///|
/// Request secondary device attributes / terminal version (DA2).
pub fn request_secondary_device_attributes() -> String {
  "\{CSI}>c"
}

///|
/// Request the current cursor position (DSR CPR).
pub fn request_cursor_position() -> String {
  "\{CSI}6n"
}

///|
/// Request the current default foreground color (OSC 10).
pub fn request_foreground_color() -> String {
  "\{OSC}10;?\{ST}"
}

///|
/// Request the current default background color (OSC 11).
pub fn request_background_color() -> String {
  "\{OSC}11;?\{ST}"
}

///|
fn hex_digit(n : Int) -> Char {
  if n < 10 {
    (0x30 + n).unsafe_to_char()
  } else {
    (0x61 + n - 10).unsafe_to_char()
  }
}

///|
fn hex_encode(input : String) -> String {
  let bytes = @utf8.encode(input)
  let buf = StringBuilder::new(size_hint=bytes.length() * 2)
  let mut i = 0
  while i < bytes.length() {
    let b = bytes[i].to_int()
    buf.write_char(hex_digit((b >> 4) & 0x0F))
    buf.write_char(hex_digit(b & 0x0F))
    i = i + 1
  }
  buf.to_string()
}

///|
/// Request an XTGETTCAP capability by name.
pub fn request_capability(name : String) -> String {
  "\{DCS}+q\{hex_encode(name)}\{ST}"
}

///|
/// Request clipboard contents from an OSC 52 selection.
pub fn request_clipboard(selection : ClipboardSelection) -> String {
  "\{OSC}52;\{clipboard_selection_code(selection)};?\{ST}"
}

///|
/// Disable all mouse reporting (CSI ?1000l, CSI ?1003l, and CSI ?1006l).
pub fn disable_mouse() -> String {
  "\{CSI}?1000l\{CSI}?1003l\{CSI}?1006l"
}

///|
/// Clear the entire screen (CSI 2 J).
pub fn clear_screen() -> String {
  "\{CSI}2J"
}

///|
/// Clear from cursor to end of line (CSI K).
pub fn clear_line() -> String {
  "\{CSI}K"
}

///|
/// Clear from cursor to end of screen (CSI J).
pub fn clear_screen_below() -> String {
  "\{CSI}J"
}

///|
/// Move cursor to (row, col), 1-based (CSI row ; col H).
pub fn move_cursor(row : Int, col : Int) -> String {
  "\{CSI}\{row};\{col}H"
}

///|
/// Set the foreground color (256-color mode: CSI 38 ; 5 ; n m).
pub fn fg_color(n : Int) -> String {
  "\{CSI}38;5;\{n}m"
}

///|
/// Set the background color (256-color mode: CSI 48 ; 5 ; n m).
pub fn bg_color(n : Int) -> String {
  "\{CSI}48;5;\{n}m"
}

///|
/// Set the foreground to an RGB color (CSI 38 ; 2 ; r ; g ; b m).
pub fn fg_rgb(r : Int, g : Int, b : Int) -> String {
  "\{CSI}38;2;\{r};\{g};\{b}m"
}

///|
/// Set the background to an RGB color (CSI 48 ; 2 ; r ; g ; b m).
pub fn bg_rgb(r : Int, g : Int, b : Int) -> String {
  "\{CSI}48;2;\{r};\{g};\{b}m"
}
