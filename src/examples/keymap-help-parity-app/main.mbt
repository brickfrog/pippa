///|
fn main {
  let program = @pippa.Program::new(
    init=@keymap_help_parity.keymap_help_parity_init,
    update=@keymap_help_parity.keymap_help_parity_update,
    view=@keymap_help_parity.keymap_help_parity_view,
    sub=@keymap_help_parity.keymap_help_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  if !@replay.maybe_run_replay(program) {
    ignore(@pippa.Program::run(program))
  }
}
