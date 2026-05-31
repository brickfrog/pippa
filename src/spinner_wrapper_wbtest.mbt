///|
fn spinner_wrapper_wbtest_tick(
  model : @component.SpinnerModel,
) -> @component.SpinnerMsg {
  @component.SpinnerMsg::TimedTick({
    instance_id: model.instance_id,
    generation: model.tick_generation,
  })
}

///|
test "spinner scheduled tick command executes with current identity" {
  let c = @component.spinner(interval_ms=37)
  let started = (c.update)((c.init)().model, @component.SpinnerMsg::Start)
  let (start_interval, start_msg) = cmd_after_wbtest_execute(started.cmd)
  assert_eq(start_interval, 37)
  @test.assert_eq(start_msg, spinner_wrapper_wbtest_tick(started.model))

  let ticked = (c.update)(
    started.model,
    spinner_wrapper_wbtest_tick(started.model),
  )
  let (next_interval, next_msg) = cmd_after_wbtest_execute(ticked.cmd)
  assert_eq(next_interval, 37)
  @test.assert_eq(next_msg, spinner_wrapper_wbtest_tick(ticked.model))
}
