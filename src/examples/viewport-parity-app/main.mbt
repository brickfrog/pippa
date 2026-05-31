///|
fn main {
  let program = @pippa.Program::new(
    init=@viewport_parity.viewport_parity_init,
    update=@viewport_parity.viewport_parity_update,
    view=@viewport_parity.viewport_parity_view,
    sub=@viewport_parity.viewport_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  ignore(@pippa.Program::run(program))
}
