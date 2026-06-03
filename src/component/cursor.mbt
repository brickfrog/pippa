///|
/// Cursor component — renders a virtual block cursor with Bubbles-style blink
/// behavior.

///|
let cursor_default_interval_ms = 530

///|
/// Cursor rendering mode.
pub(all) enum CursorMode {
  CursorBlink
  CursorStatic
  CursorHide
} derive(Debug, Eq)

///|
/// Stable identity attached to scheduled cursor ticks.
pub(all) struct CursorTickToken {
  instance_id : Int64
  generation : Int64
} derive(Debug, Eq)

///|
/// Model for the Cursor component.
///
/// - `char`: the string displayed under the cursor
/// - `mode`: blink, static, or hidden rendering behavior
/// - `is_blinked`: when true, the cursor is visually hidden and renders `char`
///   without reverse-video styling
/// - `focused`: whether the containing input is focused
/// - `interval_ms`: blink interval used for scheduled ticks
pub(all) struct CursorModel {
  char : String
  mode : CursorMode
  is_blinked : Bool
  focused : Bool
  interval_ms : Int
  instance_id : Int64
  tick_generation : Int64
} derive(Debug, Eq)

///|
/// Messages handled by the Cursor component.
pub(all) enum CursorMsg {
  /// Focus the cursor and start blinking when in `CursorBlink` mode.
  Focus
  /// Blur the cursor and render the underlying bare character.
  Blur
  /// Change the cursor mode.
  SetMode(CursorMode)
  /// Change the character under the cursor.
  SetChar(String)
  /// Toggle the blink state immediately.
  Tick
  /// Toggle from a scheduled tick when the token still matches this model.
  TimedTick(CursorTickToken)
} derive(Debug, Eq)

///|
priv struct CursorScheduledTick {
  interval_ms : Int
  task : () -> CursorMsg
}

///|
let cursor_instance_counter : Ref[Int64] = Ref(0L)

///|
fn cursor_next_instance_id() -> Int64 {
  cursor_instance_counter.val = cursor_instance_counter.val + 1L
  cursor_instance_counter.val
}

///|
fn cursor_current_tick_token(model : CursorModel) -> CursorTickToken {
  { instance_id: model.instance_id, generation: model.tick_generation }
}

///|
fn cursor_next_tick_generation(model : CursorModel) -> Int64 {
  model.tick_generation + 1L
}

///|
fn cursor_tick_task(token : CursorTickToken) -> () -> CursorMsg {
  fn() { TimedTick(token) }
}

///|
fn cursor_next_tick_schedule(
  interval_ms : Int,
  token : CursorTickToken,
) -> CursorScheduledTick {
  { interval_ms: interval_ms.max(1), task: cursor_tick_task(token) }
}

///|
fn cursor_next_tick_cmd(
  interval_ms : Int,
  token : CursorTickToken,
) -> @pippa.Cmd[CursorMsg] {
  let schedule = cursor_next_tick_schedule(interval_ms, token)
  @pippa.Cmd::after(schedule.interval_ms, schedule.task)
}

///|
fn cursor_tick_is_current(model : CursorModel, token : CursorTickToken) -> Bool {
  token == cursor_current_tick_token(model)
}

///|
fn cursor_is_visible(model : CursorModel) -> Bool {
  !model.is_blinked
}

///|
fn cursor_schedule_blink(
  model : CursorModel,
) -> @pippa.UpdateResult[CursorModel, CursorMsg] {
  let model = { ..model, tick_generation: cursor_next_tick_generation(model) }
  @pippa.UpdateResult::new(
    model~,
    cmd=cursor_next_tick_cmd(
      model.interval_ms,
      cursor_current_tick_token(model),
    ),
  )
}

///|
fn cursor_focus(
  model : CursorModel,
) -> @pippa.UpdateResult[CursorModel, CursorMsg] {
  let model = { ..model, focused: true, is_blinked: model.mode == CursorHide }
  if model.mode == CursorBlink {
    cursor_schedule_blink(model)
  } else {
    @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
  }
}

///|
fn cursor_set_mode(
  model : CursorModel,
  mode : CursorMode,
) -> @pippa.UpdateResult[CursorModel, CursorMsg] {
  let model = {
    ..model,
    mode,
    is_blinked: mode == CursorHide || !model.focused,
  }
  if mode == CursorBlink && model.focused {
    cursor_schedule_blink(model)
  } else {
    @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
  }
}

///|
fn cursor_toggle_blink(model : CursorModel) -> CursorModel {
  if model.mode != CursorBlink || !model.focused {
    model
  } else {
    { ..model, is_blinked: !model.is_blinked }
  }
}

///|
fn cursor_timed_tick(
  model : CursorModel,
  token : CursorTickToken,
) -> @pippa.UpdateResult[CursorModel, CursorMsg] {
  if model.mode != CursorBlink ||
    !model.focused ||
    !cursor_tick_is_current(model, token) {
    @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
  } else {
    let toggled = cursor_toggle_blink(model)
    cursor_schedule_blink(toggled)
  }
}

///|
fn cursor_view(model : CursorModel) -> String {
  if cursor_is_visible(model) {
    @pippa.style()
    .reverse()
    .render(if model.char == "" { " " } else { model.char })
  } else {
    model.char
  }
}

///|
/// Construct a Cursor `Component`.
///
/// ```moonbit nocheck
/// let c = cursor()
/// let { model, .. } = (c.init)()
/// ```
pub fn cursor(
  char? : String = "",
  mode? : CursorMode = CursorBlink,
  interval_ms? : Int = cursor_default_interval_ms,
  focused? : Bool = false,
) -> Component[CursorModel, CursorMsg] {
  let safe_interval_ms = interval_ms.max(1)
  {
    init: fn() {
      let instance_id = cursor_next_instance_id()
      let model = {
        char,
        mode,
        is_blinked: mode == CursorHide || !focused,
        focused,
        interval_ms: safe_interval_ms,
        instance_id,
        tick_generation: 0L,
      }
      if mode == CursorBlink && focused {
        cursor_schedule_blink(model)
      } else {
        @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
      }
    },
    update: fn(model, msg) {
      match msg {
        Focus => cursor_focus(model)
        Blur =>
          @pippa.UpdateResult::new(
            model={ ..model, focused: false, is_blinked: true },
            cmd=@pippa.Cmd::none(),
          )
        SetMode(mode) => cursor_set_mode(model, mode)
        SetChar(char) =>
          @pippa.UpdateResult::new(
            model={ ..model, char, },
            cmd=@pippa.Cmd::none(),
          )
        Tick =>
          @pippa.UpdateResult::new(
            model=cursor_toggle_blink(model),
            cmd=@pippa.Cmd::none(),
          )
        TimedTick(token) => cursor_timed_tick(model, token)
      }
    },
    view: cursor_view,
  }
}
