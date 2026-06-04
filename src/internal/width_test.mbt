///|
test "display_width counts ASCII cells" {
  assert_eq(display_width("hello"), 5)
  assert_eq(display_width(""), 0)
}

///|
test "display_width counts CJK full-width cells" {
  assert_eq(display_width("你好"), 4)
  assert_eq(display_width("a你b"), 4)
  assert_eq(display_width(String::from_array(['\u{20000}'])), 2)
}

///|
test "display_width ignores combining marks" {
  let accented = String::from_array(['a', '\u{0301}', 'b'])
  assert_eq(display_width(accented), 2)
  assert_eq(display_width(String::from_array(['a', '\u{0483}'])), 1)
  assert_eq(display_width(String::from_array(['\u{0915}', '\u{094D}'])), 1)
  assert_eq(display_width(String::from_array(['\u{0995}', '\u{09CD}'])), 1)
}

///|
test "display_width counts emoji ZWJ cluster as one wide cell cluster" {
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  assert_eq(display_width(technologist), 2)
  assert_eq(display_width("x\{technologist}y"), 4)
}

///|
test "display_width treats ANSI SGR escapes as zero width" {
  assert_eq(display_width("\u001b[31mred\u001b[0m"), 3)
  assert_eq(display_width("\u001b[1m你\u001b[0m"), 2)
}

///|
test "display_width treats OSC escapes as zero width" {
  assert_eq(
    display_width("\u001b]8;;http://example.com\u001b\\label\u001b]8;;\u001b\\"),
    5,
  )
  assert_eq(
    display_width("\u001b]8;;http://example.com\u0007label\u001b]8;;\u0007"),
    5,
  )
}

///|
test "display_width stops CSI escapes at non-letter final bytes" {
  assert_eq(display_width("\u001b[@ab"), 2)
}

///|
test "grapheme_slice keeps combining marks and ZWJ clusters intact" {
  let accented = String::from_array(['a', '\u{0301}'])
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let text = "\{accented}b\{technologist}c"
  assert_eq(grapheme_slice(text, 0, 1), accented)
  assert_eq(grapheme_slice(text, 1, 3), "b\{technologist}")
  assert_eq(grapheme_slice(text, 0, 4), text)
  let flag = String::from_array(['\u{1F1FA}', '\u{1F1F8}'])
  assert_eq(grapheme_slice(flag, 0, 1), flag)
  let devanagari = String::from_array(['\u{0915}', '\u{094D}'])
  let bengali = String::from_array(['\u{0995}', '\u{09CD}'])
  assert_eq(grapheme_slice(devanagari, 0, 1), devanagari)
  assert_eq(grapheme_slice(bengali, 0, 1), bengali)
}

///|
test "grapheme_boundaries keeps ANSI runs out of cursor stops" {
  let styled = "\u001b[31m界\u001b[0m"
  @test.assert_eq(grapheme_boundaries(styled), [0, styled.to_array().length()])
  let mixed = "a\u001b[31m界\u001b[0mb"
  @test.assert_eq(grapheme_boundaries(mixed), [0, 1, 11, 12])
  @test.assert_eq(grapheme_boundaries("\u001b[31m"), [0])
}

///|
test "grapheme_boundaries keeps OSC 8 close with label text" {
  let open = "\u001b]8;;http://example.com\u001b\\"
  let link = open + "ab" + "\u001b]8;;\u001b\\"
  @test.assert_eq(grapheme_boundaries(link), [
    0,
    open.to_array().length() + 1,
    link.to_array().length(),
  ])
}

///|
test "truncate_width cuts by cell width without splitting graphemes" {
  let accented = String::from_array(['a', '\u{0301}'])
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  assert_eq(truncate_width("abcdef", 4), "abcd")
  assert_eq(truncate_width("你好世界", 4), "你好")
  assert_eq(truncate_width("\{accented}b", 1), accented)
  assert_eq(truncate_width("a\{technologist}b", 2), "a")
}

///|
test "truncate_width preserves ANSI SGR sequences around retained text" {
  assert_eq(
    truncate_width("\u001b[31mabcdef\u001b[0m", 3),
    "\u001b[31mabc\u001b[0m",
  )
  assert_eq(
    truncate_width("\u001b[1m你好吗\u001b[0m", 4),
    "\u001b[1m你好\u001b[0m",
  )
}

///|
test "pad_right_width pads to target display cells" {
  assert_eq(pad_right_width("hi", 5), "hi   ")
  assert_eq(pad_right_width("你", 3), "你 ")
  assert_eq(pad_right_width("hello", 3), "hello")
}

///|
test "pad_right_width preserves trailing ANSI resets" {
  let styled = "\u001b[31mhi\u001b[0m"
  assert_eq(pad_right_width(styled, 5), "\u001b[31mhi   \u001b[0m")
  assert_eq(display_width(pad_right_width(styled, 5)), 5)
}

///|
test "mixed SGR sequences are not treated as trailing resets" {
  assert_eq(pad_right_width("hi\u001b[0;31m", 4), "hi\u001b[0;31m  ")
  assert_eq(truncate_width("abcd\u001b[0;31m", 2), "ab")
}

///|
test "SGR trailing reset is determined by final parameter" {
  assert_eq(pad_right_width("hi\u001b[31;0m", 4), "hi  \u001b[31;0m")
  assert_eq(
    truncate_width("\u001b[31mabcd\u001b[31;0m", 2),
    "\u001b[31mab\u001b[31;0m",
  )
}
