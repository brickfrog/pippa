///|
pub(all) struct Column {
  header : String
  width : Int
} derive(Debug)

///|
pub(all) enum TableAction {
  TableActionCursorUp
  TableActionCursorDown
  TableActionPageUp
  TableActionPageDown
  TableActionHalfPageUp
  TableActionHalfPageDown
  TableActionMoveToTop
  TableActionMoveToBottom
  TableActionSelect
} derive(Debug, Eq)

///|
pub(all) struct TableKeyBinding {
  binding : @pippa.Binding
  action : TableAction
} derive(Debug, Eq)

///|
pub(all) struct TableKeymap {
  bindings : Array[TableKeyBinding]
} derive(Debug, Eq)

///|
pub(all) struct TableModel {
  columns : Array[Column]
  rows : Array[Array[String]]
  cursor : Int
  selected : Int
  width : Int
  height : Int
  focused : Bool
  viewport : ViewportModel
} derive(Debug)

///|
pub(all) enum TableMsg {
  CursorUp
  CursorDown
  PageUp
  PageDown
  HalfPageUp
  HalfPageDown
  MoveToTop
  MoveToBottom
  Select
  SetColumns(Array[Column])
  SetRows(Array[Array[String]])
  SetWidth(Int)
  SetHeight(Int)
  SetCursor(Int)
  Focus
  Blur
  HandleInput(@pippa.InputEvent)
} derive(Debug)

///|
fn table_clamp(value : Int, lo : Int, hi : Int) -> Int {
  if value < lo {
    lo
  } else if value > hi {
    hi
  } else {
    value
  }
}

///|
fn table_safe_dimension(value : Int) -> Int {
  if value > 0 {
    value
  } else {
    0
  }
}

///|
fn table_safe_column_width(column : Column) -> Int {
  if column.width > 0 {
    column.width
  } else {
    0
  }
}

///|
fn table_natural_width(columns : Array[Column]) -> Int {
  let mut width = 0
  for i, column in columns {
    width = width + table_safe_column_width(column)
    if i < columns.length() - 1 {
      width = width + 3
    }
  }
  width
}

///|
fn table_body_line_count(rows : Array[Array[String]]) -> Int {
  if rows.length() == 0 {
    1
  } else {
    rows.length()
  }
}

///|
fn table_effective_width(model : TableModel) -> Int {
  if model.width > 0 {
    model.width
  } else {
    table_natural_width(model.columns)
  }
}

///|
fn table_effective_body_width(model : TableModel) -> Int {
  if model.width > 0 || model.rows.length() > 0 {
    table_effective_width(model)
  } else {
    @internal.display_width("(no data)")
  }
}

///|
fn table_effective_height(model : TableModel) -> Int {
  if model.height > 0 {
    model.height
  } else {
    table_body_line_count(model.rows)
  }
}

///|
fn table_fit_line(line : String, width : Int) -> String {
  component_fit_width(line, width.max(0))
}

///|
fn table_header_line(columns : Array[Column]) -> String {
  let buf = StringBuilder::new()
  for i, col in columns {
    buf.write_string(
      component_fit_width(col.header, table_safe_column_width(col)),
    )
    if i < columns.length() - 1 {
      buf.write_string(" │ ")
    }
  }
  buf.to_string()
}

///|
fn table_separator_line(columns : Array[Column]) -> String {
  String::make(table_natural_width(columns), '─')
}

///|
fn table_row_line(model : TableModel, row_index : Int) -> String {
  let row = model.rows[row_index]
  let is_cursor = model.focused && row_index == model.cursor
  let is_selected = row_index == model.selected
  let buf = StringBuilder::new()
  if is_cursor {
    buf.write_string(@pippa.bold())
  }
  if is_selected {
    buf.write_string(@pippa.underline())
  }
  for c, col in model.columns {
    let cell_text = if c < row.length() { row[c] } else { "" }
    buf.write_string(
      component_fit_width(cell_text, table_safe_column_width(col)),
    )
    if c < model.columns.length() - 1 {
      buf.write_string(" │ ")
    }
  }
  if is_cursor || is_selected {
    buf.write_string(@pippa.reset())
  }
  buf.to_string()
}

///|
fn table_body_content(model : TableModel) -> String {
  if model.rows.length() == 0 {
    "(no data)"
  } else {
    let lines : Array[String] = []
    for row_index, _row in model.rows {
      lines.push(table_row_line(model, row_index))
    }
    lines.join("\n")
  }
}

///|
fn table_cursor_highlights(model : TableModel) -> Array[ViewportHighlight] {
  if model.rows.length() == 0 {
    []
  } else {
    [
      viewport_highlight(
        line=model.cursor,
        start_col=0,
        end_col=table_natural_width(model.columns),
        style=Some(@pippa.style()),
        selected_style=Some(@pippa.style()),
      ),
    ]
  }
}

///|
fn table_sync_viewport(model : TableModel) -> TableModel {
  let width = table_effective_body_width(model)
  let height = table_effective_height(model)
  let content = table_body_content(model)
  let resized = viewport_update(model.viewport, Resize(width, height)).model
  let with_content = viewport_update(resized, SetContent(content)).model
  let with_highlight = viewport_update(
      with_content,
      SetHighlights(table_cursor_highlights(model)),
    ).model
  { ..model, viewport: with_highlight }
}

///|
fn table_normalize(model : TableModel) -> TableModel {
  let row_count = model.rows.length()
  let cursor = if row_count == 0 {
    0
  } else {
    table_clamp(model.cursor, 0, row_count - 1)
  }
  let selected = if model.selected >= 0 && model.selected < row_count {
    model.selected
  } else {
    -1
  }
  table_sync_viewport({
    ..model,
    cursor,
    selected,
    width: table_safe_dimension(model.width),
    height: table_safe_dimension(model.height),
  })
}

///|
fn table_initial_viewport(
  columns : Array[Column],
  rows : Array[Array[String]],
  width : Int,
  height : Int,
) -> ViewportModel {
  let safe_width = table_safe_dimension(width)
  let safe_height = table_safe_dimension(height)
  let viewport_width = if safe_width > 0 {
    safe_width
  } else {
    table_natural_width(columns)
  }
  let viewport_height = if safe_height > 0 {
    safe_height
  } else {
    table_body_line_count(rows)
  }
  (viewport(
    width=viewport_width,
    height=viewport_height,
    fill_height=false,
    mouse_wheel_enabled=false,
  ).init)().model
}

///|
fn table_page_step(model : TableModel) -> Int {
  table_effective_height(model).max(1)
}

///|
fn table_half_page_step(model : TableModel) -> Int {
  (table_page_step(model) / 2).max(1)
}

///|
fn table_move_cursor(model : TableModel, delta : Int) -> TableModel {
  if model.rows.length() == 0 {
    table_normalize(model)
  } else {
    table_normalize({ ..model, cursor: model.cursor + delta })
  }
}

///|
fn table_set_cursor(model : TableModel, cursor : Int) -> TableModel {
  table_normalize({ ..model, cursor, })
}

///|
fn table_move_to_top(model : TableModel) -> TableModel {
  table_set_cursor(model, 0)
}

///|
fn table_move_to_bottom(model : TableModel) -> TableModel {
  if model.rows.length() == 0 {
    table_set_cursor(model, 0)
  } else {
    table_set_cursor(model, model.rows.length() - 1)
  }
}

///|
pub fn default_table_keymap() -> TableKeymap {
  {
    bindings: [
      { binding: @pippa.up_binding(), action: TableActionCursorUp },
      { binding: @pippa.down_binding(), action: TableActionCursorDown },
      {
        binding: @pippa.binding(
          keys=["pageup", "b"],
          help_key="pgup/b",
          help="page up",
        ),
        action: TableActionPageUp,
      },
      {
        binding: @pippa.binding(
          keys=["pagedown", "f"],
          help_key="pgdn/f",
          help="page down",
        ),
        action: TableActionPageDown,
      },
      {
        binding: @pippa.binding(
          keys=["ctrl+u"],
          help_key="C-u",
          help="half page up",
        ),
        action: TableActionHalfPageUp,
      },
      {
        binding: @pippa.binding(
          keys=["ctrl+d"],
          help_key="C-d",
          help="half page down",
        ),
        action: TableActionHalfPageDown,
      },
      {
        binding: @pippa.binding(
          keys=["home", "g"],
          help_key="home/g",
          help="top",
        ),
        action: TableActionMoveToTop,
      },
      {
        binding: @pippa.binding(
          keys=["end", "G"],
          help_key="end/G",
          help="bottom",
        ),
        action: TableActionMoveToBottom,
      },
      {
        binding: @pippa.binding(
          keys=["enter", " "],
          help_key="enter",
          help="select",
        ),
        action: TableActionSelect,
      },
    ],
  }
}

///|
pub fn table_keymap_override(
  keymap : TableKeymap,
  action : TableAction,
  binding : @pippa.Binding,
) -> TableKeymap {
  let bindings : Array[TableKeyBinding] = []
  for entry in keymap.bindings {
    if entry.action == action {
      bindings.push({ binding, action })
    } else {
      bindings.push(entry)
    }
  }
  { bindings, }
}

///|
pub fn table_keymap_disable(
  keymap : TableKeymap,
  action : TableAction,
) -> TableKeymap {
  let bindings : Array[TableKeyBinding] = []
  for entry in keymap.bindings {
    if entry.action == action {
      bindings.push({
        ..entry,
        binding: @pippa.set_disabled(entry.binding, true),
      })
    } else {
      bindings.push(entry)
    }
  }
  { bindings, }
}

///|
fn table_keymap_group_name(action : TableAction) -> String {
  match action {
    TableActionCursorUp => "Movement"
    TableActionCursorDown => "Movement"
    TableActionPageUp => "Movement"
    TableActionPageDown => "Movement"
    TableActionHalfPageUp => "Movement"
    TableActionHalfPageDown => "Movement"
    TableActionMoveToTop => "Movement"
    TableActionMoveToBottom => "Movement"
    TableActionSelect => "Selection"
  }
}

///|
fn table_group_bindings(
  keymap : TableKeymap,
  group_name : String,
) -> Array[@pippa.Binding] {
  let bindings : Array[@pippa.Binding] = []
  for entry in keymap.bindings {
    if table_keymap_group_name(entry.action) == group_name {
      bindings.push(entry.binding)
    }
  }
  bindings
}

///|
pub fn table_keymap_help(keymap : TableKeymap) -> @pippa.KeyMap {
  @pippa.keymap_from_groups([
    @pippa.keymap_group("Movement", table_group_bindings(keymap, "Movement")),
    @pippa.keymap_group("Selection", table_group_bindings(keymap, "Selection")),
  ])
}

///|
pub fn table_help_model(
  keymap? : TableKeymap = default_table_keymap(),
  show_full? : Bool = false,
  width? : Int = 0,
) -> @pippa.HelpModel {
  { keymap: table_keymap_help(keymap), show_full, width }
}

///|
pub fn table_help_view(
  keymap? : TableKeymap = default_table_keymap(),
  show_full? : Bool = false,
  width? : Int = 0,
) -> String {
  @pippa.help_view(table_help_model(keymap~, show_full~, width~))
}

///|
fn table_msg_from_action(action : TableAction) -> TableMsg {
  match action {
    TableActionCursorUp => CursorUp
    TableActionCursorDown => CursorDown
    TableActionPageUp => PageUp
    TableActionPageDown => PageDown
    TableActionHalfPageUp => HalfPageUp
    TableActionHalfPageDown => HalfPageDown
    TableActionMoveToTop => MoveToTop
    TableActionMoveToBottom => MoveToBottom
    TableActionSelect => Select
  }
}

///|
fn table_keymap_action(
  keymap : TableKeymap,
  key : @pippa.KeyMsg,
) -> TableAction? {
  for entry in keymap.bindings {
    if @pippa.matches(entry.binding, key) {
      return Some(entry.action)
    }
  }
  None
}

///|
pub fn table_msg_from_input_event(
  event : @pippa.InputEvent,
  keymap? : TableKeymap = default_table_keymap(),
) -> TableMsg? {
  match event {
    @pippa.Key(key) =>
      match table_keymap_action(keymap, key) {
        Some(action) => Some(table_msg_from_action(action))
        None => None
      }
    _ => None
  }
}

///|
fn table_update(
  model : TableModel,
  msg : TableMsg,
  keymap : TableKeymap,
) -> @pippa.UpdateResult[TableModel, TableMsg] {
  let next = match msg {
    CursorUp => table_move_cursor(model, -1)
    CursorDown => table_move_cursor(model, 1)
    PageUp => table_move_cursor(model, -table_page_step(model))
    PageDown => table_move_cursor(model, table_page_step(model))
    HalfPageUp => table_move_cursor(model, -table_half_page_step(model))
    HalfPageDown => table_move_cursor(model, table_half_page_step(model))
    MoveToTop => table_move_to_top(model)
    MoveToBottom => table_move_to_bottom(model)
    Select =>
      if model.rows.length() == 0 {
        table_normalize(model)
      } else {
        table_normalize({ ..model, selected: model.cursor })
      }
    SetColumns(columns) => table_normalize({ ..model, columns, })
    SetRows(rows) => table_normalize({ ..model, rows, cursor: 0, selected: -1 })
    SetWidth(width) => table_normalize({ ..model, width, })
    SetHeight(height) => table_normalize({ ..model, height, })
    SetCursor(cursor) => table_set_cursor(model, cursor)
    Focus => table_normalize({ ..model, focused: true })
    Blur => table_normalize({ ..model, focused: false })
    HandleInput(event) =>
      if !model.focused {
        table_normalize(model)
      } else {
        match table_msg_from_input_event(event, keymap~) {
          Some(next_msg) => table_update(model, next_msg, keymap).model
          None => table_normalize(model)
        }
      }
  }
  @pippa.UpdateResult::new(model=next, cmd=@pippa.Cmd::none())
}

///|
fn table_view(model : TableModel) -> String {
  let normalized = table_normalize(model)
  let width = table_effective_width(normalized)
  let buf = StringBuilder::new()
  buf.write_string(table_fit_line(table_header_line(normalized.columns), width))
  buf.write_char('\n')
  buf.write_string(
    table_fit_line(table_separator_line(normalized.columns), width),
  )
  buf.write_char('\n')
  let body = viewport_view(normalized.viewport)
  if body != "" {
    buf.write_string(body)
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
pub fn table_selected_row(model : TableModel) -> Array[String]? {
  let normalized = table_normalize(model)
  if normalized.selected >= 0 && normalized.selected < normalized.rows.length() {
    Some(normalized.rows[normalized.selected])
  } else {
    None
  }
}

///|
pub fn table_cursor(model : TableModel) -> Int {
  table_normalize(model).cursor
}

///|
pub fn table(
  columns~ : Array[Column],
  width? : Int = 0,
  height? : Int = 0,
  keymap? : TableKeymap = default_table_keymap(),
  focused? : Bool = true,
) -> Component[TableModel, TableMsg] {
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model=table_normalize({
          columns,
          rows: [],
          cursor: 0,
          selected: -1,
          width,
          height,
          focused,
          viewport: table_initial_viewport(columns, [], width, height),
        }),
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model, msg) { table_update(model, msg, keymap) },
    view: table_view,
  }
}
