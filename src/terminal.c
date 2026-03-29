#include <termios.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <stdio.h>
#include <string.h>

// Save and restore terminal state
static struct termios orig_termios;

void pippa_enter_raw_mode(void) {
    tcgetattr(STDIN_FILENO, &orig_termios);
    struct termios raw = orig_termios;
    raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    raw.c_oflag &= ~(OPOST);
    raw.c_cflag |= (CS8);
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    raw.c_cc[VMIN] = 1;
    raw.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

void pippa_exit_raw_mode(void) {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
}

int pippa_read_byte(void) {
    unsigned char c;
    int n = read(STDIN_FILENO, &c, 1);
    if (n <= 0) return -1;
    return (int)c;
}

void pippa_write_byte(int b) {
    unsigned char c = (unsigned char)b;
    write(STDOUT_FILENO, &c, 1);
}

void pippa_write_string(int* bytes, int len) {
    if (len <= 0) return;
    char buffer[4096];
    int buf_len = 0;
    
    for (int i = 0; i < len; i++) {
        buffer[buf_len++] = (char)(bytes[i] & 0xFF);
        if (buf_len == sizeof(buffer)) {
            write(STDOUT_FILENO, buffer, buf_len);
            buf_len = 0;
        }
    }
    
    if (buf_len > 0) {
        write(STDOUT_FILENO, buffer, buf_len);
    }
}

int pippa_get_rows(void) {
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_row > 0) {
        return ws.ws_row;
    }
    return 24;
}

int pippa_get_cols(void) {
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0) {
        return ws.ws_col;
    }
    return 80;
}
