///|
fn main {
  let program = @pippa.Program::new(
    init=@terminal_state_parity.terminal_state_parity_init,
    update=@terminal_state_parity.terminal_state_parity_update,
    view=@terminal_state_parity.terminal_state_parity_view,
    sub=@terminal_state_parity.terminal_state_parity_sub,
    should_quit=fn(model) { model.quitting },
  ).with_structured_view(
    @terminal_state_parity.terminal_state_parity_structured_view,
  )
  if !@replay.maybe_run_replay(program) {
    ignore(@pippa.Program::run(program))
  }
}
