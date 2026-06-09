///|
test "table parity replay snapshots row navigation and selection frames" {
  let script : Array[@replay.ReplayStep[Msg]] = [
    @replay.Input(@pippa.Key(@pippa.Special("down"))),
    @replay.Input(@pippa.Key(@pippa.Special("pagedown"))),
    @replay.Input(@pippa.Key(@pippa.Special("enter"))),
  ]

  let frames = @replay.replay_frames(
    init=table_parity_init,
    update=table_parity_update,
    view=table_parity_view,
    sub=table_parity_sub,
    script~,
  )

  inspect(
    frames,
    content=(
      #|[Table Parity
      #|ID │ Name 
      #|──────────
      #|[1mA  │ alpha[0m
      #|B  │ bravo
      #|C  │ charl
      #|, Table Parity
      #|ID │ Name 
      #|──────────
      #|A  │ alpha
      #|[1mB  │ bravo[0m
      #|C  │ charl
      #|, Table Parity
      #|ID │ Name 
      #|──────────
      #|C  │ charl
      #|D  │ delta
      #|[1mE  │ echo [0m
      #|, Table Parity
      #|ID │ Name 
      #|──────────
      #|C  │ charl
      #|D  │ delta
      #|[1m[4mE  │ echo [0m
      #|]
    ),
  )
}
