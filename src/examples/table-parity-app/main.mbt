///|
fn main {
  let program = @pippa.Program::new(
    init=@table_parity.table_parity_init,
    update=@table_parity.table_parity_update,
    view=@table_parity.table_parity_view,
    sub=@table_parity.table_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  ignore(@pippa.Program::run(program))
}
