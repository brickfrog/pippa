///|
test "cached unscaled gradient render matches fresh reference" {
  let fill_char = "#"
  let empty_char = "-"
  let fmt = fn(pct : Double) { "\{(pct * 100.0 + 0.5).to_int()}%" }
  let style = fn(text : String) { "[" + text + "]" }
  let comp = progress_bar(
    width=4,
    show_percentage=true,
    fill_char~,
    empty_char~,
    blend_start=(0, 0, 0),
    blend_end=(100, 50, 25),
    empty_color=(9, 9, 9),
    percentage_format=fmt,
    percentage_style=style,
  )
  let { model, .. } = (comp.init)()
  let widths = [0, 1, 4, 7, 30]
  let percents = [0.0, 0.17, 0.5, 0.93, 1.0]
  for width in widths {
    for pct in percents {
      let m = { ..model, width, displayed_percent: pct, target_percent: pct }
      assert_eq(
        (comp.view)(m),
        progress_bar_view_uncached(
          m,
          fill_char,
          empty_char,
          ProgressGradient,
          fmt,
          style,
          false,
        ),
      )
    }
  }

  let recolored = {
    ..model,
    width: 4,
    displayed_percent: 0.75,
    target_percent: 0.75,
    blend_start: (10, 20, 30),
    blend_end: (200, 100, 50),
    empty_color: (1, 2, 3),
  }
  assert_eq(
    (comp.view)(recolored),
    progress_bar_view_uncached(
      recolored,
      fill_char,
      empty_char,
      ProgressGradient,
      fmt,
      style,
      false,
    ),
  )
}

///|
test "cached unscaled solid render matches fresh reference" {
  let fill_char = "#"
  let empty_char = "-"
  let fmt = fn(_pct : Double) { "solid" }
  let style = fn(text : String) { text }
  let palette = ProgressSolid((1, 2, 3))
  let comp = progress_bar(
    width=5,
    show_percentage=false,
    fill_char~,
    empty_char~,
    empty_color=(4, 5, 6),
    palette~,
  )
  let { model, .. } = (comp.init)()
  for width in [2, 5, 8] {
    for pct in [0.0, 0.4, 1.0] {
      let m = { ..model, width, displayed_percent: pct, target_percent: pct }
      assert_eq(
        (comp.view)(m),
        progress_bar_view_uncached(
          m, fill_char, empty_char, palette, fmt, style, false,
        ),
      )
    }
  }
}
