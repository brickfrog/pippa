///|
/// Bubble Tea spinner/progress parity fixture: one activity tick advances the
/// spinner frame and spring progress animation together.

///|
pub(all) struct Model {
  spinner : @component.SpinnerModel
  progress : @component.ProgressBarModel
  quitting : Bool
} derive(Debug)

///|
pub(all) enum Msg {
  SetProgress(Double)
  ActivityTick
  Quit
} derive(Debug)

///|
let spinner_progress_parity_spinner : @component.Component[
  @component.SpinnerModel,
  @component.SpinnerMsg,
] = @component.spinner(label="Syncing")

///|
let spinner_progress_parity_progress : @component.Component[
  @component.ProgressBarModel,
  @component.ProgressBarMsg,
] = @component.progress_bar(width=10, show_percentage=true)

///|
pub fn spinner_progress_parity_init() -> @pippa.UpdateResult[Model, Msg] {
  @pippa.UpdateResult::new(
    model={
      spinner: (spinner_progress_parity_spinner.init)().model,
      progress: (spinner_progress_parity_progress.init)().model,
      quitting: false,
    },
    cmd=@pippa.Cmd::none(),
  )
}

///|
pub fn spinner_progress_parity_update(
  model : Model,
  msg : Msg,
) -> @pippa.UpdateResult[Model, Msg] {
  match msg {
    SetProgress(percent) => {
      let progress = (spinner_progress_parity_progress.update)(
        model.progress,
        @component.SetPercent(percent),
      )
      @pippa.UpdateResult::new(
        model={ ..model, progress: progress.model },
        cmd=@pippa.Cmd::map(fn(_m) { ActivityTick }, progress.cmd),
      )
    }
    ActivityTick => {
      let spinner = (spinner_progress_parity_spinner.update)(
          model.spinner,
          @component.SpinnerMsg::Tick,
        ).model
      let progress = (spinner_progress_parity_progress.update)(
        model.progress,
        @component.ProgressBarMsg::Tick,
      )
      @pippa.UpdateResult::new(
        model={ ..model, spinner, progress: progress.model },
        cmd=@pippa.Cmd::map(fn(_m) { ActivityTick }, progress.cmd),
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
pub fn spinner_progress_parity_sub(event : @pippa.InputEvent) -> Msg? {
  match event {
    @pippa.Key(@pippa.Char('1')) => Some(SetProgress(1.0))
    @pippa.Key(@pippa.Char('5')) => Some(SetProgress(0.5))
    @pippa.Key(@pippa.Char(' ')) => Some(ActivityTick)
    @pippa.Key(@pippa.Char('q')) | @pippa.Key(@pippa.Modified("ctrl", "c")) =>
      Some(Quit)
    _ => None
  }
}

///|
pub fn spinner_progress_parity_view(model : Model) -> String {
  if model.quitting {
    return "Goodbye\n"
  }
  (spinner_progress_parity_spinner.view)(model.spinner) +
  "\n" +
  (spinner_progress_parity_progress.view)(model.progress) +
  "\n"
}

///|
fn main {
  let program = @pippa.Program::new(
    init=spinner_progress_parity_init,
    update=spinner_progress_parity_update,
    view=spinner_progress_parity_view,
    sub=spinner_progress_parity_sub,
    should_quit=fn(model) { model.quitting },
  )
  ignore(@pippa.Program::run(program))
}
