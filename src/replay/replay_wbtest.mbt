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
