///|
test "keymap help parity replay frames snapshot help and navigation" {
  let frames = @replay.replay_frames(
    init=keymap_help_parity_init,
    update=keymap_help_parity_update,
    view=keymap_help_parity_view,
    sub=keymap_help_parity_sub,
    script=[
      @replay.Input(@pippa.Key(@pippa.Special("down"))),
      @replay.Input(@pippa.Key(@pippa.Char('n'))),
      @replay.Input(@pippa.Key(@pippa.Char('?'))),
      @replay.Input(@pippa.Key(@pippa.Char('n'))),
      @replay.Input(@pippa.Key(@pippa.Char('?'))),
    ],
  )

  inspect(
    frames,
    content=(
      #|[Task      
      #|──────────
      #|[1mwrite     [0m
      #|review    
      #|↑/k up • n next task • pgup/b page up • pgdn/f page down • C-u half page up • C-d half page down • home/g top • end/G bottom • enter select
      #|, Task      
      #|──────────
      #|[1mwrite     [0m
      #|review    
      #|↑/k up • n next task • pgup/b page up • pgdn/f page down • C-u half page up • C-d half page down • home/g top • end/G bottom • enter select
      #|, Task      
      #|──────────
      #|write     
      #|[1mreview    [0m
      #|↑/k up • n next task • pgup/b page up • pgdn/f page down • C-u half page up • C-d half page down • home/g top • end/G bottom • enter select
      #|, Task      
      #|──────────
      #|write     
      #|[1mreview    [0m
      #|Movement
      #|  ↑/k     up
      #|  n       next task
      #|  pgup/b  page up
      #|  pgdn/f  page down
      #|  C-u     half page up
      #|  C-d     half page down
      #|  home/g  top
      #|  end/G   bottom
      #|
      #|Selection
      #|  enter  select
      #|, Task      
      #|──────────
      #|review    
      #|[1mmerge     [0m
      #|Movement
      #|  ↑/k     up
      #|  n       next task
      #|  pgup/b  page up
      #|  pgdn/f  page down
      #|  C-u     half page up
      #|  C-d     half page down
      #|  home/g  top
      #|  end/G   bottom
      #|
      #|Selection
      #|  enter  select
      #|, Task      
      #|──────────
      #|review    
      #|[1mmerge     [0m
      #|↑/k up • n next task • pgup/b page up • pgdn/f page down • C-u half page up • C-d half page down • home/g top • end/G bottom • enter select
      #|]
    ),
  )
}
