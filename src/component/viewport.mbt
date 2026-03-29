///|
pub(all) struct ViewportModel {
  content : String
  width : Int
  height : Int
  offset : Int
}

///|
pub(all) enum ViewportMsg {
  ScrollUp
  ScrollDown
  PageUp
  PageDown
  ScrollToTop
  ScrollToBottom
  SetContent(String)
  Resize(Int, Int)
}

///|
pub fn viewport(
  width~ : Int,
  height~ : Int,
) -> Component[ViewportModel, ViewportMsg] {
  Component::{
    init: fn() {
      @pippa.UpdateResult::new(
        model={ content: "", width, height, offset: 0 },
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model : ViewportModel, msg : ViewportMsg) {
      let mut offset = model.offset
      let mut content = model.content
      let mut width = model.width
      let mut height = model.height

      match msg {
        SetContent(c) => {
          content = c
          offset = 0
        }
        Resize(w, h) => {
          width = w
          height = h
        }
        _ => ()
      }

      let total_lines = @pippa.line_count(content)
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
        model={ content, width, height, offset },
        cmd=@pippa.Cmd::none(),
      )
    },
    view: fn(model : ViewportModel) {
      let lines = @pippa.split_lines(model.content)
      let buf = StringBuilder::new()
      for i = 0; i < model.height; i = i + 1 {
        let line_idx = model.offset + i
        let raw_line = if line_idx < lines.length() {
          lines[line_idx]
        } else {
          ""
        }
        let padded = @pippa.pad_right(raw_line, model.width)
        buf.write_string(padded)
        if i < model.height - 1 {
          buf.write_char('\n')
        }
      }
      buf.to_string()
    },
  }
}
