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
  //   1 = bouncing down toward 0.75
  //   2 = rebounding back toward 1.0
  //   3 = bouncing down toward 0.90 after the rebound to 1.0
  //   4 = settling back at 1.0 before the loop restarts
  progress_phase : Int
  progress_pause_ticks : Int
  spinner_ticks : Int
} derive(Debug)

///|
enum Msg {
  TabNext
  TabPrev
  ProgressMsg(@component.ProgressBarMsg)
  TextInputMsg(@component.TextInputMsg)
  ViewportMsg(@component.ViewportMsg)
  Quit
} derive(Debug)

///|
let spinner_comp : @component.Component[
  @component.SpinnerModel,
  @component.SpinnerMsg,
] = @component.spinner(label="reconciling model")

///|
let progress_comp : @component.Component[
  @component.ProgressBarModel,
  @component.ProgressBarMsg,
] = @component.progress_bar(
  width=30,
  blend_start=(199, 38, 138),
  blend_end=(255, 178, 56),
  empty_color=(96, 77, 112),
  spring_frequency=10.0,
  spring_damping=0.6,
)

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
  @pippa.Cmd::after(16, fn() { ProgressMsg(@component.ProgressBarMsg::Tick) })
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
let showcase_moon_hex = "#C7268A"

///|
let showcase_moon_hot_hex = "#F553B2"

///|
let showcase_sun_hex = "#FFB238"

///|
let showcase_tide_hex = "#2CC7BE"

///|
let showcase_mist_hex = "#9F8BAF"

///|
let showcase_paper_hex = "#FFF7FB"

///|
let showcase_shell_hex = "#120D18"

///|
let showcase_panel_hex = "#16101F"

///|
let showcase_chip_hex = "#1C1423"

///|
fn showcase_accent_hex(tab : Int) -> String {
  match tab {
    0 => showcase_moon_hex
    1 => showcase_sun_hex
    2 => showcase_tide_hex
    _ => showcase_moon_hex
  }
}

///|
fn showcase_tint(content : String, hex : String) -> String {
  @styling.style().foreground_hex(hex).render(content)
}

///|
fn showcase_loud(content : String, hex : String) -> String {
  @styling.style().foreground_hex(hex).bold().render(content)
}

///|
fn showcase_whisper(content : String) -> String {
  @styling.style().foreground_hex(showcase_mist_hex).render(content)
}

///|
fn showcase_badge(content : String, bg_hex : String) -> String {
  @styling.style()
  .foreground_hex(showcase_paper_hex)
  .background_hex(bg_hex)
  .bold()
  .padding(0, 1, 0, 1)
  .render(content)
}

///|
fn showcase_outline_badge(content : String, accent_hex : String) -> String {
  @styling.style()
  .foreground_hex(accent_hex)
  .background_hex(showcase_chip_hex)
  .bold()
  .padding(0, 1, 0, 1)
  .render(content)
}

///|
fn showcase_tab_chip(
  content : String,
  active : Bool,
  accent_hex : String,
) -> String {
  if active {
    showcase_badge(content, accent_hex)
  } else {
    showcase_outline_badge(content, accent_hex)
  }
}

///|
fn showcase_stat_card(
  label : String,
  value : String,
  accent_hex : String,
) -> String {
  @styling.style()
  .border(@styling.border_ascii())
  .border_foreground(@styling.color_hex(accent_hex))
  .padding(0, 1, 0, 1)
  .width(14)
  .render(
    @styling.col <| [
      showcase_whisper(label),
      showcase_loud(value, accent_hex),
    ],
  )
}

///|
fn showcase_sync_text_input_focus(
  model : @component.TextInputModel,
  tab : Int,
) -> @component.TextInputModel {
  let focus_msg = if tab == 1 {
    @component.TextInputMsg::Focus
  } else {
    @component.TextInputMsg::Blur
  }
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
  @styling.lines([
    "Pippa Showcase", "==============================", "This demo combines several parts of the framework:",
    "- Model / Update / View architecture", "- Periodic ticks that drive animation",
    "- Composable component models", "- ANSI styles, borders, and layout", "- Keyboard-first interaction",
    "", "Viewport notes", "--------------", "Use the arrow keys to move one line at a time.",
    "Use PageUp / PageDown for larger jumps.", "", "Why Pippa?", "-----------", "You keep state in plain structs.",
    "Updates are typed messages instead of callbacks.", "Views are just strings with ANSI styling.",
    "The runtime handles diffing and raw terminal mode.", "", "Try the other tabs too:",
    "- Activity shows spinner ticks and a progress bar.", "- Input forwards editing keys to TextInput.",
    "- This tab demonstrates a scrollable window.", "", "This block is intentionally longer than the viewport height",
    "so the scrolling behavior is obvious in a terminal session.", "", "MoonBit + Pippa makes terminal apps feel structured.",
  ])
}

///|
fn showcase_init() -> @pippa.UpdateResult[Model, Msg] {
  let spinner = (spinner_comp.init)().model
  let progress0 = (progress_comp.init)().model
  // Kick off the activity demo with a smooth fill toward 100%.
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
    cmd=showcase_tick_cmd(),
  )
}

///|
fn progress_settled(m : @component.ProgressBarModel) -> Bool {
  (m.displayed_percent - m.target_percent).abs() < 0.001 &&
  m.velocity.abs() < 0.01
}

///|
fn showcase_restart_progress(
  progress : @component.ProgressBarModel,
) -> (@component.ProgressBarModel, @pippa.Cmd[Msg]) {
  let reset = {
    ..progress,
    target_percent: 0.0,
    displayed_percent: 0.0,
    velocity: 0.0,
  }
  let sr = (progress_comp.update)(reset, @component.SetPercent(1.0))
  (sr.model, @pippa.Cmd::map(fn(m) { ProgressMsg(m) }, sr.cmd))
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
        cmd=@pippa.Cmd::none(),
      )
    TabPrev =>
      @pippa.UpdateResult::new(
        model=showcase_set_tab(model, showcase_tab_prev(model.tab)),
        cmd=@pippa.Cmd::none(),
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

      let (final_progress, final_progress_cmd, new_phase, new_pause_ticks) = match
        model.progress_phase {
        0 =>
          if ticked.displayed_percent >= 0.99 && ticked.velocity > 0.0 {
            let sr = (progress_comp.update)(ticked, @component.SetPercent(0.75))
            (sr.model, @pippa.Cmd::map(fn(m) { ProgressMsg(m) }, sr.cmd), 1, 0)
          } else {
            (
              ticked,
              @pippa.Cmd::map(fn(m) { ProgressMsg(m) }, tick_result.cmd),
              0,
              0,
            )
          }
        1 =>
          if ticked.displayed_percent <= 0.76 && ticked.velocity < 0.0 {
            let sr = (progress_comp.update)(ticked, @component.SetPercent(1.0))
            (sr.model, @pippa.Cmd::map(fn(m) { ProgressMsg(m) }, sr.cmd), 2, 0)
          } else {
            (
              ticked,
              @pippa.Cmd::map(fn(m) { ProgressMsg(m) }, tick_result.cmd),
              1,
              0,
            )
          }
        2 =>
          if ticked.displayed_percent >= 0.99 && ticked.velocity > 0.0 {
            let sr = (progress_comp.update)(ticked, @component.SetPercent(0.90))
            (sr.model, @pippa.Cmd::map(fn(m) { ProgressMsg(m) }, sr.cmd), 3, 0)
          } else {
            (
              ticked,
              @pippa.Cmd::map(fn(m) { ProgressMsg(m) }, tick_result.cmd),
              2,
              0,
            )
          }
        3 =>
          if ticked.displayed_percent <= 0.905 && ticked.velocity < 0.0 {
            let sr = (progress_comp.update)(ticked, @component.SetPercent(1.0))
            (sr.model, @pippa.Cmd::map(fn(m) { ProgressMsg(m) }, sr.cmd), 4, 0)
          } else {
            (
              ticked,
              @pippa.Cmd::map(fn(m) { ProgressMsg(m) }, tick_result.cmd),
              3,
              0,
            )
          }
        _ =>
          if progress_settled(ticked) {
            let paused = model.progress_pause_ticks + 1
            if paused >= 24 {
              let (restarted, restart_cmd) = showcase_restart_progress(ticked)
              (restarted, restart_cmd, 0, 0)
            } else {
              (ticked, @pippa.Cmd::none(), 4, paused)
            }
          } else {
            (
              ticked,
              @pippa.Cmd::map(fn(m) { ProgressMsg(m) }, tick_result.cmd),
              4,
              0,
            )
          }
      }

      // When the progress bar is actively animating it schedules its own 16ms
      // follow-up tick. Once settled, fall back to the app tick so the loop can
      // restart after a short hold at 100%.
      let cmd = if final_progress_cmd.is_none() {
        showcase_tick_cmd()
      } else {
        final_progress_cmd
      }
      @pippa.UpdateResult::new(
        model={
          ..model,
          progress: final_progress,
          spinner: new_spinner,
          progress_phase: new_phase,
          progress_pause_ticks: new_pause_ticks,
          spinner_ticks: new_spinner_ticks,
        },
        cmd~,
      )
    }
    TextInputMsg(text_input_msg) => {
      if model.tab != 1 {
        return @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
      }
      let text_input = (text_input_comp.update)(
          model.text_input,
          text_input_msg,
        ).model
      @pippa.UpdateResult::new(
        model={ ..model, text_input, },
        cmd=@pippa.Cmd::none(),
      )
    }
    ViewportMsg(viewport_msg) => {
      if model.tab != 2 {
        return @pippa.UpdateResult::new(model~, cmd=@pippa.Cmd::none())
      }
      let viewport = (viewport_comp.update)(model.viewport, viewport_msg).model
      @pippa.UpdateResult::new(
        model={ ..model, viewport, },
        cmd=@pippa.Cmd::none(),
      )
    }
  }
}

///|
fn showcase_sub(event : @pippa.InputEvent) -> Msg? {
  match event {
    @pippa.Key(@pippa.Special("tab")) => Some(TabNext)
    @pippa.Key(@pippa.Modified("shift", "tab")) => Some(TabPrev)
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
    @pippa.Key(@pippa.Special("pageup")) => Some(ViewportMsg(@component.PageUp))
    @pippa.Key(@pippa.Special("pagedown")) =>
      Some(ViewportMsg(@component.PageDown))
    @pippa.Key(@pippa.Char(ch)) => Some(TextInputMsg(@component.InsertChar(ch)))
    _ => None
  }
}

///|
fn showcase_progress_phase_label(phase : Int) -> String {
  match phase {
    0 => "launch"
    1 => "kickback"
    2 => "rebound"
    3 => "aftershock"
    4 => "settling"
    _ => "idle"
  }
}

///|
fn showcase_header(model : Model) -> String {
  @styling.col <| [
    showcase_outline_badge("MOONBIT TUI", showcase_sun_hex),
    showcase_loud("Pippa Showcase", showcase_moon_hex),
    showcase_whisper("Typed updates, composable components,"),
    showcase_whisper("and a warmer MoonBit-flavored palette."),
    "",
    @styling.row <| [
      showcase_tab_chip("1 ACTIVITY", model.tab == 0, showcase_moon_hex),
      "  ",
      showcase_tab_chip("2 INPUT", model.tab == 1, showcase_sun_hex),
      "  ",
      showcase_tab_chip("3 VIEWPORT", model.tab == 2, showcase_tide_hex),
    ],
  ]
}

///|
fn showcase_panel(
  title : String,
  accent_hex : String,
  content : String,
) -> String {
  @styling.style()
  .background_hex(showcase_panel_hex)
  .border(@styling.border_rounded())
  .border_foreground(@styling.color_hex(accent_hex))
  .padding(1, 2, 1, 2)
  .width(66)
  .render(
    @styling.col <| [
      showcase_badge(title, accent_hex),
      "",
      content,
    ],
  )
}

///|
fn showcase_activity_body(model : Model) -> String {
  let stats = @styling.row <| [
      showcase_stat_card(
        "PHASE",
        showcase_progress_phase_label(model.progress_phase),
        showcase_moon_hex,
      ),
      "  ",
      showcase_stat_card(
        "TICKS",
        model.spinner_ticks.to_string(),
        showcase_sun_hex,
      ),
      "  ",
      showcase_stat_card("TARGET", "100%", showcase_tide_hex),
    ]
  showcase_panel(
    "ACTIVITY",
    showcase_moon_hex,
    @styling.col <| [
      showcase_whisper(
        "A springy fill with deliberate recoil, not stepped progress.",
      ),
      "",
      stats,
      "",
      showcase_loud("Spinner", showcase_moon_hex),
      showcase_tint((spinner_comp.view)(model.spinner), showcase_moon_hot_hex),
      "",
      showcase_loud("Progress", showcase_sun_hex),
      (progress_comp.view)(model.progress),
      "",
      showcase_whisper(
        "Rush to 100%, bounce to 75%, rebound, then soften into a final settle.",
      ),
    ],
  )
}

///|
fn showcase_input_value(model : Model) -> String {
  if model.text_input.value == "" {
    showcase_whisper("(empty)")
  } else {
    showcase_tint(model.text_input.value, showcase_moon_hot_hex)
  }
}

///|
fn showcase_input_body(model : Model) -> String {
  let field = @styling.style()
    .background_hex(showcase_chip_hex)
    .border(@styling.border_rounded())
    .border_foreground(@styling.color_hex(showcase_sun_hex))
    .padding(0, 1, 0, 1)
    .width(60)
    .render((text_input_comp.view)(model.text_input))
  let stats = @styling.row <| [
      showcase_stat_card(
        "CURSOR",
        model.text_input.cursor.to_string(),
        showcase_sun_hex,
      ),
      "  ",
      showcase_stat_card(
        "FOCUS",
        if model.text_input.focused {
          "on"
        } else {
          "off"
        },
        showcase_moon_hex,
      ),
      "  ",
      showcase_stat_card(
        "CHARS",
        @pippa.visible_width(model.text_input.value).to_string(),
        showcase_tide_hex,
      ),
    ]
  showcase_panel(
    "INPUT",
    showcase_sun_hex,
    @styling.col <| [
      showcase_whisper(
        "Printable keys, backspace, and left/right stay routed into TextInput here.",
      ),
      "",
      field,
      "",
      stats,
      "",
      showcase_loud("Value", showcase_sun_hex) +
      ": " +
      showcase_input_value(model),
    ],
  )
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
  let framed_viewport = @styling.style()
    .background_hex(showcase_chip_hex)
    .border(@styling.border_rounded())
    .border_foreground(@styling.color_hex(showcase_tide_hex))
    .padding(0, 1, 0, 1)
    .render((viewport_comp.view)(model.viewport))
  showcase_panel(
    "VIEWPORT",
    showcase_tide_hex,
    @styling.col <| [
      showcase_whisper(
        "A fixed-size window over longer copy, with keyboard scrolling and stable diffing.",
      ),
      "",
      framed_viewport,
      "",
      showcase_outline_badge(showcase_viewport_status(model), showcase_tide_hex),
    ],
  )
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
  @styling.col <| [
    @styling.row <| [
      showcase_outline_badge("tab", showcase_accent_hex(model.tab)),
      " ",
      showcase_whisper("next"),
      "  ",
      showcase_outline_badge("shift+tab", showcase_moon_hot_hex),
      " ",
      showcase_whisper("prev"),
      "  ",
      showcase_outline_badge("q", showcase_sun_hex),
      " ",
      showcase_whisper("quit"),
    ],
    showcase_whisper(detail),
  ]
}

///|
fn showcase_view(model : Model) -> String {
  if model.tab < 0 {
    return showcase_tint("Closing Pippa showcase...", showcase_moon_hex)
  }
  @styling.style()
  .background_hex(showcase_shell_hex)
  .border(@styling.border_rounded())
  .border_foreground(@styling.color_hex(showcase_moon_hex))
  .padding(1, 2, 1, 2)
  .width(74)
  .render(
    @styling.col <| [
      showcase_header(model),
      "",
      showcase_body(model),
      "",
      showcase_footer(model),
    ],
  )
}

///|
fn main {
  let program = @pippa.Program::new(
    init=showcase_init,
    update=showcase_update,
    view=showcase_view,
    sub=showcase_sub,
    should_quit=fn(model) { model.tab < 0 },
  )
  @pippa.Program::run(program)
}
