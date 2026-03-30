///|
test "pippa cmd tick stores interval" {
  let cmd : Cmd[Int] = Cmd::tick(120)
  assert_eq(cmd.actions.length(), 1)
  assert_eq(cmd.actions[0].0, 120)
}

///|
test "pippa cmd batch concatenates all actions" {
  let batched : Cmd[Int] = Cmd::batch([
    Cmd::none(),
    Cmd::tick(120),
    Cmd::tick(40),
  ])
  assert_eq(batched.actions.length(), 2)
  assert_eq(batched.actions[0].0, 120)
  assert_eq(batched.actions[1].0, 40)
}

///|
test "pippa cmd batch preserves msgs from all sources" {
  let a : Cmd[Int] = Cmd::after(16, fn() { 1 })
  let b : Cmd[Int] = Cmd::after(16, fn() { 2 })
  let c : Cmd[Int] = Cmd::tick(100)
  let batched = Cmd::batch([a, b, c])
  assert_eq(batched.actions.length(), 3)
  assert_eq(batched.actions[0].1, Some(1))
  assert_eq(batched.actions[1].1, Some(2))
  assert_eq(batched.actions[2].1, None)
}
