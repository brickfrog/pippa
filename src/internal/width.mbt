///|
/// ANSI-aware Unicode display-width primitives for terminal layout.

///|
fn is_csi_terminator(ch : Char) -> Bool {
  ch >= '@' && ch <= '~'
}

///|
fn skip_osc_sequence(chars : Array[Char], start : Int) -> Int {
  let n = chars.length()
  let mut i = start
  while i < n {
    if chars[i] == '\u0007' {
      return i + 1
    }
    if chars[i] == '\u001b' && i + 1 < n && chars[i + 1] == '\\' {
      return i + 2
    }
    i = i + 1
  }
  start
}

///|
pub fn skip_ansi_sequence(chars : Array[Char], start : Int) -> Int {
  let n = chars.length()
  let mut i = start + 1
  if i < n {
    let next = chars[i]
    i = i + 1
    if next == '[' {
      while i < n && !is_csi_terminator(chars[i]) {
        i = i + 1
      }
      if i < n {
        i = i + 1
      }
    } else if next == ']' {
      i = skip_osc_sequence(chars, i)
    }
  }
  i
}

///|
fn write_chars(
  buf : StringBuilder,
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> Unit {
  for i in start..<end_index {
    buf.write_char(chars[i])
  }
}

///|
fn chars_to_string(chars : Array[Char], start : Int, end_index : Int) -> String {
  let buf = StringBuilder::new(size_hint=(end_index - start).max(0))
  write_chars(buf, chars, start, end_index)
  buf.to_string()
}

///|
fn in_range(code : Int, first : Int, last : Int) -> Bool {
  code >= first && code <= last
}

///|
fn is_printable_ascii_code(code : Int) -> Bool {
  code >= 0x20 && code <= 0x7E
}

///|
fn is_combining_mark(ch : Char) -> Bool {
  let code = ch.to_int()
  // Terminal wcwidth-style zero-width combining intervals: Mn/Me marks,
  // plus dependent signs and viramas that do not advance a display cell.
  in_range(code, 0x0300, 0x036F) ||
  in_range(code, 0x0483, 0x0489) ||
  in_range(code, 0x0591, 0x05BD) ||
  code == 0x05BF ||
  in_range(code, 0x05C1, 0x05C2) ||
  in_range(code, 0x05C4, 0x05C5) ||
  code == 0x05C7 ||
  in_range(code, 0x0610, 0x061A) ||
  in_range(code, 0x064B, 0x065F) ||
  code == 0x0670 ||
  in_range(code, 0x06D6, 0x06DC) ||
  in_range(code, 0x06DF, 0x06E4) ||
  in_range(code, 0x06E7, 0x06E8) ||
  in_range(code, 0x06EA, 0x06ED) ||
  in_range(code, 0x070F, 0x074A) ||
  in_range(code, 0x07A6, 0x07B0) ||
  in_range(code, 0x07EB, 0x07F3) ||
  in_range(code, 0x0816, 0x082D) ||
  in_range(code, 0x0859, 0x085B) ||
  in_range(code, 0x08D3, 0x0903) ||
  in_range(code, 0x093A, 0x094F) ||
  in_range(code, 0x0951, 0x0957) ||
  in_range(code, 0x0962, 0x0963) ||
  in_range(code, 0x0981, 0x0983) ||
  code == 0x09BC ||
  in_range(code, 0x09BE, 0x09C4) ||
  in_range(code, 0x09C7, 0x09C8) ||
  in_range(code, 0x09CB, 0x09CD) ||
  code == 0x09D7 ||
  in_range(code, 0x09E2, 0x09E3) ||
  in_range(code, 0x0A01, 0x0A03) ||
  code == 0x0A3C ||
  in_range(code, 0x0A3E, 0x0A42) ||
  in_range(code, 0x0A47, 0x0A48) ||
  in_range(code, 0x0A4B, 0x0A4D) ||
  code == 0x0A51 ||
  in_range(code, 0x0A70, 0x0A71) ||
  code == 0x0A75 ||
  in_range(code, 0x0A81, 0x0A83) ||
  code == 0x0ABC ||
  in_range(code, 0x0ABE, 0x0AC5) ||
  in_range(code, 0x0AC7, 0x0AC9) ||
  in_range(code, 0x0ACB, 0x0ACD) ||
  in_range(code, 0x0AE2, 0x0AE3) ||
  in_range(code, 0x0B01, 0x0B03) ||
  code == 0x0B3C ||
  in_range(code, 0x0B3E, 0x0B44) ||
  in_range(code, 0x0B47, 0x0B48) ||
  in_range(code, 0x0B4B, 0x0B4D) ||
  in_range(code, 0x0B55, 0x0B57) ||
  in_range(code, 0x0B62, 0x0B63) ||
  code == 0x0B82 ||
  in_range(code, 0x0BBE, 0x0BC2) ||
  in_range(code, 0x0BC6, 0x0BC8) ||
  in_range(code, 0x0BCA, 0x0BCD) ||
  code == 0x0BD7 ||
  in_range(code, 0x0C00, 0x0C04) ||
  in_range(code, 0x0C3E, 0x0C44) ||
  in_range(code, 0x0C46, 0x0C48) ||
  in_range(code, 0x0C4A, 0x0C4D) ||
  in_range(code, 0x0C55, 0x0C56) ||
  in_range(code, 0x0C62, 0x0C63) ||
  in_range(code, 0x0C81, 0x0C83) ||
  code == 0x0CBC ||
  in_range(code, 0x0CBE, 0x0CC4) ||
  in_range(code, 0x0CC6, 0x0CC8) ||
  in_range(code, 0x0CCA, 0x0CCD) ||
  in_range(code, 0x0CD5, 0x0CD6) ||
  in_range(code, 0x0CE2, 0x0CE3) ||
  in_range(code, 0x0D00, 0x0D03) ||
  in_range(code, 0x0D3B, 0x0D3C) ||
  in_range(code, 0x0D3E, 0x0D44) ||
  in_range(code, 0x0D46, 0x0D48) ||
  in_range(code, 0x0D4A, 0x0D4D) ||
  code == 0x0D57 ||
  in_range(code, 0x0D62, 0x0D63) ||
  in_range(code, 0x0D82, 0x0D83) ||
  in_range(code, 0x0DCF, 0x0DD4) ||
  code == 0x0DD6 ||
  in_range(code, 0x0DD8, 0x0DDF) ||
  in_range(code, 0x0DF2, 0x0DF3) ||
  code == 0x0E31 ||
  in_range(code, 0x0E34, 0x0E3A) ||
  in_range(code, 0x0E47, 0x0E4E) ||
  code == 0x0EB1 ||
  in_range(code, 0x0EB4, 0x0EBC) ||
  in_range(code, 0x0EC8, 0x0ECE) ||
  in_range(code, 0x0F18, 0x0F19) ||
  code == 0x0F35 ||
  code == 0x0F37 ||
  code == 0x0F39 ||
  in_range(code, 0x0F3E, 0x0F3F) ||
  in_range(code, 0x0F71, 0x0F84) ||
  in_range(code, 0x0F86, 0x0F87) ||
  in_range(code, 0x0F8D, 0x0FBC) ||
  code == 0x0FC6 ||
  in_range(code, 0x102B, 0x103E) ||
  in_range(code, 0x1056, 0x1059) ||
  in_range(code, 0x105E, 0x1060) ||
  in_range(code, 0x1062, 0x1064) ||
  in_range(code, 0x1067, 0x106D) ||
  in_range(code, 0x1071, 0x1074) ||
  in_range(code, 0x1082, 0x108D) ||
  code == 0x108F ||
  in_range(code, 0x109A, 0x109D) ||
  in_range(code, 0x135D, 0x135F) ||
  in_range(code, 0x1712, 0x1715) ||
  in_range(code, 0x1732, 0x1734) ||
  in_range(code, 0x1752, 0x1753) ||
  in_range(code, 0x1772, 0x1773) ||
  in_range(code, 0x17B4, 0x17D3) ||
  code == 0x17DD ||
  in_range(code, 0x180B, 0x180F) ||
  in_range(code, 0x1885, 0x1886) ||
  code == 0x18A9 ||
  in_range(code, 0x1920, 0x193B) ||
  in_range(code, 0x1A17, 0x1A1B) ||
  in_range(code, 0x1A55, 0x1A7F) ||
  in_range(code, 0x1AB0, 0x1AFF) ||
  in_range(code, 0x1B00, 0x1B04) ||
  in_range(code, 0x1B34, 0x1B44) ||
  in_range(code, 0x1B6B, 0x1B73) ||
  in_range(code, 0x1B80, 0x1B82) ||
  in_range(code, 0x1BA1, 0x1BAD) ||
  in_range(code, 0x1BE6, 0x1BF3) ||
  in_range(code, 0x1C24, 0x1C37) ||
  in_range(code, 0x1CD0, 0x1CD2) ||
  in_range(code, 0x1CD4, 0x1CE8) ||
  code == 0x1CED ||
  code == 0x1CF4 ||
  in_range(code, 0x1CF7, 0x1CF9) ||
  in_range(code, 0x1DC0, 0x1DFF) ||
  in_range(code, 0x20D0, 0x20FF) ||
  in_range(code, 0x2CEF, 0x2CF1) ||
  code == 0x2D7F ||
  in_range(code, 0x2DE0, 0x2DFF) ||
  in_range(code, 0x302A, 0x302F) ||
  in_range(code, 0x3099, 0x309A) ||
  in_range(code, 0xA66F, 0xA672) ||
  in_range(code, 0xA674, 0xA67D) ||
  in_range(code, 0xA69E, 0xA69F) ||
  in_range(code, 0xA6F0, 0xA6F1) ||
  code == 0xA802 ||
  code == 0xA806 ||
  code == 0xA80B ||
  in_range(code, 0xA823, 0xA827) ||
  in_range(code, 0xA880, 0xA881) ||
  in_range(code, 0xA8B4, 0xA8C5) ||
  in_range(code, 0xA8E0, 0xA8F1) ||
  in_range(code, 0xA926, 0xA92D) ||
  in_range(code, 0xA947, 0xA953) ||
  in_range(code, 0xA980, 0xA983) ||
  in_range(code, 0xA9B3, 0xA9C0) ||
  in_range(code, 0xA9E5, 0xA9E5) ||
  in_range(code, 0xAA29, 0xAA36) ||
  in_range(code, 0xAA43, 0xAA43) ||
  in_range(code, 0xAA4C, 0xAA4D) ||
  in_range(code, 0xAA7B, 0xAA7D) ||
  in_range(code, 0xAAB0, 0xAAB0) ||
  in_range(code, 0xAAB2, 0xAAB4) ||
  in_range(code, 0xAAB7, 0xAAB8) ||
  in_range(code, 0xAABE, 0xAABF) ||
  in_range(code, 0xAAC1, 0xAAC1) ||
  in_range(code, 0xAAEB, 0xAAEF) ||
  in_range(code, 0xAAF5, 0xAAF6) ||
  in_range(code, 0xABE3, 0xABEA) ||
  in_range(code, 0xABEC, 0xABED) ||
  in_range(code, 0xFB1E, 0xFB1E) ||
  in_range(code, 0xFE20, 0xFE2F)
}

///|
fn is_variation_selector(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0xFE00 && code <= 0xFE0F) || (code >= 0xE0100 && code <= 0xE01EF)
}

///|
fn is_emoji_modifier(ch : Char) -> Bool {
  let code = ch.to_int()
  code >= 0x1F3FB && code <= 0x1F3FF
}

///|
fn is_emoji(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x1F000 && code <= 0x1FAFF) || (code >= 0x2600 && code <= 0x27BF)
}

///|
fn is_wide(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x1100 && code <= 0x115F) ||
  (code >= 0x2329 && code <= 0x232A) ||
  (code >= 0x2E80 && code <= 0xA4CF) ||
  (code >= 0xAC00 && code <= 0xD7A3) ||
  (code >= 0xF900 && code <= 0xFAFF) ||
  (code >= 0xFE10 && code <= 0xFE19) ||
  (code >= 0xFE30 && code <= 0xFE6F) ||
  (code >= 0xFF00 && code <= 0xFF60) ||
  (code >= 0xFFE0 && code <= 0xFFE6) ||
  (code >= 0x20000 && code <= 0x3FFFD)
}

///|
fn is_regional_indicator(ch : Char) -> Bool {
  let code = ch.to_int()
  code >= 0x1F1E6 && code <= 0x1F1FF
}

///|
fn extends_previous_grapheme(ch : Char) -> Bool {
  let code = ch.to_int()
  if code < 0x80 {
    false
  } else {
    ch == '\u{200D}' ||
    is_combining_mark(ch) ||
    is_variation_selector(ch) ||
    is_emoji_modifier(ch)
  }
}

///|
fn char_cell_width(ch : Char) -> Int {
  let code = ch.to_int()
  if is_printable_ascii_code(code) {
    1
  } else if code < 0x80 {
    0
  } else if ch == '\u{200D}' ||
    is_combining_mark(ch) ||
    is_variation_selector(ch) ||
    is_emoji_modifier(ch) ||
    ch.is_control() {
    0
  } else if is_wide(ch) || is_emoji(ch) {
    2
  } else {
    1
  }
}

///|
fn next_grapheme_end(chars : Array[Char], start : Int) -> Int {
  let n = chars.length()
  let mut i = start + 1
  if is_printable_ascii_code(chars[start].to_int()) &&
    (i >= n || !extends_previous_grapheme(chars[i])) {
    return i
  }
  if is_regional_indicator(chars[start]) {
    if i < n && is_regional_indicator(chars[i]) {
      return i + 1
    }
    return i
  }
  let mut join_next = false
  while i < n {
    let ch = chars[i]
    if ch == '\u001b' {
      break
    } else if is_combining_mark(ch) ||
      is_variation_selector(ch) ||
      is_emoji_modifier(ch) {
      i = i + 1
    } else if ch == '\u{200D}' {
      join_next = true
      i = i + 1
    } else if join_next {
      join_next = false
      i = i + 1
    } else {
      break
    }
  }
  i
}

///|
fn grapheme_width(chars : Array[Char], start : Int, end_index : Int) -> Int {
  if end_index == start + 1 {
    let code = chars[start].to_int()
    if is_printable_ascii_code(code) {
      return 1
    } else if code < 0x80 {
      return 0
    }
  }
  let mut width = 0
  let mut has_emoji = false
  for i in start..<end_index {
    let ch = chars[i]
    if is_emoji(ch) {
      has_emoji = true
    }
    width = width.max(char_cell_width(ch))
  }
  if has_emoji {
    2
  } else {
    width
  }
}

///|
fn is_sgr_reset_sequence(
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> Bool {
  if end_index < start + 3 ||
    chars[start] != '\u001b' ||
    chars[start + 1] != '[' {
    return false
  }
  if chars[end_index - 1] != 'm' {
    return false
  }
  if end_index == start + 3 {
    return true
  }
  let mut value = 0
  let mut saw_digit = false
  for i in (start + 2)..<(end_index - 1) {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      value = value * 10 + ch.to_int() - '0'.to_int()
      saw_digit = true
    } else if ch == ';' {
      value = 0
      saw_digit = false
    } else {
      return false
    }
  }
  !saw_digit || value == 0
}

///|
fn is_osc8_close_sequence(
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> Bool {
  if end_index < start + 5 ||
    chars[start] != '\u001b' ||
    chars[start + 1] != ']' ||
    chars[start + 2] != '8' ||
    chars[start + 3] != ';' ||
    chars[start + 4] != ';' {
    return false
  }
  (end_index == start + 6 && chars[start + 5] == '\u0007') ||
  (
    end_index == start + 7 &&
    chars[start + 5] == '\u001b' &&
    chars[start + 6] == '\\'
  )
}

///|
fn is_trailing_close_sequence(
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> Bool {
  is_sgr_reset_sequence(chars, start, end_index) ||
  is_osc8_close_sequence(chars, start, end_index)
}

///|
fn trailing_sgr_reset_start(chars : Array[Char], from : Int) -> Int {
  let n = chars.length()
  let mut suffix_start = n
  let mut i = from
  while i < n {
    if chars[i] == '\u001b' {
      let start = i
      let next = skip_ansi_sequence(chars, i)
      if is_trailing_close_sequence(chars, start, next) {
        if suffix_start == n {
          suffix_start = start
        }
      } else {
        suffix_start = n
      }
      i = next
    } else {
      suffix_start = n
      i = i + 1
    }
  }
  suffix_start
}

///|
fn write_trailing_sgr_resets(
  buf : StringBuilder,
  chars : Array[Char],
  from : Int,
) -> Unit {
  let start = trailing_sgr_reset_start(chars, from)
  if start < chars.length() {
    write_chars(buf, chars, start, chars.length())
  }
}

///|
pub fn display_width(s : String) -> Int {
  let chars = s.to_array()
  display_width_chars(chars)
}

///|
fn display_width_chars(chars : Array[Char]) -> Int {
  let n = chars.length()
  let mut width = 0
  let mut i = 0
  while i < n {
    if chars[i] == '\u001b' {
      i = skip_ansi_sequence(chars, i)
    } else {
      let next = next_grapheme_end(chars, i)
      width = width + grapheme_width(chars, i, next)
      i = next
    }
  }
  width
}

///|
pub fn grapheme_slice(s : String, start : Int, end_index : Int) -> String {
  if end_index <= start {
    return ""
  }
  let from = start.max(0)
  let to = end_index.max(from)
  let chars = s.to_array()
  let n = chars.length()
  let buf = StringBuilder::new(size_hint=n)
  let mut cluster = 0
  let mut i = 0
  while i < n {
    if chars[i] == '\u001b' {
      let next = skip_ansi_sequence(chars, i)
      if cluster >= from && cluster < to {
        write_chars(buf, chars, i, next)
      }
      i = next
    } else {
      let next = next_grapheme_end(chars, i)
      if cluster >= from && cluster < to {
        write_chars(buf, chars, i, next)
      }
      cluster = cluster + 1
      i = next
    }
  }
  buf.to_string()
}

///|
fn push_boundary(boundaries : Array[Int], boundary : Int) -> Unit {
  if boundaries[boundaries.length() - 1] != boundary {
    boundaries.push(boundary)
  }
}

///|
pub fn grapheme_boundaries(s : String) -> Array[Int] {
  let chars = s.to_array()
  let n = chars.length()
  let boundaries : Array[Int] = [0]
  let mut i = 0
  let mut cluster_open = false
  while i < n {
    if chars[i] == '\u001b' {
      let next = skip_ansi_sequence(chars, i)
      if cluster_open && is_trailing_close_sequence(chars, i, next) {
        i = next
      } else {
        if cluster_open {
          push_boundary(boundaries, i)
          cluster_open = false
        }
        i = next
      }
    } else {
      if cluster_open {
        push_boundary(boundaries, i)
        cluster_open = false
      }
      cluster_open = true
      i = next_grapheme_end(chars, i)
    }
  }
  if cluster_open {
    push_boundary(boundaries, n)
  }
  boundaries
}

///|
pub fn truncate_width(s : String, max_width : Int) -> String {
  if max_width <= 0 {
    return ""
  }
  let chars = s.to_array()
  let n = chars.length()
  let buf = StringBuilder::new(size_hint=n)
  let mut width = 0
  let mut i = 0
  while i < n {
    if width >= max_width {
      write_trailing_sgr_resets(buf, chars, i)
      return buf.to_string()
    }
    if chars[i] == '\u001b' {
      let next = skip_ansi_sequence(chars, i)
      write_chars(buf, chars, i, next)
      i = next
    } else {
      let next = next_grapheme_end(chars, i)
      let next_width = grapheme_width(chars, i, next)
      if width + next_width > max_width {
        write_trailing_sgr_resets(buf, chars, i)
        return buf.to_string()
      }
      write_chars(buf, chars, i, next)
      width = width + next_width
      i = next
    }
  }
  buf.to_string()
}

///|
pub fn pad_right_width(s : String, width : Int) -> String {
  let chars = s.to_array()
  let current = display_width_chars(chars)
  if current >= width {
    return s
  }
  let suffix_start = trailing_sgr_reset_start(chars, 0)
  let padding = String::make(width - current, ' ')
  if suffix_start == chars.length() {
    s + padding
  } else {
    chars_to_string(chars, 0, suffix_start) +
    padding +
    chars_to_string(chars, suffix_start, chars.length())
  }
}
