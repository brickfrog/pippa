///|
/// Stopwatch component — counts up while running.

///|
pub(all) struct StopwatchTickToken {
  instance_id : Int64
  generation : Int64
} derive(Debug, Eq)

///|
pub(all) struct StopwatchModel {
  elapsed_ms : Int
  interval_ms : Int
  running : Bool
  instance_id : Int64
  tick_generation : Int64
} derive(Debug, Eq)

///|
pub(all) enum StopwatchMsg {
  Start
  Pause
  Reset
  Tick(StopwatchTickToken)
} derive(Debug, Eq)

///|
priv struct StopwatchScheduledTick {
  interval_ms : Int
  task : () -> StopwatchMsg
}

///|
/// Stopwatch identity counters are monotonic Int64 values. Their range is far
/// beyond realistic component lifetimes; exhausting it would be a token-collision
/// risk for a process that has already run billions of billions of ticks.
let stopwatch_instance_counter : Ref[Int64] = Ref(0L)

///|
fn stopwatch_next_instance_id() -> Int64 {
  stopwatch_instance_counter.val = stopwatch_instance_counter.val + 1L
  stopwatch_instance_counter.val
}

///|
fn stopwatch_current_tick_token(model : StopwatchModel) -> StopwatchTickToken {
  { instance_id: model.instance_id, generation: model.tick_generation }
}

///|
fn stopwatch_next_tick_generation(model : StopwatchModel) -> Int64 {
  model.tick_generation + 1L
}

///|
fn stopwatch_tick_task(token : StopwatchTickToken) -> () -> StopwatchMsg {
  fn() { Tick(token) }
}

///|
fn stopwatch_next_tick_schedule(
  interval_ms : Int,
  token : StopwatchTickToken,
) -> StopwatchScheduledTick {
  { interval_ms: interval_ms.max(1), task: stopwatch_tick_task(token) }
}

///|
fn stopwatch_next_tick_cmd(
  interval_ms : Int,
  token : StopwatchTickToken,
) -> @pippa.Cmd[StopwatchMsg] {
  let schedule = stopwatch_next_tick_schedule(interval_ms, token)
  @pippa.Cmd::after(schedule.interval_ms, schedule.task)
}

///|
fn stopwatch_tick_is_current(
  model : StopwatchModel,
  token : StopwatchTickToken,
) -> Bool {
  token == stopwatch_current_tick_token(model)
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
      let instance_id = stopwatch_next_instance_id()
      @pippa.UpdateResult::new(
        model={
          elapsed_ms: 0,
          interval_ms: safe_interval,
          running: false,
          instance_id,
          tick_generation: 0,
        },
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model, msg) {
      match msg {
        Start =>
          if model.running {
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            let tick_generation = stopwatch_next_tick_generation(model)
            let model = { ..model, running: true, tick_generation }
            @pippa.UpdateResult::new(
              model~,
              cmd=stopwatch_next_tick_cmd(
                model.interval_ms,
                stopwatch_current_tick_token(model),
              ),
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
        Tick(token) =>
          if !stopwatch_tick_is_current(model, token) || !model.running {
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            let next_generation = stopwatch_next_tick_generation(model)
            let model = {
              ..model,
              elapsed_ms: model.elapsed_ms + model.interval_ms,
              tick_generation: next_generation,
            }
            @pippa.UpdateResult::new(
              model~,
              cmd=stopwatch_next_tick_cmd(
                model.interval_ms,
                stopwatch_current_tick_token(model),
              ),
            )
          }
      }
    },
    view: fn(model) { stopwatch_format(model.elapsed_ms) },
  }
}
