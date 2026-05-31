///|
/// Bubble Tea table parity fixture: a focused, viewport-backed table with
/// paging and row selection.

///|
pub(all) struct Model {
  table : @component.TableModel
  quitting : Bool
} derive(Debug)

///|
pub(all) enum Msg {
  TableMsg(@component.TableMsg)
  Quit
} derive(Debug)

///|
let table_parity_grid : @component.Component[
  @component.TableModel,
  @component.TableMsg,
] = @component.table(
  columns=[{ header: "ID", width: 2 }, { header: "Name", width: 5 }],
  height=3,
  focused=true,
)

///|
fn table_parity_rows() -> Array[Array[String]] {
  [
    ["A", "alpha"],
    ["B", "bravo"],
    ["C", "charlie"],
    ["D", "delta"],
    ["E", "echo"],
    ["F", "foxtrot"],
  ]
}

///|
pub fn table_parity_init() -> @pippa.UpdateResult[Model, Msg] {
  let table0 = (table_parity_grid.init)().model
  let table = (table_parity_grid.update)(
      table0,
      @component.SetRows(table_parity_rows()),
    ).model
  @pippa.UpdateResult::new(
    model={ table, quitting: false },
    cmd=@pippa.Cmd::none(),
  )
}

///|
pub fn table_parity_update(
  model : Model,
  msg : Msg,
) -> @pippa.UpdateResult[Model, Msg] {
  match msg {
    TableMsg(table_msg) =>
      @pippa.UpdateResult::new(
        model={
          ..model,
          table: (table_parity_grid.update)(model.table, table_msg).model,
        },
        cmd=@pippa.Cmd::none(),
      )
    Quit =>
      @pippa.UpdateResult::new(
        model={ ..model, quitting: true },
        cmd=@pippa.Cmd::none(),
      )
  }
}

///|
pub fn table_parity_sub(event : @pippa.InputEvent) -> Msg? {
  match @component.table_msg_from_input_event(event) {
    Some(msg) => Some(TableMsg(msg))
    None =>
      match event {
        @pippa.Key(@pippa.Char('q'))
        | @pippa.Key(@pippa.Modified("ctrl", "c")) => Some(Quit)
        _ => None
      }
  }
}

///|
pub fn table_parity_view(model : Model) -> String {
  if model.quitting {
    return "Goodbye\n"
  }
  "Table Parity\n" + (table_parity_grid.view)(model.table)
}

///|
pub fn table_parity_run_script(events : Array[@pippa.InputEvent]) -> Model {
  let mut model = table_parity_init().model
  for event in events {
    match table_parity_sub(event) {
      Some(msg) => model = table_parity_update(model, msg).model
      None => ()
    }
  }
  model
}

///|
fn main {
  let program = @pippa.Program::new(
    init=table_parity_init,
    update=table_parity_update,
    view=table_parity_view,
    sub=table_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  ignore(@pippa.Program::run(program))
}
