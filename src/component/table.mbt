///|
pub(all) struct Column {
  header : String
  width : Int
} derive(Show)

///|
pub(all) struct TableModel {
  columns : Array[Column]
  rows : Array[Array[String]]
  cursor : Int
  selected : Int
} derive(Show)

///|
pub(all) enum TableMsg {
  CursorUp
  CursorDown
  Select
  SetRows(Array[Array[String]])
} derive(Show)

///|
pub fn table(columns~ : Array[Column]) -> Component[TableModel, TableMsg] {
  Component::{
    init: fn() {
      @pippa.UpdateResult::new(
        model={ columns, rows: [], cursor: 0, selected: -1 },
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model, msg) {
      match msg {
        CursorUp =>
          if model.rows.length() == 0 {
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            let mut cursor = model.cursor - 1
            if cursor < 0 {
              cursor = 0
            }
            @pippa.UpdateResult::new(
              model={ ..model, cursor, },
              cmd=@pippa.Cmd::none(),
            )
          }
        CursorDown =>
          if model.rows.length() == 0 {
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            let mut cursor = model.cursor + 1
            if cursor >= model.rows.length() {
              cursor = model.rows.length() - 1
            }
            @pippa.UpdateResult::new(
              model={ ..model, cursor, },
              cmd=@pippa.Cmd::none(),
            )
          }
        Select =>
          if model.rows.length() == 0 {
            @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
          } else {
            @pippa.UpdateResult::new(
              model={ ..model, selected: model.cursor },
              cmd=@pippa.Cmd::none(),
            )
          }
        SetRows(rows) =>
          @pippa.UpdateResult::new(
            model={ ..model, rows, cursor: 0, selected: -1 },
            cmd=@pippa.Cmd::none(),
          )
      }
    },
    view: fn(model) {
      let buf = StringBuilder::new()

      // Header row
      for i, col in model.columns {
        let w = if col.width < 0 { 0 } else { col.width }
        let cell = @pippa.truncate(col.header, w)
        buf.write_string(@pippa.pad_right(cell, w))
        if i < model.columns.length() - 1 {
          buf.write_string(" │ ")
        }
      }
      buf.write_char('\n')

      // Separator
      let mut total_width = 0
      for i, col in model.columns {
        let cw = col.width
        let w = if cw < 0 { 0 } else { cw }
        total_width = total_width + w
        if i < model.columns.length() - 1 {
          total_width = total_width + 3 // " │ "
        }
      }
      buf.write_string(String::make(total_width, '─'))
      buf.write_char('\n')

      // Data rows
      if model.rows.length() == 0 {
        buf.write_string("(no data)\n")
      } else {
        for r, row in model.rows {
          let is_cursor = r == model.cursor
          let is_selected = r == model.selected

          if is_cursor {
            buf.write_string(@pippa.bold())
          }
          if is_selected {
            buf.write_string(@pippa.underline())
          }

          for c, col in model.columns {
            let w = if col.width < 0 { 0 } else { col.width }
            let cell_text = if c < row.length() { row[c] } else { "" }
            let cell = @pippa.truncate(cell_text, w)
            buf.write_string(@pippa.pad_right(cell, w))
            if c < model.columns.length() - 1 {
              buf.write_string(" │ ")
            }
          }

          if is_cursor || is_selected {
            buf.write_string(@pippa.reset())
          }
          buf.write_char('\n')
        }
      }

      buf.to_string()
    },
  }
}
