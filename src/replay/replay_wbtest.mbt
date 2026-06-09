///|
#cfg(any(target="native", target="llvm"))
test "effective drain polls clamps non-positive values to one" {
  // The precise F7 guard: a bypassed `drain_empty_polls` of 0 (or negative)
  // resolves to at least one drain poll, so `replay`'s cancellation predicate
  // cannot fire before scripted input is processed and rendered.
  inspect(effective_drain_polls(0), content="1")
  inspect(effective_drain_polls(-7), content="1")
  inspect(effective_drain_polls(1), content="1")
  inspect(effective_drain_polls(4), content="4")
}

///|
test "join_replay_frames separates frames with a numbered delimiter line" {
  // F3: `maybe_run_replay` joins captured frames with a printable, numbered
  // delimiter line so cram fixtures can assert per-frame instead of on one
  // undelimited byte-mash.
  inspect(
    join_replay_frames(["alpha", "beta"]),
    content=(
      #|--- frame 0 ---
      #|alpha
      #|--- frame 1 ---
      #|beta
    ),
  )
}

///|
test "join_replay_frames renders a single frame with its own delimiter" {
  inspect(
    join_replay_frames(["only"]),
    content=(
      #|--- frame 0 ---
      #|only
    ),
  )
}

///|
#cfg(any(target="native", target="llvm"))
test "replay_trigger_from_env ignores a blank PIPPA_REPLAY and honors a non-empty one" {
  fn clear_replay_env() -> Unit {
    @env.unset_env_var("PIPPA_REPLAY")
    @env.unset_env_var("PIPPA_REPLAY_RAW")
    @env.unset_env_var("PIPPA_REPLAY_SIZE")
    @env.unset_env_var("PIPPA_REPLAY_CLOCK_STEP")
    @env.unset_env_var("PIPPA_REPLAY_DRAIN_POLLS")
  }

  clear_replay_env()
  // Unset: there is no env trigger at all.
  assert_true(replay_trigger_from_env() is None)
  // F10 guard: a blank `export PIPPA_REPLAY=` must NOT flip the app into
  // replay-and-exit. This runtime reports a set-but-empty var as `Some("")`, so
  // the guard's `Some("")` arm is the one exercised here; the matching `None`
  // arm covers any platform that instead collapses an empty var to `None`.
  @env.set_env_var("PIPPA_REPLAY", "")
  assert_true(@env.get_env_var("PIPPA_REPLAY") is Some(""))
  assert_true(replay_trigger_from_env() is None)
  // A non-empty value still triggers, with the RAW/SIZE/clock/drain defaults.
  @env.set_env_var("PIPPA_REPLAY", "down enter")
  match replay_trigger_from_env() {
    Some(t) => {
      assert_eq(t.script, "down enter")
      assert_false(t.raw_ansi)
      assert_eq(t.width, 80)
      assert_eq(t.height, 24)
      assert_eq(t.clock_step_ms, 20)
      assert_eq(t.drain_empty_polls, 4)
    }
    None => abort("expected a replay trigger for a non-empty PIPPA_REPLAY")
  }
  clear_replay_env()
}

///|
#cfg(any(target="native", target="llvm"))
test "replay_trigger_from_env reads the clock step and drain window, defaulting malformed values" {
  fn clear_replay_env() -> Unit {
    @env.unset_env_var("PIPPA_REPLAY")
    @env.unset_env_var("PIPPA_REPLAY_CLOCK_STEP")
    @env.unset_env_var("PIPPA_REPLAY_DRAIN_POLLS")
  }

  clear_replay_env()
  @env.set_env_var("PIPPA_REPLAY", "s")
  @env.set_env_var("PIPPA_REPLAY_CLOCK_STEP", "250")
  @env.set_env_var("PIPPA_REPLAY_DRAIN_POLLS", "6")
  match replay_trigger_from_env() {
    Some(t) => {
      assert_eq(t.clock_step_ms, 250)
      assert_eq(t.drain_empty_polls, 6)
    }
    None => abort("expected a replay trigger")
  }
  // A malformed value falls back to its default (20ms / 4 polls).
  @env.set_env_var("PIPPA_REPLAY_CLOCK_STEP", "fast")
  @env.set_env_var("PIPPA_REPLAY_DRAIN_POLLS", "")
  match replay_trigger_from_env() {
    Some(t) => {
      assert_eq(t.clock_step_ms, 20)
      assert_eq(t.drain_empty_polls, 4)
    }
    None => abort("expected a replay trigger")
  }
  clear_replay_env()
}
