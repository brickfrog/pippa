///|
extern "C" fn styling_perf_now_us() -> Int64 = "pippa_styling_perf_now_us"

///|
fn representative_render_style() -> Style {
  style()
  .background_hex("#102030")
  .border(border_rounded())
  .border_foreground(color_hex("#ddeeff"))
  .padding(1, 2, 1, 2)
  .width(74)
}

///|
fn representative_render_content() -> String {
  col([
    "Pippa render perf", "frame 0001 | alpha beta gamma", "frame 0002 | delta epsilon zeta",
    "frame 0003 | eta theta iota", "frame 0004 | kappa lambda mu", "frame 0005 | nu xi omicron",
    "frame 0006 | pi rho sigma", "frame 0007 | tau upsilon phi", "frame 0008 | chi psi omega",
    "frame 0009 | bright cyan panel", "frame 0010 | steady progress", "frame 0011 | diff stays small",
    "frame 0012 | layout stays wide", "frame 0013 | animation tick", "frame 0014 | keyboard help",
    "frame 0015 | component list", "frame 0016 | table viewport", "frame 0017 | progress meter",
    "frame 0018 | status footer", "frame 0019 | message queue", "frame 0020 | command batch",
    "frame 0021 | terminal state", "frame 0022 | mouse enabled", "frame 0023 | focus events",
    "frame 0024 | raw mode safe", "frame 0025 | window resized", "frame 0026 | render complete",
    "frame 0027 | final row",
  ])
}

///|
fn legacy_render(style : Style, content : String) -> String {
  let content_lines = @pippa.split_lines(content)
  let target_width = legacy_resolve_width(style, content_lines)
  let base_lines = legacy_shape_content_lines(
    content_lines,
    target_width,
    style.align,
  )
  let target_height = legacy_resolve_height(style, base_lines.length())
  let height_fitted = legacy_fit_height(base_lines, target_width, target_height)
  let padded = legacy_apply_padding(height_fitted, style)
  let bordered = match style.border {
    Some(border) =>
      legacy_render_border_block(
        border,
        padded,
        @internal.max_visible_width(padded, @pippa.visible_width),
        style,
      )
    None => @internal.join_lines(padded)
  }
  let margined = legacy_apply_margin(
    bordered,
    style.margin_top,
    style.margin_right,
    style.margin_bottom,
    style.margin_left,
  )
  legacy_apply_style_prefix(style, margined)
}

///|
fn legacy_resolve_width(style : Style, lines : Array[String]) -> Int {
  let natural = @internal.max_visible_width(lines, @pippa.visible_width)
  let from_width = match style.width {
    Some(width) => width
    None => natural
  }
  let with_min = from_width.max(style.min_width)
  match style.max_width {
    Some(max_width) => with_min.min(max_width)
    None => with_min
  }
}

///|
fn legacy_resolve_height(style : Style, line_count : Int) -> Int {
  let from_height = match style.height {
    Some(height) => height
    None => line_count
  }
  let with_min = from_height.max(style.min_height)
  match style.max_height {
    Some(max_height) => with_min.min(max_height)
    None => with_min
  }
}

///|
fn legacy_shape_content_lines(
  lines : Array[String],
  target_width : Int,
  align : Align,
) -> Array[String] {
  let shaped : Array[String] = []
  for line in lines {
    shaped.push(legacy_fit_line_width(line, target_width, align))
  }
  shaped
}

///|
fn legacy_fit_line_width(
  line : String,
  target_width : Int,
  align : Align,
) -> String {
  let truncated = @pippa.truncate(line, target_width)
  let width = @pippa.visible_width(truncated)
  if width >= target_width {
    truncated
  } else {
    match align {
      Left => @pippa.pad_right(truncated, target_width)
      Center => @pippa.center(truncated, target_width)
      Right => @pippa.pad_left(truncated, target_width)
    }
  }
}

///|
fn legacy_fit_height(
  lines : Array[String],
  target_width : Int,
  target_height : Int,
) -> Array[String] {
  let fitted : Array[String] = []
  for i in 0..<lines.length().min(target_height) {
    fitted.push(lines[i])
  }
  let blank = String::make(target_width, ' ')
  for _ in fitted.length()..<target_height {
    fitted.push(blank)
  }
  fitted
}

///|
fn legacy_apply_padding(lines : Array[String], style : Style) -> Array[String] {
  let padded : Array[String] = []
  let inner_width = @internal.max_visible_width(lines, @pippa.visible_width)
  let row_width = inner_width + style.padding_left + style.padding_right
  let blank = String::make(row_width, ' ')
  for _ in 0..<style.padding_top {
    padded.push(blank)
  }
  for line in lines {
    let fitted = if @pippa.visible_width(line) < inner_width {
      @pippa.pad_right(line, inner_width)
    } else {
      line
    }
    padded.push(
      String::make(style.padding_left, ' ') +
      fitted +
      String::make(style.padding_right, ' '),
    )
  }
  for _ in 0..<style.padding_bottom {
    padded.push(blank)
  }
  padded
}

///|
fn legacy_apply_margin(
  block : String,
  top : Int,
  right : Int,
  bottom : Int,
  left : Int,
) -> String {
  if top == 0 && right == 0 && bottom == 0 && left == 0 {
    return block
  }
  let lines = @pippa.split_lines(block)
  let inner_width = @internal.max_visible_width(lines, @pippa.visible_width)
  let full_width = inner_width + left + right
  let blank = String::make(full_width, ' ')
  let rows : Array[String] = []
  for _ in 0..<top {
    rows.push(blank)
  }
  for line in lines {
    let fitted = if @pippa.visible_width(line) < inner_width {
      @pippa.pad_right(line, inner_width)
    } else {
      line
    }
    rows.push(String::make(left, ' ') + fitted + String::make(right, ' '))
  }
  for _ in 0..<bottom {
    rows.push(blank)
  }
  @internal.join_lines(rows)
}

///|
fn legacy_render_border_block(
  border : @pippa.Border,
  lines : Array[String],
  inner_width : Int,
  style : Style,
) -> String {
  if style.border_fg is None && style.border_bg is None {
    return @internal.render_border(
      border.top_left,
      border.top_right,
      border.bottom_left,
      border.bottom_right,
      border.horizontal,
      border.vertical,
      lines,
      inner_width,
      @pippa.visible_width,
      style.border_top,
      style.border_right,
      style.border_bottom,
      style.border_left,
    )
  }
  let top_left = @internal.normalize_border_piece(
    border.top_left,
    @pippa.visible_width,
  )
  let top_right = @internal.normalize_border_piece(
    border.top_right,
    @pippa.visible_width,
  )
  let bottom_left = @internal.normalize_border_piece(
    border.bottom_left,
    @pippa.visible_width,
  )
  let bottom_right = @internal.normalize_border_piece(
    border.bottom_right,
    @pippa.visible_width,
  )
  let horizontal_piece = @internal.normalize_border_piece(
    border.horizontal,
    @pippa.visible_width,
  )
  let vertical_piece = @internal.normalize_border_piece(
    border.vertical,
    @pippa.visible_width,
  )
  let horizontal = @internal.repeat_string(horizontal_piece, inner_width)
  let rows : Array[String] = []
  let border_prefix = legacy_build_border_ansi_prefix(style)
  let content_prefix = legacy_build_ansi_prefix(style)
  if style.border_top {
    rows.push(
      legacy_decorate_segment(
        border_prefix,
        (if style.border_left { top_left } else { "" }) +
        horizontal +
        (if style.border_right { top_right } else { "" }),
      ),
    )
  }
  for line in lines {
    rows.push(
      legacy_decorate_segment(
        border_prefix,
        if style.border_left {
          vertical_piece
        } else {
          ""
        },
      ) +
      legacy_decorate_segment(content_prefix, line) +
      legacy_decorate_segment(
        border_prefix,
        if style.border_right {
          vertical_piece
        } else {
          ""
        },
      ),
    )
  }
  if style.border_bottom {
    rows.push(
      legacy_decorate_segment(
        border_prefix,
        (if style.border_left { bottom_left } else { "" }) +
        horizontal +
        (if style.border_right { bottom_right } else { "" }),
      ),
    )
  }
  @internal.join_lines(rows)
}

///|
fn legacy_decorate_segment(prefix : String, segment : String) -> String {
  if prefix == "" || segment == "" {
    segment
  } else {
    prefix + segment + @pippa.reset()
  }
}

///|
fn legacy_build_border_ansi_prefix(style : Style) -> String {
  let border_style = {
    ..style,
    fg: match style.border_fg {
      Some(color) => Some(color)
      None => style.fg
    },
    bg: match style.border_bg {
      Some(color) => Some(color)
      None => style.bg
    },
    border_fg: None,
    border_bg: None,
  }
  legacy_build_ansi_prefix(border_style)
}

///|
fn legacy_apply_style_prefix(style : Style, block : String) -> String {
  if style.border is Some(_) &&
    (style.border_fg is Some(_) || style.border_bg is Some(_)) {
    return block
  }
  let prefix = legacy_build_ansi_prefix(style)
  if prefix == "" {
    block
  } else {
    prefix + block + @pippa.reset()
  }
}

///|
fn legacy_build_ansi_prefix(style : Style) -> String {
  let buf = StringBuilder::new()
  style.fg
  .iter()
  .each(fn(color) { buf.write_string(foreground_sequence(color)) })
  style.bg
  .iter()
  .each(fn(color) { buf.write_string(background_sequence(color)) })
  if style.bold {
    buf.write_string(@pippa.bold())
  }
  if style.dim {
    buf.write_string(@pippa.dim())
  }
  if style.italic {
    buf.write_string("\{@pippa.CSI}3m")
  }
  if style.underline {
    buf.write_string(@pippa.underline())
  }
  if style.blink {
    buf.write_string(@pippa.blink())
  }
  if style.reverse {
    buf.write_string(@pippa.reverse())
  }
  buf.to_string()
}

///|
fn unicode_matrix_content() -> String {
  let accented = String::from_array(['e', '\u{0301}'])
  let wide = String::from_array(['\u{4F60}', '\u{597D}'])
  let technologist = String::from_array(['\u{1F469}', '\u{200D}', '\u{1F4BB}'])
  "\{wide}x\n\{accented}y\n\{@pippa.fg_color(1)}\{technologist}\{@pippa.reset()}"
}

///|
test "styling render optimized path stays byte-identical to legacy reference" {
  let contents = [
    "hi",
    "alpha\nbeta\n",
    "\{@pippa.fg_color(2)}green\{@pippa.reset()} plain",
    unicode_matrix_content(),
  ]
  let borders = [
    border_normal(),
    border_rounded(),
    border_thick(),
    border_double(),
    border_ascii(),
  ]
  let styles : Array[Style] = [
    style(),
    style().background_hex("#203040"),
    style().padding(1, 2, 1, 3),
    style().margin(1, 2, 1, 3),
    style().width(10).align(Left),
    style().width(10).align(Center),
    style().width(10).align(Right),
    style().height(4).min_width(8).max_width(12).max_height(5),
    style()
    .foreground(color_ansi(2))
    .background_rgb(1, 2, 3)
    .bold()
    .italic()
    .underline(),
  ]
  for border in borders {
    styles.push(style().border(border))
    styles.push(
      style()
      .border(border)
      .border_foreground(color_ansi(1))
      .border_background(color_hex("#101010"))
      .background_hex("#202020")
      .padding(1, 1, 1, 1)
      .width(14),
    )
    styles.push(
      style()
      .border(border)
      .border_sides(true, false, true, false)
      .padding(0, 1, 0, 1)
      .width(8),
    )
  }
  for sty in styles {
    for content in contents {
      assert_eq(sty.render(content), legacy_render(sty, content))
    }
  }
}

///|
test "styling render representative box stays below native perf budget" {
  let sty = representative_render_style()
  let content = representative_render_content()
  let iterations = 64
  let mut total = 0
  let started_at = styling_perf_now_us()
  for _ in 0..<iterations {
    total = total + sty.render(content).length()
  }
  let elapsed_us = styling_perf_now_us() - started_at
  assert_true(total > 0)
  assert_true(elapsed_us < 100000L)
}
