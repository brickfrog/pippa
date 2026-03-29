///|
/// A progress bar component for the Pippa TUI framework.
///
/// Renders a filled/empty bar with an optional label and percentage.

///|
/// The model for a progress bar component.
pub(all) struct ProgressBarModel {
  /// Current progress, clamped to [0.0, 100.0].
  percent : Double
  /// Total width of the bar in characters.
  width : Int
  /// Optional label shown before the bar.
  label : String
}

///|
/// Messages handled by the progress bar component.
pub(all) enum ProgressBarMsg {
  /// Set a new percentage value (clamped to 0..100).
  SetPercent(Double)
  /// Update the label text.
  SetLabel(String)
}

///|
/// Clamp a Double to [0.0, 100.0].
fn clamp_percent(p : Double) -> Double {
  if p < 0.0 {
    0.0
  } else if p > 100.0 {
    100.0
  } else {
    p
  }
}

///|
/// Create a progress bar component with the given default width and label.
pub fn progress_bar(
  width? : Int = 40,
  label? : String = "",
) -> Component[ProgressBarModel, ProgressBarMsg] {
  {
    init: fn() {
      let model : ProgressBarModel = { percent: 0.0, width, label }
      @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
    },
    update: fn(model, msg) {
      let next = match msg {
        SetPercent(p) => { ..model, percent: clamp_percent(p) }
        SetLabel(s) => { ..model, label: s }
      }
      @pippa.UpdateResult::new(model=next, cmd=@pippa.Cmd::none())
    },
    view: fn(model) {
      let filled = (model.percent / 100.0 * model.width.to_double()).to_int()
      let empty = model.width - filled
      let prefix = if model.label != "" { model.label + " " } else { "" }
      prefix +
      "[" +
      @pippa.fg_color(2) +
      String::make(filled, '█') +
      @pippa.reset() +
      String::make(empty, '░') +
      "] " +
      model.percent.to_int().to_string() +
      "%"
    },
  }
}
