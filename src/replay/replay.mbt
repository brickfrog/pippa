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
  /// Clamped to at least 1 at use-site in `replay`, so a 0 (or negative) value
  /// cannot fire cancellation before the scripted input is processed and
  /// rendered.
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
/// Default replay options: an 80x24 terminal, normalized output, no explicit
/// clock, and a 4-poll post-script drain window.
///
/// `clock` is `None` here; determinism does not come from this default but from
/// `replay`, which falls back to `replay_clock`'s monotonic +20ms counter when
/// no clock is supplied.
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
/// Raised by `encode` for a token that is neither a recognized key name, a
/// `ctrl+<a-z>` chord, a single literal character, nor a `text:` escape. The
/// payload is a human-readable diagnostic. `replay` surfaces this as a loud
/// abort; callers that drive `encode` directly can catch it.
pub suberror EncodeError {
  EncodeError(String)
}

///|
fn encode_token(
  out : Array[Byte],
  token : String,
  is_final~ : Bool,
) -> Unit raise EncodeError {
  let lower = token.to_lower()
  match lower {
    "" => ()
    "enter" | "return" => out.push(b'\r')
    "tab" => out.push(b'\t')
    "space" => out.push(b' ')
    "backspace" | "bs" => out.push(b'\x7F')
    "esc" | "escape" =>
      // `esc` encodes ESC ESC so the first ESC parses as a definite standalone
      // escape; a lone trailing ESC would be Incomplete (ambiguous with a CSI
      // start). A non-final ESC would bind to the next token's first byte
      // (Alt+key) or inject an extra escape, so it is rejected loudly here.
      if is_final {
        push_byte_values(out, [b'\x1B', b'\x1B'])
      } else {
        raise EncodeError(
          "pippa replay: `esc`/`escape` may only appear as the final token of a script. A terminal byte stream cannot distinguish a standalone ESC keypress from ESC+key (Alt) without timing, so a mid-script `esc` would corrupt the following token. Move `esc` to the end of the script, or drop it.",
        )
      }
    "up" => push_byte_values(out, [b'\x1B', b'[', b'A'])
    "down" => push_byte_values(out, [b'\x1B', b'[', b'B'])
    "right" => push_byte_values(out, [b'\x1B', b'[', b'C'])
    "left" => push_byte_values(out, [b'\x1B', b'[', b'D'])
    "home" => push_byte_values(out, [b'\x1B', b'[', b'H'])
    "end" => push_byte_values(out, [b'\x1B', b'[', b'F'])
    "delete" | "del" => push_byte_values(out, [b'\x1B', b'[', b'3', b'~'])
    "pageup" | "pgup" => push_byte_values(out, [b'\x1B', b'[', b'5', b'~'])
    "pagedown" | "pgdn" => push_byte_values(out, [b'\x1B', b'[', b'6', b'~'])
    _ =>
      match ctrl_token_byte(lower) {
        Some(byte) => out.push(byte)
        None => encode_text_token(out, token, lower)
      }
  }
}

///|
/// Encode a token that is not a recognized key name as literal text, or raise
/// `EncodeError` when it cannot be one.
///
/// A `text:` prefix types its remainder verbatim, so literal text that collides
/// with a key name (e.g. `text:up`) is still expressible. A bare single
/// character is typed as-is, which is how short literal runs like `/ f z` are
/// written. Any other multi-character token is rejected loudly instead of being
/// silently typed — this catches typos and unsupported key names such as
/// `pgdown` that would otherwise masquerade as typed text.
fn encode_text_token(
  out : Array[Byte],
  token : String,
  lower : String,
) -> Unit raise EncodeError {
  if lower.has_prefix("text:") {
    push_bytes(out, token[5:].to_owned())
  } else if token.to_array().length() == 1 {
    push_bytes(out, token)
  } else {
    raise EncodeError(
      "pippa replay: unknown key token \"\{token}\". Recognized tokens: enter, return, tab, space, backspace/bs, esc/escape, up, down, left, right, home, end, delete/del, pageup/pgup, pagedown/pgdn, ctrl+<a-z>. Type literal text as single-character tokens (use the `space` token for a literal space) or with a `text:` prefix, e.g. `text:hello`.",
    )
  }
}

///|
/// Split a script into its whitespace-delimited tokens, preserving order and
/// dropping the empty runs between separators.
fn tokenize(script : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut token : Array[Char] = []
  for ch in script {
    if is_token_separator(ch) {
      if !token.is_empty() {
        tokens.push(String::from_array(token))
        token = []
      }
    } else {
      token.push(ch)
    }
  }
  if !token.is_empty() {
    tokens.push(String::from_array(token))
  }
  tokens
}

///|
/// Encode line- or space-delimited replay key tokens as terminal input bytes.
///
/// Recognized key tokens (case-insensitive): `enter`/`return`, `tab`, `space`,
/// `backspace`/`bs`, `esc`/`escape`, `up`, `down`, `left`, `right`, `home`,
/// `end`, `delete`/`del`, `pageup`/`pgup`, `pagedown`/`pgdn`, and `ctrl+<a-z>`.
/// Apart from `esc`/`escape` (see below), their byte sequences round-trip
/// through `@pippa.parse_input`/`parse_all`.
///
/// `esc`/`escape` is only accepted as the **final** token of a script. A
/// terminal byte stream cannot distinguish a standalone ESC keypress from
/// ESC+key (Alt) without timing, so `esc` encodes `ESC ESC` to make the first
/// ESC parse as a definite standalone `escape` (the trailing ESC is left as an
/// incomplete byte). As the final token it therefore round-trips to a single
/// `escape` event; a non-final `esc` would corrupt the following token and so
/// raises `EncodeError`.
///
/// Literal text is written as single-character tokens (`/ f z` types `fz`) or
/// with an explicit `text:` prefix (`text:hello`, including runs that collide
/// with a key name such as `text:up`). Because tokens are whitespace-delimited,
/// an embedded space is written with the `space` token: both `a space b` and
/// `text:a space text:b` type `a b`.
///
/// Unknown multi-character tokens (e.g. a misspelled `pgdown`) raise
/// `EncodeError` rather than being silently typed as text.
pub fn encode(script : String) -> Bytes raise EncodeError {
  let tokens = tokenize(script)
  let out : Array[Byte] = []
  let last = tokens.length() - 1
  for i, token in tokens {
    encode_token(out, token, is_final=i == last)
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
/// Effective number of empty drain polls `replay` waits for after the script
/// drains. Clamped to at least 1 so a 0 (or negative) configured
/// `drain_empty_polls` cannot cancel the loop before scripted input is processed
/// and rendered.
#cfg(any(target="native", target="llvm"))
fn effective_drain_polls(configured : Int) -> Int {
  configured.max(1)
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
///
/// Aborts the process if `script` fails to `encode` (an unknown key token or a
/// non-final `esc`); callers that need to recover should `encode` the script
/// themselves and handle `EncodeError`.
#cfg(any(target="native", target="llvm"))
pub fn[Model, Msg] replay(
  program : @pippa.Program[Model, Msg],
  script : String,
  opts : ReplayOptions,
) -> ReplayResult[Model] {
  let bytes = encode(script) catch { EncodeError(message) => abort(message) }
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
  // Clamp to at least one drain poll so a 0 (or negative) `drain_empty_polls`
  // cannot cancel the loop before the scripted input is processed and rendered.
  let drain_polls = effective_drain_polls(opts.drain_empty_polls)
  let cancelled = fn() { fed.val && empty_polls.val >= drain_polls }
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
