///|
/// Timer component — counts down over time.

///|
pub(all) struct TimerModel {
  duration_ms : Int
  remaining_ms : Int
  interval_ms : Int
  running : Bool
  finished : Bool
} derive(Show, Eq)

///|
pub(all) enum TimerMsg {
  Start
  Pause
  Reset
  Tick
} derive(Show, Eq)

///|
fn timer_clamp_non_negative(n : Int) -> Int {
  n.max(0)
}

///|
fn timer_next_tick_cmd(interval_ms : Int) -> @pippa.Cmd[TimerMsg] {
  @pippa.Cmd::after(interval_ms.max(1), fn() { Tick })
}

///|
fn timer_format(ms : Int) -> String {
  let total_tenths = timer_clamp_non_negative(ms) / 100
  let minutes = total_tenths / 600
  let seconds = total_tenths / 10 % 60
  let tenths = total_tenths % 10
  let seconds_str = if seconds < 10 { "0\{seconds}" } else { "\{seconds}" }
  "\{minutes}:\{seconds_str}.\{tenths}"
}

///|
pub fn timer(
  duration_ms~ : Int,
  interval_ms? : Int = 100,
) -> Component[TimerModel, TimerMsg] {
  let safe_duration = timer_clamp_non_negative(duration_ms)
  let safe_interval = interval_ms.max(1)
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model={
          duration_ms: safe_duration,
          remaining_ms: safe_duration,
          interval_ms: safe_interval,
          running: false,
          finished: safe_duration == 0,
        },
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model, msg) {
      match msg {
        Start =>
          if model.running || model.finished {
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            @pippa.UpdateResult::new(
              model={ ..model, running: true },
              cmd=timer_next_tick_cmd(model.interval_ms),
            )
          }
        Pause =>
          @pippa.UpdateResult::new(
            model={ ..model, running: false },
            cmd=@pippa.Cmd::none(),
          )
        Reset =>
          @pippa.UpdateResult::new(
            model={
              ..model,
              remaining_ms: model.duration_ms,
              running: false,
              finished: model.duration_ms == 0,
            },
            cmd=@pippa.Cmd::none(),
          )
        Tick =>
          if !model.running || model.finished {
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            let remaining = (model.remaining_ms - model.interval_ms).max(0)
            let finished = remaining == 0
            @pippa.UpdateResult::new(
              model={
                ..model,
                remaining_ms: remaining,
                running: !finished,
                finished,
              },
              cmd=if finished {
                @pippa.Cmd::none()
              } else {
                timer_next_tick_cmd(model.interval_ms)
              },
            )
          }
      }
    },
    view: fn(model) { timer_format(model.remaining_ms) },
  }
}
