///|
/// Timer component — counts down over time.

///|
pub(all) struct TimerModel {
  duration_ms : Int
  remaining_ms : Int
  interval_ms : Int
  running : Bool
  finished : Bool
  instance_id : Int
  tick_generation : Int
} derive(Debug, Eq)

///|
pub(all) enum TimerMsg {
  Start
  Pause
  Reset
  Tick(Int, Int)
} derive(Debug, Eq)

///|
let timer_instance_counter : Ref[Int] = Ref(0)

///|
fn timer_clamp_non_negative(n : Int) -> Int {
  n.max(0)
}

///|
fn timer_next_instance_id() -> Int {
  timer_instance_counter.val = timer_instance_counter.val + 1
  timer_instance_counter.val
}

///|
fn timer_next_tick_cmd(
  interval_ms : Int,
  instance_id : Int,
  tick_generation : Int,
) -> @pippa.Cmd[TimerMsg] {
  @pippa.Cmd::after(interval_ms.max(1), fn() {
    Tick(instance_id, tick_generation)
  })
}

///|
fn timer_tick_is_current(
  model : TimerModel,
  instance_id : Int,
  tick_generation : Int,
) -> Bool {
  instance_id == model.instance_id && tick_generation == model.tick_generation
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
      let instance_id = timer_next_instance_id()
      @pippa.UpdateResult::new(
        model={
          duration_ms: safe_duration,
          remaining_ms: safe_duration,
          interval_ms: safe_interval,
          running: false,
          finished: safe_duration == 0,
          instance_id,
          tick_generation: 0,
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
            let tick_generation = model.tick_generation + 1
            @pippa.UpdateResult::new(
              model={ ..model, running: true, tick_generation },
              cmd=timer_next_tick_cmd(
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
            model={
              ..model,
              remaining_ms: model.duration_ms,
              running: false,
              finished: model.duration_ms == 0,
            },
            cmd=@pippa.Cmd::none(),
          )
        Tick(instance_id, tick_generation) =>
          if !timer_tick_is_current(model, instance_id, tick_generation) ||
            !model.running ||
            model.finished {
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            let remaining = (model.remaining_ms - model.interval_ms).max(0)
            let finished = remaining == 0
            let next_generation = if finished {
              model.tick_generation
            } else {
              model.tick_generation + 1
            }
            @pippa.UpdateResult::new(
              model={
                ..model,
                remaining_ms: remaining,
                running: !finished,
                finished,
                tick_generation: next_generation,
              },
              cmd=if finished {
                @pippa.Cmd::none()
              } else {
                timer_next_tick_cmd(
                  model.interval_ms,
                  model.instance_id,
                  next_generation,
                )
              },
            )
          }
      }
    },
    view: fn(model) { timer_format(model.remaining_ms) },
  }
}
