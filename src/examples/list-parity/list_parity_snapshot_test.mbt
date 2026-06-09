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

  inspect(
    frames,
    content=(
      #|[Parity Scenarios
      #|0:Fuzzy Finder:cursor:
      #|1:Viewport Pager:idle:
      #|2:Table Rows:idle:
      #|[2mPage 1/1[0m
      #|[2m↑/k up • ↓/j down • pgup/b page up • pgdn/f page down • / filter • C-l clear filter • esc escape • enter enter • ? help • q quit[0m, Parity Scenarios
      #|Filter: |[2mFilter[0m
      #|0:Fuzzy Finder:cursor:
      #|1:Viewport Pager:idle:
      #|2:Table Rows:idle:
      #|[2mPage 1/1[0m
      #|[2m↑/k up • ↓/j down • pgup/b page up • pgdn/f page down • / filter • C-l clear filter • esc escape • enter enter • ? help • q quit[0m, Parity Scenarios
      #|Filter: f|
      #|0:Fuzzy Finder:cursor:0
      #|[2mPage 1/1[0m
      #|[2m↑/k up • ↓/j down • pgup/b page up • pgdn/f page down • / filter • C-l clear filter • esc escape • enter enter • ? help • q quit[0m, Parity Scenarios
      #|Filter: fz|
      #|0:Fuzzy Finder:cursor:0,2
      #|[2mPage 1/1[0m
      #|[2m↑/k up • ↓/j down • pgup/b page up • pgdn/f page down • / filter • C-l clear filter • esc escape • enter enter • ? help • q quit[0m, Parity Scenarios
      #|Filter: fz
      #|0:Fuzzy Finder:cursor:0,2
      #|[2mPage 1/1[0m
      #|[2m↑/k up • ↓/j down • pgup/b page up • pgdn/f page down • / filter • C-l clear filter • esc escape • enter enter • ? help • q quit[0m, Parity Scenarios
      #|Filter: fz
      #|0:Fuzzy Finder:cursor:0,2
      #|[2mPage 1/1[0m
      #|[2m↑/k up • ↓/j down • pgup/b page up • pgdn/f page down • / filter • C-l clear filter • esc escape • enter enter • ? help • q quit[0m]
    ),
  )
}
