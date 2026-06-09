///|
test "keymap help parity replay frames snapshot help and navigation" {
  let frames = @replay.replay_frames(
    init=keymap_help_parity_init,
    update=keymap_help_parity_update,
    view=keymap_help_parity_view,
    sub=keymap_help_parity_sub,
    script=[
      @replay.Input(@pippa.Key(@pippa.Special("down"))),
      @replay.Input(@pippa.Key(@pippa.Char('n'))),
      @replay.Input(@pippa.Key(@pippa.Char('?'))),
      @replay.Input(@pippa.Key(@pippa.Char('n'))),
      @replay.Input(@pippa.Key(@pippa.Char('?'))),
    ],
  )

  @debug.debug_inspect(
    frames,
    content=(
      #|[
      #|  "Task      \n──────────\n\u{1b}[1mwrite     \u{1b}[0m\nreview    \n↑/k up • n next task • pgup/b page up • pgdn/f page down • C-u half page up • C-d half page down • home/g top • end/G bottom • enter select\n",
      #|  "Task      \n──────────\n\u{1b}[1mwrite     \u{1b}[0m\nreview    \n↑/k up • n next task • pgup/b page up • pgdn/f page down • C-u half page up • C-d half page down • home/g top • end/G bottom • enter select\n",
      #|  "Task      \n──────────\nwrite     \n\u{1b}[1mreview    \u{1b}[0m\n↑/k up • n next task • pgup/b page up • pgdn/f page down • C-u half page up • C-d half page down • home/g top • end/G bottom • enter select\n",
      #|  "Task      \n──────────\nwrite     \n\u{1b}[1mreview    \u{1b}[0m\nMovement\n  ↑/k     up\n  n       next task\n  pgup/b  page up\n  pgdn/f  page down\n  C-u     half page up\n  C-d     half page down\n  home/g  top\n  end/G   bottom\n\nSelection\n  enter  select\n",
      #|  "Task      \n──────────\nreview    \n\u{1b}[1mmerge     \u{1b}[0m\nMovement\n  ↑/k     up\n  n       next task\n  pgup/b  page up\n  pgdn/f  page down\n  C-u     half page up\n  C-d     half page down\n  home/g  top\n  end/G   bottom\n\nSelection\n  enter  select\n",
      #|  "Task      \n──────────\nreview    \n\u{1b}[1mmerge     \u{1b}[0m\n↑/k up • n next task • pgup/b page up • pgdn/f page down • C-u half page up • C-d half page down • home/g top • end/G bottom • enter select\n",
      #|]
    ),
  )
}
