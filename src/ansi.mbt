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
