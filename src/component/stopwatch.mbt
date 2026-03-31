///|
/// Stopwatch component — counts up while running.

///|
pub(all) struct StopwatchModel {
  elapsed_ms : Int
  interval_ms : Int
  running : Bool
} derive(Show, Eq)

///|
pub(all) enum StopwatchMsg {
  Start
  Pause
  Reset
  Tick
} derive(Show, Eq)

///|
fn stopwatch_next_tick_cmd(interval_ms : Int) -> @pippa.Cmd[StopwatchMsg] {
  @pippa.Cmd::after(interval_ms.max(1), fn() { Tick })
}

///|
fn stopwatch_format(ms : Int) -> String {
  let total_tenths = ms.max(0) / 100
  let minutes = total_tenths / 600
  let seconds = total_tenths / 10 % 60
  let tenths = total_tenths % 10
  let seconds_str = if seconds < 10 { "0\{seconds}" } else { "\{seconds}" }
  "\{minutes}:\{seconds_str}.\{tenths}"
}

///|
pub fn stopwatch(
  interval_ms? : Int = 100,
) -> Component[StopwatchModel, StopwatchMsg] {
  let safe_interval = interval_ms.max(1)
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model={ elapsed_ms: 0, interval_ms: safe_interval, running: false },
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model, msg) {
      match msg {
        Start =>
          if model.running {
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            @pippa.UpdateResult::new(
              model={ ..model, running: true },
              cmd=stopwatch_next_tick_cmd(model.interval_ms),
            )
          }
        Pause =>
          @pippa.UpdateResult::new(
            model={ ..model, running: false },
            cmd=@pippa.Cmd::none(),
          )
        Reset =>
          @pippa.UpdateResult::new(
            model={ ..model, elapsed_ms: 0, running: false },
            cmd=@pippa.Cmd::none(),
          )
        Tick =>
          if !model.running {
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            @pippa.UpdateResult::new(
              model={
                ..model,
                elapsed_ms: model.elapsed_ms + model.interval_ms,
              },
              cmd=stopwatch_next_tick_cmd(model.interval_ms),
            )
          }
      }
    },
    view: fn(model) { stopwatch_format(model.elapsed_ms) },
  }
}
