///|
test "strip_ansi removes CSI sequences" {
  assert_eq(strip_ansi("\u001b[31mhello\u001b[0m"), "hello")
}

///|
test "strip_ansi removes bare ESC sequences" {
  assert_eq(strip_ansi("\u001bcX"), "X")
}

///|
test "strip_ansi plain string unchanged" {
  assert_eq(strip_ansi("hello"), "hello")
}

///|
test "strip_ansi empty string" {
  assert_eq(strip_ansi(""), "")
}

///|
test "visible_width plain string" {
  assert_eq(visible_width("hello"), 5)
}

///|
test "visible_width with ANSI" {
  assert_eq(visible_width("\u001b[1mbold\u001b[0m"), 4)
}

///|
test "visible_width empty" {
  assert_eq(visible_width(""), 0)
}

///|
test "split_lines basic" {
  assert_eq(split_lines("a\nb\nc"), ["a", "b", "c"])
}

///|
test "split_lines trailing newline" {
  assert_eq(split_lines("a\nb\n"), ["a", "b", ""])
}

///|
test "split_lines empty string" {
  assert_eq(split_lines(""), [""])
}

///|
test "split_lines single line" {
  assert_eq(split_lines("hello"), ["hello"])
}

///|
test "line_count" {
  assert_eq(line_count("a\nb\nc"), 3)
  assert_eq(line_count(""), 1)
  assert_eq(line_count("a\n"), 2)
}

///|
test "max_line_width" {
  assert_eq(max_line_width("hi\nhello\nyo"), 5)
  assert_eq(max_line_width(""), 0)
  assert_eq(max_line_width("abc"), 3)
}

///|
test "max_line_width with ANSI" {
  // Bold "hello" has visible width 5
  assert_eq(max_line_width("\u001b[1mhello\u001b[0m\nhi"), 5)
}

///|
test "center even padding" {
  assert_eq(center("hi", 6), "  hi  ")
}

///|
test "center odd padding prefers right" {
  assert_eq(center("hi", 5), " hi  ")
}

///|
test "center no-op when already wide enough" {
  assert_eq(center("hello", 3), "hello")
  assert_eq(center("hello", 5), "hello")
}

///|
test "pad_left" {
  assert_eq(pad_left("hi", 5), "   hi")
  assert_eq(pad_left("hello", 3), "hello")
  assert_eq(pad_left("hello", 5), "hello")
}

///|
test "pad_right" {
  assert_eq(pad_right("hi", 5), "hi   ")
  assert_eq(pad_right("hello", 3), "hello")
  assert_eq(pad_right("hello", 5), "hello")
}

///|
test "truncate basic" {
  assert_eq(truncate("hello", 3), "hel")
  assert_eq(truncate("hello", 10), "hello")
  assert_eq(truncate("hello", 5), "hello")
}

///|
test "truncate zero" {
  assert_eq(truncate("hello", 0), "")
}

///|
test "truncate preserves ANSI sequences before limit" {
  // Bold prefix + "hi" + reset: visible width is 2, so truncate(s, 2) keeps all
  let s = "\u001b[1mhi\u001b[0m"
  assert_eq(truncate(s, 2), s)
}

///|
test "truncate ANSI-aware cut" {
  // "\u001b[1m" + "hello" — visible width 5; truncate to 3 should give prefix + "hel"
  let s = "\u001b[1mhello"
  assert_eq(truncate(s, 3), "\u001b[1mhel")
}
