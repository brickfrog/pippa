///|
test "viewport parity replay frames capture full ansi scrolling" {
  let script : Array[@replay.ReplayStep[Msg]] = [
    Input(@pippa.Key(@pippa.Special("down"))),
    Input(@pippa.Key(@pippa.Special("down"))),
    Input(@pippa.Key(@pippa.Special("up"))),
    Input(@pippa.Key(@pippa.Special("pagedown"))),
    Input(@pippa.Key(@pippa.Special("pageup"))),
  ]

  let frames = @replay.replay_frames(
    init=viewport_parity_init,
    update=viewport_parity_update,
    view=viewport_parity_view,
    sub=viewport_parity_sub,
    script~,
  )

  @debug.debug_inspect(
    frames,
    content=(
      #|[
      #|  "Viewport Parity\n1|alpha\n2|beta-\n",
      #|  "Viewport Parity\n2|beta-\n3|charl\n",
      #|  "Viewport Parity\n3|charl\n4|delta\n",
      #|  "Viewport Parity\n2|beta-\n3|charl\n",
      #|  "Viewport Parity\n4|delta\n5|echo-\n",
      #|  "Viewport Parity\n2|beta-\n3|charl\n",
      #|]
    ),
  )
}
