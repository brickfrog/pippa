///|
/// A single patch operation: move to (row, col) and replace the line with text.
pub(all) struct PatchOp {
  row : Int
  col : Int
  text : String
} derive(Show, Eq)

///|
/// Split a string on '\n', returning each line as an element.
fn split_on_newline(s : String) -> Array[String] {
  let lines : Array[String] = []
  let mut current = ""
  for ch in s {
    if ch == '\n' {
      lines.push(current)
      current = ""
    } else {
      current = current + ch.to_string()
    }
  }
  lines.push(current)
  lines
}

///|
/// Compare two view strings line-by-line and return the minimal set of
/// `PatchOp`s needed to transform the old view into the new view.
///
/// - Changed or added lines → emit a `PatchOp` with the new line text.
/// - Lines present in `old_view` but absent in `new_view` → emit a `PatchOp`
///   with `text = ""` to clear the stale line.
pub fn diff_views(old_view : String, new_view : String) -> Array[PatchOp] {
  let old_lines = split_on_newline(old_view)
  let new_lines = split_on_newline(new_view)
  let ops : Array[PatchOp] = []
  let old_len = old_lines.length()
  let new_len = new_lines.length()
  let max_len = if old_len > new_len { old_len } else { new_len }
  for i = 0; i < max_len; i = i + 1 {
    let old_line = if i < old_len { old_lines[i] } else { "" }
    let new_line = if i < new_len { new_lines[i] } else { "" }
    if old_line != new_line {
      ops.push(PatchOp::{ row: i + 1, col: 1, text: new_line })
    }
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
  let mut result = ""
  for op in ops {
    result = result + move_cursor(op.row, op.col) + clear_line() + op.text
  }
  result
}
