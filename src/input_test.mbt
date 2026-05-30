///|
/// Tests for the ANSI input parser.

///|
test "parse_input: empty bytes returns Incomplete" {
  let bytes = Bytes::from_array([])
  let bv = bytes[0:bytes.length()]
  assert_eq(parse_input(bv), Incomplete)
}

///|
test "parse_input: printable ASCII" {
  let bytes = Bytes::from_array([b'A'])
  let bv = bytes[0:bytes.length()]
  assert_eq(parse_input(bv), Ok(Key(Char('A')), 1))
}

///|
test "parse_input: UTF-8 two-byte scalar" {
  let bytes = Bytes::from_array([b'\xC3', b'\xA9'])
  assert_eq(parse_input(bytes[:]), Ok(Key(Char('é')), 2))
}

///|
test "parse_input: UTF-8 wide CJK scalar" {
  let bytes = Bytes::from_array([b'\xE7', b'\x95', b'\x8C'])
  assert_eq(parse_input(bytes[:]), Ok(Key(Char('界')), 3))
}

///|
test "parse_input: UTF-8 four-byte scalar" {
  let bytes = Bytes::from_array([b'\xF0', b'\x9F', b'\x98', b'\x80'])
  assert_eq(parse_input(bytes[:]), Ok(Key(Char('😀')), 4))
}

///|
test "parse_input: combining mark grapheme stays one text event" {
  let accented = String::from_array(['e', '\u{0301}'])
  let bytes = Bytes::from_array([b'e', b'\xCC', b'\x81'])
  assert_eq(parse_input(bytes[:]), Ok(Key(Text(accented)), 3))
}

///|
fn assert_invalid_utf8(name : String, raw : Array[Byte]) -> Unit raise {
  let bytes = Bytes::from_array(raw)
  match parse_input(bytes[:]) {
    Invalid(_) => ()
    Ok(Key(Char(ch)), _) =>
      fail("\{name}: malformed UTF-8 decoded as Char(\{ch})")
    Ok(Key(Text(text)), _) =>
      fail("\{name}: malformed UTF-8 decoded as Text(\{text})")
    _ => fail("\{name}: expected Invalid")
  }
}

///|
test "parse_input: malformed UTF-8 is rejected" {
  let cases = [
    ("invalid continuation", [b'\xC3', b'(']),
    ("overlong C0 lead", [b'\xC0', b'\x80']),
    ("overlong C1 lead", [b'\xC1', b'\xBF']),
    ("bad E0 A0 floor", [b'\xE0', b'\x9F', b'\x80']),
    ("bad F0 90 floor", [b'\xF0', b'\x80', b'\x80', b'\x80']),
    ("surrogate range", [b'\xED', b'\xA0', b'\x80']),
    ("above U+10FFFF F4", [b'\xF4', b'\x90', b'\x80', b'\x80']),
    ("above U+10FFFF F5", [b'\xF5', b'\x80', b'\x80', b'\x80']),
    ("lone continuation", [b'\x80']),
  ]
  for case in cases {
    let (name, raw) = case
    assert_invalid_utf8(name, raw)
  }
}

///|
test "parse_all: split UTF-8 scalar waits for completion" {
  let first = Bytes::from_array([b'\xC3'])
  let (first_events, first_leftover) = parse_all(first[:])
  assert_eq(first_events.length(), 0)
  assert_eq(first_leftover.to_array(), [b'\xC3'])
  let second = Bytes::from_array([..first_leftover.to_array(), b'\xA9'])
  let (events, leftover) = parse_all(second[:])
  assert_eq(events.length(), 1)
  assert_eq(events[0], Key(Char('é')))
  assert_eq(leftover.length(), 0)
}

///|
test "parse_all: complete text before split UTF-8 scalar is emitted" {
  let bytes = Bytes::from_array([b'a', b'\xC3'])
  let (events, leftover) = parse_all(bytes[:])
  assert_eq(events.length(), 1)
  assert_eq(events[0], Key(Char('a')))
  assert_eq(leftover.to_array(), [b'\xC3'])
}

///|
test "parse_input: space character" {
  let bytes = Bytes::from_array([b' '])
  let bv = bytes[0:bytes.length()]
  assert_eq(parse_input(bv), Ok(Key(Char(' ')), 1))
}

///|
test "parse_input: enter key (CR)" {
  let bytes = Bytes::from_array([b'\r'])
  let bv = bytes[0:bytes.length()]
  assert_eq(parse_input(bv), Ok(Key(Special("enter")), 1))
}

///|
test "parse_input: tab key" {
  let bytes = Bytes::from_array([b'\t'])
  let bv = bytes[0:bytes.length()]
  assert_eq(parse_input(bv), Ok(Key(Special("tab")), 1))
}

///|
test "parse_input: backspace (DEL 0x7F)" {
  let bytes = Bytes::from_array([b'\x7f'])
  let bv = bytes[0:bytes.length()]
  assert_eq(parse_input(bv), Ok(Key(Special("backspace")), 1))
}

///|
test "parse_input: lone ESC returns Incomplete" {
  let bytes = Bytes::from_array([b'\x1b'])
  let bv = bytes[0:bytes.length()]
  assert_eq(parse_input(bv), Incomplete)
}

///|
test "parse_input: ESC ESC returns escape" {
  let bytes = Bytes::from_array([b'\x1b', b'\x1b'])
  let bv = bytes[0:bytes.length()]
  assert_eq(parse_input(bv), Ok(Key(Special("escape")), 1))
}

///|
test "parse_input: Alt+a" {
  let bytes = Bytes::from_array([b'\x1b', b'a'])
  let bv = bytes[0:bytes.length()]
  assert_eq(parse_input(bv), Ok(Key(Modified("alt", "a")), 2))
}

///|
test "parse_input: Ctrl+c (0x03)" {
  let bytes = Bytes::from_array([b'\x03'])
  let bv = bytes[0:bytes.length()]
  assert_eq(parse_input(bv), Ok(Key(Modified("ctrl", "c")), 1))
}

///|
test "parse_input: arrow keys" {
  let up = Bytes::from_array([b'\x1b', b'[', b'A'])
  let down = Bytes::from_array([b'\x1b', b'[', b'B'])
  let right = Bytes::from_array([b'\x1b', b'[', b'C'])
  let left = Bytes::from_array([b'\x1b', b'[', b'D'])
  assert_eq(parse_input(up[0:3]), Ok(Key(Special("up")), 3))
  assert_eq(parse_input(down[0:3]), Ok(Key(Special("down")), 3))
  assert_eq(parse_input(right[0:3]), Ok(Key(Special("right")), 3))
  assert_eq(parse_input(left[0:3]), Ok(Key(Special("left")), 3))
}

///|
test "parse_input: page keys and shift-tab" {
  let page_up = Bytes::from_array([b'\x1b', b'[', b'5', b'~'])
  let page_down = Bytes::from_array([b'\x1b', b'[', b'6', b'~'])
  let shift_tab = Bytes::from_array([b'\x1b', b'[', b'Z'])
  assert_eq(parse_input(page_up[:]), Ok(Key(Special("pageup")), 4))
  assert_eq(parse_input(page_down[:]), Ok(Key(Special("pagedown")), 4))
  assert_eq(parse_input(shift_tab[:]), Ok(Key(Modified("shift", "tab")), 3))
}

///|
test "parse_input: focus and blur events" {
  let focus = Bytes::from_array([b'\x1b', b'[', b'I'])
  let blur = Bytes::from_array([b'\x1b', b'[', b'O'])
  assert_eq(parse_input(focus[:]), Ok(Focus, 3))
  assert_eq(parse_input(blur[:]), Ok(Blur, 3))
}

///|
fn assert_enhanced_key(raw : String, expected : EnhancedKeyMsg) -> Unit raise {
  let bytes = @utf8.encode(raw)
  assert_eq(parse_input(bytes[:]), Ok(EnhancedKey(expected), bytes.length()))
}

///|
fn assert_enhanced_invalid(raw : String) -> Unit raise {
  let bytes = @utf8.encode(raw)
  match parse_input(bytes[:]) {
    Invalid(_) => ()
    Ok(EnhancedKey(_), _) =>
      fail("\{raw}: malformed CSI-u decoded as EnhancedKey")
    _ => fail("\{raw}: expected Invalid")
  }
}

///|
test "parse_input: Kitty CSI-u press defaults to press with no modifiers" {
  assert_enhanced_key("\u001b[97u", {
    code: UnicodeKey(97),
    shifted: None,
    base_layout: None,
    modifiers: [],
    event_type: KeyPress,
    text_codepoints: [],
  })
}

///|
test "parse_input: Kitty CSI-u rejects empty modifiers field" {
  assert_enhanced_invalid("\u001b[97;u")
  assert_enhanced_invalid("\u001b[97;:3u")
}

///|
test "parse_input: Kitty CSI-u release event type" {
  assert_enhanced_key("\u001b[97;1:3u", {
    code: UnicodeKey(97),
    shifted: None,
    base_layout: None,
    modifiers: [],
    event_type: KeyRelease,
    text_codepoints: [],
  })
}

///|
test "parse_input: Kitty CSI-u repeat event type" {
  assert_enhanced_key("\u001b[97;1:2u", {
    code: UnicodeKey(97),
    shifted: None,
    base_layout: None,
    modifiers: [],
    event_type: KeyRepeat,
    text_codepoints: [],
  })
}

///|
test "parse_input: Kitty CSI-u modifiers decode bitfield plus one" {
  assert_enhanced_key("\u001b[97;6u", {
    code: UnicodeKey(97),
    shifted: None,
    base_layout: None,
    modifiers: [KeyShift, KeyCtrl],
    event_type: KeyPress,
    text_codepoints: [],
  })
}

///|
test "parse_input: Kitty CSI-u alternate keys and associated text" {
  assert_enhanced_key("\u001b[97:65:113;2;65u", {
    code: UnicodeKey(97),
    shifted: Some(UnicodeKey(65)),
    base_layout: Some(UnicodeKey(113)),
    modifiers: [KeyShift],
    event_type: KeyPress,
    text_codepoints: [65],
  })
}

///|
test "parse_input: legacy plain and escape keys keep stable KeyMsg values" {
  let plain = @utf8.encode("A")
  let up = @utf8.encode("\u001b[A")
  let shift_tab = @utf8.encode("\u001b[Z")
  let ctrl_c = Bytes::from_array([b'\x03'])
  assert_eq(parse_input(plain[:]), Ok(Key(Char('A')), 1))
  assert_eq(parse_input(up[:]), Ok(Key(Special("up")), 3))
  assert_eq(parse_input(shift_tab[:]), Ok(Key(Modified("shift", "tab")), 3))
  assert_eq(parse_input(ctrl_c[:]), Ok(Key(Modified("ctrl", "c")), 1))
}

///|
fn assert_sgr_mouse(raw : String, expected : MouseMsg) -> Unit raise {
  let bytes = @utf8.encode(raw)
  assert_eq(parse_input(bytes[:]), Ok(Mouse(expected), bytes.length()))
}

///|
fn assert_sgr_unknown(raw : String) -> Unit raise {
  let bytes = @utf8.encode(raw)
  assert_eq(parse_input(bytes[:]), Ok(Unknown(bytes), bytes.length()))
}

///|
fn assert_sgr_invalid(raw : String) -> Unit raise {
  let bytes = @utf8.encode(raw)
  match parse_input(bytes[:]) {
    Invalid(_) => ()
    _ => fail("expected Invalid")
  }
}

///|
test "parse_input: SGR mouse left press keeps coordinates" {
  assert_sgr_mouse("\u001b[<0;12;34M", {
    button: MouseLeft,
    action: MousePress,
    modifiers: [],
    col: 12,
    row: 34,
  })
}

///|
test "parse_input: SGR mouse middle and bare right press" {
  assert_sgr_mouse("\u001b[<1;3;4M", {
    button: MouseMiddle,
    action: MousePress,
    modifiers: [],
    col: 3,
    row: 4,
  })
  assert_sgr_mouse("\u001b[<2;5;6M", {
    button: MouseRight,
    action: MousePress,
    modifiers: [],
    col: 5,
    row: 6,
  })
}

///|
test "parse_input: SGR mouse release keeps button" {
  assert_sgr_mouse("\u001b[<0;12;34m", {
    button: MouseLeft,
    action: MouseRelease,
    modifiers: [],
    col: 12,
    row: 34,
  })
}

///|
test "parse_input: SGR mouse drag reports motion" {
  assert_sgr_mouse("\u001b[<32;5;6M", {
    button: MouseLeft,
    action: MouseMotion,
    modifiers: [],
    col: 5,
    row: 6,
  })
}

///|
test "parse_input: SGR mouse no-button motion" {
  assert_sgr_mouse("\u001b[<35;15;16M", {
    button: MouseNoButton,
    action: MouseMotion,
    modifiers: [],
    col: 15,
    row: 16,
  })
}

///|
test "parse_input: SGR no-button press and release are unknown" {
  assert_sgr_unknown("\u001b[<3;1;1M")
  assert_sgr_unknown("\u001b[<3;1;1m")
}

///|
test "parse_input: SGR mouse wheel up and down" {
  assert_sgr_mouse("\u001b[<64;7;8M", {
    button: MouseWheelUp,
    action: MouseWheel,
    modifiers: [],
    col: 7,
    row: 8,
  })
  assert_sgr_mouse("\u001b[<65;9;10M", {
    button: MouseWheelDown,
    action: MouseWheel,
    modifiers: [],
    col: 9,
    row: 10,
  })
}

///|
test "parse_input: SGR mouse horizontal wheel reports" {
  assert_sgr_mouse("\u001b[<66;11;12M", {
    button: MouseWheelLeft,
    action: MouseWheel,
    modifiers: [],
    col: 11,
    row: 12,
  })
  assert_sgr_mouse("\u001b[<67;13;14M", {
    button: MouseWheelRight,
    action: MouseWheel,
    modifiers: [],
    col: 13,
    row: 14,
  })
}

///|
test "parse_all: SGR horizontal wheel is consumed as one event" {
  let bytes = @utf8.encode("\u001b[<66;11;12Mx")
  let (events, leftover) = parse_all(bytes[:])
  assert_eq(events.length(), 2)
  assert_eq(
    events[0],
    Mouse({
      button: MouseWheelLeft,
      action: MouseWheel,
      modifiers: [],
      col: 11,
      row: 12,
    }),
  )
  assert_eq(events[1], Key(Char('x')))
  assert_eq(leftover.length(), 0)
}

///|
test "parse_input: SGR mouse shift alt ctrl modifiers" {
  assert_sgr_mouse("\u001b[<30;120;45M", {
    button: MouseRight,
    action: MousePress,
    modifiers: [MouseShift, MouseAlt, MouseCtrl],
    col: 120,
    row: 45,
  })
}

///|
test "parse_input: malformed SGR mouse sequences" {
  assert_sgr_invalid("\u001b[<;1;1M")
  assert_sgr_invalid("\u001b[<0;;1M")
  assert_sgr_invalid("\u001b[<0;x;1M")
  assert_sgr_invalid("\u001b[<0;1M")
  let missing_final = @utf8.encode("\u001b[<0;1;1")
  assert_eq(parse_input(missing_final[:]), Incomplete)
  let split = @utf8.encode("\u001b[<0;1;")
  let (events, leftover) = parse_all(split[:])
  assert_eq(events.length(), 0)
  assert_eq(leftover, split)
}

///|
test "parse_input: bracketed paste" {
  let pasted = Bytes::from_array([
    b'\x1b', b'[', b'2', b'0', b'0', b'~', b'h', b'i', b'\n', b'\x1b', b'[', b'2',
    b'0', b'1', b'~',
  ])
  assert_eq(parse_input(pasted[:]), Ok(Paste("hi\n"), 15))
}

///|
test "parse_input: incomplete CSI" {
  let bytes = Bytes::from_array([b'\x1b', b'['])
  let bv = bytes[0:bytes.length()]
  assert_eq(parse_input(bv), Incomplete)
}

///|
test "parse_all: multiple characters" {
  let bytes = Bytes::from_array([b'h', b'i', b'!'])
  let bv = bytes[0:bytes.length()]
  let (events, leftover) = parse_all(bv)
  assert_eq(events.length(), 3)
  assert_eq(events[0], Key(Char('h')))
  assert_eq(events[1], Key(Char('i')))
  assert_eq(events[2], Key(Char('!')))
  assert_eq(leftover.length(), 0)
}

///|
test "parse_all: incomplete sequence as leftover" {
  let bytes = Bytes::from_array([b'a', b'\x1b'])
  let bv = bytes[0:bytes.length()]
  let (events, leftover) = parse_all(bv)
  assert_eq(events.length(), 1)
  assert_eq(events[0], Key(Char('a')))
  assert_eq(leftover.length(), 1)
  assert_eq(leftover[0], b'\x1b')
}

///|
test "parse_all: arrow key in stream" {
  let bytes = Bytes::from_array([b'x', b'\x1b', b'[', b'A', b'y'])
  let bv = bytes[0:bytes.length()]
  let (events, leftover) = parse_all(bv)
  assert_eq(events.length(), 3)
  assert_eq(events[0], Key(Char('x')))
  assert_eq(events[1], Key(Special("up")))
  assert_eq(events[2], Key(Char('y')))
  assert_eq(leftover.length(), 0)
}
