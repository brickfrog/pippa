///|
/// Viewport component — a scrollable window over a larger body of text.

///|
/// Model for the Viewport component.
///
/// - `content`: the full body of text to be displayed
/// - `width`: the visible width of the viewport
/// - `height`: the visible height (number of lines) of the viewport
/// - `offset`: the index of the first visible line (0-based)
/// - `total_lines`: pre-calculated count of total lines in content
pub(all) struct ViewportModel {
  content : String
  width : Int
  height : Int
  offset : Int
  total_lines : Int
} derive(Debug)

///|
/// Messages handled by the Viewport component.
pub(all) enum ViewportMsg {
  /// Scroll up one line.
  ScrollUp
  /// Scroll down one line.
  ScrollDown
  /// Scroll up one full page (height lines).
  PageUp
  /// Scroll down one full page (height lines).
  PageDown
  /// Scroll directly to the first line.
  ScrollToTop
  /// Scroll directly to the last possible line.
  ScrollToBottom
  /// Replace the current content and reset the offset to 0.
  SetContent(String)
  /// Update the viewport dimensions and re-clamp the offset.
  Resize(Int, Int)
} derive(Debug)

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
) -> Component[ViewportModel, ViewportMsg] {
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model={
          content: "",
          width: if width > 0 {
            width
          } else {
            0
          },
          height: if height > 0 {
            height
          } else {
            0
          },
          offset: 0,
          total_lines: 1, // Empty string has one line ""
        },
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model : ViewportModel, msg : ViewportMsg) {
      let mut offset = model.offset
      let mut content = model.content
      let mut width = model.width
      let mut height = model.height
      let mut total_lines = model.total_lines

      match msg {
        SetContent(c) => {
          content = c
          total_lines = @pippa.line_count(content)
          offset = 0
        }
        Resize(w, h) => {
          width = if w > 0 { w } else { 0 }
          height = if h > 0 { h } else { 0 }
        }
        _ => ()
      }

      let max_offset = if total_lines > height {
        total_lines - height
      } else {
        0
      }

      match msg {
        ScrollUp => offset = offset - 1
        ScrollDown => offset = offset + 1
        PageUp => offset = offset - height
        PageDown => offset = offset + height
        ScrollToTop => offset = 0
        ScrollToBottom => offset = max_offset
        _ => ()
      }

      if offset > max_offset {
        offset = max_offset
      }
      if offset < 0 {
        offset = 0
      }

      @pippa.UpdateResult::new(
        model={ content, width, height, offset, total_lines },
        cmd=@pippa.Cmd::none(),
      )
    },
    view: fn(model : ViewportModel) {
      let lines = @pippa.split_lines(model.content)
      let buf = StringBuilder::new()
      for i in 0..<model.height {
        let line_idx = model.offset + i
        let raw_line = if line_idx < lines.length() {
          lines[line_idx]
        } else {
          ""
        }
        let truncated = @pippa.truncate(raw_line, model.width)
        let padded = @pippa.pad_right(truncated, model.width)
        buf.write_string(padded)
        if i < model.height - 1 {
          buf.write_char('\n')
        }
      }
      buf.to_string()
    },
  }
}
