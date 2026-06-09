TrueColor (COLORTERM=truecolor) -> 24-bit SGR escapes:
  $ env -u NO_COLOR -u CLICOLOR -u CLICOLOR_FORCE -u TERM COLORTERM=truecolor color-profile.exe
  \x1b[38;2;255;0;0mred\x1b[0m (escaped)
  \x1b[38;2;0;255;0mgreen\x1b[0m (escaped)
  \x1b[38;2;0;0;255mblue\x1b[0m (escaped)
  \x1b[38;2;230;220;180madaptive\x1b[0m (escaped)
  \x1b[38;2;255;128;0m\x1b[1mbold sample\x1b[0m (escaped)


256-color (TERM=xterm-256color) -> downsampled to the 256-color palette:
  $ env -u NO_COLOR -u CLICOLOR -u CLICOLOR_FORCE -u COLORTERM TERM=xterm-256color color-profile.exe
  \x1b[38;5;196mred\x1b[0m (escaped)
  \x1b[38;5;46mgreen\x1b[0m (escaped)
  \x1b[38;5;21mblue\x1b[0m (escaped)
  \x1b[38;5;187madaptive\x1b[0m (escaped)
  \x1b[38;5;208m\x1b[1mbold sample\x1b[0m (escaped)


NO_COLOR -> colors stripped, bold attribute retained:
  $ env -u CLICOLOR -u CLICOLOR_FORCE -u COLORTERM -u TERM NO_COLOR=1 color-profile.exe
  red
  green
  blue
  adaptive
  \x1b[1mbold sample\x1b[0m (escaped)
