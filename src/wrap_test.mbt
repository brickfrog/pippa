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
