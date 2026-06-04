///|
/// ANSI escape-sequence parser for keyboard and mouse input events.
///
/// Translates raw bytes from the terminal into typed `InputEvent` values.
/// The parser handles printable UTF-8 text, control characters, ANSI CSI
/// sequences (arrow keys, mouse reports), Ctrl-modified keys, and Alt-prefixed
/// keys. Pass a `BytesView` to `parse_input` for a single event, or
/// `parse_all` to drain all complete events at once.

///|
/// A parsed terminal input event.
pub(all) enum InputEvent {
  /// A keyboard event.
  Key(KeyMsg)
  /// An enhanced keyboard-protocol event.
  EnhancedKey(EnhancedKeyMsg)
  /// A mouse event.
  Mouse(MouseMsg)
  /// The terminal window gained focus.
  Focus
  /// The terminal window lost focus.
  Blur
  /// Bracketed paste payload.
  Paste(String)
  /// A reply emitted by a terminal query sequence.
  TerminalReply(TerminalReplyMsg)
  /// Bytes that could not be mapped to a known event.
  Unknown(Bytes)
} derive(Debug, Eq)

///|
/// Result of attempting to parse one event from a byte buffer.
pub(all) enum ParseResult[T] {
  /// Successfully parsed a value; the `Int` is the number of bytes consumed.
  Ok(T, Int)
  /// The buffer ended mid-sequence; supply more bytes and retry.
  Incomplete
  /// The byte sequence is definitively malformed.
  Invalid(String)
} derive(Debug, Eq)

///|
fn unknown_event(bv : BytesView, consumed : Int) -> InputEvent {
  Unknown(Bytes::from_array(bv[0:consumed].to_array()))
}

///|
fn unknown_reply_event(bv : BytesView, consumed : Int) -> InputEvent {
  TerminalReply(UnknownReply(Bytes::from_array(bv[0:consumed].to_array())))
}

///|
priv enum Utf8Scalar {
  Utf8Ok(Char, Int)
  Utf8Incomplete
  Utf8Invalid(String)
}

///|
fn is_utf8_continuation(b : Int) -> Bool {
  b >= 0x80 && b <= 0xBF
}

///|
fn in_byte_range(b : Int, first : Int, last : Int) -> Bool {
  b >= first && b <= last
}

///|
fn utf8_invalid(message : String) -> Utf8Scalar {
  Utf8Invalid(message)
}

///|
fn decode_utf8_scalar(bv : BytesView) -> Utf8Scalar {
  let n = bv.length()
  if n == 0 {
    return Utf8Incomplete
  }
  let b0 = bv[0].to_int()
  if b0 <= 0x7F {
    return Utf8Ok(b0.unsafe_to_char(), 1)
  }
  if b0 >= 0xC2 && b0 <= 0xDF {
    if n < 2 {
      return Utf8Incomplete
    }
    let b1 = bv[1].to_int()
    if !is_utf8_continuation(b1) {
      return utf8_invalid("invalid UTF-8 continuation byte \{b1}")
    }
    let code = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
    return Utf8Ok(code.unsafe_to_char(), 2)
  }
  if b0 >= 0xE0 && b0 <= 0xEF {
    if n < 2 {
      return Utf8Incomplete
    }
    let b1 = bv[1].to_int()
    let b1_ok = if b0 == 0xE0 {
      in_byte_range(b1, 0xA0, 0xBF)
    } else if b0 == 0xED {
      in_byte_range(b1, 0x80, 0x9F)
    } else {
      is_utf8_continuation(b1)
    }
    if !b1_ok {
      return utf8_invalid("invalid UTF-8 continuation byte \{b1}")
    }
    if n < 3 {
      return Utf8Incomplete
    }
    let b2 = bv[2].to_int()
    if !is_utf8_continuation(b2) {
      return utf8_invalid("invalid UTF-8 continuation byte \{b2}")
    }
    let code = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
    return Utf8Ok(code.unsafe_to_char(), 3)
  }
  if b0 >= 0xF0 && b0 <= 0xF4 {
    if n < 2 {
      return Utf8Incomplete
    }
    let b1 = bv[1].to_int()
    let b1_ok = if b0 == 0xF0 {
      in_byte_range(b1, 0x90, 0xBF)
    } else if b0 == 0xF4 {
      in_byte_range(b1, 0x80, 0x8F)
    } else {
      is_utf8_continuation(b1)
    }
    if !b1_ok {
      return utf8_invalid("invalid UTF-8 continuation byte \{b1}")
    }
    if n < 3 {
      return Utf8Incomplete
    }
    let b2 = bv[2].to_int()
    if !is_utf8_continuation(b2) {
      return utf8_invalid("invalid UTF-8 continuation byte \{b2}")
    }
    if n < 4 {
      return Utf8Incomplete
    }
    let b3 = bv[3].to_int()
    if !is_utf8_continuation(b3) {
      return utf8_invalid("invalid UTF-8 continuation byte \{b3}")
    }
    let code = ((b0 & 0x07) << 18) |
      ((b1 & 0x3F) << 12) |
      ((b2 & 0x3F) << 6) |
      (b3 & 0x3F)
    return Utf8Ok(code.unsafe_to_char(), 4)
  }
  utf8_invalid("invalid UTF-8 leading byte \{b0}")
}

///|
fn is_text_scalar(ch : Char) -> Bool {
  ch != '\u001b' && !ch.is_control()
}

///|
fn key_text_event(text : String) -> InputEvent {
  let cluster = @internal.grapheme_slice(text, 0, 1)
  let chars = cluster.to_array()
  let boundaries = @internal.grapheme_boundaries(cluster)
  let _width = @internal.display_width(cluster)
  if chars.length() == 1 && boundaries.length() == 2 {
    Key(Char(chars[0]))
  } else {
    Key(Text(cluster))
  }
}

///|
fn emit_text_event(
  chars : Array[Char],
  byte_offsets : Array[Int],
) -> ParseResult[InputEvent] {
  let text = String::from_array(chars)
  let boundaries = @internal.grapheme_boundaries(text)
  let cluster_chars = if boundaries.length() > 1 {
    boundaries[1]
  } else {
    chars.length()
  }
  let cluster = @internal.grapheme_slice(text, 0, 1)
  let consumed = byte_offsets[cluster_chars]
  Ok(key_text_event(cluster), consumed)
}

///|
fn parse_text_event(bv : BytesView) -> ParseResult[InputEvent] {
  let chars : Array[Char] = []
  let byte_offsets : Array[Int] = [0]
  let total = bv.length()
  let mut offset = 0
  while offset < total {
    match decode_utf8_scalar(bv[offset:total]) {
      Utf8Ok(ch, consumed) => {
        if !is_text_scalar(ch) {
          if chars.is_empty() {
            return Ok(unknown_event(bv, consumed), consumed)
          }
          return emit_text_event(chars, byte_offsets)
        }
        chars.push(ch)
        offset = offset + consumed
        byte_offsets.push(offset)
        let text = String::from_array(chars)
        let boundaries = @internal.grapheme_boundaries(text)
        if boundaries.length() > 2 {
          return emit_text_event(chars, byte_offsets)
        }
      }
      Utf8Incomplete => {
        if chars.is_empty() {
          return Incomplete
        }
        return emit_text_event(chars, byte_offsets)
      }
      Utf8Invalid(message) => {
        if chars.is_empty() {
          return Invalid(message)
        }
        return emit_text_event(chars, byte_offsets)
      }
    }
  }
  if chars.is_empty() {
    Incomplete
  } else {
    emit_text_event(chars, byte_offsets)
  }
}

///|
fn parse_bracketed_paste(
  bv : BytesView,
  payload_start : Int,
) -> ParseResult[InputEvent] {
  let total = bv.length()
  let mut i = payload_start
  while i + 5 < total {
    if bv[i].to_int() == 0x1B &&
      bv[i + 1].to_int() == 0x5B &&
      bv[i + 2].to_int() == 0x32 &&
      bv[i + 3].to_int() == 0x30 &&
      bv[i + 4].to_int() == 0x31 &&
      bv[i + 5].to_int() == 0x7E {
      let pasted = Bytes::from_array(bv[payload_start:i].to_array())
      return Ok(Paste(@utf8.decode_lossy(pasted)), i + 6)
    }
    i = i + 1
  }
  Incomplete
}

///|
fn mouse_modifiers(cb : Int) -> Array[MouseModifier] {
  let modifiers : Array[MouseModifier] = []
  if (cb & 0x04) != 0 {
    modifiers.push(MouseShift)
  }
  if (cb & 0x08) != 0 {
    modifiers.push(MouseAlt)
  }
  if (cb & 0x10) != 0 {
    modifiers.push(MouseCtrl)
  }
  modifiers
}

///|
fn mouse_button(cb : Int) -> MouseButton {
  let low = cb & 0x03
  if (cb & 0x40) != 0 {
    match low {
      0 => MouseWheelUp
      1 => MouseWheelDown
      2 => MouseWheelLeft
      _ => MouseWheelRight
    }
  } else {
    match low {
      0 => MouseLeft
      1 => MouseMiddle
      2 => MouseRight
      _ => MouseNoButton
    }
  }
}

///|
fn is_no_button_report(cb : Int) -> Bool {
  (cb & 0x40) == 0 && (cb & 0x03) == 0x03
}

///|
fn parse_sgr_mouse(bv : BytesView) -> ParseResult[InputEvent] {
  let n = bv.length()
  let mut final_index = 3
  while final_index < n {
    let b = bv[final_index].to_int()
    if b == 0x4D || b == 0x6D {
      let values : Array[Int] = []
      let mut value = 0
      let mut has_digit = false
      let mut j = 3
      while j < final_index {
        let part = bv[j].to_int()
        if part >= 0x30 && part <= 0x39 {
          value = value * 10 + part - 0x30
          has_digit = true
        } else if part == 0x3B {
          if !has_digit {
            return Invalid("empty SGR mouse parameter")
          }
          values.push(value)
          value = 0
          has_digit = false
        } else {
          return Invalid("invalid byte \{part} in SGR mouse sequence")
        }
        j = j + 1
      }
      if !has_digit {
        return Invalid("empty SGR mouse parameter")
      }
      values.push(value)
      if values.length() != 3 {
        return Invalid("SGR mouse report must contain Cb, Cx, and Cy")
      }
      let cb = values[0]
      let col = values[1]
      let row = values[2]
      if col <= 0 || row <= 0 {
        return Invalid("SGR mouse coordinates must be 1-based")
      }
      let is_wheel = (cb & 0x40) != 0
      let action = if is_wheel {
        MouseWheel
      } else if b == 0x6D {
        MouseRelease
      } else if (cb & 0x20) != 0 {
        MouseMotion
      } else {
        MousePress
      }
      if is_no_button_report(cb) && action != MouseMotion {
        return Ok(unknown_event(bv, final_index + 1), final_index + 1)
      }
      let button = mouse_button(cb)
      return Ok(
        Mouse({ button, action, modifiers: mouse_modifiers(cb), col, row }),
        final_index + 1,
      )
    } else if (b >= 0x30 && b <= 0x39) || b == 0x3B {
      final_index = final_index + 1
    } else {
      return Invalid("invalid byte \{b} in SGR mouse sequence")
    }
  }
  Incomplete
}

///|
priv enum EnhancedKeyParse {
  EnhancedKeyOk(InputEvent)
  EnhancedKeyUnknown
  EnhancedKeyInvalid(String)
}

///|
fn enhanced_key_code(value : Int) -> EnhancedKeyCode {
  if value >= 57344 && value <= 63743 {
    FunctionalKey(value)
  } else {
    UnicodeKey(value)
  }
}

///|
fn parse_decimal_segment(bv : BytesView, start : Int, end : Int) -> Int? {
  if start >= end {
    return None
  }
  let mut value = 0
  let mut i = start
  while i < end {
    let b = bv[i].to_int()
    if b < 0x30 || b > 0x39 {
      return None
    }
    value = value * 10 + b - 0x30
    i = i + 1
  }
  Some(value)
}

///|
fn parse_decimal_params(bv : BytesView, start : Int, end : Int) -> Array[Int]? {
  if start >= end {
    return None
  }
  let params : Array[Int] = []
  let mut segment_start = start
  let mut i = start
  while i <= end {
    if i == end || bv[i].to_int() == 0x3B {
      match parse_decimal_segment(bv, segment_start, i) {
        Some(value) => params.push(value)
        None => return None
      }
      segment_start = i + 1
    }
    i = i + 1
  }
  Some(params)
}

///|
fn parse_cursor_position_reply(
  bv : BytesView,
  final_index : Int,
) -> CursorPositionReply? {
  let mut semicolon = -1
  let mut i = 2
  while i < final_index {
    if bv[i].to_int() == 0x3B {
      if semicolon >= 0 {
        return None
      }
      semicolon = i
    }
    i = i + 1
  }
  if semicolon < 0 {
    return None
  }
  let row = match parse_decimal_segment(bv, 2, semicolon) {
    Some(value) => value
    None => return None
  }
  let col = match parse_decimal_segment(bv, semicolon + 1, final_index) {
    Some(value) => value
    None => return None
  }
  if row <= 0 || col <= 0 {
    return None
  }
  Some({ row, col })
}

///|
fn parse_device_attributes_reply(
  bv : BytesView,
  final_index : Int,
) -> TerminalReplyMsg? {
  if final_index <= 3 {
    return None
  }
  let prefix = bv[2].to_int()
  if prefix == 0x3F {
    match parse_decimal_params(bv, 3, final_index) {
      Some(params) => Some(DeviceAttributes(params))
      None => None
    }
  } else if prefix == 0x3E {
    match parse_decimal_params(bv, 3, final_index) {
      Some(params) => Some(SecondaryDeviceAttributes(params))
      None => None
    }
  } else {
    None
  }
}

///|
fn is_csi_unknown_reply(
  bv : BytesView,
  final_index : Int,
  final_byte : Int,
) -> Bool {
  if final_byte == 0x52 ||
    final_byte == 0x63 ||
    final_byte == 0x6E ||
    final_byte == 0x74 {
    return true
  }
  if final_index > 2 {
    let first = bv[2].to_int()
    first == 0x3F || first == 0x3E
  } else {
    false
  }
}

///|
fn decode_slice_lossy(bv : BytesView, start : Int, end : Int) -> String {
  @utf8.decode_lossy(Bytes::from_array(bv[start:end].to_array()))
}

///|
fn is_osc_command_start(b : Int) -> Bool {
  b >= 0x30 && b <= 0x39
}

///|
fn parse_osc_color_reply(
  bv : BytesView,
  payload_start : Int,
  payload_end : Int,
) -> TerminalColorReply? {
  let len = payload_end - payload_start
  if len >= 3 &&
    bv[payload_start].to_int() == 0x31 &&
    bv[payload_start + 1].to_int() == 0x30 &&
    bv[payload_start + 2].to_int() == 0x3B {
    return Some(
      ForegroundColor(decode_slice_lossy(bv, payload_start + 3, payload_end)),
    )
  }
  if len >= 3 &&
    bv[payload_start].to_int() == 0x31 &&
    bv[payload_start + 1].to_int() == 0x31 &&
    bv[payload_start + 2].to_int() == 0x3B {
    return Some(
      BackgroundColor(decode_slice_lossy(bv, payload_start + 3, payload_end)),
    )
  }
  if len >= 4 &&
    bv[payload_start].to_int() == 0x34 &&
    bv[payload_start + 1].to_int() == 0x3B {
    let index_start = payload_start + 2
    let mut separator = -1
    let mut i = index_start
    while i < payload_end {
      if bv[i].to_int() == 0x3B {
        separator = i
        break
      }
      i = i + 1
    }
    if separator > index_start {
      match parse_decimal_segment(bv, index_start, separator) {
        Some(index) =>
          return Some(
            PaletteColor(
              index,
              decode_slice_lossy(bv, separator + 1, payload_end),
            ),
          )
        None => ()
      }
    }
  }
  None
}

///|
fn base64_value(b : Int) -> Int? {
  if b >= 0x41 && b <= 0x5A {
    Some(b - 0x41)
  } else if b >= 0x61 && b <= 0x7A {
    Some(b - 0x61 + 26)
  } else if b >= 0x30 && b <= 0x39 {
    Some(b - 0x30 + 52)
  } else if b == 0x2B {
    Some(62)
  } else if b == 0x2F {
    Some(63)
  } else {
    None
  }
}

///|
fn base64_digit(value : Int) -> Char {
  if value < 26 {
    (0x41 + value).unsafe_to_char()
  } else if value < 52 {
    (0x61 + value - 26).unsafe_to_char()
  } else if value < 62 {
    (0x30 + value - 52).unsafe_to_char()
  } else if value == 62 {
    '+'
  } else if value == 63 {
    '/'
  } else {
    abort("base64 digit out of range")
  }
}

///|
fn encode_base64_utf8(input : String) -> String {
  let bytes = @utf8.encode(input)
  let len = bytes.length()
  let buf = StringBuilder::new(size_hint=(len + 2) / 3 * 4)
  let mut i = 0
  while i < len {
    let a = bytes[i].to_int()
    let has_b = i + 1 < len
    let has_c = i + 2 < len
    let b = if has_b { bytes[i + 1].to_int() } else { 0 }
    let c = if has_c { bytes[i + 2].to_int() } else { 0 }
    buf.write_char(base64_digit((a >> 2) & 0x3F))
    buf.write_char(base64_digit(((a & 0x03) << 4) | ((b >> 4) & 0x0F)))
    if has_b {
      buf.write_char(base64_digit(((b & 0x0F) << 2) | ((c >> 6) & 0x03)))
    } else {
      buf.write_char('=')
    }
    if has_c {
      buf.write_char(base64_digit(c & 0x3F))
    } else {
      buf.write_char('=')
    }
    i = i + 3
  }
  buf.to_string()
}

///|
fn decode_base64_slice(bv : BytesView, start : Int, end : Int) -> Bytes? {
  let values : Array[Int] = []
  let mut saw_padding = false
  let mut i = start
  while i < end {
    let b = bv[i].to_int()
    if b == 0x3D {
      saw_padding = true
      values.push(-1)
    } else {
      if saw_padding {
        return None
      }
      match base64_value(b) {
        Some(value) => values.push(value)
        None => return None
      }
    }
    i = i + 1
  }
  if values.length() == 0 {
    return Some(Bytes::new(0))
  }
  match values.length() % 4 {
    0 => ()
    2 => {
      values.push(-1)
      values.push(-1)
    }
    3 => values.push(-1)
    _ => return None
  }
  let decoded : Array[Byte] = []
  let mut index = 0
  while index < values.length() {
    let a = values[index]
    let b = values[index + 1]
    let c = values[index + 2]
    let d = values[index + 3]
    if a < 0 || b < 0 {
      return None
    }
    if (c < 0 || d < 0) && index + 4 != values.length() {
      return None
    }
    decoded.push((((a << 2) | (b >> 4)) & 0xFF).to_byte())
    if c >= 0 {
      decoded.push(((((b & 0x0F) << 4) | (c >> 2)) & 0xFF).to_byte())
    }
    if c >= 0 && d >= 0 {
      decoded.push(((((c & 0x03) << 6) | d) & 0xFF).to_byte())
    } else if c < 0 && d >= 0 {
      return None
    }
    index = index + 4
  }
  Some(Bytes::from_array(decoded))
}

///|
fn decode_utf8_strict(bytes : Bytes) -> String? {
  let bv = bytes[:]
  let mut offset = 0
  while offset < bv.length() {
    match decode_utf8_scalar(bv[offset:bv.length()]) {
      Utf8Ok(_, consumed) => offset = offset + consumed
      Utf8Incomplete | Utf8Invalid(_) => return None
    }
  }
  Some(@utf8.decode_lossy(bytes))
}

///|
fn parse_osc_clipboard_reply(
  bv : BytesView,
  payload_start : Int,
  payload_end : Int,
) -> ClipboardReply? {
  let len = payload_end - payload_start
  if len < 4 ||
    bv[payload_start].to_int() != 0x35 ||
    bv[payload_start + 1].to_int() != 0x32 ||
    bv[payload_start + 2].to_int() != 0x3B {
    return None
  }
  let selection_start = payload_start + 3
  let mut separator = -1
  let mut i = selection_start
  while i < payload_end {
    if bv[i].to_int() == 0x3B {
      separator = i
      break
    }
    i = i + 1
  }
  if separator < 0 {
    return None
  }
  let selection = parse_clipboard_selection_code(
    decode_slice_lossy(bv, selection_start, separator),
  )
  let raw = decode_slice_lossy(bv, separator + 1, payload_end)
  let payload = match decode_base64_slice(bv, separator + 1, payload_end) {
    Some(decoded) =>
      match decode_utf8_strict(decoded) {
        Some(text) => DecodedClipboardText(text)
        None => RawClipboardData(raw)
      }
    None => RawClipboardData(raw)
  }
  Some({ selection, payload })
}

///|
fn parse_osc_payload(
  bv : BytesView,
  payload_start : Int,
  payload_end : Int,
  consumed : Int,
) -> ParseResult[InputEvent] {
  match parse_osc_clipboard_reply(bv, payload_start, payload_end) {
    Some(reply) => Ok(TerminalReply(Clipboard(reply)), consumed)
    None =>
      match parse_osc_color_reply(bv, payload_start, payload_end) {
        Some(color) => Ok(TerminalReply(Color(color)), consumed)
        None => Ok(unknown_reply_event(bv, consumed), consumed)
      }
  }
}

///|
fn parse_osc(bv : BytesView) -> ParseResult[InputEvent] {
  let n = bv.length()
  if n < 3 {
    return Incomplete
  }
  let mut i = 2
  while i < n {
    let b = bv[i].to_int()
    if b == 0x07 {
      return parse_osc_payload(bv, 2, i, i + 1)
    }
    if b == 0x1B {
      if i + 1 >= n {
        return Incomplete
      }
      if bv[i + 1].to_int() == 0x5C {
        return parse_osc_payload(bv, 2, i, i + 2)
      }
    }
    i = i + 1
  }
  Incomplete
}

///|
fn hex_value(b : Int) -> Int? {
  if b >= 0x30 && b <= 0x39 {
    Some(b - 0x30)
  } else if b >= 0x41 && b <= 0x46 {
    Some(b - 0x41 + 10)
  } else if b >= 0x61 && b <= 0x66 {
    Some(b - 0x61 + 10)
  } else {
    None
  }
}

///|
fn decode_hex_slice(bv : BytesView, start : Int, end : Int) -> Bytes? {
  if (end - start) % 2 != 0 {
    return None
  }
  let decoded : Array[Byte] = []
  let mut i = start
  while i < end {
    let high = match hex_value(bv[i].to_int()) {
      Some(value) => value
      None => return None
    }
    let low = match hex_value(bv[i + 1].to_int()) {
      Some(value) => value
      None => return None
    }
    decoded.push(((high << 4) | low).to_byte())
    i = i + 2
  }
  Some(Bytes::from_array(decoded))
}

///|
fn decode_hex_text(bv : BytesView, start : Int, end : Int) -> String? {
  if start >= end {
    return None
  }
  match decode_hex_slice(bv, start, end) {
    Some(bytes) => Some(@utf8.decode_lossy(bytes))
    None => None
  }
}

///|
fn parse_capability_reply(
  bv : BytesView,
  payload_start : Int,
  payload_end : Int,
) -> CapabilityReply? {
  let len = payload_end - payload_start
  if len < 4 ||
    bv[payload_start + 1].to_int() != 0x2B ||
    bv[payload_start + 2].to_int() != 0x72 {
    return None
  }
  let status = bv[payload_start].to_int()
  let valid = if status == 0x31 {
    true
  } else if status == 0x30 {
    false
  } else {
    return None
  }
  let data_start = payload_start + 3
  let mut item_end = payload_end
  let mut separator = -1
  let mut i = data_start
  while i < payload_end {
    let b = bv[i].to_int()
    if b == 0x3B {
      item_end = i
      break
    }
    if b == 0x3D {
      if separator >= 0 {
        return None
      }
      separator = i
    }
    i = i + 1
  }
  let name_end = if separator >= 0 { separator } else { item_end }
  let name = match decode_hex_text(bv, data_start, name_end) {
    Some(decoded) => decoded
    None => return None
  }
  let value = if valid {
    if separator < 0 || separator + 1 >= item_end {
      return None
    }
    match decode_hex_text(bv, separator + 1, item_end) {
      Some(decoded) => Some(decoded)
      None => return None
    }
  } else {
    if separator >= 0 {
      return None
    }
    None
  }
  Some({ name, value, valid })
}

///|
fn parse_dcs_payload(
  bv : BytesView,
  payload_start : Int,
  payload_end : Int,
  consumed : Int,
) -> ParseResult[InputEvent] {
  match parse_capability_reply(bv, payload_start, payload_end) {
    Some(reply) => Ok(TerminalReply(Capability(reply)), consumed)
    None => Ok(unknown_reply_event(bv, consumed), consumed)
  }
}

///|
fn parse_dcs(bv : BytesView) -> ParseResult[InputEvent] {
  let n = bv.length()
  if n < 3 {
    return Incomplete
  }
  let mut i = 2
  while i < n {
    let b = bv[i].to_int()
    if b == 0x1B {
      if i + 1 >= n {
        return Incomplete
      }
      if bv[i + 1].to_int() == 0x5C {
        return parse_dcs_payload(bv, 2, i, i + 2)
      }
    }
    i = i + 1
  }
  Incomplete
}

///|
fn parse_key_code_segment(
  bv : BytesView,
  start : Int,
  end : Int,
) -> EnhancedKeyCode? {
  match parse_decimal_segment(bv, start, end) {
    Some(value) => Some(enhanced_key_code(value))
    None => None
  }
}

///|
fn parse_enhanced_key_code_triple(
  bv : BytesView,
  start : Int,
  end : Int,
) -> EnhancedKeyParse {
  if start >= end {
    return EnhancedKeyUnknown
  }
  let first = bv[start].to_int()
  if first < 0x30 || first > 0x39 {
    return EnhancedKeyUnknown
  }
  let colon_positions : Array[Int] = []
  let mut i = start
  while i < end {
    if bv[i].to_int() == 0x3A {
      colon_positions.push(i)
    }
    i = i + 1
  }
  if colon_positions.length() > 2 {
    return EnhancedKeyInvalid("CSI-u key code contains too many alternates")
  }
  let primary_end = if colon_positions.length() == 0 {
    end
  } else {
    colon_positions[0]
  }
  let primary = match parse_key_code_segment(bv, start, primary_end) {
    Some(code) => code
    None => return EnhancedKeyInvalid("invalid CSI-u primary key code")
  }
  let shifted = if colon_positions.length() >= 1 {
    let shifted_start = colon_positions[0] + 1
    let shifted_end = if colon_positions.length() == 1 {
      end
    } else {
      colon_positions[1]
    }
    match parse_key_code_segment(bv, shifted_start, shifted_end) {
      Some(code) => Some(code)
      None => return EnhancedKeyInvalid("invalid CSI-u shifted key code")
    }
  } else {
    None
  }
  let base_layout = if colon_positions.length() == 2 {
    match parse_key_code_segment(bv, colon_positions[1] + 1, end) {
      Some(code) => Some(code)
      None => return EnhancedKeyInvalid("invalid CSI-u base-layout key code")
    }
  } else {
    None
  }
  EnhancedKeyOk(
    EnhancedKey({
      code: primary,
      shifted,
      base_layout,
      modifiers: [],
      event_type: KeyPress,
      text_codepoints: [],
    }),
  )
}

///|
fn parse_enhanced_event_type(value : Int) -> EnhancedKeyEventType? {
  match value {
    1 => Some(KeyPress)
    2 => Some(KeyRepeat)
    3 => Some(KeyRelease)
    _ => None
  }
}

///|
fn enhanced_key_modifiers(encoded : Int) -> Array[EnhancedKeyModifier]? {
  if encoded < 1 {
    return None
  }
  let bits = encoded - 1
  let modifiers : Array[EnhancedKeyModifier] = []
  if (bits & 0x01) != 0 {
    modifiers.push(KeyShift)
  }
  if (bits & 0x02) != 0 {
    modifiers.push(KeyAlt)
  }
  if (bits & 0x04) != 0 {
    modifiers.push(KeyCtrl)
  }
  if (bits & 0x08) != 0 {
    modifiers.push(KeySuper)
  }
  if (bits & 0x10) != 0 {
    modifiers.push(KeyHyper)
  }
  if (bits & 0x20) != 0 {
    modifiers.push(KeyMeta)
  }
  if (bits & 0x40) != 0 {
    modifiers.push(KeyCapsLock)
  }
  if (bits & 0x80) != 0 {
    modifiers.push(KeyNumLock)
  }
  Some(modifiers)
}

///|
fn parse_enhanced_key_modifiers(
  bv : BytesView,
  start : Int,
  end : Int,
) -> (Array[EnhancedKeyModifier], EnhancedKeyEventType)? {
  if start >= end {
    return None
  }
  let mut colon_index = -1
  let mut i = start
  while i < end {
    if bv[i].to_int() == 0x3A {
      if colon_index >= 0 {
        return None
      }
      colon_index = i
    }
    i = i + 1
  }
  let modifiers_end = if colon_index >= 0 { colon_index } else { end }
  let modifiers = if start == modifiers_end {
    return None
  } else {
    match parse_decimal_segment(bv, start, modifiers_end) {
      Some(value) =>
        match enhanced_key_modifiers(value) {
          Some(modifiers) => modifiers
          None => return None
        }
      None => return None
    }
  }
  let event_type = if colon_index >= 0 {
    match parse_decimal_segment(bv, colon_index + 1, end) {
      Some(value) =>
        match parse_enhanced_event_type(value) {
          Some(kind) => kind
          None => return None
        }
      None => return None
    }
  } else {
    KeyPress
  }
  Some((modifiers, event_type))
}

///|
fn parse_enhanced_text_codepoints(
  bv : BytesView,
  start : Int,
  end : Int,
) -> Array[Int]? {
  let codepoints : Array[Int] = []
  if start >= end {
    return None
  }
  let mut segment_start = start
  let mut i = start
  while i <= end {
    if i == end || bv[i].to_int() == 0x3A {
      match parse_decimal_segment(bv, segment_start, i) {
        Some(value) => codepoints.push(value)
        None => return None
      }
      segment_start = i + 1
    }
    i = i + 1
  }
  Some(codepoints)
}

///|
fn parse_enhanced_key(bv : BytesView, final_index : Int) -> EnhancedKeyParse {
  let start = 2
  let end = final_index
  let semicolons : Array[Int] = []
  let mut i = start
  while i < end {
    if bv[i].to_int() == 0x3B {
      semicolons.push(i)
    }
    i = i + 1
  }
  if semicolons.length() > 2 {
    return EnhancedKeyInvalid("CSI-u key event has too many parameters")
  }
  let key_end = if semicolons.length() == 0 { end } else { semicolons[0] }
  let key_data = match parse_enhanced_key_code_triple(bv, start, key_end) {
    EnhancedKeyOk(EnhancedKey(key)) => key
    EnhancedKeyOk(_) => return EnhancedKeyInvalid("invalid CSI-u key payload")
    EnhancedKeyUnknown => return EnhancedKeyUnknown
    EnhancedKeyInvalid(message) => return EnhancedKeyInvalid(message)
  }
  let (modifiers, event_type) = if semicolons.length() >= 1 {
    let modifiers_start = semicolons[0] + 1
    let modifiers_end = if semicolons.length() == 1 {
      end
    } else {
      semicolons[1]
    }
    match parse_enhanced_key_modifiers(bv, modifiers_start, modifiers_end) {
      Some(parsed) => parsed
      None => return EnhancedKeyInvalid("invalid CSI-u modifiers or event type")
    }
  } else {
    ([], KeyPress)
  }
  let text_codepoints = if semicolons.length() == 2 {
    match parse_enhanced_text_codepoints(bv, semicolons[1] + 1, end) {
      Some(codepoints) => codepoints
      None => return EnhancedKeyInvalid("invalid CSI-u text codepoint list")
    }
  } else {
    []
  }
  EnhancedKeyOk(
    EnhancedKey({ ..key_data, modifiers, event_type, text_codepoints }),
  )
}

///|
/// Parse an ANSI CSI sequence starting at `bv[0]` (which must be ESC).
/// `bv[1]` must be `[` (0x5B) before calling this function.
fn parse_csi(bv : BytesView) -> ParseResult[InputEvent] {
  let n = bv.length()
  // Need at least ESC [ <final>
  if n < 3 {
    return Incomplete
  }
  // SGR mouse report: ESC [ < Cb ; Cx ; Cy (M|m)
  if bv[2].to_int() == 0x3C {
    return parse_sgr_mouse(bv)
  }
  // Scan parameter / intermediate bytes until we hit the final byte.
  // Parameter bytes: 0x30-0x3F, intermediate bytes: 0x20-0x2F.
  // Final byte: 0x40-0x7E.
  let mut i = 2
  while i < n {
    let b = bv[i].to_int()
    if b >= 0x40 && b <= 0x7E {
      let consumed = i + 1
      let params = @utf8.decode_lossy(Bytes::from_array(bv[2:i].to_array()))
      if b == 0x75 {
        match parse_enhanced_key(bv, i) {
          EnhancedKeyOk(evt) => return Ok(evt, consumed)
          EnhancedKeyUnknown => ()
          EnhancedKeyInvalid(message) => return Invalid(message)
        }
      }
      if b == 0x52 {
        match parse_cursor_position_reply(bv, i) {
          Some(reply) =>
            return Ok(TerminalReply(CursorPosition(reply)), consumed)
          None => return Ok(unknown_reply_event(bv, consumed), consumed)
        }
      }
      if b == 0x63 {
        match parse_device_attributes_reply(bv, i) {
          Some(reply) => return Ok(TerminalReply(reply), consumed)
          None => return Ok(unknown_reply_event(bv, consumed), consumed)
        }
      }
      if is_csi_unknown_reply(bv, i, b) {
        return Ok(unknown_reply_event(bv, consumed), consumed)
      }
      let evt : InputEvent = match (b, params) {
        (0x41, "") => Key(Special("up"))
        (0x42, "") => Key(Special("down"))
        (0x43, "") => Key(Special("right"))
        (0x44, "") => Key(Special("left"))
        (0x46, "") => Key(Special("end"))
        (0x48, "") => Key(Special("home"))
        (0x49, "") => Focus
        (0x4F, "") => Blur
        (0x5A, "") => Key(Modified("shift", "tab"))
        (0x7E, "2") => Key(Special("insert"))
        (0x7E, "3") => Key(Special("delete"))
        (0x7E, "5") => Key(Special("pageup"))
        (0x7E, "6") => Key(Special("pagedown"))
        (0x7E, "200") => return parse_bracketed_paste(bv, consumed)
        _ => unknown_event(bv, consumed)
      }
      return Ok(evt, consumed)
    } else if b >= 0x20 && b <= 0x3F {
      i = i + 1
    } else {
      // Byte is not a valid parameter/intermediate/final byte — definitively malformed.
      return Invalid("invalid byte \{b} in CSI sequence at position \{i}")
    }
  }
  // Reached end of buffer without finding the final byte.
  Incomplete
}

///|
/// Parse one `InputEvent` from the front of `bv`.
///
/// Returns `Ok(event, bytes_consumed)` on success, `Incomplete` when more
/// bytes are needed to complete the current sequence, or `Invalid` when a CSI
/// sequence contains a definitively malformed parameter byte. Unrecognised but
/// structurally valid sequences are returned as `Ok(Unknown(...), n)` so callers
/// can distinguish protocol errors from merely unknown sequences.
pub fn parse_input(bv : BytesView) -> ParseResult[InputEvent] {
  if bv.length() == 0 {
    return Incomplete
  }
  let b0 = bv[0].to_int()
  // Printable UTF-8 text, including ASCII space through tilde.
  if (b0 >= 0x20 && b0 <= 0x7E) || b0 >= 0x80 {
    return parse_text_event(bv)
  }
  // DEL (0x7F) and BS (0x08) → backspace
  if b0 == 0x7F || b0 == 0x08 {
    return Ok(Key(Special("backspace")), 1)
  }
  // CR (0x0D) → enter
  if b0 == 0x0D {
    return Ok(Key(Special("enter")), 1)
  }
  // HT (0x09) → tab
  if b0 == 0x09 {
    return Ok(Key(Special("tab")), 1)
  }
  // ESC (0x1B): could be standalone, Alt+key, or start of CSI sequence
  if b0 == 0x1B {
    let n = bv.length()
    if n == 1 {
      // Could be standalone ESC or start of a sequence; need more bytes.
      return Incomplete
    }
    let b1 = bv[1].to_int()
    // ESC [ → CSI sequence
    if b1 == 0x5B {
      return parse_csi(bv)
    }
    // ESC ] plus a digit starts an OSC reply/control string; bare ESC ]
    // stays available for the Alt+] key path below.
    if b1 == 0x5D && n > 2 && is_osc_command_start(bv[2].to_int()) {
      return parse_osc(bv)
    }
    // ESC P plus a capability reply status starts a DCS reply; bare ESC P
    // remains available for the Alt+P key path below.
    if b1 == 0x50 &&
      n > 4 &&
      (bv[2].to_int() == 0x30 || bv[2].to_int() == 0x31) &&
      bv[3].to_int() == 0x2B &&
      (bv[4].to_int() == 0x71 || bv[4].to_int() == 0x72) {
      return parse_dcs(bv)
    }
    // ESC ESC → treat first ESC as standalone escape key
    if b1 == 0x1B {
      return Ok(Key(Special("escape")), 1)
    }
    // ESC <printable> → Alt+key
    if b1 >= 0x20 && b1 <= 0x7E {
      let ch = b1.unsafe_to_char()
      return Ok(Key(Modified("alt", String::make(1, ch))), 2)
    }
    // ESC followed by anything else → standalone escape, leave the rest
    return Ok(Key(Special("escape")), 1)
  }
  // Ctrl+letter: 0x01 (Ctrl+A) … 0x1A (Ctrl+Z)
  if b0 >= 0x01 && b0 <= 0x1A {
    let letter = (b0 + 0x60).unsafe_to_char()
    return Ok(Key(Modified("ctrl", String::make(1, letter))), 1)
  }
  // Everything else is returned as an unknown single byte.
  Ok(Unknown(Bytes::from_array([bv[0]])), 1)
}

///|
/// Drain all complete `InputEvent`s from `bv`.
///
/// Returns a tuple of the parsed events and any leftover bytes that formed an
/// incomplete sequence at the end of the buffer.
pub fn parse_all(bv : BytesView) -> (Array[InputEvent], Bytes) {
  let events : Array[InputEvent] = []
  let mut offset = 0
  let total = bv.length()
  while offset < total {
    let slice = bv[offset:total]
    match parse_input(slice) {
      Ok(evt, consumed) => {
        events.push(evt)
        offset = offset + consumed
      }
      Incomplete => break
      Invalid(_) =>
        // Skip one byte on a definitive error to avoid spinning.
        offset = offset + 1
    }
  }
  (events, Bytes::from_array(bv[offset:total].to_array()))
}
