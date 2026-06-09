Timer countdown (Cmd::after) ticks end to end — a clock step past the 100ms deadline fires one tick per drain poll, so the timer counts 0:00.3 -> 0:00.0 (then leaves the view once expired) while the stopwatch climbs:
  $ env -u NO_COLOR -u CLICOLOR -u CLICOLOR_FORCE -u TERM -u PIPPA_REPLAY -u PIPPA_REPLAY_RAW -u PIPPA_REPLAY_SIZE -u PIPPA_REPLAY_CLOCK_STEP -u PIPPA_REPLAY_DRAIN_POLLS COLORTERM=truecolor timer-stopwatch-parity-app.exe --replay "s" --clock-step 200 --drain-polls 6
  --- frame 0 ---
  Timer: 0:00.3Stopwatch: 0:00.0
  --- frame 1 ---
  Timer: 0:00.2Stopwatch: 0:00.1
  --- frame 2 ---
  Timer: 0:00.1Stopwatch: 0:00.2
  --- frame 3 ---
  Timer: 0:00.0Stopwatch: 0:00.3
  --- frame 4 ---
  Stopwatch: 0:00.4
  --- frame 5 ---
  Stopwatch: 0:00.5
  --- frame 6 ---
  Stopwatch: 0:00.6


Spinner glyph advances and the spring-physics progress bar climbs across ticks once the 50% target is set, driven through the same advancing replay clock:
  $ env -u NO_COLOR -u CLICOLOR -u CLICOLOR_FORCE -u TERM -u PIPPA_REPLAY -u PIPPA_REPLAY_RAW -u PIPPA_REPLAY_SIZE -u PIPPA_REPLAY_CLOCK_STEP -u PIPPA_REPLAY_DRAIN_POLLS COLORTERM=truecolor spinner-progress-parity-app.exe --replay "5" --clock-step 200 --drain-polls 8
  --- frame 0 ---
  \xe2\xa0\x8b Syncing\x1b[38;2;96;96;96m\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\x1b[0m 0% (escaped)
  --- frame 1 ---
  \xe2\xa0\x99 Syncing\x1b[38;2;96;96;96m\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\x1b[0m 2% (escaped)
  --- frame 2 ---
  \xe2\xa0\xb9 Syncing\x1b[38;2;90;86;224m\x1b[48;2;85;94;220m\xe2\x96\x8c\x1b[0m\x1b[38;2;96;96;96m\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\x1b[0m 6% (escaped)
  --- frame 3 ---
  \xe2\xa0\xb8 Syncing\x1b[38;2;90;86;224m\x1b[48;2;85;94;220m\xe2\x96\x8c\x1b[0m\x1b[38;2;96;96;96m\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\x1b[0m 11% (escaped)
  --- frame 4 ---
  \xe2\xa0\xbc Syncing\x1b[38;2;90;86;224m\x1b[48;2;85;94;220m\xe2\x96\x8c\x1b[0m\x1b[38;2;81;102;217m\x1b[48;2;76;111;214m\xe2\x96\x8c\x1b[0m\x1b[38;2;96;96;96m\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\x1b[0m 16% (escaped)
  --- frame 5 ---
  \xe2\xa0\xb4 Syncing\x1b[38;2;90;86;224m\x1b[48;2;85;94;220m\xe2\x96\x8c\x1b[0m\x1b[38;2;81;102;217m\x1b[48;2;76;111;214m\xe2\x96\x8c\x1b[0m\x1b[38;2;96;96;96m\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\x1b[0m 21% (escaped)
  --- frame 6 ---
  \xe2\xa0\xa6 Syncing\x1b[38;2;90;86;224m\x1b[48;2;85;94;220m\xe2\x96\x8c\x1b[0m\x1b[38;2;81;102;217m\x1b[48;2;76;111;214m\xe2\x96\x8c\x1b[0m\x1b[38;2;72;119;211m\x1b[48;2;67;128;208m\xe2\x96\x8c\x1b[0m\x1b[38;2;96;96;96m\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\x1b[0m 26% (escaped)
  --- frame 7 ---
  \xe2\xa0\xa7 Syncing\x1b[38;2;90;86;224m\x1b[48;2;85;94;220m\xe2\x96\x8c\x1b[0m\x1b[38;2;81;102;217m\x1b[48;2;76;111;214m\xe2\x96\x8c\x1b[0m\x1b[38;2;72;119;211m\x1b[48;2;67;128;208m\xe2\x96\x8c\x1b[0m\x1b[38;2;96;96;96m\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\x1b[0m 30% (escaped)
  --- frame 8 ---
  \xe2\xa0\x87 Syncing\x1b[38;2;90;86;224m\x1b[48;2;85;94;220m\xe2\x96\x8c\x1b[0m\x1b[38;2;81;102;217m\x1b[48;2;76;111;214m\xe2\x96\x8c\x1b[0m\x1b[38;2;72;119;211m\x1b[48;2;67;128;208m\xe2\x96\x8c\x1b[0m\x1b[38;2;96;96;96m\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\xe2\x96\x91\x1b[0m 34% (escaped)
