#include <signal.h>
#include <termios.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <poll.h>
#include <errno.h>
#include <time.h>
#include <stdio.h>
#include <string.h>

// Save and restore terminal state
static struct termios orig_termios;
static volatile sig_atomic_t pippa_resize_flag = 0;

static void sigwinch_handler(int sig) {
    (void)sig;
    pippa_resize_flag = 1;
}

void pippa_install_sigwinch(void) {
    struct sigaction sa = {0};
    sa.sa_handler = sigwinch_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGWINCH, &sa, NULL) == -1) {
        fprintf(stderr, "Warning: failed to install SIGWINCH handler: %s\n",
                strerror(errno));
    }
}

int pippa_check_resize(void) {
    int resized = pippa_resize_flag;
    pippa_resize_flag = 0;
    return resized;
}

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
    pippa_install_sigwinch();
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

int pippa_poll_stdin(int timeout_ms) {
    struct pollfd pfd = { .fd = STDIN_FILENO, .events = POLLIN };
    while (1) {
        int result = poll(&pfd, 1, timeout_ms);
        if (result < 0 && errno == EINTR) {
            if (pippa_resize_flag != 0) {
                return 2;
            }
            continue;
        }
        return result;
    }
}

long long pippa_now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

void pippa_write_byte(int b) {
    unsigned char c = (unsigned char)b;
    write(STDOUT_FILENO, &c, 1);
}

void pippa_write_bytes(const unsigned char* buf, int len) {
    write(STDOUT_FILENO, buf, (size_t)len);
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
