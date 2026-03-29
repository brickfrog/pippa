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
