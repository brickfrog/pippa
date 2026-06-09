hide/show, line erase, and the keystroke-driven cursor-visibility diff frame:
  $ env -u NO_COLOR -u CLICOLOR -u CLICOLOR_FORCE -u TERM -u PIPPA_REPLAY -u PIPPA_REPLAY_RAW -u PIPPA_REPLAY_SIZE COLORTERM=truecolor terminal-state-parity-app.exe --replay "c" --raw
  --- frame 0 ---
  \x1b[2J\x1b[1;1H (escaped)
  --- frame 1 ---
  \x1b[?2026h\x1b]2;Pippa terminal state\x1b\\\x1b]9;4;3;0\x1b\\\x1b[?1000h\x1b[?1006h\x1b[?25l\x1b[1;1H\x1b[KTerminal State Parity\x1b[2;1H\x1b[KSize: 80x24\x1b[3;1H\x1b[KCursor visible: false\x1b[4;1H\x1b[K\x1b[2;4H\x1b[?2026l (escaped)
  --- frame 2 ---
  \x1b[?2026h\x1b[?25h\x1b[3;1H\x1b[KCursor visible: true\x1b[2;4H\x1b[?2026l (escaped)
  --- frame 3 ---
  \x1b[?25h\x1b[0 q\x1b]2;\x1b\\\x1b[39m\x1b[49m\x1b]9;4;0;0\x1b\\\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l (escaped)
