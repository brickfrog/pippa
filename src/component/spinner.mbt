///|
/// Spinner component — cycles through animation frames to indicate activity.

///|
/// Model for the Spinner component.
///
/// - `frames`: the sequence of strings to cycle through
/// - `current`: index of the frame currently displayed
/// - `label`: text shown after the frame
pub(all) struct SpinnerModel {
  frames : Array[String]
  current : Int
  label : String
  interval_ms : Int
  running : Bool
  instance_id : Int64
  tick_generation : Int64
} derive(Debug)

///|
/// Stable identity attached to scheduled spinner ticks.
pub(all) struct SpinnerTickToken {
  instance_id : Int64
  generation : Int64
} derive(Debug, Eq)

///|
/// Named spinner frame sets matching the Bubbles parity subset.
pub(all) enum SpinnerPreset {
  Line
  Dot
  MiniDot
  Jump
  Pulse
  Points
  Globe
  Moon
  Monkey
  Meter
  Hamburger
  Ellipsis
} derive(Debug, Eq)

///|
/// Messages handled by the Spinner component.
pub(all) enum SpinnerMsg {
  /// Start scheduled spinner ticks.
  Start
  /// Stop scheduled spinner ticks.
  Stop
  /// Reset to the first frame and stop scheduled spinner ticks.
  Reset
  /// Advance to the next animation frame.
  Tick
  /// Advance from a scheduled tick when the token still matches this model.
  TimedTick(SpinnerTickToken)
} derive(Debug, Eq)

///|
priv struct SpinnerScheduledTick {
  interval_ms : Int
  task : () -> SpinnerMsg
}

///|
let spinner_instance_counter : Ref[Int64] = Ref(0L)

///|
fn spinner_next_instance_id() -> Int64 {
  spinner_instance_counter.val = spinner_instance_counter.val + 1L
  spinner_instance_counter.val
}

///|
fn spinner_current_tick_token(model : SpinnerModel) -> SpinnerTickToken {
  { instance_id: model.instance_id, generation: model.tick_generation }
}

///|
fn spinner_next_tick_generation(model : SpinnerModel) -> Int64 {
  model.tick_generation + 1L
}

///|
fn spinner_tick_task(token : SpinnerTickToken) -> () -> SpinnerMsg {
  fn() { TimedTick(token) }
}

///|
fn spinner_next_tick_schedule(
  interval_ms : Int,
  token : SpinnerTickToken,
) -> SpinnerScheduledTick {
  { interval_ms: interval_ms.max(1), task: spinner_tick_task(token) }
}

///|
fn spinner_next_tick_cmd(
  interval_ms : Int,
  token : SpinnerTickToken,
) -> @pippa.Cmd[SpinnerMsg] {
  let schedule = spinner_next_tick_schedule(interval_ms, token)
  @pippa.Cmd::after(schedule.interval_ms, schedule.task)
}

///|
fn spinner_tick_is_current(
  model : SpinnerModel,
  token : SpinnerTickToken,
) -> Bool {
  token == spinner_current_tick_token(model)
}

///|
pub fn spinner_preset_frames(preset : SpinnerPreset) -> Array[String] {
  match preset {
    Line => ["|", "/", "-", "\\"]
    Dot => ["⣾ ", "⣽ ", "⣻ ", "⢿ ", "⡿ ", "⣟ ", "⣯ ", "⣷ "]
    MiniDot =>
      ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    Jump => ["⢄", "⢂", "⢁", "⡁", "⡈", "⡐", "⡠"]
    Pulse => ["█", "▓", "▒", "░"]
    Points => ["∙∙∙", "●∙∙", "∙●∙", "∙∙●"]
    Globe => ["🌍", "🌎", "🌏"]
    Moon => ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"]
    Monkey => ["🙈", "🙉", "🙊"]
    Meter =>
      [
        "▱▱▱", "▰▱▱", "▰▰▱", "▰▰▰", "▰▰▱", "▰▱▱",
        "▱▱▱",
      ]
    Hamburger => ["☱", "☲", "☴", "☲"]
    Ellipsis => ["", ".", "..", "..."]
  }
}

///|
pub fn spinner_preset_interval_ms(preset : SpinnerPreset) -> Int {
  match preset {
    Line | Dot | Jump => 100
    MiniDot => 83
    Pulse | Moon => 125
    Points | Meter => 142
    Globe => 250
    Monkey | Hamburger | Ellipsis => 333
  }
}

///|
pub fn spinner_interval_ms_from_fps(fps : Double) -> Int {
  if fps <= 0.0 {
    1
  } else {
    let rounded = (1000.0 / fps + 0.5).to_int()
    rounded.max(1)
  }
}

///|
fn spinner_resolve_interval_ms(
  preset : SpinnerPreset,
  interval_ms : Int,
  fps : Double,
) -> Int {
  if interval_ms > 0 {
    interval_ms
  } else if fps > 0.0 {
    spinner_interval_ms_from_fps(fps)
  } else {
    spinner_preset_interval_ms(preset)
  }
}

///|
fn spinner_resolve_frames(
  preset : SpinnerPreset,
  frames : Array[String],
) -> Array[String] {
  if frames.length() > 0 {
    frames
  } else {
    spinner_preset_frames(preset)
  }
}

///|
fn spinner_advance(model : SpinnerModel) -> SpinnerModel {
  if model.frames.length() == 0 {
    model
  } else {
    { ..model, current: (model.current + 1) % model.frames.length() }
  }
}

///|
fn spinner_start(
  model : SpinnerModel,
) -> @pippa.UpdateResult[SpinnerModel, SpinnerMsg] {
  if model.running {
    @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
  } else {
    let model = {
      ..model,
      running: true,
      tick_generation: spinner_next_tick_generation(model),
    }
    @pippa.UpdateResult::new(
      model~,
      cmd=spinner_next_tick_cmd(
        model.interval_ms,
        spinner_current_tick_token(model),
      ),
    )
  }
}

///|
/// Construct a Spinner `Component`.
///
/// ```moonbit nocheck
/// let s = spinner(label="Loading...")
/// let { model, .. } = (s.init)()
/// ```
pub fn spinner(
  label? : String = "Loading...",
  preset? : SpinnerPreset = MiniDot,
  frames? : Array[String] = [],
  interval_ms? : Int = 0,
  fps? : Double = 0.0,
  frame_style? : (String) -> String = fn(frame) { frame },
  autostart? : Bool = false,
) -> Component[SpinnerModel, SpinnerMsg] {
  let resolved_frames = spinner_resolve_frames(preset, frames)
  let resolved_interval_ms = spinner_resolve_interval_ms(
    preset, interval_ms, fps,
  )
  {
    init: fn() {
      let instance_id = spinner_next_instance_id()
      let base_model = {
        frames: resolved_frames,
        current: 0,
        label,
        interval_ms: resolved_interval_ms,
        running: false,
        instance_id,
        tick_generation: 0L,
      }
      if autostart {
        spinner_start(base_model)
      } else {
        @pippa.UpdateResult::new(model=base_model, cmd=@pippa.Cmd::none())
      }
    },
    update: fn(model, msg) {
      match msg {
        Start => spinner_start(model)
        Stop =>
          @pippa.UpdateResult::new(
            model={ ..model, running: false },
            cmd=@pippa.Cmd::none(),
          )
        Reset =>
          @pippa.UpdateResult::new(
            model={ ..model, current: 0, running: false },
            cmd=@pippa.Cmd::none(),
          )
        Tick =>
          @pippa.UpdateResult::new(
            model=spinner_advance(model),
            cmd=@pippa.Cmd::none(),
          )
        TimedTick(token) =>
          if !spinner_tick_is_current(model, token) || !model.running {
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            let model = {
              ..spinner_advance(model),
              tick_generation: spinner_next_tick_generation(model),
            }
            @pippa.UpdateResult::new(
              model~,
              cmd=spinner_next_tick_cmd(
                model.interval_ms,
                spinner_current_tick_token(model),
              ),
            )
          }
      }
    },
    view: fn(model) {
      let frame = frame_style(model.frames[model.current])
      "\{frame} \{model.label}"
    },
  }
}
