#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#define PIPPA_FILEPICKER_MAX_SCANNERS 32

typedef struct {
    DIR *dir;
    char *dir_path;
    int in_use;
} pippa_filepicker_scanner;

static pippa_filepicker_scanner pippa_filepicker_scanners[PIPPA_FILEPICKER_MAX_SCANNERS];

static char *pippa_filepicker_copy_path(const unsigned char *path, int path_len) {
    char *buf = (char *)malloc((size_t)path_len + 1);
    if (buf == NULL) {
        return NULL;
    }
    if (path_len > 0) {
        memcpy(buf, path, (size_t)path_len);
    }
    buf[path_len] = '\0';
    return buf;
}

static int pippa_filepicker_is_dir(const char *dir_path, const struct dirent *entry) {
#ifdef DT_DIR
    if (entry->d_type == DT_DIR) {
        return 1;
    }
    if (entry->d_type != DT_UNKNOWN && entry->d_type != DT_LNK) {
        return 0;
    }
#endif
    size_t dir_len = strlen(dir_path);
    size_t name_len = strlen(entry->d_name);
    int needs_sep = dir_len > 0 && dir_path[dir_len - 1] != '/';
    char *full_path = (char *)malloc(dir_len + (size_t)needs_sep + name_len + 1);
    if (full_path == NULL) {
        return 0;
    }
    memcpy(full_path, dir_path, dir_len);
    if (needs_sep) {
        full_path[dir_len] = '/';
        dir_len += 1;
    }
    memcpy(full_path + dir_len, entry->d_name, name_len);
    full_path[dir_len + name_len] = '\0';

    struct stat st;
    int is_dir = stat(full_path, &st) == 0 && S_ISDIR(st.st_mode);
    free(full_path);
    return is_dir;
}

static int pippa_filepicker_should_skip(const char *name) {
    return strcmp(name, ".") == 0 || strcmp(name, "..") == 0;
}

static void pippa_filepicker_close_scanner_slot(pippa_filepicker_scanner *scanner) {
    if (scanner->dir != NULL) {
        closedir(scanner->dir);
        scanner->dir = NULL;
    }
    if (scanner->dir_path != NULL) {
        free(scanner->dir_path);
        scanner->dir_path = NULL;
    }
    scanner->in_use = 0;
}

static pippa_filepicker_scanner *pippa_filepicker_lookup_scanner(int handle) {
    int index = handle - 1;
    if (index < 0 || index >= PIPPA_FILEPICKER_MAX_SCANNERS) {
        return NULL;
    }
    if (!pippa_filepicker_scanners[index].in_use) {
        return NULL;
    }
    return &pippa_filepicker_scanners[index];
}

static int pippa_filepicker_alloc_scanner(DIR *dir, char *dir_path) {
    for (int i = 0; i < PIPPA_FILEPICKER_MAX_SCANNERS; i++) {
        if (!pippa_filepicker_scanners[i].in_use) {
            pippa_filepicker_scanners[i].dir = dir;
            pippa_filepicker_scanners[i].dir_path = dir_path;
            pippa_filepicker_scanners[i].in_use = 1;
            return i + 1;
        }
    }
    return -1;
}

int pippa_filepicker_read_dir_size(const unsigned char *path, int path_len) {
    char *dir_path = pippa_filepicker_copy_path(path, path_len);
    if (dir_path == NULL) {
        return -1;
    }
    DIR *dir = opendir(dir_path);
    if (dir == NULL) {
        free(dir_path);
        return -1;
    }
    int total = 0;
    errno = 0;
    while (1) {
        struct dirent *entry = readdir(dir);
        if (entry == NULL) {
            break;
        }
        if (pippa_filepicker_should_skip(entry->d_name)) {
            continue;
        }
        size_t name_len = strlen(entry->d_name);
        if (name_len > (size_t)INT_MAX || total > INT_MAX - (int)name_len - 3) {
            closedir(dir);
            free(dir_path);
            return -1;
        }
        total += (int)name_len + 3;
    }
    if (errno != 0) {
        closedir(dir);
        free(dir_path);
        return -1;
    }
    closedir(dir);
    free(dir_path);
    return total;
}

int pippa_filepicker_read_dir_fill(
    const unsigned char *path,
    int path_len,
    unsigned char *out_buf,
    int out_len
) {
    char *dir_path = pippa_filepicker_copy_path(path, path_len);
    if (dir_path == NULL) {
        return -1;
    }
    DIR *dir = opendir(dir_path);
    if (dir == NULL) {
        free(dir_path);
        return -1;
    }
    int pos = 0;
    errno = 0;
    while (1) {
        struct dirent *entry = readdir(dir);
        if (entry == NULL) {
            break;
        }
        if (pippa_filepicker_should_skip(entry->d_name)) {
            continue;
        }
        size_t name_len = strlen(entry->d_name);
        if (out_len - pos < 2 || name_len > (size_t)(out_len - pos - 2)) {
            closedir(dir);
            free(dir_path);
            return -1;
        }
        out_buf[pos++] = pippa_filepicker_is_dir(dir_path, entry) ? 'D' : 'F';
        out_buf[pos++] = '\0';
        memcpy(out_buf + pos, entry->d_name, name_len);
        pos += (int)name_len;
        out_buf[pos++] = '\0';
    }
    if (errno != 0) {
        closedir(dir);
        free(dir_path);
        return -1;
    }
    closedir(dir);
    free(dir_path);
    return pos;
}

int pippa_filepicker_scan_open(const unsigned char *path, int path_len) {
    char *dir_path = pippa_filepicker_copy_path(path, path_len);
    if (dir_path == NULL) {
        return -1;
    }
    DIR *dir = opendir(dir_path);
    if (dir == NULL) {
        free(dir_path);
        return -1;
    }
    int handle = pippa_filepicker_alloc_scanner(dir, dir_path);
    if (handle < 0) {
        closedir(dir);
        free(dir_path);
        return -1;
    }
    return handle;
}

int pippa_filepicker_scan_next_size(int handle, int max_entries) {
    pippa_filepicker_scanner *scanner = pippa_filepicker_lookup_scanner(handle);
    if (scanner == NULL || max_entries <= 0) {
        return scanner == NULL ? -1 : 0;
    }
    errno = 0;
    long marker = telldir(scanner->dir);
    if (marker < 0) {
        return -1;
    }
    int total = 0;
    int count = 0;
    while (count < max_entries) {
        struct dirent *entry = readdir(scanner->dir);
        if (entry == NULL) {
            break;
        }
        if (pippa_filepicker_should_skip(entry->d_name)) {
            continue;
        }
        size_t name_len = strlen(entry->d_name);
        if (name_len > (size_t)INT_MAX || total > INT_MAX - (int)name_len - 3) {
            seekdir(scanner->dir, marker);
            return -1;
        }
        total += (int)name_len + 3;
        count += 1;
    }
    if (errno != 0) {
        seekdir(scanner->dir, marker);
        return -1;
    }
    seekdir(scanner->dir, marker);
    return total;
}

int pippa_filepicker_scan_next_fill(
    int handle,
    int max_entries,
    unsigned char *out_buf,
    int out_len
) {
    pippa_filepicker_scanner *scanner = pippa_filepicker_lookup_scanner(handle);
    if (scanner == NULL || max_entries <= 0) {
        return scanner == NULL ? -1 : 0;
    }
    int pos = 0;
    int count = 0;
    errno = 0;
    while (count < max_entries) {
        struct dirent *entry = readdir(scanner->dir);
        if (entry == NULL) {
            break;
        }
        if (pippa_filepicker_should_skip(entry->d_name)) {
            continue;
        }
        size_t name_len = strlen(entry->d_name);
        if (out_len - pos < 2 || name_len > (size_t)(out_len - pos - 2)) {
            return -1;
        }
        out_buf[pos++] = pippa_filepicker_is_dir(scanner->dir_path, entry) ? 'D' : 'F';
        out_buf[pos++] = '\0';
        memcpy(out_buf + pos, entry->d_name, name_len);
        pos += (int)name_len;
        out_buf[pos++] = '\0';
        count += 1;
    }
    if (errno != 0) {
        return -1;
    }
    return pos;
}

void pippa_filepicker_scan_close(int handle) {
    pippa_filepicker_scanner *scanner = pippa_filepicker_lookup_scanner(handle);
    if (scanner != NULL) {
        pippa_filepicker_close_scanner_slot(scanner);
    }
}
