///|
#cfg(any(target="native", target="llvm"))
#external
type WidthPerfTimestamp

///|
#cfg(any(target="native", target="llvm"))
extern "C" fn width_perf_clock_start() -> WidthPerfTimestamp = "moonbit_monotonic_clock_start"

///|
#cfg(any(target="native", target="llvm"))
extern "C" fn width_perf_clock_end(ts : WidthPerfTimestamp) -> Double = "moonbit_monotonic_clock_stop"

///|
fn reference_char_cell_width(ch : Char) -> Int {
  if ch == '\u{200D}' ||
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
fn reference_next_grapheme_end(chars : Array[Char], start : Int) -> Int {
  let n = chars.length()
  let mut i = start + 1
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
fn reference_grapheme_width(
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> Int {
  let mut width = 0
  let mut has_emoji = false
  for i in start..<end_index {
    let ch = chars[i]
    if is_emoji(ch) {
      has_emoji = true
    }
    width = width.max(reference_char_cell_width(ch))
  }
  if has_emoji {
    2
  } else {
    width
  }
}

///|
fn reference_display_width(s : String) -> Int {
  let chars = s.to_array()
  let n = chars.length()
  let mut width = 0
  let mut i = 0
  while i < n {
    if chars[i] == '\u001b' {
      i = skip_ansi_sequence(chars, i)
    } else {
      let next = reference_next_grapheme_end(chars, i)
      width = width + reference_grapheme_width(chars, i, next)
      i = next
    }
  }
  width
}

///|
fn reference_truncate_width(s : String, max_width : Int) -> String {
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
      let next = reference_next_grapheme_end(chars, i)
      let next_width = reference_grapheme_width(chars, i, next)
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
fn reference_pad_right_width(s : String, width : Int) -> String {
  let current = reference_display_width(s)
  if current >= width {
    return s
  }
  let chars = s.to_array()
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

///|
fn width_identity_cases() -> Array[String] {
  let ascii_combining = String::from_array(['a', '\u{0301}', 'b'])
  let devanagari = String::from_array(['\u{0915}', '\u{094D}', 'a'])
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let ascii_zwj = String::from_array(['a', '\u{200D}', 'b'])
  let flag = String::from_array(['\u{1F1FA}', '\u{1F1F8}'])
  let controls = String::from_array([
    'a', '\u{0001}', '\t', '\u{001F}', '\u{007F}', 'b',
  ])
  [
    "",
    "plain ASCII text",
    "\u001b[31;1mred bold text\u001b[0m plain",
    "left \u001b[38;2;1;2;3mcolor\u001b[0m right",
    "\u001b[1mexact-fit\u001b[0m",
    "你好世界",
    "a你b界",
    ascii_combining,
    devanagari,
    technologist,
    "x\{technologist}y",
    ascii_zwj,
    flag,
    controls,
    "\u001b[31mA\{ascii_combining}界\{technologist}\u001b[0mZ",
    "\u001b[@ab",
    "tail\u001b[31;0m",
    "tail\u001b[0;31m",
  ]
}

///|
fn assert_width_identity(input : String) -> Unit raise {
  assert_eq(display_width(input), reference_display_width(input))
  let max_width = reference_display_width(input) + 4
  for width in 0..<(max_width + 1) {
    assert_eq(
      truncate_width(input, width),
      reference_truncate_width(input, width),
    )
    assert_eq(
      pad_right_width(input, width),
      reference_pad_right_width(input, width),
    )
  }
}

///|
test "optimized width primitives stay byte-identical to reference cases" {
  for input in width_identity_cases() {
    assert_width_identity(input)
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn width_perf_plain_line() -> String {
  "frame 0001 | alpha beta gamma delta epsilon zeta eta theta iota kappa"
}

///|
#cfg(any(target="native", target="llvm"))
fn width_perf_ansi_line() -> String {
  "\u001b[38;2;120;200;255;1m\{width_perf_plain_line()}\u001b[0m"
}

///|
#cfg(any(target="native", target="llvm"))
fn width_perf_box_lines() -> Array[String] {
  let line = width_perf_ansi_line()
  [
    "\u001b[38;2;221;238;255;1m+----------------------------------------------------------------------+\u001b[0m",
    "\u001b[38;2;120;200;255;1m| \{line} |\u001b[0m",
    "\u001b[38;2;120;200;255;1m| frame 0002 | delta epsilon zeta eta theta iota kappa lambda mu    |\u001b[0m",
    "\u001b[38;2;120;200;255;1m| frame 0003 | styled ASCII content drives the hot width path       |\u001b[0m",
    "\u001b[38;2;221;238;255;1m+----------------------------------------------------------------------+\u001b[0m",
  ]
}

///|
#cfg(any(target="native", target="llvm"))
fn measure_display_width(line : String, iterations : Int) -> Double {
  let mut total = 0
  let started = width_perf_clock_start()
  for _ in 0..<iterations {
    total = total + display_width(line)
  }
  let elapsed = width_perf_clock_end(started)
  if total <= 0 {
    abort("display_width benchmark did not run")
  }
  elapsed
}

///|
#cfg(any(target="native", target="llvm"))
fn measure_truncate_width(line : String, iterations : Int) -> Double {
  let mut total = 0
  let started = width_perf_clock_start()
  for _ in 0..<iterations {
    total = total + truncate_width(line, 48).length()
  }
  let elapsed = width_perf_clock_end(started)
  if total <= 0 {
    abort("truncate_width benchmark did not run")
  }
  elapsed
}

///|
#cfg(any(target="native", target="llvm"))
fn measure_pad_right_width(line : String, iterations : Int) -> Double {
  let mut total = 0
  let started = width_perf_clock_start()
  for _ in 0..<iterations {
    total = total + pad_right_width(line, 80).length()
  }
  let elapsed = width_perf_clock_end(started)
  if total <= 0 {
    abort("pad_right_width benchmark did not run")
  }
  elapsed
}

///|
#cfg(any(target="native", target="llvm"))
fn measure_to_array(line : String, iterations : Int) -> Double {
  let mut total = 0
  let started = width_perf_clock_start()
  for _ in 0..<iterations {
    total = total + line.to_array().length()
  }
  let elapsed = width_perf_clock_end(started)
  if total <= 0 {
    abort("to_array benchmark did not run")
  }
  elapsed
}

///|
#cfg(any(target="native", target="llvm"))
fn measure_char_cell_width(chars : Array[Char], iterations : Int) -> Double {
  let mut total = 0
  let started = width_perf_clock_start()
  for _ in 0..<iterations {
    for ch in chars {
      total = total + char_cell_width(ch)
    }
  }
  let elapsed = width_perf_clock_end(started)
  if total <= 0 {
    abort("char_cell_width benchmark did not run")
  }
  elapsed
}

///|
#cfg(any(target="native", target="llvm"))
fn measure_next_grapheme_end(chars : Array[Char], iterations : Int) -> Double {
  let mut total = 0
  let started = width_perf_clock_start()
  for _ in 0..<iterations {
    for i in 0..<chars.length() {
      total = total + next_grapheme_end(chars, i)
    }
  }
  let elapsed = width_perf_clock_end(started)
  if total <= 0 {
    abort("next_grapheme_end benchmark did not run")
  }
  elapsed
}

///|
#cfg(any(target="native", target="llvm"))
fn measure_grapheme_width(chars : Array[Char], iterations : Int) -> Double {
  let mut total = 0
  let started = width_perf_clock_start()
  for _ in 0..<iterations {
    for i in 0..<chars.length() {
      total = total + grapheme_width(chars, i, i + 1)
    }
  }
  let elapsed = width_perf_clock_end(started)
  if total <= 0 {
    abort("grapheme_width benchmark did not run")
  }
  elapsed
}

///|
#cfg(any(target="native", target="llvm"))
fn measure_styled_box(iterations : Int) -> Double {
  let lines = width_perf_box_lines()
  let mut total = 0
  let started = width_perf_clock_start()
  for _ in 0..<iterations {
    for line in lines {
      total = total + display_width(line)
      total = total + truncate_width(line, 74).length()
      total = total + pad_right_width(line, 74).length()
    }
  }
  let elapsed = width_perf_clock_end(started)
  if total <= 0 {
    abort("styled box benchmark did not run")
  }
  elapsed
}

///|
#cfg(any(target="native", target="llvm"))
fn per_iter(elapsed_us : Double, iterations : Int) -> Double {
  elapsed_us / iterations.to_double()
}

///|
#cfg(any(target="native", target="llvm"))
fn perf_line(
  name : String,
  ascii_us : Double,
  ansi_us : Double,
  iterations : Int,
) -> String {
  let ascii_per = per_iter(ascii_us, iterations)
  let ansi_per = per_iter(ansi_us, iterations)
  "\{name}: ascii=\{ascii_per}us ansi=\{ansi_per}us ratio=\{ansi_per / ascii_per}"
}

///|
#cfg(any(target="native", target="llvm"))
fn width_perf_failure_report(
  display_ascii : Double,
  display_ansi : Double,
  truncate_ascii : Double,
  truncate_ansi : Double,
  pad_ascii : Double,
  pad_ansi : Double,
  iterations : Int,
) -> String {
  let plain_chars = width_perf_plain_line().to_array()
  let profile_iterations = 2048
  let to_array_us = per_iter(
    measure_to_array(width_perf_ansi_line(), profile_iterations),
    profile_iterations,
  )
  let char_us = per_iter(
    measure_char_cell_width(plain_chars, profile_iterations),
    profile_iterations,
  )
  let next_us = per_iter(
    measure_next_grapheme_end(plain_chars, profile_iterations),
    profile_iterations,
  )
  let grapheme_us = per_iter(
    measure_grapheme_width(plain_chars, profile_iterations),
    profile_iterations,
  )
  let box_iterations = 128
  let box_us = per_iter(measure_styled_box(box_iterations), box_iterations)
  perf_line("display_width", display_ascii, display_ansi, iterations) +
  "; " +
  perf_line("truncate_width", truncate_ascii, truncate_ansi, iterations) +
  "; " +
  perf_line("pad_right_width", pad_ascii, pad_ansi, iterations) +
  "; profile per line: to_array=\{to_array_us}us char_cell_width=\{char_us}us next_grapheme_end=\{next_us}us grapheme_width=\{grapheme_us}us" +
  "; styled_box=\{box_us}us"
}

///|
#cfg(any(target="native", target="llvm"))
fn assert_ansi_close_to_ascii(
  name : String,
  ascii_us : Double,
  ansi_us : Double,
  iterations : Int,
  report : String,
) -> Unit {
  let ascii_per = per_iter(ascii_us, iterations)
  let ansi_per = per_iter(ansi_us, iterations)
  if ansi_per > ascii_per * 4.0 + 0.25 {
    abort("\{name} ANSI path too slow; \{report}")
  }
}

///|
#cfg(any(target="native", target="llvm"))
test "ANSI width primitive hot paths stay close to plain ASCII" {
  let plain = width_perf_plain_line()
  let ansi = width_perf_ansi_line()
  let iterations = 4096
  let _warm_display = display_width(ansi)
  let _warm_truncate = truncate_width(ansi, 48)
  let _warm_pad = pad_right_width(ansi, 80)
  let display_ascii = measure_display_width(plain, iterations)
  let display_ansi = measure_display_width(ansi, iterations)
  let truncate_ascii = measure_truncate_width(plain, iterations)
  let truncate_ansi = measure_truncate_width(ansi, iterations)
  let pad_ascii = measure_pad_right_width(plain, iterations)
  let pad_ansi = measure_pad_right_width(ansi, iterations)
  let report = width_perf_failure_report(
    display_ascii, display_ansi, truncate_ascii, truncate_ansi, pad_ascii, pad_ansi,
    iterations,
  )
  assert_ansi_close_to_ascii(
    "display_width", display_ascii, display_ansi, iterations, report,
  )
  assert_ansi_close_to_ascii(
    "truncate_width", truncate_ascii, truncate_ansi, iterations, report,
  )
  assert_ansi_close_to_ascii(
    "pad_right_width", pad_ascii, pad_ansi, iterations, report,
  )
  let box_us = per_iter(measure_styled_box(128), 128)
  if box_us > 1000.0 {
    abort("representative ANSI styled box over budget; \{report}")
  }
}
