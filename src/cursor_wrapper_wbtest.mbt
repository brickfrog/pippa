///|
fn cursor_wrapper_wbtest_tick(
  model : @component.CursorModel,
) -> @component.CursorMsg {
  @component.CursorMsg::TimedTick({
    instance_id: model.instance_id,
    generation: model.tick_generation,
  })
}

///|
test "cursor scheduled tick command executes with current identity" {
  let c = @component.cursor(interval_ms=37, focused=true)
  let started = (c.init)()
  let (start_interval, start_msg) = cmd_after_wbtest_execute(started.cmd)
  assert_eq(start_interval, started.model.interval_ms)
  @test.assert_eq(start_msg, cursor_wrapper_wbtest_tick(started.model))

  let ticked = (c.update)(started.model, start_msg)
  assert_eq(ticked.model.tick_generation, started.model.tick_generation + 1L)
  let (next_interval, next_msg) = cmd_after_wbtest_execute(ticked.cmd)
  assert_eq(next_interval, ticked.model.interval_ms)
  @test.assert_eq(next_msg, cursor_wrapper_wbtest_tick(ticked.model))
}
