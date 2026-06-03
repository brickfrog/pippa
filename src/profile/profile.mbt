///|
/// Terminal color capability used when rendering style color escapes.
pub(all) enum ColorProfile {
  TrueColor
  Ansi256
  Ansi16
  NoColor
} derive(Debug, Eq)

///|
/// Detected terminal background. Unknown resolves like Dark for adaptive colors.
pub(all) enum Background {
  Dark
  Light
  Unknown
} derive(Debug, Eq)

///|
/// User color policy layered on top of detected terminal capability.
pub(all) enum ColorPolicy {
  Auto
  Always
  Never
} derive(Debug, Eq)

///|
/// Immutable render-time color facts consumed by style renderers.
pub(all) struct RenderContext {
  color_profile : ColorProfile
  background : Background
  color_policy : ColorPolicy
} derive(Debug, Eq)

///|
/// Resolved color value before profile degradation.
pub(all) enum ColorValue {
  Palette(Int)
  Rgb(Int, Int, Int)
} derive(Debug, Eq)

///|
pub impl Show for ColorProfile with fn output(self, logger) {
  match self {
    TrueColor => logger.write_string("TrueColor")
    Ansi256 => logger.write_string("Ansi256")
    Ansi16 => logger.write_string("Ansi16")
    NoColor => logger.write_string("NoColor")
  }
}

///|
pub impl Show for Background with fn output(self, logger) {
  match self {
    Dark => logger.write_string("Dark")
    Light => logger.write_string("Light")
    Unknown => logger.write_string("Unknown")
  }
}

///|
pub impl Show for ColorPolicy with fn output(self, logger) {
  match self {
    Auto => logger.write_string("Auto")
    Always => logger.write_string("Always")
    Never => logger.write_string("Never")
  }
}

///|
pub impl Show for RenderContext with fn output(self, logger) {
  logger.write_string(
    "RenderContext(color_profile=\{self.color_profile}, background=\{self.background}, color_policy=\{self.color_policy})",
  )
}

///|
const CSI : String = "\u001b["

///|
let ambient_render_context : Ref[RenderContext] = Ref(RenderContext::default())

///|
pub fn RenderContext::default() -> RenderContext {
  { color_profile: TrueColor, background: Unknown, color_policy: Auto }
}

///|
pub fn RenderContext::with_color_profile(
  self : RenderContext,
  color_profile : ColorProfile,
) -> RenderContext {
  { ..self, color_profile, }
}

///|
pub fn RenderContext::with_background(
  self : RenderContext,
  background : Background,
) -> RenderContext {
  { ..self, background, }
}

///|
pub fn RenderContext::with_color_policy(
  self : RenderContext,
  color_policy : ColorPolicy,
) -> RenderContext {
  { ..self, color_policy, }
}

///|
pub fn RenderContext::detect() -> RenderContext {
  let no_color = @env.get_env_var("NO_COLOR")
  let clicolor_force = @env.get_env_var("CLICOLOR_FORCE")
  let clicolor = @env.get_env_var("CLICOLOR")
  let colorterm = @env.get_env_var("COLORTERM")
  let term = @env.get_env_var("TERM")
  let policy = match no_color {
    Some(value) if value != "" => Never
    _ =>
      match clicolor_force {
        Some(value) if value != "0" => Always
        _ =>
          match clicolor {
            Some("0") => Never
            _ => Auto
          }
      }
  }
  let profile = match colorterm {
    Some(value) if is_truecolor_colorterm(value) => TrueColor
    _ => detect_profile_from_term(term)
  }
  { color_profile: profile, background: Unknown, color_policy: policy }
}

///|
pub fn ambient_context() -> RenderContext {
  ambient_render_context.val
}

///|
pub fn set_render_context(ctx : RenderContext) -> Unit {
  ambient_render_context.val = ctx
}

///|
/// Run `f` with a scoped ambient render context, restoring on return or raise.
pub fn[T] with_render_context(
  ctx : RenderContext,
  f : () -> T raise?,
) -> T raise? {
  let previous = ambient_render_context.val
  ambient_render_context.val = ctx
  try f() catch {
    err => {
      ambient_render_context.val = previous
      raise err
    }
  } noraise {
    result => {
      ambient_render_context.val = previous
      result
    }
  }
}

///|
fn is_truecolor_colorterm(value : String) -> Bool {
  let lower = value.to_lower()
  lower == "truecolor" || lower == "24bit"
}

///|
fn detect_profile_from_term(term : String?) -> ColorProfile {
  match term {
    Some(value) if value == "" => NoColor
    Some(value) if value == "dumb" => NoColor
    Some(value) if value.to_lower().contains("256color") => Ansi256
    Some(_) => Ansi16
    None => NoColor
  }
}

///|
fn clamp_channel(n : Int) -> Int {
  if n < 0 {
    0
  } else if n > 255 {
    255
  } else {
    n
  }
}

///|
fn clamp_palette(n : Int) -> Int {
  if n < 0 {
    0
  } else if n > 255 {
    255
  } else {
    n
  }
}

///|
fn color_level(level : Int) -> Int {
  match level {
    0 => 0
    1 => 95
    2 => 135
    3 => 175
    4 => 215
    _ => 255
  }
}

///|
fn standard16_rgb(n : Int) -> (Int, Int, Int) {
  match n {
    0 => (0, 0, 0)
    1 => (128, 0, 0)
    2 => (0, 128, 0)
    3 => (128, 128, 0)
    4 => (0, 0, 128)
    5 => (128, 0, 128)
    6 => (0, 128, 128)
    7 => (192, 192, 192)
    8 => (128, 128, 128)
    9 => (255, 0, 0)
    10 => (0, 255, 0)
    11 => (255, 255, 0)
    12 => (0, 0, 255)
    13 => (255, 0, 255)
    14 => (0, 255, 255)
    _ => (255, 255, 255)
  }
}

///|
fn ansi256_rgb(n : Int) -> (Int, Int, Int) {
  let index = clamp_palette(n)
  if index < 16 {
    standard16_rgb(index)
  } else if index < 232 {
    let i = index - 16
    (color_level(i / 36), color_level(i / 6 % 6), color_level(i % 6))
  } else {
    let value = 8 + (index - 232) * 10
    (value, value, value)
  }
}

///|
fn rgb_distance_sq(
  r1 : Int,
  g1 : Int,
  b1 : Int,
  r2 : Int,
  g2 : Int,
  b2 : Int,
) -> Int {
  let dr = r1 - r2
  let dg = g1 - g2
  let db = b1 - b2
  dr * dr + dg * dg + db * db
}

///|
pub fn rgb_to_ansi256(r : Int, g : Int, b : Int) -> Int {
  let cr = clamp_channel(r)
  let cg = clamp_channel(g)
  let cb = clamp_channel(b)
  let mut best = 16
  let mut best_distance = 1_000_000
  for index in 16..<256 {
    let (pr, pg, pb) = ansi256_rgb(index)
    let distance = rgb_distance_sq(cr, cg, cb, pr, pg, pb)
    if distance < best_distance {
      best = index
      best_distance = distance
    }
  }
  best
}

///|
pub fn ansi256_to_ansi16(n : Int) -> Int {
  let (r, g, b) = ansi256_rgb(n)
  let mut best = 0
  let mut best_distance = 1_000_000
  for index in 0..<16 {
    let (pr, pg, pb) = standard16_rgb(index)
    let distance = rgb_distance_sq(r, g, b, pr, pg, pb)
    if distance < best_distance {
      best = index
      best_distance = distance
    }
  }
  best
}

///|
fn effective_profile(ctx : RenderContext) -> ColorProfile {
  match ctx.color_policy {
    Never => NoColor
    Always =>
      match ctx.color_profile {
        NoColor => Ansi16
        _ => ctx.color_profile
      }
    Auto => ctx.color_profile
  }
}

///|
fn sgr16(is_fg : Bool, n : Int) -> String {
  let non_negative = if n < 0 { 0 } else { n }
  let index = non_negative.min(15)
  if is_fg {
    if index < 8 {
      "\{CSI}3\{index}m"
    } else {
      "\{CSI}9\{index - 8}m"
    }
  } else if index < 8 {
    "\{CSI}4\{index}m"
  } else {
    "\{CSI}10\{index - 8}m"
  }
}

///|
fn render_color(
  ctx : RenderContext,
  value : ColorValue,
  is_fg : Bool,
) -> String {
  match effective_profile(ctx) {
    NoColor => ""
    Ansi16 => {
      let n = match value {
        Palette(index) =>
          if index < 16 {
            if index < 0 {
              0
            } else {
              index
            }
          } else {
            ansi256_to_ansi16(index)
          }
        Rgb(r, g, b) => ansi256_to_ansi16(rgb_to_ansi256(r, g, b))
      }
      sgr16(is_fg, n)
    }
    Ansi256 => {
      let n = match value {
        Palette(index) => clamp_palette(index)
        Rgb(r, g, b) => rgb_to_ansi256(r, g, b)
      }
      if is_fg {
        "\{CSI}38;5;\{n}m"
      } else {
        "\{CSI}48;5;\{n}m"
      }
    }
    TrueColor =>
      match value {
        Palette(index) =>
          if is_fg {
            "\{CSI}38;5;\{clamp_palette(index)}m"
          } else {
            "\{CSI}48;5;\{clamp_palette(index)}m"
          }
        Rgb(r, g, b) => {
          let cr = clamp_channel(r)
          let cg = clamp_channel(g)
          let cb = clamp_channel(b)
          if is_fg {
            "\{CSI}38;2;\{cr};\{cg};\{cb}m"
          } else {
            "\{CSI}48;2;\{cr};\{cg};\{cb}m"
          }
        }
      }
  }
}

///|
pub fn render_fg(ctx : RenderContext, value : ColorValue) -> String {
  render_color(ctx, value, true)
}

///|
pub fn render_bg(ctx : RenderContext, value : ColorValue) -> String {
  render_color(ctx, value, false)
}
