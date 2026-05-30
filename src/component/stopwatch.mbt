///|
/// Stopwatch component — counts up while running.

///|
pub(all) struct StopwatchModel {
  elapsed_ms : Int
  interval_ms : Int
  running : Bool
  instance_id : Int
  tick_generation : Int
} derive(Debug, Eq)

///|
pub(all) enum StopwatchMsg {
  Start
  Pause
  Reset
  Tick(Int, Int)
} derive(Debug, Eq)

///|
let stopwatch_instance_counter : Ref[Int] = Ref(0)

///|
fn stopwatch_next_instance_id() -> Int {
  stopwatch_instance_counter.val = stopwatch_instance_counter.val + 1
  stopwatch_instance_counter.val
}

///|
fn stopwatch_next_tick_cmd(
  interval_ms : Int,
  instance_id : Int,
  tick_generation : Int,
) -> @pippa.Cmd[StopwatchMsg] {
  @pippa.Cmd::after(interval_ms.max(1), fn() {
    Tick(instance_id, tick_generation)
  })
}

///|
fn stopwatch_tick_is_current(
  model : StopwatchModel,
  instance_id : Int,
  tick_generation : Int,
) -> Bool {
  instance_id == model.instance_id && tick_generation == model.tick_generation
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
            let tick_generation = model.tick_generation + 1
            @pippa.UpdateResult::new(
              model={ ..model, running: true, tick_generation },
              cmd=stopwatch_next_tick_cmd(
                model.interval_ms,
                model.instance_id,
                tick_generation,
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
        Tick(instance_id, tick_generation) =>
          if !stopwatch_tick_is_current(model, instance_id, tick_generation) ||
            !model.running {
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            let next_generation = model.tick_generation + 1
            @pippa.UpdateResult::new(
              model={
                ..model,
                elapsed_ms: model.elapsed_ms + model.interval_ms,
                tick_generation: next_generation,
              },
              cmd=stopwatch_next_tick_cmd(
                model.interval_ms,
                model.instance_id,
                next_generation,
              ),
            )
          }
      }
    },
    view: fn(model) { stopwatch_format(model.elapsed_ms) },
  }
}
