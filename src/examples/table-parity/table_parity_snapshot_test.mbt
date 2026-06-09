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

  @debug.debug_inspect(
    frames,
    content=(
      #|[
      #|  "Table Parity\nID │ Name \n──────────\n\u{1b}[1mA  │ alpha\u{1b}[0m\nB  │ bravo\nC  │ charl\n",
      #|  "Table Parity\nID │ Name \n──────────\nA  │ alpha\n\u{1b}[1mB  │ bravo\u{1b}[0m\nC  │ charl\n",
      #|  "Table Parity\nID │ Name \n──────────\nC  │ charl\nD  │ delta\n\u{1b}[1mE  │ echo \u{1b}[0m\n",
      #|  "Table Parity\nID │ Name \n──────────\nC  │ charl\nD  │ delta\n\u{1b}[1m\u{1b}[4mE  │ echo \u{1b}[0m\n",
      #|]
    ),
  )
}
