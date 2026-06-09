///|
/// A single pure replay step.
///
/// `Input` is translated through the caller's `sub` function before update.
/// `Message` is applied directly, which is useful for deterministic timer and
/// component tick fixtures.
pub(all) enum ReplayStep[Msg] {
  Input(@pippa.InputEvent)
  Message(Msg)
}

///|
/// Options for runtime replay.
pub(all) struct ReplayOptions {
  /// Initial terminal width supplied through `Program::with_window_size`.
  width : Int
  /// Initial terminal height supplied through `Program::with_window_size`.
  height : Int
  /// Keep raw runtime ANSI output when true. Output is normalized by default.
  raw_ansi : Bool
  /// Optional deterministic monotonic clock for `Program::with_clock`.
  clock : (() -> Int64)?
  /// Empty raw-input polls to wait after the script has drained before cancel.
  drain_empty_polls : Int
}

///|
/// Captured runtime replay output and final model.
pub(all) struct ReplayResult[Model] {
  /// Captured output chunks after optional normalization.
  frames : Array[String]
  /// Final model returned by `Program::run`.
  final_model : Model
}

///|
/// Default replay options: 80x24, normalized output, and a deterministic clock.
pub fn ReplayOptions::default() -> ReplayOptions {
  { width: 80, height: 24, raw_ansi: false, clock: None, drain_empty_polls: 4 }
}

///|
/// Return options with a different initial window size.
pub fn ReplayOptions::with_window_size(
  self : ReplayOptions,
  width : Int,
  height : Int,
) -> ReplayOptions {
  { ..self, width, height }
}

///|
/// Return options that keep or normalize raw ANSI runtime output.
pub fn ReplayOptions::with_raw_ansi(
  self : ReplayOptions,
  raw_ansi : Bool,
) -> ReplayOptions {
  { ..self, raw_ansi, }
}

///|
/// Return options with an explicit deterministic monotonic clock.
pub fn ReplayOptions::with_clock(
  self : ReplayOptions,
  clock : () -> Int64,
) -> ReplayOptions {
  { ..self, clock: Some(clock) }
}

///|
/// Return options with a different post-script drain poll count.
pub fn ReplayOptions::with_drain_empty_polls(
  self : ReplayOptions,
  drain_empty_polls : Int,
) -> ReplayOptions {
  { ..self, drain_empty_polls: drain_empty_polls.max(1) }
}

///|
fn default_replay_context() -> @profile.RenderContext {
  @profile.RenderContext::default()
  .with_color_profile(@profile.TrueColor)
  .with_color_policy(@profile.Always)
}

///|
fn[Model] render_frame(
  model : Model,
  view : (Model) -> String,
  ctx : @profile.RenderContext,
) -> String {
  @profile.with_render_context(ctx, fn() { view(model) })
}

///|
/// Fold a scripted sequence through `init` and `update`, rendering after init
/// and after each step under a pinned truecolor render context.
pub fn[Model, Msg] replay_frames(
  init~ : () -> @pippa.UpdateResult[Model, Msg],
  update~ : (Model, Msg) -> @pippa.UpdateResult[Model, Msg],
  view~ : (Model) -> String,
  script~ : Array[ReplayStep[Msg]],
  sub? : (@pippa.InputEvent) -> Msg? = fn(_event) { None },
  ctx? : @profile.RenderContext = default_replay_context(),
) -> Array[String] {
  let frames : Array[String] = []
  let mut model = init().model
  frames.push(render_frame(model, view, ctx))
  for step in script {
    match step {
      Input(event) =>
        match sub(event) {
          Some(msg) => model = update(model, msg).model
          None => ()
        }
      Message(msg) => model = update(model, msg).model
    }
    frames.push(render_frame(model, view, ctx))
  }
  frames
}

///|
fn is_token_separator(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'
}

///|
fn push_bytes(out : Array[Byte], text : String) -> Unit {
  for byte in @utf8.encode(text).to_array() {
    out.push(byte)
  }
}

///|
fn push_byte_values(out : Array[Byte], bytes : Array[Byte]) -> Unit {
  for byte in bytes {
    out.push(byte)
  }
}

///|
fn ctrl_token_byte(token : String) -> Byte? {
  let chars = token.to_array()
  if chars.length() == 6 &&
    chars[0] == 'c' &&
    chars[1] == 't' &&
    chars[2] == 'r' &&
    chars[3] == 'l' &&
    chars[4] == '+' {
    let ch = chars[5]
    if ch >= 'a' && ch <= 'z' {
      return Some((ch.to_int() - 0x60).to_byte())
    }
  }
  None
}

///|
fn encode_token(out : Array[Byte], token : String) -> Unit {
  let lower = token.to_lower()
  match lower {
    "" => ()
    "enter" | "return" => out.push(b'\r')
    "tab" => out.push(b'\t')
    "space" => out.push(b' ')
    "backspace" | "bs" => out.push(b'\x7F')
    "esc" | "escape" => push_byte_values(out, [b'\x1B', b'\x1B'])
    "up" => push_byte_values(out, [b'\x1B', b'[', b'A'])
    "down" => push_byte_values(out, [b'\x1B', b'[', b'B'])
    "right" => push_byte_values(out, [b'\x1B', b'[', b'C'])
    "left" => push_byte_values(out, [b'\x1B', b'[', b'D'])
    _ =>
      match ctrl_token_byte(lower) {
        Some(byte) => out.push(byte)
        None => push_bytes(out, token)
      }
  }
}

///|
/// Encode line- or space-delimited replay key tokens as terminal input bytes.
///
/// Recognized tokens include printable text, `enter`, `esc`, `tab`, `space`,
/// `backspace`, arrows, and `ctrl+<letter>`.
pub fn encode(script : String) -> Bytes {
  let out : Array[Byte] = []
  let mut token : Array[Char] = []
  for ch in script {
    if is_token_separator(ch) {
      if !token.is_empty() {
        encode_token(out, String::from_array(token))
        token = []
      }
    } else {
      token.push(ch)
    }
  }
  if !token.is_empty() {
    encode_token(out, String::from_array(token))
  }
  Bytes::from_array(out)
}

///|
fn is_csi_final(ch : Char) -> Bool {
  let code = ch.to_int()
  code >= 0x40 && code <= 0x7E
}

///|
fn write_chars(
  buf : StringBuilder,
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> Unit {
  for i in start..<end_index {
    buf.write_char(chars[i])
  }
}

///|
fn skip_csi(chars : Array[Char], start : Int) -> (Int, Bool) {
  let mut i = start + 2
  while i < chars.length() {
    if is_csi_final(chars[i]) {
      return (i + 1, chars[i] == 'm')
    }
    i = i + 1
  }
  (chars.length(), false)
}

///|
fn skip_string_control(chars : Array[Char], start : Int) -> Int {
  let mut i = start + 2
  while i < chars.length() {
    if chars[i] == '\u{0007}' {
      return i + 1
    }
    if chars[i] == '\u001b' && i + 1 < chars.length() && chars[i + 1] == '\\' {
      return i + 2
    }
    i = i + 1
  }
  chars.length()
}

///|
/// Strip runtime cursor, clear-screen, alternate-screen, synchronized-output,
/// OSC, and DCS controls while preserving SGR styling and printable text.
pub fn normalize(output : String) -> String {
  let chars = output.to_array()
  let buf = StringBuilder::new(size_hint=chars.length())
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\u001b' {
      if i + 1 >= chars.length() {
        i = i + 1
      } else if chars[i + 1] == '[' {
        let (next, keep_sgr) = skip_csi(chars, i)
        if keep_sgr {
          write_chars(buf, chars, i, next)
        }
        i = next
      } else if chars[i + 1] == ']' || chars[i + 1] == 'P' {
        i = skip_string_control(chars, i)
      } else {
        i = i + 2
      }
    } else {
      buf.write_char(chars[i])
      i = i + 1
    }
  }
  buf.to_string()
}

///|
#cfg(any(target="native", target="llvm"))
fn replay_clock(opts : ReplayOptions) -> () -> Int64 {
  match opts.clock {
    Some(clock) => clock
    None => {
      let now = Ref(0L)
      fn() {
        now.val = now.val + 20L
        now.val
      }
    }
  }
}

///|
fn[Model] replay_model_from_run_result(
  result : @pippa.RunResult[Model],
) -> Model {
  match result {
    @pippa.RunCompleted(model) => model
    @pippa.RunQuit(model) => model
    @pippa.RunInterrupted(model) => model
    @pippa.RunExec(model, _) => model
    @pippa.RunRuntimeError(message) =>
      abort("pippa replay runtime error: \{message}")
  }
}

///|
/// Drive a `Program::run` loop headlessly through public runtime seams and
/// capture rendered output chunks plus the final model.
#cfg(any(target="native", target="llvm"))
pub fn[Model, Msg] replay(
  program : @pippa.Program[Model, Msg],
  script : String,
  opts : ReplayOptions,
) -> ReplayResult[Model] {
  let bytes = encode(script)
  let fed = Ref(false)
  let empty_polls = Ref(0)
  let frames : Array[String] = []
  let capture = fn(output : String) {
    let frame = if opts.raw_ansi { output } else { normalize(output) }
    if frame != "" {
      frames.push(frame)
    }
  }
  let raw_input = fn() {
    if fed.val {
      empty_polls.val = empty_polls.val + 1
      Bytes::new(0)
    } else {
      fed.val = true
      if bytes.length() == 0 {
        empty_polls.val = empty_polls.val + 1
      }
      bytes
    }
  }
  let cancelled = fn() { fed.val && empty_polls.val >= opts.drain_empty_polls }
  let result = program
    .headless()
    .with_rendering(true)
    .with_output(capture)
    .with_raw_input(raw_input)
    .with_window_size(opts.width, opts.height)
    .with_cancelled(cancelled)
    .with_clock(replay_clock(opts))
    .run()
  { frames, final_model: replay_model_from_run_result(result) }
}

///|
/// Non-native fallback for packages that compile replay outside the native
/// runtime targets.
#cfg(not(any(target="native", target="llvm")))
pub fn[Model, Msg] replay(
  program : @pippa.Program[Model, Msg],
  script : String,
  opts : ReplayOptions,
) -> ReplayResult[Model] {
  ignore(script)
  ignore(opts)
  let result = program.headless().run()
  { frames: [], final_model: replay_model_from_run_result(result) }
}
