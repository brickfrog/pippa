///|
test "pippa cmd tick stores interval" {
  let cmd : Cmd[Int] = Cmd::tick(120)
  assert_eq(cmd.interval_ms, 120)
}

///|
test "pippa cmd batch keeps minimum non-zero interval" {
  let batched : Cmd[Int] = Cmd::batch([
    Cmd::none(),
    Cmd::tick(120),
    Cmd::tick(40),
  ])
  assert_eq(batched.interval_ms, 40)
}
