///|
/// String layout utilities for terminal rendering.
///
/// All width calculations operate on visible characters only — ANSI escape
/// sequences are excluded from width counts.

///|
/// Returns true if the character terminates a CSI escape sequence (A–Z or a–z).
fn is_csi_terminator(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

///|
/// Remove all ANSI escape sequences from `s`.
///
/// Handles CSI sequences (`ESC [` … letter) and bare two-char sequences
/// (`ESC` followed by any single non-`[` character).
pub fn strip_ansi(s : String) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let buf = StringBuilder::new(size_hint=n)
  let mut i = 0
  while i < n {
    let ch = chars[i]
    if ch == '\u001b' {
      i = i + 1
      if i < n {
        let next = chars[i]
        if next == '[' {
          // CSI sequence: skip until (and including) the terminating letter.
          i = i + 1
          while i < n && not(is_csi_terminator(chars[i])) {
            i = i + 1
          }
          if i < n {
            i = i + 1
          }
        } else {
          // Single char after ESC — skip it.
          i = i + 1
        }
      }
    } else {
      buf.write_char(ch)
      i = i + 1
    }
  }
  buf.to_string()
}

///|
/// Return the visible width of `s` (number of printable characters after
/// stripping ANSI sequences).  No wide-character handling is performed yet;
/// every character counts as 1.
pub fn visible_width(s : String) -> Int {
  strip_ansi(s).length()
}

///|
/// Split `s` on newline characters.
///
/// `"a\nb\n"` → `["a", "b", ""]`
/// `""`       → `[""]`
pub fn split_lines(s : String) -> Array[String] {
  let arr : Array[String] = []
  let mut line_buf = StringBuilder::new(size_hint=64)
  s
  .iter()
  .each(fn(ch) {
    if ch == '\n' {
      arr.push(line_buf.to_string())
      line_buf = StringBuilder::new(size_hint=64)
    } else {
      line_buf.write_char(ch)
    }
  })
  arr.push(line_buf.to_string())
  arr
}

///|
/// Return the number of lines in `s` (equivalent to `split_lines(s).length()`).
pub fn line_count(s : String) -> Int {
  split_lines(s).length()
}

///|
/// Return the maximum visible width across all lines in `s`.
/// Returns 0 for an empty string.
pub fn max_line_width(s : String) -> Int {
  let mut max = 0
  split_lines(s).each(fn(line) {
    let w = visible_width(line)
    if w > max {
      max = w
    }
  })
  max
}

///|
/// Center `s` within a field of `width` visible characters by padding with
/// spaces on both sides.  Returns `s` unchanged if its visible width is
/// already ≥ `width`.
pub fn center(s : String, width : Int) -> String {
  let sw = visible_width(s)
  if sw >= width {
    return s
  }
  let total_pad = width - sw
  let left_pad = total_pad / 2
  let right_pad = total_pad - left_pad
  String::make(left_pad, ' ') + s + String::make(right_pad, ' ')
}

///|
/// Left-pad `s` with spaces until its visible width equals `width`.
/// Returns `s` unchanged if its visible width is already ≥ `width`.
pub fn pad_left(s : String, width : Int) -> String {
  let sw = visible_width(s)
  if sw >= width {
    return s
  }
  String::make(width - sw, ' ') + s
}

///|
/// Right-pad `s` with spaces until its visible width equals `width`.
/// Returns `s` unchanged if its visible width is already ≥ `width`.
pub fn pad_right(s : String, width : Int) -> String {
  let sw = visible_width(s)
  if sw >= width {
    return s
  }
  s + String::make(width - sw, ' ')
}

///|
/// Truncate `s` so that its visible width is at most `max_width`.
///
/// ANSI-aware: escape sequences are never split mid-sequence and do not
/// themselves consume any visible width.
pub fn truncate(s : String, max_width : Int) -> String {
  if max_width <= 0 {
    return ""
  }
  let chars = s.to_array()
  let n = chars.length()
  let buf = StringBuilder::new(size_hint=n)
  let mut i = 0
  let mut width = 0
  while i < n {
    let ch = chars[i]
    if ch == '\u001b' {
      // Copy the entire escape sequence without counting visible width.
      buf.write_char(ch)
      i = i + 1
      if i < n {
        let next = chars[i]
        buf.write_char(next)
        i = i + 1
        if next == '[' {
          // CSI sequence: copy until (and including) the terminating letter.
          while i < n && not(is_csi_terminator(chars[i])) {
            buf.write_char(chars[i])
            i = i + 1
          }
          if i < n {
            buf.write_char(chars[i])
            i = i + 1
          }
        }
      }
    } else {
      if width >= max_width {
        break
      }
      buf.write_char(ch)
      width = width + 1
      i = i + 1
    }
  }
  buf.to_string()
}
