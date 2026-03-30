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
  /// Produce a message when a tick command fires. Prefer `Cmd::after` for
  /// component-local clocks; `on_tick` is a compatibility hook for app-wide
  /// timers.
  on_tick : () -> Msg?
  /// Enable terminal mouse reporting while the program runs.
  mouse : Bool
  /// Enter the terminal alternate screen buffer while the program runs.
  alt_screen : Bool
  /// Enable terminal focus reporting while the program runs.
  focus_reporting : Bool
  /// Enable bracketed paste while the program runs.
  bracketed_paste : Bool
  /// Hide the terminal cursor while the program runs.
  hide_cursor : Bool
  /// Render view output and screen control sequences.
  rendering : Bool
  /// Read input events from stdin and enable terminal input modes.
  read_stdin : Bool
  /// Optional non-blocking input source polled by the runtime before waiting
  /// on stdin/timers. Return currently available events and never block.
  input : (() -> Array[InputEvent])?
  /// Write rendered output and terminal control sequences.
  output : (String) -> Unit
  /// Produce a message when the terminal size changes. Return None to ignore it.
  on_resize : (Int, Int) -> Msg?
  /// Return true to exit the event loop after an update.
  should_quit : (Model) -> Bool
}

///|
/// Handle for sending messages to a running program.
///
/// `send` is intended for the same MoonBit runtime thread. Native cross-thread
/// delivery of generic MoonBit values is not supported by the runtime today.
struct ProgramHandle[Msg] {
  pending_msgs : @queue.Queue[Msg]
  wake : () -> Unit
  closed : Ref[Bool]
}

///|
fn[Msg] ProgramHandle::new(
  pending_msgs : @queue.Queue[Msg],
  wake : () -> Unit,
  closed : Ref[Bool],
) -> ProgramHandle[Msg] {
  { pending_msgs, wake, closed }
}

///|
/// Enqueue a message for delivery to the running program.
pub fn[Msg] ProgramHandle::send(self : ProgramHandle[Msg], msg : Msg) -> Bool {
  if self.closed.val {
    false
  } else {
    self.pending_msgs.push(msg)
    (self.wake)()
    true
  }
}

///|
/// Returns true after the program has exited and the handle can no longer send.
pub fn[Msg] ProgramHandle::is_closed(self : ProgramHandle[Msg]) -> Bool {
  self.closed.val
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
  alt_screen? : Bool = true,
  focus_reporting? : Bool = true,
  bracketed_paste? : Bool = true,
  hide_cursor? : Bool = true,
  rendering? : Bool = true,
  read_stdin? : Bool = true,
  input? : (() -> Array[InputEvent])? = None,
  output? : (String) -> Unit = default_output,
  on_resize? : (Int, Int) -> Msg? = fn(_cols, _rows) { None },
  should_quit? : (Model) -> Bool = fn(_model) { false },
) -> Program[Model, Msg] {
  {
    init,
    update,
    view,
    sub,
    on_tick,
    mouse,
    alt_screen,
    focus_reporting,
    bracketed_paste,
    hide_cursor,
    rendering,
    read_stdin,
    input,
    output,
    on_resize,
    should_quit,
  }
}

///|
pub fn[Model, Msg] Program::with_alt_screen(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, alt_screen: enabled }
}

///|
pub fn[Model, Msg] Program::with_focus_reporting(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, focus_reporting: enabled }
}

///|
pub fn[Model, Msg] Program::with_bracketed_paste(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, bracketed_paste: enabled }
}

///|
pub fn[Model, Msg] Program::with_hide_cursor(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, hide_cursor: enabled }
}

///|
pub fn[Model, Msg] Program::with_rendering(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, rendering: enabled }
}

///|
pub fn[Model, Msg] Program::with_stdin(
  self : Program[Model, Msg],
  enabled : Bool,
) -> Program[Model, Msg] {
  { ..self, read_stdin: enabled }
}

///|
pub fn[Model, Msg] Program::with_input(
  self : Program[Model, Msg],
  input : () -> Array[InputEvent],
) -> Program[Model, Msg] {
  { ..self, input: Some(input), read_stdin: false }
}

///|
pub fn[Model, Msg] Program::with_output(
  self : Program[Model, Msg],
  output : (String) -> Unit,
) -> Program[Model, Msg] {
  { ..self, output, }
}

///|
pub fn[Model, Msg] Program::headless(
  self : Program[Model, Msg],
) -> Program[Model, Msg] {
  {
    ..self,
    mouse: false,
    alt_screen: false,
    focus_reporting: false,
    bracketed_paste: false,
    hide_cursor: false,
    rendering: false,
    read_stdin: false,
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn default_output(output : String) -> Unit {
  if output != "" {
    let bytes = @utf8.encode(output)
    pippa_write_bytes(bytes, bytes.length())
  }
}

///|
#cfg(not(any(target="native", target="llvm")))
fn default_output(_output : String) -> Unit {

}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] emit_output(
  program : Program[Model, Msg],
  output : String,
) -> Unit {
  if output != "" {
    (program.output)(output)
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] program_enter_sequence(program : Program[Model, Msg]) -> String {
  let buf = StringBuilder::new()
  if program.rendering {
    if program.alt_screen {
      buf.write_string(enter_alt_screen())
    }
    if program.hide_cursor {
      buf.write_string(hide_cursor())
    }
    buf.write_string(clear_screen())
    buf.write_string(move_cursor(1, 1))
  }
  if program.read_stdin && program.focus_reporting {
    buf.write_string(enable_focus_reporting())
  }
  if program.read_stdin && program.bracketed_paste {
    buf.write_string(enable_bracketed_paste())
  }
  buf.to_string()
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] program_exit_sequence(program : Program[Model, Msg]) -> String {
  let buf = StringBuilder::new()
  if program.read_stdin && program.focus_reporting {
    buf.write_string(disable_focus_reporting())
  }
  if program.read_stdin && program.bracketed_paste {
    buf.write_string(disable_bracketed_paste())
  }
  if program.rendering {
    if program.alt_screen {
      buf.write_string(exit_alt_screen())
    }
    if program.hide_cursor {
      buf.write_string(show_cursor())
    }
  }
  buf.to_string()
}

///|
/// Run the program.
///
/// On `native` and `llvm` targets this enters raw terminal mode and drives
/// the main event loop. On other targets this is a no-op.
pub fn[Model, Msg] Program::run(program : Program[Model, Msg]) -> Unit {
  run_internal(program, fn(_handle) { () })
}

///|
/// Run the program and expose a handle that can inject messages while it is
/// running.
pub fn[Model, Msg] Program::run_with_handle(
  program : Program[Model, Msg],
  on_start : (ProgramHandle[Msg]) -> Unit,
) -> Unit {
  run_internal(program, on_start)
}

///|
#cfg(not(any(target="native", target="llvm")))
fn[Model, Msg] run_internal(
  _program : Program[Model, Msg],
  on_start : (ProgramHandle[Msg]) -> Unit,
) -> Unit {
  on_start(ProgramHandle::new(@queue.Queue::new(), fn() { () }, Ref::new(true)))
}

///|
/// Active one-shot timer managed by the runtime.
#cfg(any(target="native", target="llvm"))
priv enum RuntimeTimer[Msg] {
  TickAt(Int64)
  AfterAt(Int64, () -> Msg?)
}

///|
#cfg(any(target="native", target="llvm"))
fn[Msg] timer_deadline(timer : RuntimeTimer[Msg]) -> Int64 {
  match timer {
    TickAt(deadline) => deadline
    AfterAt(deadline, _) => deadline
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Msg] queue_cmd_effects(
  cmd : Cmd[Msg],
  now : Int64,
  pending : @queue.Queue[() -> Msg?],
  timers : Array[RuntimeTimer[Msg]],
  sequences : @deque.Deque[Array[Cmd[Msg]]],
) -> Unit {
  for action in cmd.actions {
    match action {
      Perform(task) => pending.push(task)
      Tick(interval_ms) =>
        if interval_ms > 0 {
          timers.push(TickAt(now + interval_ms.to_int64()))
        }
      After(interval_ms, task) => {
        let ms = if interval_ms > 0 { interval_ms } else { 1 }
        timers.push(AfterAt(now + ms.to_int64(), fn() { Some(task()) }))
      }
      Sequence(cmds) =>
        match cmds {
          [] => ()
          [head, .. tail] => {
            queue_cmd_effects(head, now, pending, timers, sequences)
            if not(tail.is_empty()) {
              sequences.push_back(tail.to_array())
            }
          }
        }
    }
  }
}

///|
/// Compute the poll timeout from the earliest timer deadline. Returns -1 if
/// no timers are active (block indefinitely).
#cfg(any(target="native", target="llvm"))
fn[Msg] timers_timeout(timers : Array[RuntimeTimer[Msg]]) -> Int {
  let mut min_deadline : Int64? = None
  for timer in timers {
    match min_deadline {
      None => min_deadline = Some(timer_deadline(timer))
      Some(m) => {
        let deadline = timer_deadline(timer)
        if deadline < m {
          min_deadline = Some(deadline)
        }
      }
    }
  }
  match min_deadline {
    Some(deadline) => {
      let remaining = deadline - pippa_now_ms()
      if remaining < 0L {
        0
      } else {
        remaining.to_int()
      }
    }
    None => -1
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] runtime_timeout_ms(
  program : Program[Model, Msg],
  timers : Array[RuntimeTimer[Msg]],
) -> Int {
  let timeout = timers_timeout(timers)
  match program.input {
    Some(_) => if timeout < 0 || timeout > 16 { 16 } else { timeout }
    None => timeout
  }
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] poll_input_events(
  program : Program[Model, Msg],
) -> Array[InputEvent] {
  match program.input {
    Some(input) => input()
    None => []
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
fn[Model, Msg] apply_input_events(
  program : Program[Model, Msg],
  model : Model,
  events : Array[InputEvent],
  pending : @queue.Queue[() -> Msg?],
  timers : Array[RuntimeTimer[Msg]],
  sequences : @deque.Deque[Array[Cmd[Msg]]],
) -> (Model, Bool, Bool) {
  let mut current_model = model
  let mut quit = false
  let mut updated = false
  for evt in events {
    match evt {
      Key(Modified("ctrl", "c")) => quit = true
      _ => ()
    }
    match (program.sub)(evt) {
      Some(msg) => {
        let (next_model, should_quit, cmd) = apply_msg(
          program, current_model, msg,
        )
        current_model = next_model
        queue_cmd_effects(cmd, pippa_now_ms(), pending, timers, sequences)
        updated = true
        if should_quit {
          quit = true
        }
      }
      None => ()
    }
    if quit {
      break
    }
  }
  (current_model, quit, updated)
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] drain_runtime(
  program : Program[Model, Msg],
  model : Model,
  sent_msgs : @queue.Queue[Msg],
  pending : @queue.Queue[() -> Msg?],
  timers : Array[RuntimeTimer[Msg]],
  sequences : @deque.Deque[Array[Cmd[Msg]]],
) -> (Model, Bool, Bool) {
  let mut current_model = model
  let mut quit = false
  let mut updated = false
  while not(quit) {
    let mut progressed = false

    while not(quit) && not(sent_msgs.is_empty()) {
      let msg = sent_msgs.pop().unwrap()
      let (next_model, should_quit, cmd) = apply_msg(
        program, current_model, msg,
      )
      current_model = next_model
      updated = true
      progressed = true
      queue_cmd_effects(cmd, pippa_now_ms(), pending, timers, sequences)
      if should_quit {
        quit = true
      }
    }

    while not(quit) && not(pending.is_empty()) {
      let task = pending.pop().unwrap()
      progressed = true
      match task() {
        Some(msg) => {
          let (next_model, should_quit, cmd) = apply_msg(
            program, current_model, msg,
          )
          current_model = next_model
          updated = true
          queue_cmd_effects(cmd, pippa_now_ms(), pending, timers, sequences)
          if should_quit {
            quit = true
          }
        }
        None => ()
      }
    }

    if quit {
      break
    }

    if pending.is_empty() && sent_msgs.is_empty() {
      match sequences.pop_front() {
        Some([head, .. tail]) => {
          queue_cmd_effects(head, pippa_now_ms(), pending, timers, sequences)
          if not(tail.is_empty()) {
            sequences.push_back(tail.to_array())
          }
          progressed = true
        }
        Some([]) => progressed = true
        None => ()
      }
    }

    if not(progressed) {
      break
    }
  }
  (current_model, quit, updated)
}

///|
#cfg(any(target="native", target="llvm"))
fn[Model, Msg] run_internal(
  program : Program[Model, Msg],
  on_start : (ProgramHandle[Msg]) -> Unit,
) -> Unit {
  if program.read_stdin {
    pippa_enter_raw_mode()
  }
  pippa_init_wakeup()

  let enter_seq = program_enter_sequence(program)
  emit_output(program, enter_seq)
  defer pippa_close_wakeup()
  if program.rendering && program.read_stdin && program.mouse {
    emit_output(program, enable_mouse())
  }

  let init_res = (program.init)()
  let mut model = init_res.model
  let sent_msgs = @queue.Queue::new()
  let handle_closed = Ref::new(false)
  let handle = ProgramHandle::new(sent_msgs, pippa_signal_wakeup, handle_closed)
  let pending = @queue.Queue::new()
  let sequences = @deque.Deque::new()
  let mut timers : Array[RuntimeTimer[Msg]] = []
  queue_cmd_effects(init_res.cmd, pippa_now_ms(), pending, timers, sequences)
  on_start(handle)

  let mut current_view = if program.rendering {
    (program.view)(model)
  } else {
    ""
  }
  if program.rendering {
    emit_output(program, render_full(current_view, 0))
  }
  let mut prev_line_count = if program.rendering {
    line_count(current_view)
  } else {
    0
  }

  let mut buf : Array[Byte] = []
  let mut quit = false

  while not(quit) {
    let (drained_model, drained_quit, drained_updated) = drain_runtime(
      program, model, sent_msgs, pending, timers, sequences,
    )
    model = drained_model
    if drained_quit {
      quit = true
    }
    if drained_updated {
      if program.rendering {
        let new_view = (program.view)(model)
        if new_view != current_view {
          let ops = diff_views(current_view, new_view)
          let output = if ops.is_empty() {
            render_full(new_view, prev_line_count)
          } else {
            render_patch(ops)
          }
          emit_output(program, output)
          current_view = new_view
          prev_line_count = line_count(new_view)
        }
      }
    }
    if quit {
      break
    }

    let mut updated = false
    let (input_model, input_quit, input_updated) = apply_input_events(
      program,
      model,
      poll_input_events(program),
      pending,
      timers,
      sequences,
    )
    model = input_model
    if input_quit {
      quit = true
    }
    if input_updated {
      updated = true
    }
    if quit {
      break
    }

    if not(updated) {
      let poll_result = pippa_poll_events(
        runtime_timeout_ms(program, timers),
        if program.read_stdin {
          1
        } else {
          0
        },
      )
      if poll_result < 0 {
        break
      }

      if poll_result == 0 {
        let now = pippa_now_ms()
        let remaining : Array[RuntimeTimer[Msg]] = []
        for timer in timers {
          if timer_deadline(timer) <= now {
            match timer {
              TickAt(_) => pending.push(program.on_tick)
              AfterAt(_, task) => pending.push(task)
            }
          } else {
            remaining.push(timer)
          }
        }
        timers = remaining
      } else {
        if (poll_result & 4) != 0 {
          pippa_drain_wakeup()
        }
        if (poll_result & 1) != 0 {
          let b = pippa_read_byte()
          if b < 0 {
            break
          }

          buf.push(b.to_byte())

          let bytes = Bytes::from_array(buf)
          let bv = bytes[:]
          let (events, leftover) = parse_all(bv)

          buf = leftover.to_array()

          let (next_model, should_quit, input_updated) = apply_input_events(
            program, model, events, pending, timers, sequences,
          )
          model = next_model
          if should_quit {
            quit = true
          }
          if input_updated {
            updated = true
          }
        }
      }
    }

    if program.read_stdin && pippa_check_resize() != 0 {
      let cols = pippa_get_cols()
      let rows = pippa_get_rows()
      updated = true
      match (program.on_resize)(cols, rows) {
        Some(msg) => {
          let (next_model, should_quit, cmd) = apply_msg(program, model, msg)
          model = next_model
          queue_cmd_effects(cmd, pippa_now_ms(), pending, timers, sequences)
          if should_quit {
            quit = true
          }
        }
        None => ()
      }
    }

    let (final_model, final_quit, final_updated) = drain_runtime(
      program, model, sent_msgs, pending, timers, sequences,
    )
    model = final_model
    if final_quit {
      quit = true
    }
    if final_updated {
      updated = true
    }

    if updated {
      if program.rendering {
        let new_view = (program.view)(model)
        if new_view != current_view {
          let ops = diff_views(current_view, new_view)
          let output = if ops.is_empty() {
            render_full(new_view, prev_line_count)
          } else {
            render_patch(ops)
          }
          emit_output(program, output)
          current_view = new_view
          prev_line_count = line_count(new_view)
        }
      }
    }
  }
  handle_closed.val = true

  if program.rendering && program.read_stdin && program.mouse {
    emit_output(program, disable_mouse())
  }
  let exit_seq = program_exit_sequence(program)
  emit_output(program, exit_seq)
  if program.read_stdin {
    pippa_exit_raw_mode()
  }
}
