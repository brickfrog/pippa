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

  inspect(
    frames,
    content=(
      #|[[1m.[0m
      #|[1m> [0m[2mdrwxr-xr-x[0m [2m4096[0m [4m[38;2;90;130;220msrc/[0m[0m
      #|  [2m-rw-r--r--[0m [2m  42[0m notes.md
      #|  [2mlrwxrwxrwx[0m [2m   3[0m [38;2;30;160;150mcurrent@[0m
      #|[2mhidden:off items:3[0m, [1m.[0m
      #|  [2mdrwxr-xr-x[0m [2m4096[0m [38;2;90;130;220msrc/[0m
      #|[1m> [0m[2m-rw-r--r--[0m [2m  42[0m [4mnotes.md[0m
      #|  [2mlrwxrwxrwx[0m [2m   3[0m [38;2;30;160;150mcurrent@[0m
      #|[2mhidden:off items:3[0m, [1m.[0m
      #|  [2mdrwxr-xr-x[0m [2m4096[0m [38;2;90;130;220msrc/[0m
      #|[1m> [0m[2m-rw-r--r--[0m [2m  42[0m [4mnotes.md[0m
      #|  [2mlrwxrwxrwx[0m [2m   3[0m [38;2;30;160;150mcurrent@[0m
      #|[2mhidden:off items:3[0m]
    ),
  )
}
