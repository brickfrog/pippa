///|
pub(all) struct RoleKey {
  scope : String
  name : String
} derive(Eq, Hash)

///|
pub(all) struct StyledSpan {
  text : String
  role : RoleKey
  style_override : @pippa.Style?
  href : String?
  no_wrap : Bool
} derive(Eq)

///|
priv enum SpanUnit {
  TextUnit(StyledSpan, Int, Bool)
  LineBreak
}

///|
pub impl Show for RoleKey with fn output(self, logger) {
  logger.write_string("RoleKey(scope=\{self.scope}, name=\{self.name})")
}

///|
struct Theme {
  roles : Map[RoleKey, @pippa.Style]
  fallback : @pippa.Style
}

///|
pub fn RoleKey::new(scope~ : String, name~ : String) -> RoleKey {
  { scope, name }
}

///|
pub fn RoleKey::ui(name : String) -> RoleKey {
  RoleKey::new(scope="ui", name~)
}

///|
pub fn RoleKey::markdown(name : String) -> RoleKey {
  RoleKey::new(scope="markdown", name~)
}

///|
pub fn RoleKey::syntax(name : String) -> RoleKey {
  RoleKey::new(scope="syntax", name~)
}

///|
pub fn RoleKey::form(name : String) -> RoleKey {
  RoleKey::new(scope="form", name~)
}

///|
pub fn StyledSpan::new(
  text : String,
  role : RoleKey,
  style_override? : @pippa.Style? = None,
  href? : String? = None,
  no_wrap? : Bool = false,
) -> StyledSpan {
  { text, role, style_override, href, no_wrap }
}

///|
pub fn StyledSpan::with_text(self : StyledSpan, text : String) -> StyledSpan {
  { ..self, text, }
}

///|
pub fn StyledSpan::with_style(
  self : StyledSpan,
  style : @pippa.Style,
) -> StyledSpan {
  { ..self, style_override: Some(style) }
}

///|
pub fn StyledSpan::with_href(self : StyledSpan, href : String) -> StyledSpan {
  { ..self, href: Some(href) }
}

///|
pub fn StyledSpan::without_wrap(self : StyledSpan) -> StyledSpan {
  { ..self, no_wrap: true }
}

///|
pub fn Theme::new(fallback? : @pippa.Style = @pippa.style()) -> Theme {
  { roles: Map([]), fallback }
}

///|
pub fn Theme::with_role(
  self : Theme,
  role : RoleKey,
  style : @pippa.Style,
) -> Theme {
  let roles = self.roles.copy()
  roles.set(role, style)
  { ..self, roles, }
}

///|
pub fn Theme::style(self : Theme, role : RoleKey) -> @pippa.Style {
  match self.roles.get(role) {
    Some(style) => style
    None => self.fallback
  }
}

///|
pub fn Theme::render(
  self : Theme,
  role : RoleKey,
  text : String,
  ctx : @profile.RenderContext,
) -> String {
  self.style(role).render_with(text, ctx)
}

///|
pub fn span_plain_text(spans : Array[StyledSpan]) -> String {
  let buf = StringBuilder::new()
  for span in spans {
    buf.write_string(span.text)
  }
  buf.to_string()
}

///|
fn span_chars_to_string(
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> String {
  let n = chars.length()
  let from = start.max(0).min(n)
  let to = end_index.max(from).min(n)
  let buf = StringBuilder::new(size_hint=to - from)
  for i in from..<to {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn span_is_break_space(span : StyledSpan) -> Bool {
  if span.no_wrap || span.text == "" {
    return false
  }
  for ch in span.text {
    if ch != ' ' && ch != '\t' {
      return false
    }
  }
  true
}

///|
fn push_text_unit(
  units : Array[SpanUnit],
  span : StyledSpan,
  break_space? : Bool = span_is_break_space(span),
) -> Unit {
  if span.text != "" {
    units.push(TextUnit(span, @internal.display_width(span.text), break_space))
  }
}

///|
fn push_span_units_for_part(
  units : Array[SpanUnit],
  span : StyledSpan,
  part : String,
) -> Unit {
  if part == "" {
    return
  }
  if span.no_wrap {
    push_text_unit(units, { ..span, text: part }, break_space=false)
  } else {
    let chars = part.to_array()
    let boundaries = @internal.grapheme_boundaries(part)
    for i in 0..<(boundaries.length() - 1) {
      let cluster = span_chars_to_string(
        chars,
        boundaries[i],
        boundaries[i + 1],
      )
      push_text_unit(units, { ..span, text: cluster })
    }
  }
}

///|
fn span_units(spans : Array[StyledSpan]) -> Array[SpanUnit] {
  let units : Array[SpanUnit] = []
  for span in spans {
    let parts = @pippa.split_lines(span.text)
    for i in 0..<parts.length() {
      if i > 0 {
        units.push(LineBreak)
      }
      push_span_units_for_part(units, span, parts[i])
    }
  }
  units
}

///|
fn span_style_matches(left : StyledSpan, right : StyledSpan) -> Bool {
  left.role == right.role &&
  left.style_override == right.style_override &&
  left.href == right.href &&
  left.no_wrap == right.no_wrap
}

///|
fn line_push_span(line : Array[StyledSpan], span : StyledSpan) -> Unit {
  if span.text == "" {
    return
  }
  if line.length() > 0 {
    let last_index = line.length() - 1
    let last = line[last_index]
    if span_style_matches(last, span) {
      line[last_index] = { ..last, text: last.text + span.text }
      return
    }
  }
  line.push(span)
}

///|
fn line_push_units(
  line : Array[StyledSpan],
  units : Array[SpanUnit],
  start : Int,
  end_index : Int,
) -> Unit {
  for i in start..<end_index {
    match units[i] {
      TextUnit(span, _, _) => line_push_span(line, span)
      LineBreak => ()
    }
  }
}

///|
fn unit_is_space(unit : SpanUnit) -> Bool {
  match unit {
    TextUnit(_, _, is_space) => is_space
    LineBreak => false
  }
}

///|
fn unit_is_text(unit : SpanUnit) -> Bool {
  match unit {
    TextUnit(_, _, _) => true
    LineBreak => false
  }
}

///|
fn unit_width(unit : SpanUnit) -> Int {
  match unit {
    TextUnit(_, width, _) => width
    LineBreak => 0
  }
}

///|
fn finish_span_line(
  lines : Array[Array[StyledSpan]],
  current : Array[StyledSpan],
) -> Array[StyledSpan] {
  lines.push(current)
  []
}

///|
/// Wrap styled plaintext spans to a terminal-cell width.
///
/// A non-positive `width` disables wrapping and returns all spans as one line.
/// For positive widths, breakable text is wrapped by plaintext grapheme width.
/// Break-point spaces may be consumed at line boundaries. Non-space content is
/// preserved; an indivisible unit wider than `width` is placed on its own line.
pub fn wrap_spans(
  spans : Array[StyledSpan],
  width : Int,
) -> Array[Array[StyledSpan]] {
  if width <= 0 {
    return [spans]
  }
  let units = span_units(spans)
  let lines : Array[Array[StyledSpan]] = []
  let mut current : Array[StyledSpan] = []
  let mut current_width = 0
  let mut index = 0
  while index < units.length() {
    match units[index] {
      LineBreak => {
        current = finish_span_line(lines, current)
        current_width = 0
        index = index + 1
        continue
      }
      _ => ()
    }
    let space_start = index
    let mut space_width = 0
    while index < units.length() && unit_is_space(units[index]) {
      space_width = space_width + unit_width(units[index])
      index = index + 1
    }
    let word_start = index
    let mut word_width = 0
    while index < units.length() &&
          unit_is_text(units[index]) &&
          !unit_is_space(units[index]) {
      word_width = word_width + unit_width(units[index])
      index = index + 1
    }
    if word_start == index {
      if current_width + space_width <= width {
        line_push_units(current, units, space_start, index)
        current_width = current_width + space_width
      }
      continue
    }
    if space_start < word_start {
      if current_width == 0 {
        if space_width + word_width <= width {
          line_push_units(current, units, space_start, word_start)
          current_width = current_width + space_width
        }
      } else if current_width + space_width + word_width <= width {
        line_push_units(current, units, space_start, word_start)
        current_width = current_width + space_width
      } else {
        current = finish_span_line(lines, current)
        current_width = 0
      }
    }
    if word_width <= width - current_width {
      line_push_units(current, units, word_start, index)
      current_width = current_width + word_width
    } else {
      if current_width > 0 {
        current = finish_span_line(lines, current)
        current_width = 0
      }
      let mut word_index = word_start
      while word_index < index {
        let next_width = unit_width(units[word_index])
        if current_width > 0 && current_width + next_width > width {
          current = finish_span_line(lines, current)
          current_width = 0
        }
        line_push_units(current, units, word_index, word_index + 1)
        current_width = current_width + next_width
        word_index = word_index + 1
        if current_width >= width && word_index < index {
          current = finish_span_line(lines, current)
          current_width = 0
        }
      }
    }
  }
  lines.push(current)
  lines
}

///|
pub fn Theme::render_span(
  self : Theme,
  span : StyledSpan,
  ctx : @profile.RenderContext,
) -> String {
  let styled = match span.style_override {
    Some(style) => style.render_with(span.text, ctx)
    None => self.render(span.role, span.text, ctx)
  }
  match span.href {
    Some(href) => @pippa.hyperlink(href, styled)
    None => styled
  }
}

///|
pub fn render_spans(
  spans : Array[StyledSpan],
  theme : Theme,
  ctx : @profile.RenderContext,
) -> String {
  let buf = StringBuilder::new()
  for span in spans {
    buf.write_string(theme.render_span(span, ctx))
  }
  buf.to_string()
}

///|
pub fn render_span_lines(
  lines : Array[Array[StyledSpan]],
  theme : Theme,
  ctx : @profile.RenderContext,
) -> String {
  let rendered : Array[String] = []
  for line in lines {
    rendered.push(render_spans(line, theme, ctx))
  }
  rendered.join("\n")
}

///|
pub fn render_wrapped_spans(
  spans : Array[StyledSpan],
  width : Int,
  theme : Theme,
  ctx : @profile.RenderContext,
) -> String {
  render_span_lines(wrap_spans(spans, width), theme, ctx)
}

///|
pub fn default_theme() -> Theme {
  Theme::new()
  .with_role(
    RoleKey::ui("text"),
    adaptive_foreground(
      light=@pippa.color_rgb(31, 41, 55),
      dark=@pippa.color_rgb(229, 231, 235),
    ),
  )
  .with_role(
    RoleKey::ui("muted"),
    adaptive_foreground(
      light=@pippa.color_rgb(107, 114, 128),
      dark=@pippa.color_rgb(156, 163, 175),
    ),
  )
  .with_role(
    RoleKey::ui("accent"),
    adaptive_foreground(
      light=@pippa.color_rgb(37, 99, 235),
      dark=@pippa.color_rgb(96, 165, 250),
    ),
  )
  .with_role(
    RoleKey::ui("focus"),
    adaptive_foreground(
      light=@pippa.color_rgb(124, 58, 237),
      dark=@pippa.color_rgb(167, 139, 250),
    ),
  )
  .with_role(
    RoleKey::ui("error"),
    adaptive_foreground(
      light=@pippa.color_rgb(185, 28, 28),
      dark=@pippa.color_rgb(248, 113, 113),
    ),
  )
  .with_role(
    RoleKey::ui("warning"),
    adaptive_foreground(
      light=@pippa.color_rgb(180, 83, 9),
      dark=@pippa.color_rgb(251, 191, 36),
    ),
  )
  .with_role(
    RoleKey::ui("success"),
    adaptive_foreground(
      light=@pippa.color_rgb(21, 128, 61),
      dark=@pippa.color_rgb(74, 222, 128),
    ),
  )
  .with_role(
    RoleKey::ui("border"),
    adaptive_foreground(
      light=@pippa.color_rgb(156, 163, 175),
      dark=@pippa.color_rgb(75, 85, 99),
    ),
  )
  .with_role(
    RoleKey::form("label"),
    adaptive_foreground(
      light=@pippa.color_rgb(31, 41, 55),
      dark=@pippa.color_rgb(229, 231, 235),
    ).bold(),
  )
  .with_role(
    RoleKey::form("help"),
    adaptive_foreground(
      light=@pippa.color_rgb(107, 114, 128),
      dark=@pippa.color_rgb(156, 163, 175),
    ),
  )
  .with_role(
    RoleKey::form("validation.info"),
    adaptive_foreground(
      light=@pippa.color_rgb(37, 99, 235),
      dark=@pippa.color_rgb(96, 165, 250),
    ),
  )
  .with_role(
    RoleKey::form("validation.warning"),
    adaptive_foreground(
      light=@pippa.color_rgb(180, 83, 9),
      dark=@pippa.color_rgb(251, 191, 36),
    ),
  )
  .with_role(
    RoleKey::form("validation.error"),
    adaptive_foreground(
      light=@pippa.color_rgb(185, 28, 28),
      dark=@pippa.color_rgb(248, 113, 113),
    ),
  )
  .with_role(
    RoleKey::markdown("paragraph"),
    adaptive_foreground(
      light=@pippa.color_rgb(31, 41, 55),
      dark=@pippa.color_rgb(229, 231, 235),
    ),
  )
  .with_role(
    RoleKey::markdown("heading.1"),
    adaptive_foreground(
      light=@pippa.color_rgb(17, 24, 39),
      dark=@pippa.color_rgb(243, 244, 246),
    ).bold(),
  )
  .with_role(
    RoleKey::markdown("heading.2"),
    adaptive_foreground(
      light=@pippa.color_rgb(30, 64, 175),
      dark=@pippa.color_rgb(147, 197, 253),
    ).bold(),
  )
  .with_role(
    RoleKey::markdown("heading.3"),
    adaptive_foreground(
      light=@pippa.color_rgb(15, 118, 110),
      dark=@pippa.color_rgb(94, 234, 212),
    ).bold(),
  )
  .with_role(
    RoleKey::markdown("heading.4"),
    adaptive_foreground(
      light=@pippa.color_rgb(88, 28, 135),
      dark=@pippa.color_rgb(216, 180, 254),
    ).bold(),
  )
  .with_role(
    RoleKey::markdown("heading.5"),
    adaptive_foreground(
      light=@pippa.color_rgb(157, 23, 77),
      dark=@pippa.color_rgb(249, 168, 212),
    ).bold(),
  )
  .with_role(
    RoleKey::markdown("heading.6"),
    adaptive_foreground(
      light=@pippa.color_rgb(67, 56, 202),
      dark=@pippa.color_rgb(165, 180, 252),
    ).bold(),
  )
  .with_role(
    RoleKey::markdown("emphasis"),
    adaptive_foreground(
      light=@pippa.color_rgb(55, 65, 81),
      dark=@pippa.color_rgb(209, 213, 219),
    ).italic(),
  )
  .with_role(
    RoleKey::markdown("strong"),
    adaptive_foreground(
      light=@pippa.color_rgb(17, 24, 39),
      dark=@pippa.color_rgb(243, 244, 246),
    ).bold(),
  )
  .with_role(
    RoleKey::markdown("code.inline"),
    adaptive_foreground(
      light=@pippa.color_rgb(127, 29, 29),
      dark=@pippa.color_rgb(252, 165, 165),
    ).background(
      @pippa.color_adaptive(
        @pippa.color_rgb(243, 244, 246),
        @pippa.color_rgb(31, 41, 55),
      ),
    ),
  )
  .with_role(
    RoleKey::markdown("code.block"),
    adaptive_foreground(
      light=@pippa.color_rgb(75, 85, 99),
      dark=@pippa.color_rgb(209, 213, 219),
    ),
  )
  .with_role(
    RoleKey::markdown("link"),
    adaptive_foreground(
      light=@pippa.color_rgb(37, 99, 235),
      dark=@pippa.color_rgb(96, 165, 250),
    ).underline(),
  )
  .with_role(
    RoleKey::markdown("blockquote"),
    adaptive_foreground(
      light=@pippa.color_rgb(107, 114, 128),
      dark=@pippa.color_rgb(156, 163, 175),
    ),
  )
  .with_role(
    RoleKey::markdown("list.marker"),
    adaptive_foreground(
      light=@pippa.color_rgb(5, 150, 105),
      dark=@pippa.color_rgb(52, 211, 153),
    ).bold(),
  )
  .with_role(
    RoleKey::markdown("thematic_break"),
    adaptive_foreground(
      light=@pippa.color_rgb(156, 163, 175),
      dark=@pippa.color_rgb(75, 85, 99),
    ),
  )
}

///|
fn adaptive_foreground(
  light~ : @pippa.Color,
  dark~ : @pippa.Color,
) -> @pippa.Style {
  @pippa.style().foreground(@pippa.color_adaptive(light, dark))
}
