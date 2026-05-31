///|
fn main {
  let program = @pippa.Program::new(
    init=@filepicker_parity.filepicker_parity_init,
    update=@filepicker_parity.filepicker_parity_update,
    view=@filepicker_parity.filepicker_parity_view,
    sub=@filepicker_parity.filepicker_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  ignore(@pippa.Program::run(program))
}
