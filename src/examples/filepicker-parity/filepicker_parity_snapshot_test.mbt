///|
test "filepicker parity snapshots full ansi navigate and toggle hidden frames" {
  // `down` moves the cursor onto notes.md, then `.` toggles hidden entries: the
  // hidden .env row appears and the footer flips (hidden:off items:3 -> on
  // items:4). Selection (space) is deliberately not scripted here — it always
  // targets the cursor row, which already renders with the `selected` style, so
  // the keystroke produces no observable change in this view.
  let script : Array[@replay.ReplayStep[Msg]] = [
    @replay.Input(@pippa.Key(@pippa.Special("down"))),
    @replay.Input(@pippa.Key(@pippa.Char('.'))),
  ]
  let frames = @replay.replay_frames(
    init=filepicker_parity_init,
    update=filepicker_parity_update,
    view=filepicker_parity_view,
    sub=filepicker_parity_sub,
    script~,
  )

  @debug.debug_inspect(
    frames,
    content=(
      #|[
      #|  "\u{1b}[1m.\u{1b}[0m\n\u{1b}[1m> \u{1b}[0m\u{1b}[2mdrwxr-xr-x\u{1b}[0m \u{1b}[2m4096\u{1b}[0m \u{1b}[4m\u{1b}[38;2;90;130;220msrc/\u{1b}[0m\u{1b}[0m\n  \u{1b}[2m-rw-r--r--\u{1b}[0m \u{1b}[2m  42\u{1b}[0m notes.md\n  \u{1b}[2mlrwxrwxrwx\u{1b}[0m \u{1b}[2m   3\u{1b}[0m \u{1b}[38;2;30;160;150mcurrent@\u{1b}[0m\n\u{1b}[2mhidden:off items:3\u{1b}[0m",
      #|  "\u{1b}[1m.\u{1b}[0m\n  \u{1b}[2mdrwxr-xr-x\u{1b}[0m \u{1b}[2m4096\u{1b}[0m \u{1b}[38;2;90;130;220msrc/\u{1b}[0m\n\u{1b}[1m> \u{1b}[0m\u{1b}[2m-rw-r--r--\u{1b}[0m \u{1b}[2m  42\u{1b}[0m \u{1b}[4mnotes.md\u{1b}[0m\n  \u{1b}[2mlrwxrwxrwx\u{1b}[0m \u{1b}[2m   3\u{1b}[0m \u{1b}[38;2;30;160;150mcurrent@\u{1b}[0m\n\u{1b}[2mhidden:off items:3\u{1b}[0m",
      #|  "\u{1b}[1m.\u{1b}[0m\n  \u{1b}[2mdrwxr-xr-x\u{1b}[0m \u{1b}[2m4096\u{1b}[0m \u{1b}[38;2;90;130;220msrc/\u{1b}[0m\n\u{1b}[1m> \u{1b}[0m\u{1b}[2m-rw-r--r--\u{1b}[0m \u{1b}[2m  42\u{1b}[0m \u{1b}[4mnotes.md\u{1b}[0m\n  \u{1b}[2m-rw-------\u{1b}[0m \u{1b}[2m   7\u{1b}[0m .env\n  \u{1b}[2mlrwxrwxrwx\u{1b}[0m \u{1b}[2m   3\u{1b}[0m \u{1b}[38;2;30;160;150mcurrent@\u{1b}[0m\n\u{1b}[2mhidden:on items:4\u{1b}[0m",
      #|]
    ),
  )
}
