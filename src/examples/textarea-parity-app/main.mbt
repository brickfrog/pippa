///|
fn main {
  let program = @pippa.Program::new(
    init=@textarea_parity.textarea_parity_init,
    update=@textarea_parity.textarea_parity_update,
    view=@textarea_parity.textarea_parity_view,
    sub=@textarea_parity.textarea_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  ignore(@pippa.Program::run(program))
}
