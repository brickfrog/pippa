///|
/// Bubble Tea viewport parity fixture: pager content with vertical scroll,
/// horizontal scroll, and a line-number gutter.

///|
pub(all) struct Model {
  pager : @component.ViewportModel
  quitting : Bool
} derive(Debug)

///|
pub(all) enum Msg {
  PagerMsg(@component.ViewportMsg)
  Quit
} derive(Debug)

///|
let viewport_parity_pager : @component.Component[
  @component.ViewportModel,
  @component.ViewportMsg,
] = @component.viewport(
  width=7,
  height=2,
  horizontal_step=2,
  gutter=Some(fn(ctx) { "\{ctx.logical_line + 1}|" }),
)

///|
fn viewport_parity_content() -> String {
  [
    "alpha-line", "beta-line", "charlie", "delta-line", "echo-line", "foxtrot-line",
  ].join("\n")
}

///|
pub fn viewport_parity_init() -> @pippa.UpdateResult[Model, Msg] {
  let pager0 = (viewport_parity_pager.init)().model
  let pager = (viewport_parity_pager.update)(
      pager0,
      @component.SetContent(viewport_parity_content()),
    ).model
  @pippa.UpdateResult::new(
    model={ pager, quitting: false },
    cmd=@pippa.Cmd::none(),
  )
}

///|
pub fn viewport_parity_update(
  model : Model,
  msg : Msg,
) -> @pippa.UpdateResult[Model, Msg] {
  match msg {
    PagerMsg(pager_msg) =>
      @pippa.UpdateResult::new(
        model={
          ..model,
          pager: (viewport_parity_pager.update)(model.pager, pager_msg).model,
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
pub fn viewport_parity_sub(event : @pippa.InputEvent) -> Msg? {
  match event {
    @pippa.Key(@pippa.Special("up")) => Some(PagerMsg(@component.ScrollUp))
    @pippa.Key(@pippa.Special("down")) => Some(PagerMsg(@component.ScrollDown))
    @pippa.Key(@pippa.Special("left")) => Some(PagerMsg(@component.ScrollLeft))
    @pippa.Key(@pippa.Special("right")) =>
      Some(PagerMsg(@component.ScrollRight))
    @pippa.Key(@pippa.Special("pageup")) => Some(PagerMsg(@component.PageUp))
    @pippa.Key(@pippa.Special("pagedown")) =>
      Some(PagerMsg(@component.PageDown))
    @pippa.Key(@pippa.Char('q')) | @pippa.Key(@pippa.Modified("ctrl", "c")) =>
      Some(Quit)
    _ => None
  }
}

///|
pub fn viewport_parity_snapshot(model : Model) -> String {
  (viewport_parity_pager.view)(model.pager)
}

///|
pub fn viewport_parity_view(model : Model) -> String {
  if model.quitting {
    return "Goodbye\n"
  }
  "Viewport Parity\n" + viewport_parity_snapshot(model) + "\n"
}

///|
pub fn viewport_parity_run_script(events : Array[@pippa.InputEvent]) -> Model {
  let mut model = viewport_parity_init().model
  for event in events {
    match viewport_parity_sub(event) {
      Some(msg) => model = viewport_parity_update(model, msg).model
      None => ()
    }
  }
  model
}
