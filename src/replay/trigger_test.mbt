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
