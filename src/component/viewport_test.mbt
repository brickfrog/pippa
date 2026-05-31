///|
test "viewport init" {
  let vp = viewport(width=10, height=5)
  let res = (vp.init)()
  assert_eq(res.model.width, 10)
  assert_eq(res.model.height, 5)
  assert_eq(res.model.offset, 0)
  assert_eq(res.model.content, "")
}

///|
test "viewport scroll and clamp" {
  let vp = viewport(width=10, height=2)
  let mut m = (vp.init)().model

  // Set content to 4 lines
  m = (vp.update)(m, SetContent("1\n2\n3\n4")).model
  assert_eq(m.offset, 0)

  // Scroll down
  m = (vp.update)(m, ScrollDown).model
  assert_eq(m.offset, 1)

  // Scroll down more than max
  m = (vp.update)(m, ScrollDown).model
  m = (vp.update)(m, ScrollDown).model
  m = (vp.update)(m, ScrollDown).model
  assert_eq(m.offset, 2) // max_offset = 4 - 2 = 2

  // Scroll to top
  m = (vp.update)(m, ScrollToTop).model
  assert_eq(m.offset, 0)

  // Scroll up at top
  m = (vp.update)(m, ScrollUp).model
  assert_eq(m.offset, 0)

  // Page down
  m = (vp.update)(m, PageDown).model
  assert_eq(m.offset, 2)

  // Page up
  m = (vp.update)(m, PageUp).model
  assert_eq(m.offset, 0)

  // Scroll to bottom
  m = (vp.update)(m, ScrollToBottom).model
  assert_eq(m.offset, 2)

  // Resize
  m = (vp.update)(m, Resize(10, 5)).model
  assert_eq(m.height, 5)
  assert_eq(m.offset, 0) // clamped because 4 - 5 < 0 => max_offset = 0
}

///|
test "viewport view output" {
  let vp = viewport(width=5, height=3)
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("one\ntwo\nthree\nfour")).model

  let v1 = (vp.view)(m)
  assert_eq(v1, "one  \ntwo  \nthree")

  m = (vp.update)(m, ScrollDown).model
  let v2 = (vp.view)(m)
  assert_eq(v2, "two  \nthree\nfour ")
}

///|
test "viewport view padding when few lines" {
  let vp = viewport(width=4, height=3)
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("a\nb")).model
  let v = (vp.view)(m)
  assert_eq(v, "a   \nb   \n    ")
}

///|
test "viewport truncation" {
  let vp = viewport(width=3, height=1)
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("longline")).model
  let v = (vp.view)(m)
  assert_eq(v, "lon")
}

///|
test "viewport truncates wide text by display width" {
  let vp = viewport(width=4, height=1)
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("你好x")).model
  let v = (vp.view)(m)
  assert_eq(v, "你好")
}

///|
test "viewport does not split emoji ZWJ clusters" {
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let vp = viewport(width=2, height=1)
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("\{technologist}x")).model
  let v = (vp.view)(m)
  assert_eq(v, technologist)
}

///|
test "viewport pads ANSI-styled wide content before trailing reset" {
  let vp = viewport(width=4, height=1)
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("\u001b[1m界\u001b[0m")).model
  let v = (vp.view)(m)
  assert_true(v == "\u001b[1m界  \u001b[0m")
}

///|
test "viewport horizontal scroll is display-cell and ANSI safe" {
  let wide = viewport(width=4, height=1, horizontal_step=1)
  let mut wide_model = (wide.init)().model
  wide_model = (wide.update)(wide_model, SetContent("a你好z")).model
  wide_model = (wide.update)(wide_model, ScrollRight).model
  assert_eq((wide.view)(wide_model), "你好")
  wide_model = (wide.update)(wide_model, ScrollRight).model
  assert_eq((wide.view)(wide_model), " 好z")

  let ansi = viewport(width=2, height=1, horizontal_step=3)
  let mut ansi_model = (ansi.init)().model
  ansi_model = (ansi.update)(ansi_model, SetContent("ab\u001b[31mcd\u001b[0me")).model
  ansi_model = (ansi.update)(ansi_model, ScrollRight).model
  assert_eq((ansi.view)(ansi_model), "\u001b[31md\u001b[0me")
}

///|
test "viewport soft wrap is grapheme and ANSI safe and disables h-scroll" {
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let vp = viewport(width=4, height=3, soft_wrap=true, horizontal_step=2)
  let mut m = (vp.init)().model
  m = (vp.update)(
      m,
      SetContent("A\{technologist}B界C\n\u001b[31mabcdef\u001b[0m"),
    ).model

  assert_eq((vp.view)(m), "A\{technologist}B\n界C \n\u001b[31mabcd\u001b[0m")

  m = (vp.update)(m, ScrollRight).model
  assert_eq(m.x_offset, 0)

  m = (vp.update)(m, SetSoftWrap(false)).model
  m = (vp.update)(m, ScrollRight).model
  assert_eq(m.x_offset, 2)
  assert_eq((vp.view)(m), " B界\n\u001b[31mcdef\u001b[0m\n    ")
}

///|
test "viewport fill height can be disabled and re-enabled" {
  let vp = viewport(width=3, height=3, fill_height=false)
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("a")).model
  assert_eq((vp.view)(m), "a  ")

  m = (vp.update)(m, SetFillHeight(true)).model
  assert_eq((vp.view)(m), "a  \n   \n   ")
}

///|
test "viewport mouse wheel respects enabled and delta toggles" {
  let vp = viewport(
    width=4,
    height=2,
    mouse_wheel_enabled=true,
    mouse_wheel_delta=2,
    horizontal_step=2,
  )
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("abcd\nefgh\nijkl\nmnop\nqrst")).model
  m = (vp.update)(
      m,
      HandleMouse({
        button: @pippa.MouseWheelDown,
        action: @pippa.MouseWheel,
        modifiers: [],
        col: 1,
        row: 1,
      }),
    ).model
  assert_eq(m.offset, 2)

  m = (vp.update)(m, SetMouseWheelDelta(1)).model
  m = (vp.update)(
      m,
      HandleMouse({
        button: @pippa.MouseWheelUp,
        action: @pippa.MouseWheel,
        modifiers: [],
        col: 1,
        row: 1,
      }),
    ).model
  assert_eq(m.offset, 1)

  m = (vp.update)(m, SetMouseWheelEnabled(false)).model
  m = (vp.update)(
      m,
      HandleMouse({
        button: @pippa.MouseWheelDown,
        action: @pippa.MouseWheel,
        modifiers: [],
        col: 1,
        row: 1,
      }),
    ).model
  assert_eq(m.offset, 1)

  m = (vp.update)(m, SetMouseWheelEnabled(true)).model
  m = (vp.update)(m, SetContent("abcdef")).model
  m = (vp.update)(
      m,
      HandleMouse({
        button: @pippa.MouseWheelRight,
        action: @pippa.MouseWheel,
        modifiers: [],
        col: 1,
        row: 1,
      }),
    ).model
  assert_eq(m.x_offset, 2)

  m = (vp.update)(
      m,
      HandleMouse({
        button: @pippa.MouseWheelLeft,
        action: @pippa.MouseWheel,
        modifiers: [],
        col: 1,
        row: 1,
      }),
    ).model
  assert_eq(m.x_offset, 0)
}

///|
test "viewport gutter eats content width and renders line numbers" {
  let vp = viewport(
    width=5,
    height=2,
    gutter=Some(fn(ctx) { "\{ctx.logical_line + 1}|" }),
  )
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("abcdef\nxy")).model
  assert_eq((vp.view)(m), "1|abc\n2|xy ")
}

///|
test "viewport gutter measures all soft-wrapped visual rows" {
  let vp = viewport(
    width=6,
    height=10,
    soft_wrap=true,
    gutter=Some(fn(ctx) { "\{ctx.visual_line + 1}|" }),
  )
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("abcdefghijklmnopqrstuvwxyzabcdefghijklmn")).model
  assert_eq(
    (vp.view)(m),
    "1| abc\n2| def\n3| ghi\n4| jkl\n5| mno\n6| pqr\n7| stu\n8| vwx\n9| yza\n10|bcd",
  )
}

///|
test "viewport highlights render and next previous scroll selected range into view" {
  let vp = viewport(width=14, height=2, highlights=[
    viewport_highlight(line=1, start_col=4, end_col=7),
    viewport_highlight(line=4, start_col=5, end_col=11),
  ])
  let mut m = (vp.init)().model
  m = (vp.update)(
      m,
      SetContent("zero\none-hit!\ntwo\nthree\nfour-target!\nfive"),
    ).model

  assert_eq((vp.view)(m), "zero          \none-\u001b[7mhit\u001b[0m!      ")

  m = (vp.update)(m, NextHighlight).model
  assert_eq(m.selected_highlight, 1)
  assert_eq(m.offset, 3)
  assert_eq((vp.view)(m), "three         \nfour-\u001b[7mtarget\u001b[0m!  ")

  m = (vp.update)(m, PreviousHighlight).model
  assert_eq(m.selected_highlight, 0)
  assert_eq(m.offset, 1)
  assert_eq((vp.view)(m), "one-\u001b[7mhit\u001b[0m!      \ntwo           ")
}

///|
test "viewport highlights use display-cell columns for wide glyphs" {
  let vp = viewport(width=5, height=1, highlights=[
    viewport_highlight(line=0, start_col=1, end_col=3),
  ])
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("a界b")).model
  assert_eq((vp.view)(m), "a\u001b[7m界\u001b[0mb ")
}

///|
test "viewport highlights preserve active ANSI state after selected range" {
  let vp = viewport(width=6, height=1, highlights=[
    viewport_highlight(line=0, start_col=2, end_col=4),
  ])
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("\u001b[31mabcdef\u001b[0m")).model
  assert_eq(
    (vp.view)(m),
    "\u001b[31mab\u001b[7mcd\u001b[0m\u001b[31mef\u001b[0m",
  )
}

///|
test "viewport multi-line highlight scrolls horizontal view to selected start" {
  let vp = viewport(width=5, height=1)
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("0123456789abcdef\nsecond line")).model
  m = (vp.update)(
      m,
      SetHighlights([
        viewport_highlight_range(
          start_line=0,
          start_col=2,
          end_line=1,
          end_col=80,
        ),
      ]),
    ).model
  assert_eq(m.x_offset, 2)
  assert_eq((vp.view)(m), "\u001b[7m23456\u001b[0m")
}

///|
test "viewport reversed multi-line highlights normalize endpoint columns" {
  let vp = viewport(width=8, height=4, highlights=[
    viewport_highlight_range(start_line=3, start_col=4, end_line=1, end_col=2),
  ])
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("000000\nabcdef!\nuvwxyz\n123456!")).model
  let view = (vp.view)(m)
  assert_true(view.contains("ab\u001b[7mc"))
  assert_true(view.contains("\u001b[7muvwxyz"))
  assert_true(view.contains("\u001b[7m1234\u001b[0m56"))
}

///|
test "viewport reversed multi-line highlights normalize display-cell endpoints" {
  let vp = viewport(width=7, height=4, highlights=[
    viewport_highlight_range(start_line=3, start_col=4, end_line=1, end_col=3),
  ])
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("000000\na界b!\nuvwxyz\n123456")).model
  let view = (vp.view)(m)
  assert_true(view.contains("a界\u001b[7mb!"))
  assert_true(view.contains("\u001b[7m1234\u001b[0m56"))
}

///|
test "viewport scroll state helpers cover vertical and horizontal bounds" {
  let vp = viewport(width=4, height=2, horizontal_step=2)
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("abcdef\nline2\nline3\nline4\nline5")).model

  assert_true(viewport_at_top(m))
  assert_false(viewport_at_bottom(m))
  assert_false(viewport_past_bottom(m))
  assert_eq(viewport_scroll_percent(m), 0.0)
  assert_true(viewport_at_left(m))
  assert_false(viewport_at_right(m))
  assert_false(viewport_past_right(m))
  assert_eq(viewport_horizontal_scroll_percent(m), 0.0)

  m = (vp.update)(m, ScrollToBottom).model
  assert_true(viewport_at_bottom(m))
  assert_eq(viewport_scroll_percent(m), 1.0)

  m = (vp.update)(m, ScrollRight).model
  assert_true(viewport_at_right(m))
  assert_eq(viewport_horizontal_scroll_percent(m), 1.0)

  let beyond = { ..m, offset: 99, x_offset: 99 }
  assert_true(viewport_past_bottom(beyond))
  assert_true(viewport_past_right(beyond))
}

///|
test "viewport content and line style hooks render visible rows" {
  let vp = viewport(
    width=5,
    height=1,
    content_style=Some(@pippa.style().bold()),
    line_style=Some(@pippa.style().underline()),
  )
  let mut m = (vp.init)().model
  m = (vp.update)(m, SetContent("abc")).model
  assert_eq(
    (vp.view)(m),
    @pippa.underline() +
    @pippa.bold() +
    "abc  " +
    @pippa.reset() +
    @pippa.reset(),
  )
}
