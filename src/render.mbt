///|
/// A single patch operation: move to (row, col) and replace the line with text.
pub(all) struct PatchOp {
  row : Int
  col : Int
  text : String
} derive(Debug, Eq)

///|
fn next_line_end(view : String, start : Int) -> Int {
  let n = view.length()
  let mut i = start
  while i < n && view[i] != '\n' {
    i = i + 1
  }
  i
}

///|
/// Compare two view strings line-by-line and return the minimal set of
/// `PatchOp`s needed to transform the old view into the new view.
///
/// - Changed or added lines → emit a `PatchOp` with the new line text.
/// - Lines present in `old_view` but absent in `new_view` → emit a `PatchOp`
///   with `text = ""` to clear the stale line.
pub fn diff_views(old_view : String, new_view : String) -> Array[PatchOp] {
  let ops : Array[PatchOp] = []
  let old_len = old_view.length()
  let new_len = new_view.length()
  let mut old_start = 0
  let mut new_start = 0
  let mut row = 1
  while old_start <= old_len || new_start <= new_len {
    let old_has_line = old_start <= old_len
    let new_has_line = new_start <= new_len
    if old_has_line && new_has_line {
      let old_end = next_line_end(old_view, old_start)
      let new_end = next_line_end(new_view, new_start)
      let old_line = old_view[old_start:old_end]
      let new_line = new_view[new_start:new_end]
      if old_line != new_line {
        ops.push(PatchOp::{ row, col: 1, text: new_line.to_owned() })
      }
      old_start = old_end + 1
      new_start = new_end + 1
    } else if new_has_line {
      let new_end = next_line_end(new_view, new_start)
      ops.push(PatchOp::{
        row,
        col: 1,
        text: new_view[new_start:new_end].to_owned(),
      })
      new_start = new_end + 1
    } else {
      ops.push(PatchOp::{ row, col: 1, text: "" })
      old_start = next_line_end(old_view, old_start) + 1
    }
    row = row + 1
  }
  ops
}

///|
/// Convert a list of `PatchOp`s into a single ANSI escape string that, when
/// written to the terminal, applies all the patches in order.
///
/// Each op moves the cursor to `(row, col)`, clears to end-of-line, then
/// writes `text`. Returns `""` when `ops` is empty.
pub fn render_patch(ops : Array[PatchOp]) -> String {
  if ops.is_empty() {
    return ""
  }
  let buf = StringBuilder::new()
  for op in ops {
    buf.write_string(move_cursor(op.row, op.col))
    buf.write_string(clear_line())
    buf.write_string(op.text)
  }
  buf.to_string()
}

///|
/// Render a complete view string to the terminal using cursor positioning.
///
/// Splits `view` on newlines and emits `move_cursor + clear_line + text` for
/// every line, then clears any remaining lines below down to `prev_lines`.
/// This avoids writing raw `\n` bytes in raw terminal mode.
pub fn render_full(view : String, prev_lines : Int) -> String {
  let lines = split_lines(view)
  let buf = StringBuilder::new()
  for i in 0..<lines.length() {
    buf.write_string(move_cursor(i + 1, 1))
    buf.write_string(clear_line())
    buf.write_string(lines[i])
  }
  // Clear stale lines below the new view
  for i in lines.length()..<prev_lines {
    buf.write_string(move_cursor(i + 1, 1))
    buf.write_string(clear_line())
  }
  buf.to_string()
}
