///|
test "parse_replay_args reads script, raw, and size flags" {
  match
    parse_replay_args([
      "list-parity-app", "--replay", "down enter", "--raw", "--size", "40x12",
    ]) {
    Some(t) => {
      assert_eq(t.script, "down enter")
      assert_true(t.raw_ansi)
      assert_eq(t.width, 40)
      assert_eq(t.height, 12)
    }
    None => abort("expected a replay trigger")
  }
}

///|
test "parse_replay_args supports --flag=value forms and 80x24 defaults" {
  match parse_replay_args(["--replay=tab tab", "--size=100x30"]) {
    Some(t) => {
      assert_eq(t.script, "tab tab")
      assert_false(t.raw_ansi)
      assert_eq(t.width, 100)
      assert_eq(t.height, 30)
    }
    None => abort("expected a replay trigger")
  }
}

///|
test "parse_replay_args treats --ansi as a raw alias and a bare --replay as empty script" {
  match parse_replay_args(["--ansi", "--replay"]) {
    Some(t) => {
      assert_eq(t.script, "")
      assert_true(t.raw_ansi)
      assert_eq(t.width, 80)
      assert_eq(t.height, 24)
    }
    None => abort("expected a replay trigger")
  }
}

///|
test "parse_replay_args returns None without --replay" {
  assert_true(parse_replay_args(["--raw", "--size", "40x12"]) is None)
}

///|
test "parse_replay_args reads --clock-step and --drain-polls in both forms" {
  match
    parse_replay_args([
      "--replay", "s", "--clock-step", "250", "--drain-polls", "6",
    ]) {
    Some(t) => {
      assert_eq(t.clock_step_ms, 250)
      assert_eq(t.drain_empty_polls, 6)
    }
    None => abort("expected a replay trigger")
  }
  match
    parse_replay_args(["--replay=s", "--clock-step=300", "--drain-polls=9"]) {
    Some(t) => {
      assert_eq(t.clock_step_ms, 300)
      assert_eq(t.drain_empty_polls, 9)
    }
    None => abort("expected a replay trigger")
  }
}

///|
test "parse_replay_args defaults the clock step and drain window and ignores malformed values" {
  // Absent flags fall back to the ReplayOptions defaults (20ms / 4 polls).
  match parse_replay_args(["--replay", "s"]) {
    Some(t) => {
      assert_eq(t.clock_step_ms, 20)
      assert_eq(t.drain_empty_polls, 4)
    }
    None => abort("expected a replay trigger")
  }
  // A non-numeric value keeps the default; a following `--...` is not swallowed
  // as the value, so it still parses on its own (here `--raw`).
  match
    parse_replay_args([
      "--replay", "s", "--clock-step", "fast", "--drain-polls", "--raw",
    ]) {
    Some(t) => {
      assert_eq(t.clock_step_ms, 20)
      assert_eq(t.drain_empty_polls, 4)
      assert_true(t.raw_ansi)
    }
    None => abort("expected a replay trigger")
  }
}

///|
test "parse_replay_args does not swallow a following --flag as the --replay script" {
  match parse_replay_args(["--replay", "--raw"]) {
    Some(t) => {
      // The following `--raw` is another option, not the script: no script is
      // provided (same as a bare trailing `--replay`) and `--raw` still parses.
      assert_eq(t.script, "")
      assert_true(t.raw_ansi)
      assert_eq(t.width, 80)
      assert_eq(t.height, 24)
    }
    None => abort("expected a replay trigger")
  }
}

///|
test "parse_replay_args treats a following --size as no --replay script" {
  match parse_replay_args(["--replay", "--size", "20x5"]) {
    Some(t) => {
      // `--replay` takes no value here; the `--size 20x5` that follows is parsed
      // on its own rather than being consumed as the script token.
      assert_eq(t.script, "")
      assert_false(t.raw_ansi)
      assert_eq(t.width, 20)
      assert_eq(t.height, 5)
    }
    None => abort("expected a replay trigger")
  }
}

///|
test "parse_replay_args does not swallow a following --flag as the --size value" {
  match parse_replay_args(["--replay=app", "--size", "--raw"]) {
    Some(t) => {
      // `--size` takes no value when the next token is another option, so the
      // default 80x24 holds and the following `--raw` still parses.
      assert_eq(t.script, "app")
      assert_true(t.raw_ansi)
      assert_eq(t.width, 80)
      assert_eq(t.height, 24)
    }
    None => abort("expected a replay trigger")
  }
}
