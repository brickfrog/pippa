///|
test "filepicker parity snapshots full ansi navigate and select frames" {
  let script : Array[@replay.ReplayStep[Msg]] = [
    @replay.Input(@pippa.Key(@pippa.Special("down"))),
    @replay.Input(@pippa.Key(@pippa.Char(' '))),
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
      #|  "\u{1b}[1m.\u{1b}[0m\n  \u{1b}[2mdrwxr-xr-x\u{1b}[0m \u{1b}[2m4096\u{1b}[0m \u{1b}[38;2;90;130;220msrc/\u{1b}[0m\n\u{1b}[1m> \u{1b}[0m\u{1b}[2m-rw-r--r--\u{1b}[0m \u{1b}[2m  42\u{1b}[0m \u{1b}[4mnotes.md\u{1b}[0m\n  \u{1b}[2mlrwxrwxrwx\u{1b}[0m \u{1b}[2m   3\u{1b}[0m \u{1b}[38;2;30;160;150mcurrent@\u{1b}[0m\n\u{1b}[2mhidden:off items:3\u{1b}[0m",
      #|]
    ),
  )
}
