frame text across the captured frames:
  $ env -u NO_COLOR -u CLICOLOR -u CLICOLOR_FORCE -u TERM -u PIPPA_REPLAY -u PIPPA_REPLAY_RAW -u PIPPA_REPLAY_SIZE -u PIPPA_REPLAY_CLOCK_STEP -u PIPPA_REPLAY_DRAIN_POLLS COLORTERM=truecolor list-parity-app.exe --replay "/ f z enter"
  --- frame 0 ---
  Parity Scenarios0:Fuzzy Finder:cursor:1:Viewport Pager:idle:2:Table Rows:idle:\x1b[2mPage 1/1\x1b[0m\x1b[2m\xe2\x86\x91/k up \xe2\x80\xa2 \xe2\x86\x93/j down \xe2\x80\xa2 pgup/b page up \xe2\x80\xa2 pgdn/f page down \xe2\x80\xa2 / filter \xe2\x80\xa2 C-l clear filter \xe2\x80\xa2 esc escape \xe2\x80\xa2 enter enter \xe2\x80\xa2 ? help \xe2\x80\xa2 q quit\x1b[0m (escaped)
  --- frame 1 ---
  Filter: fz0:Fuzzy Finder:cursor:0,2\x1b[2mPage 1/1\x1b[0m\x1b[2m\xe2\x86\x91/k up \xe2\x80\xa2 \xe2\x86\x93/j down \xe2\x80\xa2 pgup/b page up \xe2\x80\xa2 pgdn/f page down \xe2\x80\xa2 / filter \xe2\x80\xa2 C-l clear filter \xe2\x80\xa2 esc escape \xe2\x80\xa2 enter enter \xe2\x80\xa2 ? help \xe2\x80\xa2 q quit\x1b[0m (escaped)
