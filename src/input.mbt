///|
/// ANSI escape-sequence parser for keyboard and mouse input events.
///
/// Translates raw bytes from the terminal into typed `InputEvent` values.
/// The parser handles printable ASCII, control characters, ANSI CSI
/// sequences (arrow keys, mouse reports), Ctrl-modified keys, and Alt-prefixed
/// keys. Pass a `BytesView` to `parse_input` for a single event, or
/// `parse_all` to drain all complete events at once.

///|
/// A parsed terminal input event.
pub(all) enum InputEvent {
  /// A keyboard event.
  Key(KeyMsg)
  /// A mouse event.
  Mouse(MouseMsg)
  /// Bytes that could not be mapped to a known event.
  Unknown(Bytes)
} derive(Show, Eq, Compare)

///|
/// Result of attempting to parse one event from a byte buffer.
pub(all) enum ParseResult[T] {
  /// Successfully parsed a value; the `Int` is the number of bytes consumed.
  Ok(T, Int)
  /// The buffer ended mid-sequence; supply more bytes and retry.
  Incomplete
  /// The byte sequence is definitively malformed.
  Invalid(String)
} derive(Show, Eq)

///|
/// Parse an ANSI CSI sequence starting at `bv[0]` (which must be ESC).
/// `bv[1]` must be `[` (0x5B) before calling this function.
fn parse_csi(bv : BytesView) -> ParseResult[InputEvent] {
  let n = bv.length()
  // Need at least ESC [ <final>
  if n < 3 {
    return Incomplete
  }
  // X10 mouse report: ESC [ M cb cx cy
  if bv[2].to_int() == 0x4D {
    if n < 6 {
      return Incomplete
    }
    let cb = bv[3].to_int() - 32
    let cx = bv[4].to_int() - 32
    let cy = bv[5].to_int() - 32
    let evt = if (cb & 64) != 0 {
      InputEvent::Mouse(MouseMsg::Motion(cx, cy))
    } else if cb == 3 {
      InputEvent::Mouse(MouseMsg::Release(cx, cy))
    } else {
      InputEvent::Mouse(MouseMsg::Press(cx, cy))
    }
    return Ok(evt, 6)
  }
  // Scan parameter / intermediate bytes until we hit the final byte.
  // Parameter bytes: 0x30-0x3F, intermediate bytes: 0x20-0x2F.
  // Final byte: 0x40-0x7E.
  let mut i = 2
  while i < n {
    let b = bv[i].to_int()
    if b >= 0x40 && b <= 0x7E {
      let consumed = i + 1
      let evt : InputEvent = match b {
        0x41 => Key(Special("up"))
        0x42 => Key(Special("down"))
        0x43 => Key(Special("right"))
        0x44 => Key(Special("left"))
        0x48 => Key(Special("home"))
        0x46 => Key(Special("end"))
        _ => {
          let arr : Array[Byte] = []
          for j in 0..<consumed {
            arr.push(bv[j])
          }
          Unknown(Bytes::from_array(arr))
        }
      }
      return Ok(evt, consumed)
    } else if b >= 0x20 && b <= 0x3F {
      i = i + 1
    } else {
      // Invalid byte inside CSI parameter area; consume up to and including it.
      let arr : Array[Byte] = []
      for j in 0..<=i {
        arr.push(bv[j])
      }
      return Ok(Unknown(Bytes::from_array(arr)), i + 1)
    }
  }
  // Reached end of buffer without finding the final byte.
  Incomplete
}

///|
/// Parse one `InputEvent` from the front of `bv`.
///
/// Returns `Ok(event, bytes_consumed)` on success, `Incomplete` when more
/// bytes are needed to complete the current sequence, or `Invalid` for a
/// definitively malformed sequence.
pub fn parse_input(bv : BytesView) -> ParseResult[InputEvent] {
  if bv.length() == 0 {
    return Incomplete
  }
  let b0 = bv[0].to_int()
  // Printable ASCII (space through tilde)
  if b0 >= 0x20 && b0 <= 0x7E {
    return Ok(Key(Char(b0.unsafe_to_char())), 1)
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
  let leftover : Array[Byte] = []
  for i in offset..<total {
    leftover.push(bv[i])
  }
  (events, Bytes::from_array(leftover))
}
