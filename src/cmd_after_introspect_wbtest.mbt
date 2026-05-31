///|
fn[Msg] cmd_after_wbtest_execute(cmd : Cmd[Msg]) -> (Int, Msg) raise {
  assert_eq(cmd.actions.length(), 1)
  match cmd.actions[0] {
    After(interval_ms, task) => (interval_ms, task())
    _ => fail("expected a single Cmd::after action")
  }
}

///|
fn timer_wbtest_tick(model : @component.TimerModel) -> @component.TimerMsg {
  @component.TimerMsg::Tick({
    instance_id: model.instance_id,
    generation: model.tick_generation,
  })
}

///|
fn stopwatch_wbtest_tick(
  model : @component.StopwatchModel,
) -> @component.StopwatchMsg {
  @component.StopwatchMsg::Tick({
    instance_id: model.instance_id,
    generation: model.tick_generation,
  })
}

///|
test "timer scheduled tick command executes with current identity" {
  let c = @component.timer(duration_ms=300, interval_ms=100)
  let started = (c.update)((c.init)().model, @component.TimerMsg::Start)
  let (start_interval, start_msg) = cmd_after_wbtest_execute(started.cmd)
  assert_eq(start_interval, 100)
  @test.assert_eq(start_msg, timer_wbtest_tick(started.model))

  let ticked = (c.update)(started.model, timer_wbtest_tick(started.model))
  let (next_interval, next_msg) = cmd_after_wbtest_execute(ticked.cmd)
  assert_eq(next_interval, 100)
  @test.assert_eq(next_msg, timer_wbtest_tick(ticked.model))
}

///|
test "stopwatch scheduled tick command executes with current identity" {
  let c = @component.stopwatch(interval_ms=100)
  let started = (c.update)((c.init)().model, @component.StopwatchMsg::Start)
  let (start_interval, start_msg) = cmd_after_wbtest_execute(started.cmd)
  assert_eq(start_interval, 100)
  @test.assert_eq(start_msg, stopwatch_wbtest_tick(started.model))

  let ticked = (c.update)(started.model, stopwatch_wbtest_tick(started.model))
  let (next_interval, next_msg) = cmd_after_wbtest_execute(ticked.cmd)
  assert_eq(next_interval, 100)
  @test.assert_eq(next_msg, stopwatch_wbtest_tick(ticked.model))
}
