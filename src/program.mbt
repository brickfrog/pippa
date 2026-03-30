///|
/// Program configuration and entry-point for a Pippa TUI application.
///
/// A `Program[Model, Msg]` ties together the three core functions of the Elm
/// Architecture (init, update, view) and drives the main event loop.
///
/// Construct with `Program::new` and run with `Program::run`.

///|
/// Configuration for a Pippa application.
pub(all) struct Program[Model, Msg] {
  /// Initial state and optional initial command.
  init : () -> UpdateResult[Model, Msg]
  /// Pure update function: given the current model and a message, produce
  /// the next model and an optional command.
  update : (Model, Msg) -> UpdateResult[Model, Msg]
  /// Pure view function: render the current model to a string.
  view : (Model) -> String
  /// Map input events to messages. Return None to ignore an event.
  sub : (InputEvent) -> Msg?
  /// Produce a message when a periodic tick fires. Return None to ignore it.
  on_tick : () -> Msg?
  /// Enable terminal mouse reporting while the program runs.
  mouse : Bool
  /// Produce a message when the terminal size changes. Return None to ignore it.
  on_resize : (Int, Int) -> Msg?
  /// Return true to exit the event loop after an update.
  should_quit : (Model) -> Bool
}

///|
/// Create a new Program from init, update, and view functions.
pub fn[Model, Msg] Program::new(
  init~ : () -> UpdateResult[Model, Msg],
  update~ : (Model, Msg) -> UpdateResult[Model, Msg],
  view~ : (Model) -> String,
  sub? : (InputEvent) -> Msg? = fn(_evt) { None },
  on_tick? : () -> Msg? = fn() { None },
  mouse? : Bool = false,
  on_resize? : (Int, Int) -> Msg? = fn(_cols, _rows) { None },
  should_quit? : (Model) -> Bool = fn(_model) { false },
) -> Program[Model, Msg] {
  { init, update, view, sub, on_tick, mouse, on_resize, should_quit }
}

///|
/// Run the program.
///
/// On `native` and `llvm` targets this enters raw terminal mode and drives
/// the main event loop. On other targets this is a no-op.
pub fn[Model, Msg] Program::run(program : Program[Model, Msg]) -> Unit {
  run_internal(program)
}

///|
#cfg(not(any(target="native", target="llvm")))
fn[Model, Msg] run_internal(_program : Program[Model, Msg]) -> Unit {
  ()
}

///|
#cfg(any(target="native", target="llvm"))
fn write_bytes(bytes : Bytes) -> Unit {
  pippa_write_bytes(bytes, bytes.length())
}

///|
#cfg(any(target="native", target="llvm"))
fn[Msg] next_tick_at(cmd : Cmd[Msg], base_ms : Int64) -> Int64? {
  if cmd.interval_ms > 0 {
    Some(base_ms + cmd.interval_ms.to_int64())
  } else {
    None
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn tick_timeout_ms(next_tick_ms : Int64?) -> Int {
  match next_tick_ms {
    Some(deadline) => Int64::max(0L, deadline - pippa_now_ms()).to_int()
    None => -1
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] apply_msg(
  program : Program[Model, Msg],
  model : Model,
  msg : Msg,
) -> (Model, Bool, Cmd[Msg]) {
  let res = (program.update)(model, msg)
  (res.model, (program.should_quit)(res.model), res.cmd)
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] run_internal(program : Program[Model, Msg]) -> Unit {
  pippa_enter_raw_mode()

  write_bytes(
    @utf8.encode(
      enter_alt_screen() + hide_cursor() + clear_screen() + move_cursor(1, 1),
    ),
  )
  if program.mouse {
    write_bytes(@utf8.encode(enable_mouse()))
  }

  let init_res = (program.init)()
  let mut model = init_res.model
  let mut tick_cmd = init_res.cmd
  let mut next_tick_ms = next_tick_at(tick_cmd, pippa_now_ms())

  let mut current_view = (program.view)(model)
  write_bytes(@utf8.encode(render_full(current_view, 0)))
  let mut prev_line_count = line_count(current_view)

  let mut buf : Array[Byte] = []
  let mut quit = false

  while not(quit) {
    let poll_result = pippa_poll_stdin(tick_timeout_ms(next_tick_ms))
    if poll_result < 0 {
      break
    }

    let mut updated = false

    if poll_result == 0 {
      let fired_at = pippa_now_ms()
      next_tick_ms = next_tick_at(tick_cmd, fired_at)
      match (program.on_tick)() {
        Some(msg) => {
          let (next_model, should_quit, next_cmd) = apply_msg(
            program, model, msg,
          )
          model = next_model
          tick_cmd = next_cmd
          next_tick_ms = next_tick_at(tick_cmd, fired_at)
          updated = true
          if should_quit {
            quit = true
          }
        }
        None => ()
      }
    } else if poll_result == 1 {
      let b = pippa_read_byte()
      if b < 0 {
        break
      }

      buf.push(b.to_byte())

      let bytes = Bytes::from_array(buf)
      let bv = bytes[:]
      let (events, leftover) = parse_all(bv)

      buf = []
      for i = 0; i < leftover.length(); i = i + 1 {
        buf.push(leftover[i])
      }

      for evt in events {
        match evt {
          Key(Modified("ctrl", "c")) => quit = true
          _ => ()
        }

        match (program.sub)(evt) {
          Some(msg) => {
            let now_ms = pippa_now_ms()
            let (next_model, should_quit, next_cmd) = apply_msg(
              program, model, msg,
            )
            model = next_model
            tick_cmd = next_cmd
            next_tick_ms = next_tick_at(tick_cmd, now_ms)
            updated = true
            if should_quit {
              quit = true
            }
          }
          None => ()
        }
      }
    }

    if pippa_check_resize() != 0 {
      let cols = pippa_get_cols()
      let rows = pippa_get_rows()
      updated = true
      match (program.on_resize)(cols, rows) {
        Some(msg) => {
          let now_ms = pippa_now_ms()
          let (next_model, should_quit, next_cmd) = apply_msg(
            program, model, msg,
          )
          model = next_model
          tick_cmd = next_cmd
          next_tick_ms = next_tick_at(tick_cmd, now_ms)
          if should_quit {
            quit = true
          }
        }
        None => ()
      }
    }

    if updated {
      let new_view = (program.view)(model)
      if new_view != current_view {
        write_bytes(@utf8.encode(render_full(new_view, prev_line_count)))
        current_view = new_view
        prev_line_count = line_count(new_view)
      }
    }
  }

  if program.mouse {
    write_bytes(@utf8.encode(disable_mouse()))
  }
  write_bytes(@utf8.encode(exit_alt_screen() + show_cursor()))
  pippa_exit_raw_mode()
}
