#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

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
