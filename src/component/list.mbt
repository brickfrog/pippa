///|
/// List component — a filterable, paged list of string items.

///|
pub(all) struct ListModel {
  items : Array[String]
  filter : String
  cursor : Int
  selected : Int
  page_size : Int
} derive(Show, Eq)

///|
pub(all) enum ListMsg {
  CursorUp
  CursorDown
  PageUp
  PageDown
  Select
  SetItems(Array[String])
  SetFilter(String)
  FilterInsertChar(Char)
  FilterBackspace
  ClearFilter
} derive(Show, Eq)

///|
fn list_chars_to_string(chars : Array[Char]) -> String {
  let buf = StringBuilder::new(size_hint=chars.length() + 4)
  for ch in chars {
    buf.write_char(ch)
  }
  buf.to_string()
}

///|
fn list_filtered_indices(items : Array[String], filter : String) -> Array[Int] {
  if filter == "" {
    let indices : Array[Int] = []
    for i in 0..<items.length() {
      indices.push(i)
    }
    return indices
  }
  let lowered = filter.to_lower()
  let indices : Array[Int] = []
  for i, item in items {
    if item.to_lower().contains(lowered) {
      indices.push(i)
    }
  }
  indices
}

///|
fn list_normalize(
  items : Array[String],
  filter : String,
  cursor : Int,
  selected : Int,
  page_size : Int,
) -> ListModel {
  let filtered = list_filtered_indices(items, filter)
  let max_cursor = if filtered.is_empty() { 0 } else { filtered.length() - 1 }
  let next_selected = if selected >= 0 && selected < items.length() {
    selected
  } else {
    -1
  }
  {
    items,
    filter,
    cursor: cursor.max(0).min(max_cursor),
    selected: next_selected,
    page_size: page_size.max(1),
  }
}

///|
fn list_page_start(model : ListModel) -> Int {
  model.cursor / model.page_size * model.page_size
}

///|
pub fn list(
  items? : Array[String] = [],
  page_size? : Int = 8,
) -> Component[ListModel, ListMsg] {
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model=list_normalize(items, "", 0, -1, page_size),
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model, msg) {
      let filtered = list_filtered_indices(model.items, model.filter)
      let next = match msg {
        CursorUp =>
          list_normalize(
            model.items,
            model.filter,
            model.cursor - 1,
            model.selected,
            model.page_size,
          )
        CursorDown =>
          list_normalize(
            model.items,
            model.filter,
            model.cursor + 1,
            model.selected,
            model.page_size,
          )
        PageUp =>
          list_normalize(
            model.items,
            model.filter,
            model.cursor - model.page_size,
            model.selected,
            model.page_size,
          )
        PageDown =>
          list_normalize(
            model.items,
            model.filter,
            model.cursor + model.page_size,
            model.selected,
            model.page_size,
          )
        Select => {
          let selected = if filtered.is_empty() {
            -1
          } else {
            filtered[model.cursor]
          }
          list_normalize(
            model.items,
            model.filter,
            model.cursor,
            selected,
            model.page_size,
          )
        }
        SetItems(items) =>
          list_normalize(items, model.filter, 0, -1, model.page_size)
        SetFilter(filter) =>
          list_normalize(
            model.items,
            filter,
            0,
            model.selected,
            model.page_size,
          )
        FilterInsertChar(ch) => {
          let chars = model.filter.to_array()
          list_normalize(
            model.items,
            list_chars_to_string([..chars, ch]),
            0,
            model.selected,
            model.page_size,
          )
        }
        FilterBackspace => {
          let chars = model.filter.to_array()
          let next_filter = if chars.is_empty() {
            ""
          } else {
            list_chars_to_string(chars[0:chars.length() - 1].to_array())
          }
          list_normalize(
            model.items,
            next_filter,
            0,
            model.selected,
            model.page_size,
          )
        }
        ClearFilter =>
          list_normalize(model.items, "", 0, model.selected, model.page_size)
      }
      @pippa.UpdateResult::new(model=next, cmd=@pippa.Cmd::none())
    },
    view: fn(model) {
      let filtered = list_filtered_indices(model.items, model.filter)
      let page_start = list_page_start(model)
      let page_end = (page_start + model.page_size).min(filtered.length())
      let lines : Array[String] = []
      if model.filter != "" {
        lines.push("Filter: \{model.filter}")
      }
      if filtered.is_empty() {
        lines.push(@pippa.dim() + "(no items)" + @pippa.reset())
      } else {
        for i in page_start..<page_end {
          let item_index = filtered[i]
          let item = model.items[item_index]
          let prefix = if i == model.cursor {
            @pippa.bold() + "> " + @pippa.reset()
          } else {
            "  "
          }
          let selected_prefix = if item_index == model.selected {
            @pippa.underline()
          } else {
            ""
          }
          let selected_suffix = if item_index == model.selected {
            @pippa.reset()
          } else {
            ""
          }
          lines.push(prefix + selected_prefix + item + selected_suffix)
        }
      }
      let total_pages = if filtered.is_empty() {
        1
      } else {
        (filtered.length() + model.page_size - 1) / model.page_size
      }
      let page = if filtered.is_empty() {
        1
      } else {
        page_start / model.page_size + 1
      }
      lines.push(@pippa.dim() + "Page \{page}/\{total_pages}" + @pippa.reset())
      lines.join("\n")
    },
  }
}
