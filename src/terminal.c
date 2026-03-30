#include <signal.h>
#include <termios.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <poll.h>
#include <errno.h>
#include <fcntl.h>
#include <time.h>
#include <stdio.h>
#include <string.h>

// Save and restore terminal state
static struct termios orig_termios;
static volatile sig_atomic_t pippa_resize_flag = 0;
static int pippa_wakeup_pipe[2] = { -1, -1 };

static void pippa_close_wakeup_pipe(void) {
    if (pippa_wakeup_pipe[0] >= 0) {
        close(pippa_wakeup_pipe[0]);
        pippa_wakeup_pipe[0] = -1;
    }
    if (pippa_wakeup_pipe[1] >= 0) {
        close(pippa_wakeup_pipe[1]);
        pippa_wakeup_pipe[1] = -1;
    }
}

static int pippa_make_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) {
        return -1;
    }
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

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

void pippa_init_wakeup(void) {
    pippa_close_wakeup_pipe();
    if (pipe(pippa_wakeup_pipe) != 0) {
        fprintf(stderr, "Warning: failed to create wakeup pipe: %s\n",
                strerror(errno));
        pippa_wakeup_pipe[0] = -1;
        pippa_wakeup_pipe[1] = -1;
        return;
    }
    if (pippa_make_nonblocking(pippa_wakeup_pipe[0]) != 0 ||
        pippa_make_nonblocking(pippa_wakeup_pipe[1]) != 0) {
        fprintf(stderr, "Warning: failed to configure wakeup pipe: %s\n",
                strerror(errno));
        pippa_close_wakeup_pipe();
    }
}

void pippa_close_wakeup(void) {
    pippa_close_wakeup_pipe();
}

void pippa_signal_wakeup(void) {
    if (pippa_wakeup_pipe[1] < 0) {
        return;
    }
    unsigned char byte = 1;
    ssize_t written = write(pippa_wakeup_pipe[1], &byte, 1);
    if (written < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) {
        fprintf(stderr, "Warning: failed to signal wakeup pipe: %s\n",
                strerror(errno));
    }
}

void pippa_drain_wakeup(void) {
    if (pippa_wakeup_pipe[0] < 0) {
        return;
    }
    unsigned char buf[64];
    while (1) {
        ssize_t n = read(pippa_wakeup_pipe[0], buf, sizeof(buf));
        if (n > 0) {
            continue;
        }
        if (n < 0 && errno == EINTR) {
            continue;
        }
        if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            return;
        }
        return;
    }
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

int pippa_poll_events(int timeout_ms, int include_stdin) {
    struct pollfd pfds[2];
    int nfds = 0;
    if (include_stdin) {
        pfds[nfds].fd = STDIN_FILENO;
        pfds[nfds].events = POLLIN;
        pfds[nfds].revents = 0;
        nfds += 1;
    }
    if (pippa_wakeup_pipe[0] >= 0) {
        pfds[nfds].fd = pippa_wakeup_pipe[0];
        pfds[nfds].events = POLLIN;
        pfds[nfds].revents = 0;
        nfds += 1;
    }
    while (1) {
        int result = poll(pfds, nfds, timeout_ms);
        if (result < 0 && errno == EINTR) {
            if (pippa_resize_flag != 0) {
                return 2;
            }
            continue;
        }
        if (result <= 0) {
            return result;
        }
        int events = 0;
        int stdin_index = include_stdin ? 0 : -1;
        int wakeup_index = include_stdin ? 1 : 0;
        if (stdin_index >= 0 && (pfds[stdin_index].revents & (POLLIN | POLLHUP | POLLERR))) {
            events |= 1;
        }
        if (pippa_wakeup_pipe[0] >= 0 &&
            wakeup_index < nfds &&
            (pfds[wakeup_index].revents & (POLLIN | POLLHUP | POLLERR))) {
            events |= 4;
        }
        if (pippa_resize_flag != 0) {
            events |= 2;
        }
        return events;
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
