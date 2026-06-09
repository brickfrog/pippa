///|
fn timer_stopwatch_parity_timer_tick_msg(model : Model) -> Msg {
  Msg::TimerMsg(
    @component.TimerMsg::Tick({
      instance_id: model.timer.instance_id,
      generation: model.timer.tick_generation,
    }),
  )
}

///|
fn timer_stopwatch_parity_stopwatch_tick_msg(model : Model) -> Msg {
  Msg::StopwatchMsg(
    @component.StopwatchMsg::Tick({
      instance_id: model.stopwatch.instance_id,
      generation: model.stopwatch.tick_generation,
    }),
  )
}

///|
fn timer_stopwatch_parity_snapshot_script(
  model : Model,
) -> Array[@replay.ReplayStep[Msg]] {
  let started = timer_stopwatch_parity_update(model, StartBoth).model
  let timer_tick_1 = timer_stopwatch_parity_timer_tick_msg(started)
  let timer_ticked_1 = timer_stopwatch_parity_update(started, timer_tick_1).model
  let stopwatch_tick_1 = timer_stopwatch_parity_stopwatch_tick_msg(
    timer_ticked_1,
  )
  let ticked_1 = timer_stopwatch_parity_update(timer_ticked_1, stopwatch_tick_1).model
  let timer_tick_2 = timer_stopwatch_parity_timer_tick_msg(ticked_1)
  let timer_ticked_2 = timer_stopwatch_parity_update(ticked_1, timer_tick_2).model
  let stopwatch_tick_2 = timer_stopwatch_parity_stopwatch_tick_msg(
    timer_ticked_2,
  )
  [
    @replay.ReplayStep::Input(@pippa.Key(@pippa.Char('s'))),
    @replay.ReplayStep::Message(timer_tick_1),
    @replay.ReplayStep::Message(stopwatch_tick_1),
    @replay.ReplayStep::Message(timer_tick_2),
    @replay.ReplayStep::Message(stopwatch_tick_2),
    @replay.ReplayStep::Input(@pippa.Key(@pippa.Char('p'))),
    @replay.ReplayStep::Input(@pippa.Key(@pippa.Char('r'))),
  ]
}

///|
test "timer stopwatch parity replay frames full ansi" {
  let initial = timer_stopwatch_parity_init()
  let frames = @replay.replay_frames(
    init=fn() { initial },
    update=timer_stopwatch_parity_update,
    view=timer_stopwatch_parity_view,
    sub=timer_stopwatch_parity_sub,
    script=timer_stopwatch_parity_snapshot_script(initial.model),
  )

  @debug.debug_inspect(
    frames,
    content=(
      #|[
      #|  "Timer: 0:00.3\nStopwatch: 0:00.0\n",
      #|  "Timer: 0:00.3\nStopwatch: 0:00.0\n",
      #|  "Timer: 0:00.2\nStopwatch: 0:00.0\n",
      #|  "Timer: 0:00.2\nStopwatch: 0:00.1\n",
      #|  "Timer: 0:00.1\nStopwatch: 0:00.1\n",
      #|  "Timer: 0:00.1\nStopwatch: 0:00.2\n",
      #|  "Timer: 0:00.1\nStopwatch: 0:00.2\n",
      #|  "Timer: 0:00.3\nStopwatch: 0:00.0\n",
      #|]
    ),
  )
}
