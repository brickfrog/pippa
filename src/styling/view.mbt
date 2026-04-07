///|
/// Vertical layout — stacks children separated by newlines.
/// Designed for use with the `<|` operator:
///
/// ```
/// col <| [
///   "header",
///   row <| ["a", " ", "b"],
///   "footer",
/// ]
/// ```
pub fn col(children : Array[String]) -> String {
  join_vertical(children)
}

///|
/// Horizontal layout — places children side by side.
/// Designed for use with the `<|` operator:
///
/// ```
/// row <| [
///   stat_card("PHASE", label),
///   "  ",
///   stat_card("TICKS", count),
/// ]
/// ```
pub fn row(children : Array[String]) -> String {
  join_horizontal(children)
}

///|
/// Simple newline join — no width normalization or alignment.
/// Lighter than `col` when blocks are already uniform width.
pub fn lines(children : Array[String]) -> String {
  @internal.join_lines(children)
}

///|
/// Identity function — returns the input string unchanged.
/// Exists for readability in DSL expressions where a bare string
/// literal would be unclear.
pub fn text(s : String) -> String {
  s
}

///|
/// Produces `n` blank lines for vertical spacing inside a `col`.
/// `gap()` is equivalent to `""` — a single blank line in vertical layout.
/// `gap(n=2)` produces two blank lines (`"\n"`), and so on.
pub fn gap(n? : Int = 1) -> String {
  if n <= 1 {
    return ""
  }
  let buf = StringBuilder::new()
  for i = 1; i < n; i = i + 1 {
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
/// Produces `n` spaces for horizontal spacing inside a `row`.
pub fn hgap(n? : Int = 1) -> String {
  String::make(n, ' ')
}
