///|
/// SelectList component — a scrollable list with keyboard navigation and item
/// selection.

///|
/// Model for the SelectList component.
///
/// - `items`: the list of strings to display
/// - `cursor`: index of the currently highlighted item
/// - `selected`: index of the confirmed selection, or -1 if none
pub(all) struct SelectListModel {
  items : Array[String]
  cursor : Int
  selected : Int
} derive(Debug)

///|
/// Messages handled by the SelectList component.
pub(all) enum SelectListMsg {
  /// Move the cursor up by one item.
  CursorUp
  /// Move the cursor down by one item.
  CursorDown
  /// Confirm the current cursor position as the selection.
  Select
  /// Replace the item list entirely.
  SetItems(Array[String])
} derive(Debug)

///|
/// Construct a SelectList `Component`.
pub fn select_list(
  items? : Array[String] = [],
) -> Component[SelectListModel, SelectListMsg] {
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model={ items, cursor: 0, selected: -1 },
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model, msg) {
      match msg {
        CursorUp => {
          let next = if model.cursor - 1 < 0 { 0 } else { model.cursor - 1 }
          @pippa.UpdateResult::new(
            model={ ..model, cursor: next },
            cmd=@pippa.Cmd::none(),
          )
        }
        CursorDown => {
          let len = model.items.length()
          let next = if len == 0 || model.cursor + 1 >= len {
            model.cursor
          } else {
            model.cursor + 1
          }
          @pippa.UpdateResult::new(
            model={ ..model, cursor: next },
            cmd=@pippa.Cmd::none(),
          )
        }
        Select => {
          let selected = if model.items.length() == 0 {
            -1
          } else {
            model.cursor
          }
          @pippa.UpdateResult::new(
            model={ ..model, selected, },
            cmd=@pippa.Cmd::none(),
          )
        }
        SetItems(new_items) =>
          @pippa.UpdateResult::new(
            model={ items: new_items, cursor: 0, selected: -1 },
            cmd=@pippa.Cmd::none(),
          )
      }
    },
    view: fn(model) {
      let lines : Array[String] = []
      for i, item in model.items {
        let is_cursor = i == model.cursor
        let is_selected = model.selected == i && model.selected == model.cursor
        let prefix = if is_cursor {
          @pippa.bold() + "> " + @pippa.reset()
        } else {
          "  "
        }
        let decoration = if is_selected { @pippa.underline() } else { "" }
        let suffix = if is_selected { @pippa.reset() } else { "" }
        lines.push(prefix + decoration + item + suffix)
      }
      lines.join("\n")
    },
  }
}
