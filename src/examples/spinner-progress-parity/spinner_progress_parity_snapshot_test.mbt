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

  @debug.debug_inspect(
    frames,
    content=(
      #|[
      #|  "⠋ Syncing\n\u{1b}[38;2;96;96;96m░░░░░░░░░░\u{1b}[0m 0%\n",
      #|  "⠋ Syncing\n\u{1b}[38;2;96;96;96m░░░░░░░░░░\u{1b}[0m 0%\n",
      #|  "⠙ Syncing\n\u{1b}[38;2;96;96;96m░░░░░░░░░░\u{1b}[0m 2%\n",
      #|  "⠹ Syncing\n\u{1b}[38;2;90;86;224m\u{1b}[48;2;85;94;220m▌\u{1b}[0m\u{1b}[38;2;96;96;96m░░░░░░░░░\u{1b}[0m 6%\n",
      #|  "⠸ Syncing\n\u{1b}[38;2;90;86;224m\u{1b}[48;2;85;94;220m▌\u{1b}[0m\u{1b}[38;2;96;96;96m░░░░░░░░░\u{1b}[0m 11%\n",
      #|  "⠼ Syncing\n\u{1b}[38;2;90;86;224m\u{1b}[48;2;85;94;220m▌\u{1b}[0m\u{1b}[38;2;81;102;217m\u{1b}[48;2;76;111;214m▌\u{1b}[0m\u{1b}[38;2;96;96;96m░░░░░░░░\u{1b}[0m 16%\n",
      #|]
    ),
  )
}
