///|
fn main {
  let program = @pippa.Program::new(
    init=@text_input_parity.text_input_parity_init,
    update=@text_input_parity.text_input_parity_update,
    view=@text_input_parity.text_input_parity_view,
    sub=@text_input_parity.text_input_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  ignore(@pippa.Program::run(program))
}
