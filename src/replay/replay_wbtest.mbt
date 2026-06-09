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
