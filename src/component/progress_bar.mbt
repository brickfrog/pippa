///|
/// A spring-physics animated gradient progress bar component.
///
/// Uses an analytical spring solution for smooth, stable animation with the
/// component's fixed timestep (~16 ms, 16.0 / 1000.0 s).

///|
/// Model for the animated gradient progress bar.
pub(all) struct ProgressBarModel {
  /// Total width of the bar in characters.
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
} derive(Show)

///|
/// Messages handled by the progress bar component.
pub(all) enum ProgressBarMsg {
  /// Set a new target percentage (0.0–1.0); kicks off spring animation.
  SetPercent(Double)
  /// Drive one spring physics step (~16 ms dt); issued by the app's on_tick.
  Tick
} derive(Show)

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
/// Create an animated gradient progress bar component with spring physics.
pub fn progress_bar(
  width? : Int = 40,
  show_percentage? : Bool = true,
  blend_start? : (Int, Int, Int) = (90, 86, 224),
  blend_end? : (Int, Int, Int) = (0, 255, 163),
  empty_color? : (Int, Int, Int) = (96, 96, 96),
  spring_frequency? : Double = 18.0,
  spring_damping? : Double = 1.0,
) -> Component[ProgressBarModel, ProgressBarMsg] {
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
            cmd=@pippa.Cmd::tick(16),
          )
        }
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
          let cmd = if is_animating(next) {
            @pippa.Cmd::tick(16)
          } else {
            @pippa.Cmd::none()
          }
          @pippa.UpdateResult::new(model=next, cmd~)
        }
      }
    },
    view: fn(model) {
      let w = if model.width < 0 { 0 } else { model.width }
      let pct = if model.displayed_percent < 0.0 {
        0.0
      } else if model.displayed_percent > 1.0 {
        1.0
      } else {
        model.displayed_percent
      }
      let filled = (pct * w.to_double()).to_int()
      let filled = if filled < 0 { 0 } else if filled > w { w } else { filled }
      let empty = w - filled
      let total_width = w.to_double()
      let buf = StringBuilder::new()
      if filled > 0 && total_width > 0.0 {
        for i in 0..<filled {
          let t = i.to_double() / total_width
          let tb = t + 0.5 / total_width
          let t_bg = if tb > 1.0 { 1.0 } else { tb }
          let fg = lerp_rgb(model.blend_start, model.blend_end, t)
          let bg = lerp_rgb(model.blend_start, model.blend_end, t_bg)
          buf.write_string(@pippa.fg_rgb(fg.0, fg.1, fg.2))
          buf.write_string(@pippa.bg_rgb(bg.0, bg.1, bg.2))
          buf.write_string("▌")
          buf.write_string(@pippa.reset())
        }
      }
      if empty > 0 {
        let (er, eg, eb) = model.empty_color
        buf.write_string(@pippa.fg_rgb(er, eg, eb))
        for _ in 0..<empty {
          buf.write_string("░")
        }
        buf.write_string(@pippa.reset())
      }
      if model.show_percentage {
        let pct_int = (pct * 100.0).to_int()
        buf.write_string(" \{pct_int}%")
      }
      buf.to_string()
    },
  }
}
