#include <time.h>

long long pippa_styling_perf_now_us(void) {
    struct timespec ts = {0};
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        return 0;
    }
    return (long long)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}
