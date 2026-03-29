///|
/// Spinner component — cycles through animation frames to indicate activity.

///|
/// Model for the Spinner component.
///
/// - `frames`: the sequence of strings to cycle through
/// - `current`: index of the frame currently displayed
/// - `label`: text shown after the frame
pub(all) struct SpinnerModel {
  frames : Array[String]
  current : Int
  label : String
} derive(Show)

///|
/// Messages handled by the Spinner component.
pub(all) enum SpinnerMsg {
  /// Advance to the next animation frame.
  Tick
} derive(Show)

///|
/// Construct a Spinner `Component`.
///
/// ```moonbit nocheck
/// let s = spinner(label="Loading...")
/// let { model, .. } = (s.init)()
/// ```
pub fn spinner(
  label? : String = "Loading...",
) -> Component[SpinnerModel, SpinnerMsg] {
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model={
          frames: [
            "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏",
          ],
          current: 0,
          label,
        },
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model, msg) {
      match msg {
        Tick => {
          let next = (model.current + 1) % model.frames.length()
          @pippa.UpdateResult::new(
            model={ ..model, current: next },
            cmd=@pippa.Cmd::none(),
          )
        }
      }
    },
    view: fn(model) {
      let frame = model.frames[model.current]
      "\{frame} \{model.label}"
    },
  }
}
