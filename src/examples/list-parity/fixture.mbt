///|
/// Bubble Tea list parity fixture: fuzzy filtering plus delegate rendering.

///|
pub(all) struct Model {
  items : @component.ListModel[String]
  quitting : Bool
} derive(Debug)

///|
pub(all) enum Msg {
  ListMsg(@component.ListMsg[String])
  Quit
} derive(Debug)

///|
fn list_parity_delegate() -> @component.ListDelegate[String] {
  {
    render: fn(ctx) {
      let cursor = if ctx.cursor { "cursor" } else { "idle" }
      let matches = list_parity_join_ints(ctx.matched_indexes)
      "\{ctx.index}:\{ctx.item.title}:\{cursor}:\{matches}"
    },
    update: None,
  }
}

///|
fn list_parity_join_ints(values : Array[Int]) -> String {
  let parts : Array[String] = []
  for value in values {
    parts.push(value.to_string())
  }
  parts.join(",")
}

///|
fn list_parity_items() -> Array[@component.ListItem[String]] {
  [
    @component.ListItem::new(
      id="fuzzy",
      filter_value="fuzzy",
      title="Fuzzy Finder",
      description=Some("filter with slash"),
      payload=Some("fuzzy"),
    ),
    @component.ListItem::new(
      id="viewport",
      filter_value="viewport",
      title="Viewport Pager",
      description=Some("scrolling content"),
      payload=Some("viewport"),
    ),
    @component.ListItem::new(
      id="table",
      filter_value="table",
      title="Table Rows",
      description=Some("row selection"),
      payload=Some("table"),
    ),
  ]
}

///|
let list_parity_component : @component.Component[
  @component.ListModel[String],
  @component.ListMsg[String],
] = @component.list(
  items=list_parity_items(),
  page_size=3,
  title="Parity Scenarios",
  delegate=list_parity_delegate(),
)

///|
pub fn list_parity_init() -> @pippa.UpdateResult[Model, Msg] {
  @pippa.UpdateResult::new(
    model={ items: (list_parity_component.init)().model, quitting: false },
    cmd=@pippa.Cmd::none(),
  )
}

///|
pub fn list_parity_update(
  model : Model,
  msg : Msg,
) -> @pippa.UpdateResult[Model, Msg] {
  match msg {
    ListMsg(list_msg) => {
      let result = (list_parity_component.update)(model.items, list_msg)
      @pippa.UpdateResult::new(
        model={ ..model, items: result.model },
        cmd=@pippa.Cmd::map(fn(m) { ListMsg(m) }, result.cmd),
      )
    }
    Quit =>
      @pippa.UpdateResult::new(
        model={ ..model, quitting: true },
        cmd=@pippa.Cmd::none(),
      )
  }
}

///|
pub fn list_parity_sub(event : @pippa.InputEvent) -> Msg? {
  match event {
    @pippa.Key(@pippa.Char('q')) | @pippa.Key(@pippa.Modified("ctrl", "c")) =>
      Some(Quit)
    _ => Some(ListMsg(@component.HandleInput(event)))
  }
}

///|
pub fn list_parity_view(model : Model) -> String {
  if model.quitting {
    return "Goodbye\n"
  }
  (list_parity_component.view)(model.items)
}

///|
pub fn list_parity_run_script(events : Array[@pippa.InputEvent]) -> Model {
  let mut model = list_parity_init().model
  for event in events {
    match list_parity_sub(event) {
      Some(msg) => model = list_parity_update(model, msg).model
      None => ()
    }
  }
  model
}
