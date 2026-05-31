///|
/// A spring-physics animated gradient progress bar component.
///
/// Uses an analytical spring solution for smooth, stable animation with the
/// component's fixed timestep (~16 ms, 16.0 / 1000.0 s).

///|
/// Model for the animated gradient progress bar.
pub(all) struct ProgressBarModel {
  /// Total width of the bar in terminal cells.
  width : Int
  /// Target fill fraction (0.0–1.0).
  target_percent : Double
  /// Currently rendered fill fraction (0.0–1.0); animated toward target.
  displayed_percent : Double
  /// Spring velocity (internal animation state).
  velocity : Double
  /// Spring natural frequency (default 18.0).
  spring_frequency : Double
  /// Spring damping ratio ζ (default 1.0 = critically damped).
  spring_damping : Double
  /// RGB colour at the left edge of the gradient.
  blend_start : (Int, Int, Int)
  /// RGB colour at the right edge of the gradient.
  blend_end : (Int, Int, Int)
  /// RGB colour for the unfilled portion.
  empty_color : (Int, Int, Int)
  /// Whether to show a percentage label to the right of the bar.
  show_percentage : Bool
} derive(Debug)

///|
/// Fill-colour strategy for the progress bar.
pub(all) enum ProgressBarPalette {
  /// Use the existing left-to-right gradient.
  ProgressGradient
  /// Use a single foreground colour for filled cells.
  ProgressSolid((Int, Int, Int))
  /// Render without ANSI colour.
  ProgressNoColor
} derive(Debug, Eq)

///|
/// Messages handled by the progress bar component.
pub(all) enum ProgressBarMsg {
  /// Set a new target percentage (0.0–1.0); kicks off spring animation.
  SetPercent(Double)
  /// Set the render width in terminal cells.
  SetWidth(Int)
  /// Drive one spring physics step (~16 ms dt); typically scheduled via `Cmd::after`.
  Tick
} derive(Debug)

///|
fn lerp_channel(a : Int, b : Int, t : Double) -> Int {
  (a.to_double() + (b.to_double() - a.to_double()) * t).to_int()
}

///|
fn lerp_rgb(
  start : (Int, Int, Int),
  end_ : (Int, Int, Int),
  t : Double,
) -> (Int, Int, Int) {
  (
    lerp_channel(start.0, end_.0, t),
    lerp_channel(start.1, end_.1, t),
    lerp_channel(start.2, end_.2, t),
  )
}

///|
/// Analytical spring integration. Returns (new_pos, new_vel).
pub fn spring_step(
  pos : Double,
  vel : Double,
  target : Double,
  frequency : Double,
  damping : Double,
  dt : Double,
) -> (Double, Double) {
  // Clamp damping to non-negative to avoid NaN from sqrt(1 - ζ²) when ζ < -1.
  let zeta = if damping < 0.0 { 0.0 } else { damping }
  let omega = frequency
  if (zeta - 1.0).abs() < 1.0e-10 {
    // Critically damped
    let a = pos - target
    let b = vel + omega * a
    let e = @math.exp(-omega * dt)
    (target + (a + b * dt) * e, (b - omega * (a + b * dt)) * e)
  } else if zeta < 1.0 {
    // Underdamped — produces bounce
    let wd = omega * Double::sqrt(1.0 - zeta * zeta)
    let a = pos - target
    let b = (vel + zeta * omega * a) / wd
    let e = @math.exp(-zeta * omega * dt)
    let cos_t = @math.cos(wd * dt)
    let sin_t = @math.sin(wd * dt)
    let new_pos = target + e * (a * cos_t + b * sin_t)
    let new_vel = e *
      (
        (b * wd - zeta * omega * a) * cos_t -
        (a * wd + zeta * omega * b) * sin_t
      )
    (new_pos, new_vel)
  } else {
    // Overdamped
    let wd = omega * Double::sqrt(zeta * zeta - 1.0)
    let r1 = -zeta * omega + wd
    let r2 = -zeta * omega - wd
    let denom = 2.0 * wd
    let c1 = (vel - r2 * (pos - target)) / denom
    let c2 = pos - target - c1
    let new_pos = target + c1 * @math.exp(r1 * dt) + c2 * @math.exp(r2 * dt)
    let new_vel = c1 * r1 * @math.exp(r1 * dt) + c2 * r2 * @math.exp(r2 * dt)
    (new_pos, new_vel)
  }
}

///|
fn is_animating(model : ProgressBarModel) -> Bool {
  (model.displayed_percent - model.target_percent).abs() > 0.001 ||
  model.velocity.abs() > 0.01
}

///|
fn rounded_filled_cells(percent : Double, width : Int) -> Int {
  let filled = (percent * width.to_double() + 0.5).to_int()
  if filled < 0 {
    0
  } else if filled > width {
    width
  } else {
    filled
  }
}

///|
fn progress_default_percentage_format(pct : Double) -> String {
  let pct_int = (pct * 100.0 + 0.5).to_int()
  "\{pct_int}%"
}

///|
fn progress_rgb_for_cell(
  palette : ProgressBarPalette,
  blend_start : (Int, Int, Int),
  blend_end : (Int, Int, Int),
  index : Int,
  denominator : Double,
) -> (Int, Int, Int)? {
  match palette {
    ProgressNoColor => None
    ProgressSolid(rgb) => Some(rgb)
    ProgressGradient => {
      let t = if denominator <= 0.0 {
        0.0
      } else {
        index.to_double() / denominator
      }
      Some(lerp_rgb(blend_start, blend_end, t))
    }
  }
}

///|
fn progress_bg_for_cell(
  palette : ProgressBarPalette,
  blend_start : (Int, Int, Int),
  blend_end : (Int, Int, Int),
  index : Int,
  denominator : Double,
) -> (Int, Int, Int)? {
  match palette {
    ProgressGradient => {
      let t = if denominator <= 0.0 {
        0.0
      } else {
        (index.to_double() + 0.5) / denominator
      }
      let clamped = if t > 1.0 { 1.0 } else { t }
      Some(lerp_rgb(blend_start, blend_end, clamped))
    }
    _ => None
  }
}

///|
priv struct ProgressBarRenderCache {
  width : Int
  blend_start : (Int, Int, Int)
  blend_end : (Int, Int, Int)
  empty_color : (Int, Int, Int)
  palette : ProgressBarPalette
  filled_cells : Array[String]
  empty_prefix : String
}

///|
fn progress_rgb_equal(a : (Int, Int, Int), b : (Int, Int, Int)) -> Bool {
  a.0 == b.0 && a.1 == b.1 && a.2 == b.2
}

///|
fn progress_render_cache_matches(
  cache : ProgressBarRenderCache,
  width : Int,
  blend_start : (Int, Int, Int),
  blend_end : (Int, Int, Int),
  empty_color : (Int, Int, Int),
  palette : ProgressBarPalette,
) -> Bool {
  cache.width == width &&
  progress_rgb_equal(cache.blend_start, blend_start) &&
  progress_rgb_equal(cache.blend_end, blend_end) &&
  progress_rgb_equal(cache.empty_color, empty_color) &&
  cache.palette == palette
}

///|
fn progress_write_cell_sequence(
  buf : StringBuilder,
  palette : ProgressBarPalette,
  blend_start : (Int, Int, Int),
  blend_end : (Int, Int, Int),
  index : Int,
  denominator : Double,
  fill_char : String,
) -> Unit {
  match
    progress_rgb_for_cell(palette, blend_start, blend_end, index, denominator) {
    Some(fg) => buf.write_string(@pippa.fg_rgb(fg.0, fg.1, fg.2))
    None => ()
  }
  match
    progress_bg_for_cell(palette, blend_start, blend_end, index, denominator) {
    Some(bg) => buf.write_string(@pippa.bg_rgb(bg.0, bg.1, bg.2))
    None => ()
  }
  buf.write_string(fill_char)
  if palette != ProgressNoColor {
    buf.write_string(@pippa.reset())
  }
}

///|
fn progress_cell_sequence(
  palette : ProgressBarPalette,
  blend_start : (Int, Int, Int),
  blend_end : (Int, Int, Int),
  index : Int,
  denominator : Double,
  fill_char : String,
) -> String {
  let buf = StringBuilder::new(size_hint=48 + fill_char.length())
  progress_write_cell_sequence(
    buf, palette, blend_start, blend_end, index, denominator, fill_char,
  )
  buf.to_string()
}

///|
fn progress_empty_prefix(
  palette : ProgressBarPalette,
  empty_color : (Int, Int, Int),
) -> String {
  if palette == ProgressNoColor {
    ""
  } else {
    let (er, eg, eb) = empty_color
    @pippa.fg_rgb(er, eg, eb)
  }
}

///|
fn progress_build_render_cache(
  width : Int,
  blend_start : (Int, Int, Int),
  blend_end : (Int, Int, Int),
  empty_color : (Int, Int, Int),
  palette : ProgressBarPalette,
  fill_char : String,
) -> ProgressBarRenderCache {
  let cells : Array[String] = []
  let denominator = width.to_double()
  for i in 0..<width {
    cells.push(
      progress_cell_sequence(
        palette, blend_start, blend_end, i, denominator, fill_char,
      ),
    )
  }
  {
    width,
    blend_start,
    blend_end,
    empty_color,
    palette,
    filled_cells: cells,
    empty_prefix: progress_empty_prefix(palette, empty_color),
  }
}

///|
fn progress_render_cache(
  cache_ref : Ref[ProgressBarRenderCache?],
  width : Int,
  blend_start : (Int, Int, Int),
  blend_end : (Int, Int, Int),
  empty_color : (Int, Int, Int),
  palette : ProgressBarPalette,
  fill_char : String,
) -> ProgressBarRenderCache {
  match cache_ref.val {
    Some(cache) => {
      let matches = progress_render_cache_matches(
        cache, width, blend_start, blend_end, empty_color, palette,
      )
      if matches {
        cache
      } else {
        let next = progress_build_render_cache(
          width, blend_start, blend_end, empty_color, palette, fill_char,
        )
        cache_ref.val = Some(next)
        next
      }
    }
    None => {
      let next = progress_build_render_cache(
        width, blend_start, blend_end, empty_color, palette, fill_char,
      )
      cache_ref.val = Some(next)
      next
    }
  }
}

///|
fn progress_bar_size_hint(
  width : Int,
  fill_char : String,
  empty_char : String,
  show_percentage : Bool,
) -> Int {
  let cell_width = fill_char.length().max(empty_char.length())
  let percentage_hint = if show_percentage { 8 } else { 0 }
  width * (cell_width + 42) + percentage_hint
}

///|
fn progress_render_empty_cells(
  buf : StringBuilder,
  empty : Int,
  palette : ProgressBarPalette,
  empty_color : (Int, Int, Int),
  empty_char : String,
  cached_prefix? : String = "",
) -> Unit {
  if empty > 0 {
    if palette != ProgressNoColor {
      if cached_prefix != "" {
        buf.write_string(cached_prefix)
      } else {
        let (er, eg, eb) = empty_color
        buf.write_string(@pippa.fg_rgb(er, eg, eb))
      }
    }
    for _ in 0..<empty {
      buf.write_string(empty_char)
    }
    if palette != ProgressNoColor {
      buf.write_string(@pippa.reset())
    }
  }
}

///|
fn progress_bar_view_uncached(
  model : ProgressBarModel,
  fill_char : String,
  empty_char : String,
  palette : ProgressBarPalette,
  percentage_format : (Double) -> String,
  percentage_style : (String) -> String,
  scaled : Bool,
) -> String {
  let w = if model.width < 0 { 0 } else { model.width }
  let pct = if model.displayed_percent < 0.0 {
    0.0
  } else if model.displayed_percent > 1.0 {
    1.0
  } else {
    model.displayed_percent
  }
  let filled = rounded_filled_cells(pct, w)
  let empty = w - filled
  let fill_width = if scaled { filled } else { w }
  let denominator = fill_width.to_double()
  let buf = StringBuilder::new(
    size_hint=progress_bar_size_hint(
      w,
      fill_char,
      empty_char,
      model.show_percentage,
    ),
  )
  if filled > 0 {
    for i in 0..<filled {
      progress_write_cell_sequence(
        buf,
        palette,
        model.blend_start,
        model.blend_end,
        i,
        denominator,
        fill_char,
      )
    }
  }
  progress_render_empty_cells(
    buf,
    empty,
    palette,
    model.empty_color,
    empty_char,
  )
  if model.show_percentage {
    buf.write_string(" ")
    buf.write_string(percentage_style(percentage_format(pct)))
  }
  buf.to_string()
}

///|
fn progress_bar_view_cached(
  model : ProgressBarModel,
  fill_char : String,
  empty_char : String,
  palette : ProgressBarPalette,
  percentage_format : (Double) -> String,
  percentage_style : (String) -> String,
  scaled : Bool,
  cache_ref : Ref[ProgressBarRenderCache?],
) -> String {
  let w = if model.width < 0 { 0 } else { model.width }
  let pct = if model.displayed_percent < 0.0 {
    0.0
  } else if model.displayed_percent > 1.0 {
    1.0
  } else {
    model.displayed_percent
  }
  if scaled {
    return progress_bar_view_uncached(
      model, fill_char, empty_char, palette, percentage_format, percentage_style,
      scaled,
    )
  }
  let filled = rounded_filled_cells(pct, w)
  let empty = w - filled
  let cache = progress_render_cache(
    cache_ref,
    w,
    model.blend_start,
    model.blend_end,
    model.empty_color,
    palette,
    fill_char,
  )
  let buf = StringBuilder::new(
    size_hint=progress_bar_size_hint(
      w,
      fill_char,
      empty_char,
      model.show_percentage,
    ),
  )
  if filled > 0 {
    for i in 0..<filled {
      buf.write_string(cache.filled_cells[i])
    }
  }
  progress_render_empty_cells(
    buf,
    empty,
    palette,
    model.empty_color,
    empty_char,
    cached_prefix=cache.empty_prefix,
  )
  if model.show_percentage {
    buf.write_string(" ")
    buf.write_string(percentage_style(percentage_format(pct)))
  }
  buf.to_string()
}

///|
/// Create an animated gradient progress bar component with spring physics.
pub fn progress_bar(
  width? : Int = 40,
  show_percentage? : Bool = true,
  blend_start? : (Int, Int, Int) = (90, 86, 224),
  blend_end? : (Int, Int, Int) = (0, 255, 163),
  empty_color? : (Int, Int, Int) = (96, 96, 96),
  spring_frequency? : Double = 18.0,
  spring_damping? : Double = 1.0,
  fill_char? : String = "▌",
  empty_char? : String = "░",
  palette? : ProgressBarPalette = ProgressGradient,
  percentage_format? : (Double) -> String = progress_default_percentage_format,
  percentage_style? : (String) -> String = fn(text) { text },
  scaled? : Bool = false,
) -> Component[ProgressBarModel, ProgressBarMsg] {
  let render_cache : Ref[ProgressBarRenderCache?] = Ref(None)
  {
    init: fn() {
      let model : ProgressBarModel = {
        width,
        target_percent: 0.0,
        displayed_percent: 0.0,
        velocity: 0.0,
        spring_frequency,
        spring_damping,
        blend_start,
        blend_end,
        empty_color,
        show_percentage,
      }
      @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
    },
    update: fn(model, msg) {
      match msg {
        SetPercent(p) => {
          let clamped = if p < 0.0 { 0.0 } else if p > 1.0 { 1.0 } else { p }
          @pippa.UpdateResult::new(
            model={ ..model, target_percent: clamped },
            cmd=@pippa.Cmd::after(16, fn() { ProgressBarMsg::Tick }),
          )
        }
        SetWidth(w) =>
          @pippa.UpdateResult::new(
            model={ ..model, width: w.max(0) },
            cmd=@pippa.Cmd::none(),
          )
        Tick => {
          let (new_pos, new_vel) = spring_step(
            model.displayed_percent,
            model.velocity,
            model.target_percent,
            model.spring_frequency,
            model.spring_damping,
            16.0 / 1000.0,
          )
          let next = { ..model, displayed_percent: new_pos, velocity: new_vel }
          let animating = is_animating(next)
          let settled = if animating {
            next
          } else {
            { ..next, displayed_percent: model.target_percent, velocity: 0.0 }
          }
          let cmd = if animating {
            @pippa.Cmd::after(16, fn() { ProgressBarMsg::Tick })
          } else {
            @pippa.Cmd::none()
          }
          @pippa.UpdateResult::new(model=settled, cmd~)
        }
      }
    },
    view: fn(model) {
      progress_bar_view_cached(
        model, fill_char, empty_char, palette, percentage_format, percentage_style,
        scaled, render_cache,
      )
    },
  }
}
