///|
test "text input parity snapshots full ANSI replay frames for typing and backspace edits" {
  let frames = @replay.replay_frames(
    init=text_input_parity_init,
    update=text_input_parity_update,
    view=text_input_parity_view,
    sub=text_input_parity_sub,
    script=[
      @replay.Input(@pippa.Key(@pippa.Text("Ada"))),
      @replay.Input(@pippa.Key(@pippa.Special("backspace"))),
      @replay.Input(@pippa.Key(@pippa.Text("e"))),
      @replay.Input(@pippa.Key(@pippa.Special("tab"))),
      @replay.Input(@pippa.Key(@pippa.Text("moon"))),
      @replay.Input(@pippa.Key(@pippa.Special("backspace"))),
      @replay.Input(@pippa.Key(@pippa.Text("n"))),
    ],
  )

  @debug.debug_inspect(
    frames,
    content=(
      #|[
      #|  "Text Input Parity\nName: |\u{1b}[2mname\u{1b}[0m\nPassword: \u{1b}[2mpassword\u{1b}[0m\nat least 4 chars\n",
      #|  "Text Input Parity\nName: Ada|\nPassword: \u{1b}[2mpassword\u{1b}[0m\nat least 4 chars\n",
      #|  "Text Input Parity\nName: Ad|\nPassword: \u{1b}[2mpassword\u{1b}[0m\nat least 4 chars\n",
      #|  "Text Input Parity\nName: Ade|\nPassword: \u{1b}[2mpassword\u{1b}[0m\nat least 4 chars\n",
      #|  "Text Input Parity\nName: Ade\nPassword: |\u{1b}[2mpassword\u{1b}[0m\nat least 4 chars\n",
      #|  "Text Input Parity\nName: Ade\nPassword: ****|\npassword ok\n",
      #|  "Text Input Parity\nName: Ade\nPassword: ***|\nat least 4 chars\n",
      #|  "Text Input Parity\nName: Ade\nPassword: ****|\npassword ok\n",
      #|]
    ),
  )
}
