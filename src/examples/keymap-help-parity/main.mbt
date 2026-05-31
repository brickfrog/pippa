///|
/// Bubble Tea keymap/help parity fixture: a table with an overridden navigation
/// binding and short/full help rendering.

///|
pub(all) struct Model {
  grid : @component.TableModel
  show_full_help : Bool
  quitting : Bool
} derive(Debug)

///|
pub(all) enum Msg {
  GridMsg(@component.TableMsg)
  ToggleHelp
  Quit
} derive(Debug)

///|
fn keymap_help_parity_keymap() -> @component.TableKeymap {
  @component.table_keymap_override(
    @component.default_table_keymap(),
    @component.TableActionCursorDown,
    @pippa.binding(keys=["n"], help_key="n", help="next task"),
  )
}

///|
let keymap_help_parity_grid : @component.Component[
  @component.TableModel,
  @component.TableMsg,
] = @component.table(
  columns=[{ header: "Task", width: 10 }],
  height=2,
  focused=true,
  keymap=keymap_help_parity_keymap(),
)

///|
pub fn keymap_help_parity_init() -> @pippa.UpdateResult[Model, Msg] {
  let grid0 = (keymap_help_parity_grid.init)().model
  let grid = (keymap_help_parity_grid.update)(
      grid0,
      @component.SetRows([["write"], ["review"], ["merge"]]),
    ).model
  @pippa.UpdateResult::new(
    model={ grid, show_full_help: false, quitting: false },
    cmd=@pippa.Cmd::none(),
  )
}

///|
pub fn keymap_help_parity_update(
  model : Model,
  msg : Msg,
) -> @pippa.UpdateResult[Model, Msg] {
  match msg {
    GridMsg(grid_msg) =>
      @pippa.UpdateResult::new(
        model={
          ..model,
          grid: (keymap_help_parity_grid.update)(model.grid, grid_msg).model,
        },
        cmd=@pippa.Cmd::none(),
      )
    ToggleHelp =>
      @pippa.UpdateResult::new(
        model={ ..model, show_full_help: !model.show_full_help },
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
pub fn keymap_help_parity_sub(event : @pippa.InputEvent) -> Msg? {
  match event {
    @pippa.Key(@pippa.Char('?')) => Some(ToggleHelp)
    @pippa.Key(@pippa.Char('q')) | @pippa.Key(@pippa.Modified("ctrl", "c")) =>
      Some(Quit)
    _ =>
      match
        @component.table_msg_from_input_event(
          event,
          keymap=keymap_help_parity_keymap(),
        ) {
        Some(msg) => Some(GridMsg(msg))
        None => None
      }
  }
}

///|
pub fn keymap_help_parity_view(model : Model) -> String {
  if model.quitting {
    return "Goodbye\n"
  }
  (keymap_help_parity_grid.view)(model.grid) +
  @component.table_help_view(
    keymap=keymap_help_parity_keymap(),
    show_full=model.show_full_help,
    width=0,
  ) +
  "\n"
}

///|
fn main {
  let program = @pippa.Program::new(
    init=keymap_help_parity_init,
    update=keymap_help_parity_update,
    view=keymap_help_parity_view,
    sub=keymap_help_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  ignore(@pippa.Program::run(program))
}
