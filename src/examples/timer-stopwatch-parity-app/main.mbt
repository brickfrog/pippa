///|
fn main {
  let program = @pippa.Program::new(
    init=@timer_stopwatch_parity.timer_stopwatch_parity_init,
    update=@timer_stopwatch_parity.timer_stopwatch_parity_update,
    view=@timer_stopwatch_parity.timer_stopwatch_parity_view,
    sub=@timer_stopwatch_parity.timer_stopwatch_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  if !@replay.maybe_run_replay(program) {
    ignore(@pippa.Program::run(program))
  }
}
