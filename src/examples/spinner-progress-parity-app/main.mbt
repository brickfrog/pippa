///|
fn main {
  let program = @pippa.Program::new(
    init=@spinner_progress_parity.spinner_progress_parity_init,
    update=@spinner_progress_parity.spinner_progress_parity_update,
    view=@spinner_progress_parity.spinner_progress_parity_view,
    sub=@spinner_progress_parity.spinner_progress_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  if !@replay.maybe_run_replay(program) {
    ignore(@pippa.Program::run(program))
  }
}
