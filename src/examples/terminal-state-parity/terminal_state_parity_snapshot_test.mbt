///|
test "terminal state parity replay frames snapshot state toggles" {
  let frames = @replay.replay_frames(
    init=terminal_state_parity_init,
    update=terminal_state_parity_update,
    view=terminal_state_parity_view,
    sub=terminal_state_parity_sub,
    script=[
      Message(WindowMeasured({ width: 100, height: 30 })),
      Input(@pippa.Key(@pippa.Char('c'))),
      Input(@pippa.Key(@pippa.Char('c'))),
      Input(@pippa.Key(@pippa.Char('q'))),
    ],
  )

  @debug.debug_inspect(
    frames,
    content=(
      #|[
      #|  "Terminal State Parity\nSize: pending\nCursor visible: false\n",
      #|  "Terminal State Parity\nSize: 100x30\nCursor visible: false\n",
      #|  "Terminal State Parity\nSize: 100x30\nCursor visible: true\n",
      #|  "Terminal State Parity\nSize: 100x30\nCursor visible: false\n",
      #|  "Goodbye\n",
      #|]
    ),
  )
}
