///|
/// Paginator component — tracks page position over a collection.

///|
pub(all) struct PaginatorModel {
  page : Int
  per_page : Int
  total_items : Int
} derive(Debug, Eq)

///|
pub(all) enum PaginatorMsg {
  NextPage
  PrevPage
  SetPage(Int)
  SetPerPage(Int)
  SetTotalItems(Int)
} derive(Debug, Eq)

///|
fn paginator_page_count(total_items : Int, per_page : Int) -> Int {
  let safe_per_page = per_page.max(1)
  let safe_total = total_items.max(0)
  if safe_total == 0 {
    1
  } else {
    (safe_total + safe_per_page - 1) / safe_per_page
  }
}

///|
fn paginator_normalize(
  page : Int,
  per_page : Int,
  total_items : Int,
) -> PaginatorModel {
  let safe_per_page = per_page.max(1)
  let safe_total = total_items.max(0)
  let page_count = paginator_page_count(safe_total, safe_per_page)
  {
    page: page.max(0).min(page_count - 1),
    per_page: safe_per_page,
    total_items: safe_total,
  }
}

///|
pub fn paginator(
  per_page? : Int = 10,
) -> Component[PaginatorModel, PaginatorMsg] {
  {
    init: fn() {
      @pippa.UpdateResult::new(
        model=paginator_normalize(0, per_page, 0),
        cmd=@pippa.Cmd::none(),
      )
    },
    update: fn(model, msg) {
      let next = match msg {
        NextPage =>
          paginator_normalize(model.page + 1, model.per_page, model.total_items)
        PrevPage =>
          paginator_normalize(model.page - 1, model.per_page, model.total_items)
        SetPage(page) =>
          paginator_normalize(page, model.per_page, model.total_items)
        SetPerPage(per_page) =>
          paginator_normalize(model.page, per_page, model.total_items)
        SetTotalItems(total_items) =>
          paginator_normalize(model.page, model.per_page, total_items)
      }
      @pippa.UpdateResult::new(model=next, cmd=@pippa.Cmd::none())
    },
    view: fn(model) {
      let page_count = paginator_page_count(model.total_items, model.per_page)
      "Page \{model.page + 1}/\{page_count}"
    },
  }
}
