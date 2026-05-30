///|
/// Timer component — counts down over time.

///|
pub(all) struct TimerTickToken {
  instance_id : Int64
  generation : Int64
} derive(Debug, Eq)

///|
pub(all) struct TimerModel {
  duration_ms : Int
  remaining_ms : Int
  interval_ms : Int
  running : Bool
  finished : Bool
  instance_id : Int64
  tick_generation : Int64
} derive(Debug, Eq)

///|
pub(all) enum TimerMsg {
  Start
  Pause
  Reset
  Tick(TimerTickToken)
} derive(Debug, Eq)

///|
priv struct TimerScheduledTick {
  interval_ms : Int
  task : () -> TimerMsg
}

///|
/// Timer identity counters are monotonic Int64 values. Their range is far
/// beyond realistic component lifetimes; exhausting it would be a token-collision
/// risk for a process that has already run billions of billions of ticks.
let timer_instance_counter : Ref[Int64] = Ref(0L)

///|
fn timer_clamp_non_negative(n : Int) -> Int {
  n.max(0)
}

///|
fn timer_next_instance_id() -> Int64 {
  timer_instance_counter.val = timer_instance_counter.val + 1L
  timer_instance_counter.val
}

///|
fn timer_current_tick_token(model : TimerModel) -> TimerTickToken {
  { instance_id: model.instance_id, generation: model.tick_generation }
}

///|
fn timer_next_tick_generation(model : TimerModel) -> Int64 {
  model.tick_generation + 1L
}

///|
fn timer_tick_task(token : TimerTickToken) -> () -> TimerMsg {
  fn() { Tick(token) }
}

///|
fn timer_next_tick_schedule(
  interval_ms : Int,
  token : TimerTickToken,
) -> TimerScheduledTick {
  { interval_ms: interval_ms.max(1), task: timer_tick_task(token) }
}

///|
fn timer_next_tick_cmd(
  interval_ms : Int,
  token : TimerTickToken,
) -> @pippa.Cmd[TimerMsg] {
  let schedule = timer_next_tick_schedule(interval_ms, token)
  @pippa.Cmd::after(schedule.interval_ms, schedule.task)
}

///|
fn timer_tick_is_current(model : TimerModel, token : TimerTickToken) -> Bool {
  token == timer_current_tick_token(model)
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
            let tick_generation = timer_next_tick_generation(model)
            let model = { ..model, running: true, tick_generation }
            @pippa.UpdateResult::new(
              model~,
              cmd=timer_next_tick_cmd(
                model.interval_ms,
                timer_current_tick_token(model),
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
        Tick(token) =>
          if !timer_tick_is_current(model, token) ||
            !model.running ||
            model.finished {
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            let remaining = (model.remaining_ms - model.interval_ms).max(0)
            let finished = remaining == 0
            let next_generation = if finished {
              model.tick_generation
            } else {
              timer_next_tick_generation(model)
            }
            let model = {
              ..model,
              remaining_ms: remaining,
              running: !finished,
              finished,
              tick_generation: next_generation,
            }
            @pippa.UpdateResult::new(
              model~,
              cmd=if finished {
                @pippa.Cmd::none()
              } else {
                timer_next_tick_cmd(
                  model.interval_ms,
                  timer_current_tick_token(model),
                )
              },
            )
          }
      }
    },
    view: fn(model) { timer_format(model.remaining_ms) },
  }
}
