///|
test "list parity replay frames fuzzy filter full ansi" {
  let script : Array[@replay.ReplayStep[Msg]] = [
    @replay.Input(@pippa.Key(@pippa.Char('/'))),
    @replay.Input(@pippa.Key(@pippa.Char('f'))),
    @replay.Input(@pippa.Key(@pippa.Char('z'))),
    @replay.Input(@pippa.Key(@pippa.Special("enter"))),
    @replay.Input(@pippa.Key(@pippa.Special("down"))),
  ]
  let frames = @replay.replay_frames(
    init=list_parity_init,
    update=list_parity_update,
    view=list_parity_view,
    sub=list_parity_sub,
    script~,
  )

  @debug.debug_inspect(
    frames,
    content=(
      #|[
      #|  "Parity Scenarios\n0:Fuzzy Finder:cursor:\n1:Viewport Pager:idle:\n2:Table Rows:idle:\n\u{1b}[2mPage 1/1\u{1b}[0m\n\u{1b}[2m↑/k up • ↓/j down • pgup/b page up • pgdn/f page down • / filter • C-l clear filter • esc escape • enter enter • ? help • q quit\u{1b}[0m",
      #|  "Parity Scenarios\nFilter: |\u{1b}[2mFilter\u{1b}[0m\n0:Fuzzy Finder:cursor:\n1:Viewport Pager:idle:\n2:Table Rows:idle:\n\u{1b}[2mPage 1/1\u{1b}[0m\n\u{1b}[2m↑/k up • ↓/j down • pgup/b page up • pgdn/f page down • / filter • C-l clear filter • esc escape • enter enter • ? help • q quit\u{1b}[0m",
      #|  "Parity Scenarios\nFilter: f|\n0:Fuzzy Finder:cursor:0\n\u{1b}[2mPage 1/1\u{1b}[0m\n\u{1b}[2m↑/k up • ↓/j down • pgup/b page up • pgdn/f page down • / filter • C-l clear filter • esc escape • enter enter • ? help • q quit\u{1b}[0m",
      #|  "Parity Scenarios\nFilter: fz|\n0:Fuzzy Finder:cursor:0,2\n\u{1b}[2mPage 1/1\u{1b}[0m\n\u{1b}[2m↑/k up • ↓/j down • pgup/b page up • pgdn/f page down • / filter • C-l clear filter • esc escape • enter enter • ? help • q quit\u{1b}[0m",
      #|  "Parity Scenarios\nFilter: fz\n0:Fuzzy Finder:cursor:0,2\n\u{1b}[2mPage 1/1\u{1b}[0m\n\u{1b}[2m↑/k up • ↓/j down • pgup/b page up • pgdn/f page down • / filter • C-l clear filter • esc escape • enter enter • ? help • q quit\u{1b}[0m",
      #|  "Parity Scenarios\nFilter: fz\n0:Fuzzy Finder:cursor:0,2\n\u{1b}[2mPage 1/1\u{1b}[0m\n\u{1b}[2m↑/k up • ↓/j down • pgup/b page up • pgdn/f page down • / filter • C-l clear filter • esc escape • enter enter • ? help • q quit\u{1b}[0m",
      #|]
    ),
  )
}
