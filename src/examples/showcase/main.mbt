///|
/// Tabbed showcase app for the Pippa framework.

///|
struct Model {
  tab : Int
  spinner : @component.SpinnerModel
  progress : @component.ProgressBarModel
  text_input : @component.TextInputModel
  viewport : @component.ViewportModel
  // Progress animation phase:
  //   0 = animating to 1.0
  //   1 = pausing at 1.0  (fires SetPercent(0.75) after pause)
  //   2 = animating to 0.75
  //   3 = pausing at 0.75 (fires SetPercent(1.0) after pause)
  //   4 = animating to 1.0 again → loops to phase 1
  progress_phase : Int
  progress_pause_ticks : Int
  spinner_ticks : Int
} derive(Show)

///|
enum Msg {
  TabNext
  TabPrev
  ProgressMsg(@component.ProgressBarMsg)
  TextInputMsg(@component.TextInputMsg)
  ViewportMsg(@component.ViewportMsg)
  Quit
} derive(Show)

///|
let spinner_comp : @component.Component[
  @component.SpinnerModel,
  @component.SpinnerMsg,
] = @component.spinner()

///|
let progress_comp : @component.Component[
  @component.ProgressBarModel,
  @component.ProgressBarMsg,
] = @component.progress_bar(width=30, spring_frequency=2.0, spring_damping=1.0)

///|
let text_input_comp : @component.Component[
  @component.TextInputModel,
  @component.TextInputMsg,
] = @component.text_input(placeholder="type something...")

///|
let viewport_comp : @component.Component[
  @component.ViewportModel,
  @component.ViewportMsg,
] = @component.viewport(width=60, height=10)

///|
fn showcase_tick_cmd() -> @pippa.Cmd[Msg] {
  @pippa.Cmd::tick(150)
}

///|
fn showcase_shift_tab_bytes() -> Bytes {
  Bytes::from_array([b'\x1b', b'[', b'Z'])
}

///|
fn showcase_page_up_bytes() -> Bytes {
  Bytes::from_array([b'\x1b', b'[', b'5', b'~'])
}

///|
fn showcase_page_down_bytes() -> Bytes {
  Bytes::from_array([b'\x1b', b'[', b'6', b'~'])
}

///|
fn showcase_tab_next(tab : Int) -> Int {
  (tab + 1) % 3
}

///|
fn showcase_tab_prev(tab : Int) -> Int {
  if tab <= 0 {
    2
  } else {
    tab - 1
  }
}

///|
fn showcase_sync_text_input_focus(
  model : @component.TextInputModel,
  tab : Int,
) -> @component.TextInputModel {
  let focus_msg = if tab == 1 { @component.Focus } else { @component.Blur }
  (text_input_comp.update)(model, focus_msg).model
}

///|
fn showcase_set_tab(model : Model, tab : Int) -> Model {
  {
    ..model,
    tab,
    text_input: showcase_sync_text_input_focus(model.text_input, tab),
  }
}

///|
fn showcase_viewport_content() -> String {
  let buf = StringBuilder::new()
  buf.write_string("Pippa Showcase\n")
  buf.write_string("==============================\n")
  buf.write_string("This demo combines several parts of the framework:\n")
  buf.write_string("- Model / Update / View architecture\n")
  buf.write_string("- Periodic ticks that drive animation\n")
  buf.write_string("- Composable component models\n")
  buf.write_string("- ANSI styles, borders, and layout\n")
  buf.write_string("- Keyboard-first interaction\n")
  buf.write_string("\n")
  buf.write_string("Viewport notes\n")
  buf.write_string("--------------\n")
  buf.write_string("Use the arrow keys to move one line at a time.\n")
  buf.write_string("Use PageUp / PageDown for larger jumps.\n")
  buf.write_string("\n")
  buf.write_string("Why Pippa?\n")
  buf.write_string("-----------\n")
  buf.write_string("You keep state in plain structs.\n")
  buf.write_string("Updates are typed messages instead of callbacks.\n")
  buf.write_string("Views are just strings with ANSI styling.\n")
  buf.write_string("The runtime handles diffing and raw terminal mode.\n")
  buf.write_string("\n")
  buf.write_string("Try the other tabs too:\n")
  buf.write_string("- Activity shows spinner ticks and a progress bar.\n")
  buf.write_string("- Input forwards editing keys to TextInput.\n")
  buf.write_string("- This tab demonstrates a scrollable window.\n")
  buf.write_string("\n")
  buf.write_string(
    "This block is intentionally longer than the viewport height\n",
  )
  buf.write_string(
    "so the scrolling behavior is obvious in a terminal session.\n",
  )
  buf.write_string("\n")
  buf.write_string("MoonBit + Pippa makes terminal apps feel structured.\n")
  buf.to_string()
}

///|
fn showcase_init() -> @pippa.UpdateResult[Model, Msg] {
  let spinner = (spinner_comp.init)().model
  let progress0 = (progress_comp.init)().model
  // Kick off the animation toward 100% immediately.
  let progress = (progress_comp.update)(progress0, @component.SetPercent(1.0)).model
  let text_input = (text_input_comp.init)().model
  let viewport0 = (viewport_comp.init)().model
  let viewport = (viewport_comp.update)(
      viewport0,
      @component.SetContent(showcase_viewport_content()),
    ).model

  @pippa.UpdateResult::new(
    model={
      tab: 0,
      spinner,
      progress,
      text_input,
      viewport,
      progress_phase: 0,
      progress_pause_ticks: 0,
      spinner_ticks: 0,
    },
    cmd=@pippa.Cmd::tick(16),
  )
}

///|
fn progress_settled(m : @component.ProgressBarModel) -> Bool {
  (m.displayed_percent - m.target_percent).abs() < 0.001 &&
  m.velocity.abs() < 0.01
}

///|
fn showcase_update(model : Model, msg : Msg) -> @pippa.UpdateResult[Model, Msg] {
  if model.tab < 0 {
    return @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
  }

  match msg {
    Quit =>
      @pippa.UpdateResult::new(
        model={ ..model, tab: -1 },
        cmd=@pippa.Cmd::none(),
      )
    TabNext =>
      @pippa.UpdateResult::new(
        model=showcase_set_tab(model, showcase_tab_next(model.tab)),
        cmd=showcase_tick_cmd(),
      )
    TabPrev =>
      @pippa.UpdateResult::new(
        model=showcase_set_tab(model, showcase_tab_prev(model.tab)),
        cmd=showcase_tick_cmd(),
      )
    ProgressMsg(progress_msg) => {
      // Step the spring.
      let tick_result = (progress_comp.update)(model.progress, progress_msg)
      let ticked = tick_result.model

      // Tick the spinner every 8 spring frames (~128ms).
      let new_spinner_ticks = model.spinner_ticks + 1
      let new_spinner = if new_spinner_ticks % 8 == 0 {
        (spinner_comp.update)(model.spinner, @component.SpinnerMsg::Tick).model
      } else {
        model.spinner
      }

      // Phase state machine.
      //   0 → settled → 1(pause 30) → SetPercent(0.75) → 2
      //   2 → settled → 3(pause 20) → SetPercent(1.0)  → 4
      //   4 → settled → 1  (loop)
      //
      // IMPORTANT: when SetPercent fires we use sr.model so the target actually changes.
      let (final_progress, new_phase, new_pause_ticks, phase_cmd) = match
        model.progress_phase {
        0 | 2 | 4 =>
          if progress_settled(ticked) {
            let pause_phase = if model.progress_phase == 2 { 3 } else { 1 }
            (ticked, pause_phase, 1, @pippa.Cmd::none())
          } else {
            (ticked, model.progress_phase, 0, @pippa.Cmd::none())
          }
        1 => {
          let paused = model.progress_pause_ticks + 1
          if paused >= 30 {
            let sr = (progress_comp.update)(ticked, @component.SetPercent(0.75))
            (sr.model, 2, 0, sr.cmd)
          } else {
            (ticked, 1, paused, @pippa.Cmd::none())
          }
        }
        3 => {
          let paused = model.progress_pause_ticks + 1
          if paused >= 20 {
            let sr = (progress_comp.update)(ticked, @component.SetPercent(1.0))
            (sr.model, 4, 0, sr.cmd)
          } else {
            (ticked, 3, paused, @pippa.Cmd::none())
          }
        }
        _ =>
          (
            ticked,
            model.progress_phase,
            model.progress_pause_ticks,
            @pippa.Cmd::none(),
          )
      }

      let merged = @pippa.Cmd::batch([
        @pippa.Cmd::map(fn(m) { ProgressMsg(m) }, phase_cmd),
        @pippa.Cmd::map(fn(m) { ProgressMsg(m) }, tick_result.cmd),
        @pippa.Cmd::tick(16),
      ])
      @pippa.UpdateResult::new(
        model={
          ..model,
          progress: final_progress,
          spinner: new_spinner,
          spinner_ticks: new_spinner_ticks,
          progress_phase: new_phase,
          progress_pause_ticks: new_pause_ticks,
        },
        cmd=merged,
      )
    }
    TextInputMsg(text_input_msg) => {
      if model.tab != 1 {
        return @pippa.UpdateResult::new(model~, cmd=showcase_tick_cmd())
      }
      let text_input = (text_input_comp.update)(
          model.text_input,
          text_input_msg,
        ).model
      @pippa.UpdateResult::new(
        model={ ..model, text_input, },
        cmd=showcase_tick_cmd(),
      )
    }
    ViewportMsg(viewport_msg) => {
      if model.tab != 2 {
        return @pippa.UpdateResult::new(model~, cmd=showcase_tick_cmd())
      }
      let viewport = (viewport_comp.update)(model.viewport, viewport_msg).model
      @pippa.UpdateResult::new(
        model={ ..model, viewport, },
        cmd=showcase_tick_cmd(),
      )
    }
  }
}

///|
fn showcase_sub(event : @pippa.InputEvent) -> Msg? {
  match event {
    @pippa.Key(@pippa.Special("tab")) => Some(TabNext)
    @pippa.Key(@pippa.Char('q')) | @pippa.Key(@pippa.Modified("ctrl", "c")) =>
      Some(Quit)
    @pippa.Key(@pippa.Special("backspace")) =>
      Some(TextInputMsg(@component.DeleteBefore))
    @pippa.Key(@pippa.Special("left")) =>
      Some(TextInputMsg(@component.MoveCursorLeft))
    @pippa.Key(@pippa.Special("right")) =>
      Some(TextInputMsg(@component.MoveCursorRight))
    @pippa.Key(@pippa.Special("up")) => Some(ViewportMsg(@component.ScrollUp))
    @pippa.Key(@pippa.Special("down")) =>
      Some(ViewportMsg(@component.ScrollDown))
    @pippa.Key(@pippa.Char(ch)) => Some(TextInputMsg(@component.InsertChar(ch)))
    @pippa.Unknown(bytes) =>
      if bytes == showcase_shift_tab_bytes() {
        Some(TabPrev)
      } else if bytes == showcase_page_up_bytes() {
        Some(ViewportMsg(@component.PageUp))
      } else if bytes == showcase_page_down_bytes() {
        Some(ViewportMsg(@component.PageDown))
      } else {
        None
      }
    _ => None
  }
}

///|
fn showcase_tab_label(name : String, active : Bool) -> String {
  if active {
    @pippa.bold() + @pippa.underline() + name + @pippa.reset()
  } else {
    name
  }
}

///|
fn showcase_header(model : Model) -> String {
  let buf = StringBuilder::new()
  buf.write_string(@pippa.bold())
  buf.write_string("Pippa Showcase")
  buf.write_string(@pippa.reset())
  buf.write_string("\n")
  buf.write_string("Tabs: ")
  buf.write_string(showcase_tab_label("1 Activity", model.tab == 0))
  buf.write_string("  ")
  buf.write_string(showcase_tab_label("2 Input", model.tab == 1))
  buf.write_string("  ")
  buf.write_string(showcase_tab_label("3 Viewport", model.tab == 2))
  buf.to_string()
}

///|
fn showcase_panel(content : String) -> String {
  @pippa.style()
  .border(@pippa.border_normal())
  .padding(1, 2, 1, 2)
  .width(62)
  .render(content)
}

///|
fn showcase_activity_body(model : Model) -> String {
  let buf = StringBuilder::new()
  buf.write_string("Spring-physics progress bar animates at ~60fps;\n")
  buf.write_string("target advances every ~150ms and wraps back to 0.\n")
  buf.write_string("\n")
  buf.write_string("Spinner\n")
  buf.write_string((spinner_comp.view)(model.spinner))
  buf.write_string("\n\n")
  buf.write_string("Progress\n")
  buf.write_string((progress_comp.view)(model.progress))
  buf.write_string("\n\n")
  buf.write_string("Spring frames: ")
  buf.write_string(model.spinner_ticks.to_string())
  showcase_panel(buf.to_string())
}

///|
fn showcase_input_value(model : Model) -> String {
  if model.text_input.value == "" {
    @pippa.dim() + "(empty)" + @pippa.reset()
  } else {
    model.text_input.value
  }
}

///|
fn showcase_input_body(model : Model) -> String {
  let field = @pippa.style()
    .border(@pippa.border_ascii())
    .padding(0, 1, 0, 1)
    .width(58)
    .render((text_input_comp.view)(model.text_input))
  let buf = StringBuilder::new()
  buf.write_string("Printable keys, backspace, and left/right arrows are\n")
  buf.write_string("forwarded to the TextInput component on this tab.\n")
  buf.write_string("\n")
  buf.write_string(field)
  buf.write_string("\n\n")
  buf.write_string("Value: ")
  buf.write_string(showcase_input_value(model))
  buf.write_string("\n")
  buf.write_string("Cursor: ")
  buf.write_string(model.text_input.cursor.to_string())
  buf.write_string("   Focused: ")
  buf.write_string(model.text_input.focused.to_string())
  showcase_panel(buf.to_string())
}

///|
fn showcase_viewport_status(model : Model) -> String {
  let start_line = model.viewport.offset + 1
  let end_line = if model.viewport.offset + model.viewport.height <
    model.viewport.total_lines {
    model.viewport.offset + model.viewport.height
  } else {
    model.viewport.total_lines
  }
  "Showing lines \{start_line}-\{end_line} of \{model.viewport.total_lines}"
}

///|
fn showcase_viewport_body(model : Model) -> String {
  let framed_viewport = @pippa.style()
    .border(@pippa.border_ascii())
    .render((viewport_comp.view)(model.viewport))
  let buf = StringBuilder::new()
  buf.write_string(
    "The viewport renders a fixed-size window into longer text.\n",
  )
  buf.write_string("Use Up / Down or PageUp / PageDown to move around.\n")
  buf.write_string("\n")
  buf.write_string(framed_viewport)
  buf.write_string("\n\n")
  buf.write_string(showcase_viewport_status(model))
  showcase_panel(buf.to_string())
}

///|
fn showcase_body(model : Model) -> String {
  match model.tab {
    0 => showcase_activity_body(model)
    1 => showcase_input_body(model)
    2 => showcase_viewport_body(model)
    _ => "Closing showcase..."
  }
}

///|
fn showcase_footer(model : Model) -> String {
  let detail = match model.tab {
    0 => "spring physics drives the progress bar"
    1 => "type, backspace, and left/right edit the input"
    2 => "up/down and page keys scroll the viewport"
    _ => "q quit"
  }
  @pippa.dim() +
  "tab next  shift+tab prev  q quit  |  " +
  detail +
  @pippa.reset()
}

///|
fn showcase_view(model : Model) -> String {
  if model.tab < 0 {
    return "Closing Pippa showcase..."
  }

  let content = showcase_header(model) +
    "\n\n" +
    showcase_body(model) +
    "\n\n" +
    showcase_footer(model)

  @pippa.style()
  .border(@pippa.border_rounded())
  .padding(1, 2, 1, 2)
  .width(70)
  .render(content)
}

///|
fn main {
  let program = @pippa.Program::new(
    init=showcase_init,
    update=showcase_update,
    view=showcase_view,
    sub=showcase_sub,
    on_tick=fn() { Some(ProgressMsg(@component.ProgressBarMsg::Tick)) },
    should_quit=fn(model) { model.tab < 0 },
  )
  @pippa.Program::run(program)
}
