///|
/// Bubble Tea timer/stopwatch parity fixture: two lifecycle components sharing
/// app-level start, tick, pause, and reset messages.

///|
pub(all) struct Model {
  timer : @component.TimerModel
  stopwatch : @component.StopwatchModel
  quitting : Bool
} derive(Debug)

///|
pub(all) enum Msg {
  TimerMsg(@component.TimerMsg)
  StopwatchMsg(@component.StopwatchMsg)
  StartBoth
  PauseBoth
  ResetBoth
  Quit
} derive(Debug)

///|
let timer_stopwatch_parity_timer : @component.Component[
  @component.TimerModel,
  @component.TimerMsg,
] = @component.timer(duration_ms=300, interval_ms=100)

///|
let timer_stopwatch_parity_stopwatch : @component.Component[
  @component.StopwatchModel,
  @component.StopwatchMsg,
] = @component.stopwatch(interval_ms=100)

///|
fn timer_stopwatch_parity_timer_tick(
  model : @component.TimerModel,
) -> @component.TimerMsg {
  @component.TimerMsg::Tick({
    instance_id: model.instance_id,
    generation: model.tick_generation,
  })
}

///|
fn timer_stopwatch_parity_stopwatch_tick(
  model : @component.StopwatchModel,
) -> @component.StopwatchMsg {
  @component.StopwatchMsg::Tick({
    instance_id: model.instance_id,
    generation: model.tick_generation,
  })
}

///|
pub fn timer_stopwatch_parity_init() -> @pippa.UpdateResult[Model, Msg] {
  @pippa.UpdateResult::new(
    model={
      timer: (timer_stopwatch_parity_timer.init)().model,
      stopwatch: (timer_stopwatch_parity_stopwatch.init)().model,
      quitting: false,
    },
    cmd=@pippa.Cmd::none(),
  )
}

///|
pub fn timer_stopwatch_parity_update(
  model : Model,
  msg : Msg,
) -> @pippa.UpdateResult[Model, Msg] {
  match msg {
    TimerMsg(timer_msg) => {
      let result = (timer_stopwatch_parity_timer.update)(model.timer, timer_msg)
      @pippa.UpdateResult::new(
        model={ ..model, timer: result.model },
        cmd=@pippa.Cmd::map(fn(m) { TimerMsg(m) }, result.cmd),
      )
    }
    StopwatchMsg(stopwatch_msg) => {
      let result = (timer_stopwatch_parity_stopwatch.update)(
        model.stopwatch,
        stopwatch_msg,
      )
      @pippa.UpdateResult::new(
        model={ ..model, stopwatch: result.model },
        cmd=@pippa.Cmd::map(fn(m) { StopwatchMsg(m) }, result.cmd),
      )
    }
    StartBoth => {
      let timer = (timer_stopwatch_parity_timer.update)(
        model.timer,
        @component.TimerMsg::Start,
      )
      let stopwatch = (timer_stopwatch_parity_stopwatch.update)(
        model.stopwatch,
        @component.StopwatchMsg::Start,
      )
      @pippa.UpdateResult::new(
        model={ ..model, timer: timer.model, stopwatch: stopwatch.model },
        cmd=@pippa.Cmd::batch([
          @pippa.Cmd::map(fn(m) { TimerMsg(m) }, timer.cmd),
          @pippa.Cmd::map(fn(m) { StopwatchMsg(m) }, stopwatch.cmd),
        ]),
      )
    }
    PauseBoth => {
      let timer = (timer_stopwatch_parity_timer.update)(
          model.timer,
          @component.TimerMsg::Pause,
        ).model
      let stopwatch = (timer_stopwatch_parity_stopwatch.update)(
          model.stopwatch,
          @component.StopwatchMsg::Pause,
        ).model
      @pippa.UpdateResult::new(
        model={ ..model, timer, stopwatch },
        cmd=@pippa.Cmd::none(),
      )
    }
    ResetBoth => {
      let timer = (timer_stopwatch_parity_timer.update)(
          model.timer,
          @component.TimerMsg::Reset,
        ).model
      let stopwatch = (timer_stopwatch_parity_stopwatch.update)(
          model.stopwatch,
          @component.StopwatchMsg::Reset,
        ).model
      @pippa.UpdateResult::new(
        model={ ..model, timer, stopwatch },
        cmd=@pippa.Cmd::none(),
      )
    }
    Quit =>
      @pippa.UpdateResult::new(
        model={ ..model, quitting: true },
        cmd=@pippa.Cmd::none(),
      )
  }
}

///|
pub fn timer_stopwatch_parity_tick_both(model : Model) -> Model {
  let timer_msg = timer_stopwatch_parity_timer_tick(model.timer)
  let stopwatch_msg = timer_stopwatch_parity_stopwatch_tick(model.stopwatch)
  let timer = timer_stopwatch_parity_update(model, TimerMsg(timer_msg)).model
  timer_stopwatch_parity_update(timer, StopwatchMsg(stopwatch_msg)).model
}

///|
pub fn timer_stopwatch_parity_sub(event : @pippa.InputEvent) -> Msg? {
  match event {
    @pippa.Key(@pippa.Char('s')) => Some(StartBoth)
    @pippa.Key(@pippa.Char('p')) => Some(PauseBoth)
    @pippa.Key(@pippa.Char('r')) => Some(ResetBoth)
    @pippa.Key(@pippa.Char('q')) | @pippa.Key(@pippa.Modified("ctrl", "c")) =>
      Some(Quit)
    _ => None
  }
}

///|
pub fn timer_stopwatch_parity_view(model : Model) -> String {
  if model.quitting {
    return "Goodbye\n"
  }
  "Timer: \{(timer_stopwatch_parity_timer.view)(model.timer)}\n" +
  "Stopwatch: \{(timer_stopwatch_parity_stopwatch.view)(model.stopwatch)}\n"
}
