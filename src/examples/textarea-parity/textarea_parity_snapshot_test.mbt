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

  inspect(
    frames,
    content=(
      #|[Textarea Parity
      #|1 > [2mnote[0m
      #|, Textarea Parity
      #|1 > |   
      #|, Textarea Parity
      #|1 > alph
      #|  > a   
      #|  > bet|
      #|, Textarea Parity
      #|  > a   
      #|  > beta
      #|2 > |   
      #|, Textarea Parity
      #|  > beta
      #|2 > gamm
      #|  > a|  
      #|, Textarea Parity
      #|  > beta
      #|2 > gamm
      #|  > |a  
      #|, Textarea Parity
      #|  > beta
      #|2 > gam|
      #|  > a   
      #|, Textarea Parity
      #|  > beta
      #|2 > gam!
      #|  > |ma 
      #|, Textarea Parity
      #|  > beta
      #|2 > |gam
      #|  > ma  
      #|, Textarea Parity
      #|  > beta
      #|2 > g|am
      #|  > ma  
      #|]
    ),
  )
}
