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
      if i + 1 < args.length() {
        script = args[i + 1]
        i = i + 1
      }
    } else if arg.has_prefix("--replay=") {
      found = true
      script = arg[9:].to_owned()
    } else if arg == "--raw" || arg == "--ansi" {
      raw_ansi = true
    } else if arg == "--size" {
      if i + 1 < args.length() {
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
fn replay_trigger_from_env() -> ReplayTrigger? {
  match @env.get_env_var("PIPPA_REPLAY") {
    None => None
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
/// Detect a replay trigger from process arguments or the environment, run a
/// headless `replay`, print the captured frames to stdout, and report whether a
/// replay was handled.
///
/// Trigger (native, cram-authorable):
/// - CLI: `--replay <tokens> [--raw|--ansi] [--size <WxH>]`
/// - Env: `PIPPA_REPLAY=<tokens> PIPPA_REPLAY_RAW=1 PIPPA_REPLAY_SIZE=<WxH>`
///
/// Output is normalized by default; `--raw`/`PIPPA_REPLAY_RAW` keeps raw ANSI.
/// Returns `false` when no trigger is present, so callers fall through to the
/// interactive `@pippa.Program::run` path with byte-identical behavior.
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
      println(result.frames.join(""))
      true
    }
  }
}
