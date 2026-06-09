///|
/// A replay trigger resolved from process arguments or the environment: a key
/// token script plus the runtime options to drive `replay` with.
pub(all) struct ReplayTrigger {
  /// Key-token replay script handed to `encode`/`replay`.
  script : String
  /// Keep raw runtime ANSI output when true. Normalized output by default.
  raw_ansi : Bool
  /// Initial terminal width supplied to the headless runtime.
  width : Int
  /// Initial terminal height supplied to the headless runtime.
  height : Int
}

///|
fn parse_nonneg_int(text : StringView) -> Int? {
  if text.length() == 0 {
    return None
  }
  let mut value = 0
  for ch in text.iter() {
    if ch >= '0' && ch <= '9' {
      value = value * 10 + (ch.to_int() - '0'.to_int())
    } else {
      return None
    }
  }
  Some(value)
}

///|
/// Parse a positive `WxH` terminal size, returning `None` on any malformed part.
fn parse_size(text : String) -> (Int, Int)? {
  match text.to_lower().split_once("x") {
    Some((w, h)) =>
      match (parse_nonneg_int(w), parse_nonneg_int(h)) {
        (Some(width), Some(height)) if width > 0 && height > 0 =>
          Some((width, height))
        _ => None
      }
    None => None
  }
}

///|
/// Parse a `--replay <tokens>` trigger out of process arguments.
///
/// Recognized flags (both `--flag value` and `--flag=value` forms):
/// - `--replay <tokens>`: enable replay with the given key-token script.
/// - `--raw` / `--ansi`: keep raw runtime ANSI output (normalized otherwise).
/// - `--size <WxH>`: initial terminal size (default 80x24).
///
/// Returns `None` when no `--replay` flag is present, so callers fall through to
/// the interactive path.
pub fn parse_replay_args(args : Array[String]) -> ReplayTrigger? {
  let mut found = false
  let mut script = ""
  let mut raw_ansi = false
  let mut width = 80
  let mut height = 24
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--replay" {
      found = true
      // A following `--...` token is another option, not the script: treat this
      // like a bare trailing `--replay` (no script) and let that flag parse.
      if i + 1 < args.length() && !args[i + 1].has_prefix("--") {
        script = args[i + 1]
        i = i + 1
      }
    } else if arg.has_prefix("--replay=") {
      found = true
      script = arg[9:].to_owned()
    } else if arg == "--raw" || arg == "--ansi" {
      raw_ansi = true
    } else if arg == "--size" {
      // Only consume the next argv as the size value when it is not another
      // `--...` option; otherwise leave the default size and let that flag parse.
      if i + 1 < args.length() && !args[i + 1].has_prefix("--") {
        match parse_size(args[i + 1]) {
          Some((w, h)) => {
            width = w
            height = h
          }
          None => ()
        }
        i = i + 1
      }
    } else if arg.has_prefix("--size=") {
      match parse_size(arg[7:].to_owned()) {
        Some((w, h)) => {
          width = w
          height = h
        }
        None => ()
      }
    }
    i = i + 1
  }
  if found {
    Some({ script, raw_ansi, width, height })
  } else {
    None
  }
}

///|
/// Resolve a replay trigger from `PIPPA_REPLAY` environment variables, mirroring
/// the `color-profile.t` style of env-pinned cram fixtures.
///
/// - `PIPPA_REPLAY=<tokens>`: enable replay with the given key-token script.
/// - `PIPPA_REPLAY_RAW=1`: keep raw runtime ANSI output.
/// - `PIPPA_REPLAY_SIZE=<WxH>`: initial terminal size (default 80x24).
///
/// ⚠️ This reads the *ambient* environment, so an exported `PIPPA_REPLAY` in the
/// surrounding shell silently flips every app built on `maybe_run_replay` into
/// replay-and-exit (see the footgun caveat on `maybe_run_replay`). As a small
/// guard, a blank `export PIPPA_REPLAY=` (empty value) is treated as absent so it
/// cannot trigger an empty replay; any non-empty value still triggers, so prefer
/// the explicit `--replay` CLI flag and unset the env vars in tests.
fn replay_trigger_from_env() -> ReplayTrigger? {
  match @env.get_env_var("PIPPA_REPLAY") {
    None | Some("") => None
    Some(script) => {
      let raw_ansi = match @env.get_env_var("PIPPA_REPLAY_RAW") {
        Some(value) => value != "" && value != "0"
        None => false
      }
      let (width, height) = match @env.get_env_var("PIPPA_REPLAY_SIZE") {
        Some(value) =>
          match parse_size(value) {
            Some(size) => size
            None => (80, 24)
          }
        None => (80, 24)
      }
      Some({ script, raw_ansi, width, height })
    }
  }
}

///|
/// Per-frame delimiter line marking the start of frame `index` (0-based) in
/// joined replay output. A printable, deterministic marker so cram fixtures can
/// assert on an individual frame instead of one undelimited byte-mash.
///
/// `index` counts the non-empty captured output chunks `replay` recorded — it is
/// NOT the update-step index, and the count differs between raw and normalized
/// modes (normalization can reduce a control-only chunk to empty, which is then
/// dropped). The marker is a plaintext sentinel with no escaping or collision
/// guard: an app whose own view renders a literal `--- frame N ---` line is
/// indistinguishable from this delimiter.
fn frame_delimiter(index : Int) -> String {
  "--- frame \{index} ---"
}

///|
/// Join captured replay frames into a single printable stream, prefixing each
/// frame with a numbered `frame_delimiter` line so frames stay per-frame
/// separable in cram snapshots (F3).
///
/// This *assumes* captured frames carry no trailing newline — true for the
/// headless runtime's rendered chunks today, but an assumption rather than a
/// guarantee. Under it, a single `\n` separates each delimiter from its frame and
/// each frame from the next delimiter, and the final newline is added by
/// `println`; a frame that did end in `\n` would simply render a blank line ahead
/// of the next delimiter.
fn join_replay_frames(frames : Array[String]) -> String {
  let buf = StringBuilder::new()
  for i, frame in frames {
    if i > 0 {
      buf.write_string("\n")
    }
    buf.write_string(frame_delimiter(i))
    buf.write_string("\n")
    buf.write_string(frame)
  }
  buf.to_string()
}

///|
/// Detect a replay trigger from process arguments or the environment, run a
/// headless `replay`, print the captured frames to stdout, and report whether a
/// replay was handled.
///
/// Trigger (native, cram-authorable):
/// - CLI: `--replay <tokens> [--raw|--ansi] [--size <WxH>]`
/// - Env: `PIPPA_REPLAY=<tokens> PIPPA_REPLAY_RAW=1 PIPPA_REPLAY_SIZE=<WxH>`
///
/// Output is normalized by default; `--raw`/`PIPPA_REPLAY_RAW` keeps raw ANSI.
/// Frames are joined with a printable `--- frame N ---` delimiter line so the
/// per-frame boundaries stay separable (a cram fixture can assert on a single
/// frame). Returns `false` when no trigger is present, so callers fall through to
/// the interactive `@pippa.Program::run` path with byte-identical behavior.
///
/// ⚠️ FOOTGUN — the environment trigger is *ambient*. Because this consults
/// `PIPPA_REPLAY` on every launch, any shell with `export PIPPA_REPLAY=...` set
/// silently turns EVERY app built on `maybe_run_replay` into replay-and-exit
/// instead of starting interactively — there is no per-app opt-in. Prefer the
/// explicit `--replay` CLI flag, and in tests/CI unset `PIPPA_REPLAY`,
/// `PIPPA_REPLAY_RAW`, and `PIPPA_REPLAY_SIZE` (the cram suite does this with
/// `env -u` on every command). A blank `export PIPPA_REPLAY=` is ignored as a
/// small guard, but any non-empty value still triggers.
pub fn[Model, Msg] maybe_run_replay(
  program : @pippa.Program[Model, Msg],
) -> Bool {
  let trigger = match parse_replay_args(@env.args()) {
    Some(t) => Some(t)
    None => replay_trigger_from_env()
  }
  match trigger {
    None => false
    Some(t) => {
      let opts = ReplayOptions::default()
        .with_window_size(t.width, t.height)
        .with_raw_ansi(t.raw_ansi)
      let result = replay(program, t.script, opts)
      println(join_replay_frames(result.frames))
      true
    }
  }
}
