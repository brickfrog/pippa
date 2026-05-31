///|
/// Viewport component — a scrollable window over a larger body of text.

///|
/// Context passed to a viewport gutter callback.
pub(all) struct ViewportGutterContext {
  /// 0-based logical content line.
  logical_line : Int
  /// 0-based visual row within that logical line.
  visual_line : Int
  /// Whether this row is a continuation produced by soft wrapping.
  continuation : Bool
}

///|
/// Highlight range in logical content coordinates.
///
/// Columns are character offsets and are clamped to grapheme boundaries before
/// rendering so highlight styling never splits a cluster.
pub(all) struct ViewportHighlight {
  start_line : Int
  start_col : Int
  end_line : Int
  end_col : Int
  style : @pippa.Style?
  selected_style : @pippa.Style?
} derive(Debug, Eq)

///|
/// Model for the Viewport component.
///
/// - `content`: the full body of text to be displayed
/// - `width`: the visible width of the viewport
/// - `height`: the visible height (number of rows) of the viewport
/// - `offset`: the index of the first visible row (0-based)
/// - `x_offset`: the first visible display cell in horizontal-scroll mode
/// - `total_lines`: pre-calculated count of logical lines in content
pub(all) struct ViewportModel {
  content : String
  width : Int
  height : Int
  offset : Int
  x_offset : Int
  total_lines : Int
  horizontal_step : Int
  soft_wrap : Bool
  fill_height : Bool
  mouse_wheel_enabled : Bool
  mouse_wheel_delta : Int
  gutter : ((ViewportGutterContext) -> String)?
  highlights : Array[ViewportHighlight]
  selected_highlight : Int
  content_style : @pippa.Style?
  line_style : @pippa.Style?
}

///|
pub impl Debug for ViewportModel with fn to_repr(self) {
  let buf = StringBuilder::new()
  buf.write_string("ViewportModel(")
  buf.write_string("width=")
  buf.write_string(self.width.to_string())
  buf.write_string(", height=")
  buf.write_string(self.height.to_string())
  buf.write_string(", offset=")
  buf.write_string(self.offset.to_string())
  buf.write_string(", x_offset=")
  buf.write_string(self.x_offset.to_string())
  buf.write_string(", total_lines=")
  buf.write_string(self.total_lines.to_string())
  buf.write_string(", soft_wrap=")
  buf.write_string(self.soft_wrap.to_string())
  buf.write_string(", fill_height=")
  buf.write_string(self.fill_height.to_string())
  buf.write_string(", highlights=")
  buf.write_string(self.highlights.length().to_string())
  buf.write_string(", selected_highlight=")
  buf.write_string(self.selected_highlight.to_string())
  buf.write_string(")")
  Repr::literal(buf.to_string())
}

///|
/// Messages handled by the Viewport component.
pub(all) enum ViewportMsg {
  /// Scroll up one row.
  ScrollUp
  /// Scroll down one row.
  ScrollDown
  /// Scroll left by the configured horizontal step.
  ScrollLeft
  /// Scroll right by the configured horizontal step.
  ScrollRight
  /// Scroll up one full page (height rows).
  PageUp
  /// Scroll down one full page (height rows).
  PageDown
  /// Scroll directly to the first row.
  ScrollToTop
  /// Scroll directly to the last possible row.
  ScrollToBottom
  /// Replace the current content and reset offsets to 0.
  SetContent(String)
  /// Update the viewport dimensions and re-clamp offsets.
  Resize(Int, Int)
  /// Set the horizontal offset directly.
  SetXOffset(Int)
  /// Set the horizontal scroll step.
  SetHorizontalStep(Int)
  /// Toggle soft wrapping. Soft wrapping disables horizontal scroll.
  SetSoftWrap(Bool)
  /// Toggle padding rendered rows to the full viewport height.
  SetFillHeight(Bool)
  /// Handle an input mouse event, scrolling only for wheel events.
  HandleMouse(@pippa.MouseMsg)
  /// Toggle mouse wheel handling.
  SetMouseWheelEnabled(Bool)
  /// Set the row delta used for vertical mouse wheel events.
  SetMouseWheelDelta(Int)
  /// Replace highlight ranges.
  SetHighlights(Array[ViewportHighlight])
  /// Select the next highlight and scroll it into view.
  NextHighlight
  /// Select the previous highlight and scroll it into view.
  PreviousHighlight
  /// Set the optional content-area style hook.
  SetContentStyle(@pippa.Style?)
  /// Set the optional full-line style hook.
  SetLineStyle(@pippa.Style?)
} derive(Debug)

///|
priv struct ViewportVisualRow {
  logical_line : Int
  start_cell : Int
  width : Int
  continuation : Bool
  visual_line : Int
}

///|
pub fn viewport_highlight_range(
  start_line~ : Int,
  start_col~ : Int,
  end_line~ : Int,
  end_col~ : Int,
  style? : @pippa.Style? = None,
  selected_style? : @pippa.Style? = None,
) -> ViewportHighlight {
  { start_line, start_col, end_line, end_col, style, selected_style }
}

///|
pub fn viewport_highlight(
  line~ : Int,
  start_col~ : Int,
  end_col~ : Int,
  style? : @pippa.Style? = None,
  selected_style? : @pippa.Style? = None,
) -> ViewportHighlight {
  viewport_highlight_range(
    start_line=line,
    start_col~,
    end_line=line,
    end_col~,
    style~,
    selected_style~,
  )
}

///|
fn viewport_clamp(value : Int, lo : Int, hi : Int) -> Int {
  if value < lo {
    lo
  } else if value > hi {
    hi
  } else {
    value
  }
}

///|
fn viewport_safe_dimension(value : Int) -> Int {
  if value > 0 {
    value
  } else {
    0
  }
}

///|
fn viewport_safe_step(value : Int) -> Int {
  if value > 0 {
    value
  } else {
    1
  }
}

///|
fn viewport_safe_delta(value : Int) -> Int {
  if value > 0 {
    value
  } else {
    1
  }
}

///|
fn viewport_lines(model : ViewportModel) -> Array[String] {
  @pippa.split_lines(model.content)
}

///|
fn viewport_selected_highlight(highlights : Array[ViewportHighlight]) -> Int {
  if highlights.length() == 0 {
    -1
  } else {
    0
  }
}

///|
fn viewport_highlight_start_line(highlight : ViewportHighlight) -> Int {
  highlight.start_line.min(highlight.end_line)
}

///|
fn viewport_highlight_end_line(highlight : ViewportHighlight) -> Int {
  highlight.start_line.max(highlight.end_line)
}

///|
fn viewport_line_highlight_bounds(
  highlight : ViewportHighlight,
  line_index : Int,
  line : String,
) -> (Int, Int)? {
  let start_line = viewport_highlight_start_line(highlight)
  let end_line = viewport_highlight_end_line(highlight)
  if line_index < start_line || line_index > end_line {
    return None
  }
  let line_len = component_char_len(line)
  let raw_start = if line_index == highlight.start_line {
    highlight.start_col
  } else {
    0
  }
  let raw_end = if line_index == highlight.end_line {
    highlight.end_col
  } else {
    line_len
  }
  let start = component_clamp_grapheme_boundary(line, raw_start)
  let end_ = component_clamp_grapheme_boundary(line, raw_end)
  let from = start.min(end_).max(0).min(line_len)
  let to = start.max(end_).max(from).min(line_len)
  if to <= from {
    None
  } else {
    Some((from, to))
  }
}

///|
fn viewport_highlight_style(
  highlight : ViewportHighlight,
  selected : Bool,
) -> @pippa.Style {
  if selected {
    match highlight.selected_style {
      Some(style) => style
      None =>
        match highlight.style {
          Some(style) => style
          None => @pippa.style().reverse()
        }
    }
  } else {
    match highlight.style {
      Some(style) => style
      None => @pippa.style().reverse()
    }
  }
}

///|
fn viewport_next_highlight_start(
  model : ViewportModel,
  line_index : Int,
  line : String,
  cursor : Int,
) -> (Int, Int, Int)? {
  let mut best_index = -1
  let mut best_start = component_char_len(line) + 1
  let mut best_end = best_start
  for i, highlight in model.highlights {
    match viewport_line_highlight_bounds(highlight, line_index, line) {
      Some((start, end_)) =>
        if end_ > cursor && start < best_start {
          best_index = i
          best_start = start.max(cursor)
          best_end = end_
        }
      None => ()
    }
  }
  if best_index < 0 {
    None
  } else {
    Some((best_index, best_start, best_end))
  }
}

///|
fn viewport_apply_highlights(
  model : ViewportModel,
  line_index : Int,
  line : String,
) -> String {
  if model.highlights.length() == 0 {
    return line
  }
  let line_len = component_char_len(line)
  let buf = StringBuilder::new(size_hint=line.to_array().length() + 16)
  let mut cursor = 0
  while cursor < line_len {
    match viewport_next_highlight_start(model, line_index, line, cursor) {
      Some((highlight_index, start, end_)) => {
        if start > cursor {
          buf.write_string(component_char_slice(line, cursor, start))
        }
        let segment = component_char_slice(line, start, end_)
        let selected = highlight_index == model.selected_highlight
        buf.write_string(
          viewport_highlight_style(model.highlights[highlight_index], selected).render(
            segment,
          ),
        )
        cursor = end_
      }
      None => {
        buf.write_string(component_char_slice(line, cursor, line_len))
        cursor = line_len
      }
    }
  }
  if line_len == 0 {
    match viewport_next_highlight_start(model, line_index, line, 0) {
      Some((highlight_index, _, _)) => {
        let selected = highlight_index == model.selected_highlight
        return viewport_highlight_style(
          model.highlights[highlight_index],
          selected,
        ).render("")
      }
      None => ()
    }
  }
  buf.to_string()
}

///|
fn viewport_gutter_text(
  model : ViewportModel,
  logical_line : Int,
  visual_line : Int,
  continuation : Bool,
) -> String {
  match model.gutter {
    Some(gutter) => gutter({ logical_line, visual_line, continuation })
    None => ""
  }
}

///|
fn viewport_gutter_width(model : ViewportModel, lines : Array[String]) -> Int {
  if model.gutter is None || model.width <= 0 {
    return 0
  }
  let mut width = 0
  for line_index in 0..<lines.length().max(1) {
    width = width.max(
      @internal.display_width(viewport_gutter_text(model, line_index, 0, false)),
    )
    width = width.max(
      @internal.display_width(viewport_gutter_text(model, line_index, 1, true)),
    )
  }
  width.min(model.width)
}

///|
fn viewport_content_width(model : ViewportModel, lines : Array[String]) -> Int {
  if model.width <= 0 {
    0
  } else {
    (model.width - viewport_gutter_width(model, lines)).max(0)
  }
}

///|
fn viewport_visual_rows_for_line(
  line : String,
  logical_line : Int,
  content_width : Int,
  soft_wrap : Bool,
) -> Array[ViewportVisualRow] {
  let rows : Array[ViewportVisualRow] = []
  if !soft_wrap {
    rows.push({
      logical_line,
      start_cell: 0,
      width: @internal.display_width(line),
      continuation: false,
      visual_line: 0,
    })
    return rows
  }
  let text_rows = textarea_visual_rows_for_line(
    line, logical_line, content_width,
  )
  for visual_index, visual in text_rows {
    rows.push({
      logical_line,
      start_cell: visual.start_cell,
      width: visual.width,
      continuation: visual.continuation,
      visual_line: visual_index,
    })
  }
  rows
}

///|
fn viewport_visual_rows(
  model : ViewportModel,
  lines : Array[String],
  content_width : Int,
) -> Array[ViewportVisualRow] {
  let rows : Array[ViewportVisualRow] = []
  for line_index, line in lines {
    let line_rows = viewport_visual_rows_for_line(
      line,
      line_index,
      content_width,
      model.soft_wrap,
    )
    for row in line_rows {
      rows.push(row)
    }
  }
  if rows.length() == 0 {
    rows.push({
      logical_line: 0,
      start_cell: 0,
      width: 0,
      continuation: false,
      visual_line: 0,
    })
  }
  rows
}

///|
fn viewport_total_rows(model : ViewportModel) -> Int {
  let lines = viewport_lines(model)
  let content_width = viewport_content_width(model, lines)
  viewport_visual_rows(model, lines, content_width).length().max(1)
}

///|
fn viewport_max_offset(model : ViewportModel) -> Int {
  (viewport_total_rows(model) - model.height.max(0)).max(0)
}

///|
fn viewport_max_x_offset(model : ViewportModel) -> Int {
  if model.soft_wrap {
    return 0
  }
  let lines = viewport_lines(model)
  let content_width = viewport_content_width(model, lines)
  let mut max_width = 0
  for line in lines {
    max_width = max_width.max(@internal.display_width(line))
  }
  (max_width - content_width).max(0)
}

///|
fn viewport_normalize(model : ViewportModel) -> ViewportModel {
  let selected_highlight = if model.highlights.length() == 0 {
    -1
  } else {
    viewport_clamp(
      model.selected_highlight.max(0),
      0,
      model.highlights.length() - 1,
    )
  }
  let base = {
    ..model,
    width: viewport_safe_dimension(model.width),
    height: viewport_safe_dimension(model.height),
    horizontal_step: viewport_safe_step(model.horizontal_step),
    mouse_wheel_delta: viewport_safe_delta(model.mouse_wheel_delta),
    x_offset: if model.soft_wrap {
      0
    } else {
      model.x_offset.max(0)
    },
    offset: model.offset.max(0),
    selected_highlight,
    total_lines: @pippa.line_count(model.content),
  }
  let max_offset = viewport_max_offset(base)
  let max_x_offset = viewport_max_x_offset(base)
  {
    ..base,
    offset: viewport_clamp(base.offset, 0, max_offset),
    x_offset: if base.soft_wrap {
      0
    } else {
      viewport_clamp(base.x_offset, 0, max_x_offset)
    },
  }
}

///|
fn viewport_highlight_visual_row(
  model : ViewportModel,
  lines : Array[String],
  rows : Array[ViewportVisualRow],
  highlight : ViewportHighlight,
) -> Int {
  let line_index = viewport_clamp(
    highlight.start_line,
    0,
    lines.length().max(1) - 1,
  )
  let line = if line_index < lines.length() { lines[line_index] } else { "" }
  let col = component_clamp_grapheme_boundary(line, highlight.start_col)
  let cell = component_prefix_display_width(line, col)
  let mut fallback = 0
  for row_index, visual in rows {
    if visual.logical_line == line_index {
      fallback = row_index
      if !model.soft_wrap {
        return row_index
      }
      let final_row = row_index + 1 >= rows.length() ||
        rows[row_index + 1].logical_line != line_index
      if final_row {
        if cell >= visual.start_cell {
          return row_index
        }
      } else if cell >= visual.start_cell &&
        cell < visual.start_cell + visual.width.max(1) {
        return row_index
      }
    }
  }
  fallback
}

///|
fn viewport_scroll_highlight_into_view(model : ViewportModel) -> ViewportModel {
  if model.selected_highlight < 0 ||
    model.selected_highlight >= model.highlights.length() {
    return viewport_normalize(model)
  }
  let normalized = viewport_normalize(model)
  let highlight = normalized.highlights[normalized.selected_highlight]
  let lines = viewport_lines(normalized)
  let content_width = viewport_content_width(normalized, lines)
  let rows = viewport_visual_rows(normalized, lines, content_width)
  let visual_index = viewport_highlight_visual_row(
    normalized, lines, rows, highlight,
  )
  let mut offset = normalized.offset
  if normalized.height > 0 {
    if visual_index < offset {
      offset = visual_index
    } else if visual_index >= offset + normalized.height {
      offset = visual_index - normalized.height + 1
    }
  }
  let mut x_offset = normalized.x_offset
  if !normalized.soft_wrap && content_width > 0 {
    let line_index = viewport_clamp(
      highlight.start_line,
      0,
      lines.length().max(1) - 1,
    )
    let line = if line_index < lines.length() { lines[line_index] } else { "" }
    let start_col = component_clamp_grapheme_boundary(line, highlight.start_col)
    let end_col = component_clamp_grapheme_boundary(line, highlight.end_col)
    let start_cell = component_prefix_display_width(
      line,
      start_col.min(end_col),
    )
    let end_cell = component_prefix_display_width(line, start_col.max(end_col))
    if start_cell < x_offset {
      x_offset = start_cell
    } else if end_cell > x_offset + content_width {
      x_offset = (end_cell - content_width).max(start_cell)
    }
  }
  viewport_normalize({ ..normalized, offset, x_offset })
}

///|
fn viewport_apply_style(style : @pippa.Style?, content : String) -> String {
  match style {
    Some(s) => s.render(content)
    None => content
  }
}

///|
fn viewport_render_blank_row(
  model : ViewportModel,
  gutter_width : Int,
  content_width : Int,
) -> String {
  let gutter = if gutter_width > 0 {
    component_fit_width("", gutter_width)
  } else {
    ""
  }
  let content = viewport_apply_style(
    model.content_style,
    component_fit_width("", content_width),
  )
  viewport_apply_style(
    model.line_style,
    component_fit_width(gutter + content, model.width),
  )
}

///|
fn viewport_render_visual_row(
  model : ViewportModel,
  lines : Array[String],
  visual : ViewportVisualRow,
  gutter_width : Int,
  content_width : Int,
) -> String {
  let raw_line = if visual.logical_line < lines.length() {
    lines[visual.logical_line]
  } else {
    ""
  }
  let highlighted = viewport_apply_highlights(
    model,
    visual.logical_line,
    raw_line,
  )
  let start_cell = if model.soft_wrap {
    visual.start_cell
  } else {
    model.x_offset
  }
  let visible = component_visible_cell_slice(
    highlighted, start_cell, content_width,
  )
  let content = viewport_apply_style(
    model.content_style,
    component_fit_width(visible, content_width),
  )
  let gutter = if gutter_width > 0 {
    component_fit_width(
      viewport_gutter_text(
        model,
        visual.logical_line,
        visual.visual_line,
        visual.continuation,
      ),
      gutter_width,
    )
  } else {
    ""
  }
  viewport_apply_style(
    model.line_style,
    component_fit_width(gutter + content, model.width),
  )
}

///|
fn viewport_update(
  model : ViewportModel,
  msg : ViewportMsg,
) -> @pippa.UpdateResult[ViewportModel, ViewportMsg] {
  let next = match msg {
    SetContent(content) =>
      viewport_normalize({
        ..model,
        content,
        offset: 0,
        x_offset: 0,
        total_lines: @pippa.line_count(content),
      })
    Resize(width, height) => viewport_normalize({ ..model, width, height })
    ScrollUp => viewport_normalize({ ..model, offset: model.offset - 1 })
    ScrollDown => viewport_normalize({ ..model, offset: model.offset + 1 })
    ScrollLeft =>
      viewport_normalize({
        ..model,
        x_offset: model.x_offset - model.horizontal_step,
      })
    ScrollRight =>
      viewport_normalize({
        ..model,
        x_offset: model.x_offset + model.horizontal_step,
      })
    PageUp =>
      viewport_normalize({ ..model, offset: model.offset - model.height })
    PageDown =>
      viewport_normalize({ ..model, offset: model.offset + model.height })
    ScrollToTop => viewport_normalize({ ..model, offset: 0 })
    ScrollToBottom => {
      let normalized = viewport_normalize(model)
      viewport_normalize({
        ..normalized,
        offset: viewport_max_offset(normalized),
      })
    }
    SetXOffset(x_offset) => viewport_normalize({ ..model, x_offset, })
    SetHorizontalStep(step) =>
      viewport_normalize({ ..model, horizontal_step: step })
    SetSoftWrap(soft_wrap) =>
      viewport_normalize({
        ..model,
        soft_wrap,
        x_offset: if soft_wrap {
          0
        } else {
          model.x_offset
        },
      })
    SetFillHeight(fill_height) => viewport_normalize({ ..model, fill_height, })
    HandleMouse(mouse) =>
      if !model.mouse_wheel_enabled || mouse.action != @pippa.MouseWheel {
        viewport_normalize(model)
      } else {
        match mouse.button {
          @pippa.MouseWheelUp =>
            viewport_normalize({
              ..model,
              offset: model.offset - model.mouse_wheel_delta,
            })
          @pippa.MouseWheelDown =>
            viewport_normalize({
              ..model,
              offset: model.offset + model.mouse_wheel_delta,
            })
          @pippa.MouseWheelLeft =>
            viewport_normalize({
              ..model,
              x_offset: model.x_offset - model.horizontal_step,
            })
          @pippa.MouseWheelRight =>
            viewport_normalize({
              ..model,
              x_offset: model.x_offset + model.horizontal_step,
            })
          _ => viewport_normalize(model)
        }
      }
    SetMouseWheelEnabled(mouse_wheel_enabled) =>
      viewport_normalize({ ..model, mouse_wheel_enabled, })
    SetMouseWheelDelta(mouse_wheel_delta) =>
      viewport_normalize({ ..model, mouse_wheel_delta, })
    SetHighlights(highlights) =>
      viewport_scroll_highlight_into_view({
        ..model,
        highlights,
        selected_highlight: viewport_selected_highlight(highlights),
      })
    NextHighlight =>
      if model.highlights.length() == 0 {
        viewport_normalize(model)
      } else {
        let next_selected = if model.selected_highlight < 0 {
          0
        } else {
          (model.selected_highlight + 1) % model.highlights.length()
        }
        viewport_scroll_highlight_into_view({
          ..model,
          selected_highlight: next_selected,
        })
      }
    PreviousHighlight =>
      if model.highlights.length() == 0 {
        viewport_normalize(model)
      } else {
        let next_selected = if model.selected_highlight <= 0 {
          model.highlights.length() - 1
        } else {
          model.selected_highlight - 1
        }
        viewport_scroll_highlight_into_view({
          ..model,
          selected_highlight: next_selected,
        })
      }
    SetContentStyle(content_style) =>
      viewport_normalize({ ..model, content_style, })
    SetLineStyle(line_style) => viewport_normalize({ ..model, line_style, })
  }

  @pippa.UpdateResult::new(model=next, cmd=@pippa.Cmd::none())
}

///|
fn viewport_view(model : ViewportModel) -> String {
  let normalized = viewport_normalize(model)
  if normalized.height <= 0 {
    return ""
  }
  let lines = viewport_lines(normalized)
  let gutter_width = viewport_gutter_width(normalized, lines)
  let content_width = viewport_content_width(normalized, lines)
  let visual_rows = viewport_visual_rows(normalized, lines, content_width)
  let available = (visual_rows.length() - normalized.offset).max(0)
  let row_count = if normalized.fill_height {
    normalized.height
  } else {
    normalized.height.min(available)
  }
  let rows : Array[String] = []
  for i in 0..<row_count {
    let row_index = normalized.offset + i
    if row_index < visual_rows.length() {
      rows.push(
        viewport_render_visual_row(
          normalized,
          lines,
          visual_rows[row_index],
          gutter_width,
          content_width,
        ),
      )
    } else {
      rows.push(
        viewport_render_blank_row(normalized, gutter_width, content_width),
      )
    }
  }
  rows.join("\n")
}

///|
pub fn viewport_scroll_percent(model : ViewportModel) -> Double {
  let max_offset = viewport_max_offset(model)
  if max_offset <= 0 {
    1.0
  } else {
    model.offset.max(0).min(max_offset).to_double() / max_offset.to_double()
  }
}

///|
pub fn viewport_at_top(model : ViewportModel) -> Bool {
  model.offset <= 0
}

///|
pub fn viewport_at_bottom(model : ViewportModel) -> Bool {
  model.offset >= viewport_max_offset(model)
}

///|
pub fn viewport_past_bottom(model : ViewportModel) -> Bool {
  model.offset > viewport_max_offset(model)
}

///|
pub fn viewport_horizontal_scroll_percent(model : ViewportModel) -> Double {
  let max_offset = viewport_max_x_offset(model)
  if max_offset <= 0 {
    1.0
  } else {
    model.x_offset.max(0).min(max_offset).to_double() / max_offset.to_double()
  }
}

///|
pub fn viewport_at_left(model : ViewportModel) -> Bool {
  model.x_offset <= 0
}

///|
pub fn viewport_at_right(model : ViewportModel) -> Bool {
  model.x_offset >= viewport_max_x_offset(model)
}

///|
pub fn viewport_past_right(model : ViewportModel) -> Bool {
  model.x_offset > viewport_max_x_offset(model)
}

///|
/// Construct a Viewport `Component`.
///
/// ```moonbit nocheck
/// let vp = viewport(width=80, height=24)
/// let { model, .. } = (vp.init)()
/// ```
pub fn viewport(
  width~ : Int,
  height~ : Int,
  horizontal_step? : Int = 1,
  soft_wrap? : Bool = false,
  fill_height? : Bool = true,
  mouse_wheel_enabled? : Bool = true,
  mouse_wheel_delta? : Int = 3,
  gutter? : ((ViewportGutterContext) -> String)? = None,
  highlights? : Array[ViewportHighlight] = [],
  content_style? : @pippa.Style? = None,
  line_style? : @pippa.Style? = None,
) -> Component[ViewportModel, ViewportMsg] {
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model=viewport_normalize({
          content: "",
          width,
          height,
          offset: 0,
          x_offset: 0,
          total_lines: 1,
          horizontal_step,
          soft_wrap,
          fill_height,
          mouse_wheel_enabled,
          mouse_wheel_delta,
          gutter,
          highlights,
          selected_highlight: viewport_selected_highlight(highlights),
          content_style,
          line_style,
        }),
        cmd=@pippa.Cmd::none(),
      )
    },
    update: viewport_update,
    view: viewport_view,
  }
}
