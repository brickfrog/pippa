///|
test "textarea parity replays full ansi multiline editing frames" {
  let frames = @replay.replay_frames(
    init=textarea_parity_init,
    update=textarea_parity_update,
    view=textarea_parity_view,
    sub=textarea_parity_sub,
    script=[
      @replay.Message(EditorMsg(@component.Focus)),
      @replay.Input(@pippa.Key(@pippa.Text("alpha beta"))),
      @replay.Input(@pippa.Key(@pippa.Special("enter"))),
      @replay.Input(@pippa.Key(@pippa.Text("gamma"))),
      @replay.Input(@pippa.Key(@pippa.Special("left"))),
      @replay.Input(@pippa.Key(@pippa.Special("left"))),
      @replay.Input(@pippa.Key(@pippa.Char('!'))),
      @replay.Input(@pippa.Key(@pippa.Special("up"))),
      @replay.Input(@pippa.Key(@pippa.Special("right"))),
    ],
  )

  @debug.debug_inspect(
    frames,
    content=(
      #|[
      #|  "Textarea Parity\n1 > \u{1b}[2mnote\u{1b}[0m\n",
      #|  "Textarea Parity\n1 > |   \n",
      #|  "Textarea Parity\n1 > alph\n  > a   \n  > bet|\n",
      #|  "Textarea Parity\n  > a   \n  > beta\n2 > |   \n",
      #|  "Textarea Parity\n  > beta\n2 > gamm\n  > a|  \n",
      #|  "Textarea Parity\n  > beta\n2 > gamm\n  > |a  \n",
      #|  "Textarea Parity\n  > beta\n2 > gam|\n  > a   \n",
      #|  "Textarea Parity\n  > beta\n2 > gam!\n  > |ma \n",
      #|  "Textarea Parity\n  > beta\n2 > |gam\n  > ma  \n",
      #|  "Textarea Parity\n  > beta\n2 > g|am\n  > ma  \n",
      #|]
    ),
  )
}
