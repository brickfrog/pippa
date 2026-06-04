///|
fn assert_wrapped_lines_within(text : String, width : Int) -> Unit raise {
  for line in split_lines(text) {
    assert_true(visible_width(line) <= width)
  }
}

///|
test "word_wrap leaves non-positive widths unchanged" {
  assert_eq(word_wrap("alpha beta", 0), "alpha beta")
  assert_eq(word_wrap("alpha beta", -2), "alpha beta")
}

///|
test "word_wrap breaks ASCII at spaces" {
  assert_eq(word_wrap("alpha beta gamma", 10), "alpha beta\ngamma")
}

///|
test "word_wrap keeps ANSI escapes intact while wrapping" {
  let actual = word_wrap("\u001b[31mred fox jumps\u001b[0m", 7)
  assert_eq(actual, "\u001b[31mred fox\njumps\u001b[0m")
  let lines = split_lines(actual)
  assert_eq(lines.length(), 2)
  assert_eq(visible_width(lines[0]), 7)
  assert_eq(visible_width(lines[1]), 5)
}

///|
test "word_wrap keeps OSC 8 escapes intact while wrapping" {
  let url = "https://example.com"
  let open = "\u001b]8;;\{url}\u001b\\"
  let close = "\u001b]8;;\u001b\\"
  let actual = word_wrap("alpha " + hyperlink(url, "beta ") + "gamma", 10)
  assert_eq(strip_ansi(actual), word_wrap("alpha beta gamma", 10))
  assert_eq(actual, "alpha \{open}beta\{close}\ngamma")
  assert_true(actual.contains(open))
  assert_true(actual.contains(close))
  let lines = split_lines(actual)
  assert_eq(lines.length(), 2)
  assert_eq(strip_ansi(lines[0]), "alpha beta")
  assert_eq(strip_ansi(lines[1]), "gamma")
  assert_wrapped_lines_within(actual, 10)
}

///|
test "word_wrap can break an OSC 8 label at visible boundaries" {
  let url = "https://example.com"
  let open = "\u001b]8;;\{url}\u001b\\"
  let close = "\u001b]8;;\u001b\\"
  let actual = word_wrap("alpha " + hyperlink(url, "betagamma"), 7)
  assert_eq(strip_ansi(actual), word_wrap("alpha betagamma", 7))
  assert_eq(actual, "alpha\n\{open}betagam\nma\{close}")
  assert_true(actual.contains(open))
  assert_true(actual.contains(close))
  let lines = split_lines(actual)
  assert_eq(lines.length(), 3)
  assert_eq(strip_ansi(lines[0]), "alpha")
  assert_eq(strip_ansi(lines[1]), "betagam")
  assert_eq(strip_ansi(lines[2]), "ma")
  assert_wrapped_lines_within(actual, 7)
}

///|
test "word_wrap preserves trailing non-reset ANSI bytes" {
  let trailing_style = "word\u001b[31m"
  assert_eq(word_wrap(trailing_style, 10), trailing_style)
  assert_eq(word_wrap("alpha \{trailing_style}", 5), "alpha\n\{trailing_style}")
}

///|
test "word_wrap keeps odd-width CJK graphemes intact" {
  assert_eq(word_wrap("你好世界", 3), "你\n好\n世\n界")
}

///|
test "word_wrap hard-breaks overlong words without dropping text" {
  assert_eq(word_wrap("abcdefghij", 4), "abcd\nefgh\nij")
}

///|
test "word_wrap preserves embedded newlines" {
  assert_eq(
    word_wrap("alpha beta\n\ngamma delta", 6),
    "alpha\nbeta\n\ngamma\ndelta",
  )
}
