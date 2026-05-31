///|
fn main {
  let program = @pippa.Program::new(
    init=@list_parity.list_parity_init,
    update=@list_parity.list_parity_update,
    view=@list_parity.list_parity_view,
    sub=@list_parity.list_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  ignore(@pippa.Program::run(program))
}
