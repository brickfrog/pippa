///|
/// Program configuration and entry-point for a Pippa TUI application.
///
/// A `Program[Model, Msg]` ties together the three core functions of the Elm
/// Architecture (init, update, view) and drives the main event loop.
///
/// Construct with `Program::new` and run with `Program::run` (not yet
/// implemented).

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
  /// Map input events to messages.
  sub : (InputEvent) -> Msg?
}

///|
/// Create a new Program from init, update, and view functions.
pub fn[Model, Msg] Program::new(
  init~ : () -> UpdateResult[Model, Msg],
  update~ : (Model, Msg) -> UpdateResult[Model, Msg],
  view~ : (Model) -> String,
  sub? : (InputEvent) -> Msg? = fn(_evt) { None },
) -> Program[Model, Msg] {
  { init, update, view, sub }
}

///|
/// Run the program (placeholder — will enter raw terminal mode and drive the
/// event loop).
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
  for i = 0; i < bytes.length(); i = i + 1 {
    pippa_write_byte(bytes[i].to_int())
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] run_internal(program : Program[Model, Msg]) -> Unit {
  pippa_enter_raw_mode()

  // Hide cursor and clear screen
  let hide_cursor = "\u001b[?25l"
  let clear_screen = "\u001b[2J\u001b[H"
  write_bytes((hide_cursor + clear_screen).to_bytes())

  let init_res = (program.init)()
  let mut model = init_res.model

  let mut current_view = (program.view)(model)
  write_bytes(current_view.to_bytes())

  let mut buf : Array[Byte] = []
  let mut quit = false

  while not(quit) {
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

    let mut updated = false

    for evt in events {
      match evt {
        Key(Modified("ctrl", "c")) => quit = true
        _ => ()
      }

      match (program.sub)(evt) {
        Some(msg) => {
          let res = (program.update)(model, msg)
          model = res.model
          updated = true
        }
        None => ()
      }
    }

    if updated {
      let new_view = (program.view)(model)
      let patches = diff_views(current_view, new_view)
      let patch_str = render_patch(patches)
      if patch_str.length() > 0 {
        write_bytes(patch_str.to_bytes())
        current_view = new_view
      }
    }
  }

  let show_cursor = "\u001b[?25h"
  write_bytes(show_cursor.to_bytes())

  pippa_exit_raw_mode()
}
