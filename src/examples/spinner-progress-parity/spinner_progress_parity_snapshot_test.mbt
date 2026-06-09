///|
test "spinner progress parity replay frames full ansi" {
  let frames = @replay.replay_frames(
    init=spinner_progress_parity_init,
    update=spinner_progress_parity_update,
    view=spinner_progress_parity_view,
    sub=spinner_progress_parity_sub,
    script=[
      @replay.Input(@pippa.Key(@pippa.Char('5'))),
      @replay.Message(ActivityTick),
      @replay.Message(ActivityTick),
      @replay.Message(ActivityTick),
      @replay.Message(ActivityTick),
    ],
  )

  inspect(
    frames,
    content=(
      #|[⠋ Syncing
      #|[38;2;96;96;96m░░░░░░░░░░[0m 0%
      #|, ⠋ Syncing
      #|[38;2;96;96;96m░░░░░░░░░░[0m 0%
      #|, ⠙ Syncing
      #|[38;2;96;96;96m░░░░░░░░░░[0m 2%
      #|, ⠹ Syncing
      #|[38;2;90;86;224m[48;2;85;94;220m▌[0m[38;2;96;96;96m░░░░░░░░░[0m 6%
      #|, ⠸ Syncing
      #|[38;2;90;86;224m[48;2;85;94;220m▌[0m[38;2;96;96;96m░░░░░░░░░[0m 11%
      #|, ⠼ Syncing
      #|[38;2;90;86;224m[48;2;85;94;220m▌[0m[38;2;81;102;217m[48;2;76;111;214m▌[0m[38;2;96;96;96m░░░░░░░░[0m 16%
      #|]
    ),
  )
}
