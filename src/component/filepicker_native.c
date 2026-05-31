#define _GNU_SOURCE

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#if defined(_WIN32)
#define lstat stat
#endif

#define PIPPA_FILEPICKER_MAX_SCANNERS 32
#define PIPPA_FILEPICKER_MAX_TEST_FIXTURES 8

typedef struct {
    DIR *dir;
    char *dir_path;
    int in_use;
} pippa_filepicker_scanner;

typedef struct {
    char kind;
    int is_symlink;
    char permissions[11];
    char size[32];
    int hidden;
} pippa_filepicker_entry_meta;

static pippa_filepicker_scanner pippa_filepicker_scanners[PIPPA_FILEPICKER_MAX_SCANNERS];
static char *pippa_filepicker_test_fixture_roots[PIPPA_FILEPICKER_MAX_TEST_FIXTURES];

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

static char *pippa_filepicker_join_path(const char *dir_path, const char *name) {
    size_t dir_len = strlen(dir_path);
    size_t name_len = strlen(name);
    int needs_sep = dir_len > 0 && dir_path[dir_len - 1] != '/';
    char *full_path = (char *)malloc(dir_len + (size_t)needs_sep + name_len + 1);
    if (full_path == NULL) {
        return NULL;
    }
    memcpy(full_path, dir_path, dir_len);
    if (needs_sep) {
        full_path[dir_len] = '/';
        dir_len += 1;
    }
    memcpy(full_path + dir_len, name, name_len);
    full_path[dir_len + name_len] = '\0';
    return full_path;
}

static char pippa_filepicker_mode_type(mode_t mode) {
    if (S_ISDIR(mode)) {
        return 'd';
    }
    if (S_ISLNK(mode)) {
        return 'l';
    }
#ifdef S_ISCHR
    if (S_ISCHR(mode)) {
        return 'c';
    }
#endif
#ifdef S_ISBLK
    if (S_ISBLK(mode)) {
        return 'b';
    }
#endif
#ifdef S_ISFIFO
    if (S_ISFIFO(mode)) {
        return 'p';
    }
#endif
#ifdef S_ISSOCK
    if (S_ISSOCK(mode)) {
        return 's';
    }
#endif
    return '-';
}

static void pippa_filepicker_mode_string(mode_t mode, char out[11]) {
    out[0] = pippa_filepicker_mode_type(mode);
    out[1] = (mode & S_IRUSR) ? 'r' : '-';
    out[2] = (mode & S_IWUSR) ? 'w' : '-';
    out[3] = (mode & S_IXUSR) ? ((mode & S_ISUID) ? 's' : 'x') : ((mode & S_ISUID) ? 'S' : '-');
    out[4] = (mode & S_IRGRP) ? 'r' : '-';
    out[5] = (mode & S_IWGRP) ? 'w' : '-';
    out[6] = (mode & S_IXGRP) ? ((mode & S_ISGID) ? 's' : 'x') : ((mode & S_ISGID) ? 'S' : '-');
    out[7] = (mode & S_IROTH) ? 'r' : '-';
    out[8] = (mode & S_IWOTH) ? 'w' : '-';
    out[9] = (mode & S_IXOTH) ? ((mode & S_ISVTX) ? 't' : 'x') : ((mode & S_ISVTX) ? 'T' : '-');
    out[10] = '\0';
}

static int pippa_filepicker_is_hidden_entry(const char *name, const struct stat *st) {
    if (name[0] == '.' && strcmp(name, ".") != 0 && strcmp(name, "..") != 0) {
        return 1;
    }
#if defined(UF_HIDDEN)
    if (st != NULL && (st->st_flags & UF_HIDDEN) != 0) {
        return 1;
    }
#else
    (void)st;
#endif
    return 0;
}

static void pippa_filepicker_default_metadata(
    const struct dirent *entry,
    pippa_filepicker_entry_meta *meta
) {
    meta->kind = 'F';
    meta->is_symlink = 0;
    strcpy(meta->permissions, "----------");
    strcpy(meta->size, "0");
    meta->hidden = pippa_filepicker_is_hidden_entry(entry->d_name, NULL);
}

static int pippa_filepicker_fill_metadata(
    const char *dir_path,
    const struct dirent *entry,
    pippa_filepicker_entry_meta *meta
) {
    pippa_filepicker_default_metadata(entry, meta);
    char *full_path = pippa_filepicker_join_path(dir_path, entry->d_name);
    if (full_path == NULL) {
        return -1;
    }

    struct stat lst;
    int saved_errno = errno;
    if (lstat(full_path, &lst) != 0) {
        errno = saved_errno;
        free(full_path);
        return 0;
    }
    errno = saved_errno;

    int is_dir = S_ISDIR(lst.st_mode);
    int is_symlink = S_ISLNK(lst.st_mode);
    if (is_symlink) {
        struct stat target;
        saved_errno = errno;
        if (stat(full_path, &target) == 0 && S_ISDIR(target.st_mode)) {
            is_dir = 1;
        }
        errno = saved_errno;
    }

    meta->kind = is_dir ? 'D' : 'F';
    meta->is_symlink = is_symlink;
    pippa_filepicker_mode_string(lst.st_mode, meta->permissions);
    long long size = (long long)lst.st_size;
    if (size < 0) {
        size = 0;
    }
    if (size > INT_MAX) {
        size = INT_MAX;
    }
    snprintf(meta->size, sizeof(meta->size), "%lld", size);
    meta->hidden = pippa_filepicker_is_hidden_entry(entry->d_name, &lst);
    free(full_path);
    return 0;
}

static int pippa_filepicker_write_text_file(
    const char *path,
    const char *content,
    mode_t mode
) {
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, mode);
    if (fd < 0) {
        return -1;
    }
    size_t len = strlen(content);
    size_t written_total = 0;
    while (written_total < len) {
        ssize_t written = write(fd, content + written_total, len - written_total);
        if (written < 0) {
            close(fd);
            return -1;
        }
        written_total += (size_t)written;
    }
    if (close(fd) != 0) {
        return -1;
    }
    return chmod(path, mode);
}

static void pippa_filepicker_fixture_unlink_name(const char *root, const char *name) {
    char *path = pippa_filepicker_join_path(root, name);
    if (path != NULL) {
        unlink(path);
        free(path);
    }
}

static void pippa_filepicker_fixture_rmdir_name(const char *root, const char *name) {
    char *path = pippa_filepicker_join_path(root, name);
    if (path != NULL) {
        rmdir(path);
        free(path);
    }
}

static void pippa_filepicker_remove_test_fixture(const char *root) {
    char name[32];
    for (int i = 0; i < 70; i++) {
        snprintf(name, sizeof(name), "extra-%02d.txt", i);
        pippa_filepicker_fixture_unlink_name(root, name);
    }
    pippa_filepicker_fixture_unlink_name(root, "regular.txt");
    pippa_filepicker_fixture_unlink_name(root, ".hidden");
    pippa_filepicker_fixture_unlink_name(root, "link-file");
    pippa_filepicker_fixture_unlink_name(root, "link-dir");
    pippa_filepicker_fixture_unlink_name(root, "broken-link");
    pippa_filepicker_fixture_rmdir_name(root, "subdir");
    rmdir(root);
}

static int pippa_filepicker_fixture_write_file(
    const char *root,
    const char *name,
    const char *content,
    mode_t mode
) {
    char *path = pippa_filepicker_join_path(root, name);
    if (path == NULL) {
        return -1;
    }
    int result = pippa_filepicker_write_text_file(path, content, mode);
    free(path);
    return result;
}

static int pippa_filepicker_fixture_mkdir(
    const char *root,
    const char *name,
    mode_t mode
) {
    char *path = pippa_filepicker_join_path(root, name);
    if (path == NULL) {
        return -1;
    }
    int result = mkdir(path, mode);
    if (result == 0) {
        result = chmod(path, mode);
    }
    free(path);
    return result;
}

static int pippa_filepicker_fixture_symlink(
    const char *root,
    const char *name,
    const char *target
) {
    char *path = pippa_filepicker_join_path(root, name);
    if (path == NULL) {
        return -1;
    }
    int result = symlink(target, path);
    free(path);
    return result;
}

static int pippa_filepicker_populate_test_fixture(const char *root) {
    if (pippa_filepicker_fixture_mkdir(root, "subdir", 0750) != 0 ||
        pippa_filepicker_fixture_write_file(root, "regular.txt", "regular\n", 0640) != 0 ||
        pippa_filepicker_fixture_write_file(root, ".hidden", "hidden\n", 0600) != 0 ||
        pippa_filepicker_fixture_symlink(root, "link-file", "regular.txt") != 0 ||
        pippa_filepicker_fixture_symlink(root, "link-dir", "subdir") != 0 ||
        pippa_filepicker_fixture_symlink(root, "broken-link", "missing-target") != 0) {
        return -1;
    }
    char name[32];
    for (int i = 0; i < 70; i++) {
        snprintf(name, sizeof(name), "extra-%02d.txt", i);
        if (pippa_filepicker_fixture_write_file(root, name, "x", 0644) != 0) {
            return -1;
        }
    }
    return 0;
}

static int pippa_filepicker_test_fixture_remember(const char *root) {
    for (int i = 0; i < PIPPA_FILEPICKER_MAX_TEST_FIXTURES; i++) {
        if (pippa_filepicker_test_fixture_roots[i] == NULL) {
            pippa_filepicker_test_fixture_roots[i] = strdup(root);
            return pippa_filepicker_test_fixture_roots[i] == NULL ? -1 : 0;
        }
    }
    return -1;
}

static int pippa_filepicker_test_fixture_forget(const char *root) {
    for (int i = 0; i < PIPPA_FILEPICKER_MAX_TEST_FIXTURES; i++) {
        char *known = pippa_filepicker_test_fixture_roots[i];
        if (known != NULL && strcmp(known, root) == 0) {
            free(known);
            pippa_filepicker_test_fixture_roots[i] = NULL;
            return 1;
        }
    }
    return 0;
}

static int pippa_filepicker_test_fixture_path_valid(const char *root) {
    if (root == NULL || root[0] == '\0' || strcmp(root, ".") == 0) {
        return 0;
    }
    char expected_prefix[PATH_MAX];
    int prefix_len = snprintf(
        expected_prefix,
        sizeof(expected_prefix),
        "/tmp/pippa-filepicker-%ld-",
        (long)getpid()
    );
    if (prefix_len <= 0 || prefix_len >= (int)sizeof(expected_prefix)) {
        return 0;
    }
    if (strncmp(root, expected_prefix, (size_t)prefix_len) != 0) {
        return 0;
    }
    const char *suffix = root + prefix_len;
    if (strlen(suffix) != 6) {
        return 0;
    }
    for (const char *p = suffix; *p != '\0'; p++) {
        if (*p == '/' || *p == '.') {
            return 0;
        }
    }
    return 1;
}

int pippa_filepicker_test_fixture_create(unsigned char *out_buf, int out_len) {
    if (out_buf == NULL || out_len <= 0) {
        return -1;
    }
    char template_path[PATH_MAX];
    int len = snprintf(
        template_path,
        sizeof(template_path),
        "/tmp/pippa-filepicker-%ld-XXXXXX",
        (long)getpid()
    );
    if (len <= 0 || len >= (int)sizeof(template_path)) {
        return -1;
    }
    char *root = mkdtemp(template_path);
    if (root == NULL) {
        return -1;
    }
    if (pippa_filepicker_populate_test_fixture(root) != 0) {
        pippa_filepicker_remove_test_fixture(root);
        return -1;
    }
    if (!pippa_filepicker_test_fixture_path_valid(root) ||
        pippa_filepicker_test_fixture_remember(root) != 0) {
        pippa_filepicker_remove_test_fixture(root);
        return -1;
    }
    size_t root_len = strlen(root);
    if (root_len > (size_t)INT_MAX || root_len > (size_t)out_len) {
        pippa_filepicker_test_fixture_forget(root);
        pippa_filepicker_remove_test_fixture(root);
        return -1;
    }
    memcpy(out_buf, root, root_len);
    return (int)root_len;
}

void pippa_filepicker_test_fixture_cleanup(const unsigned char *path, int path_len) {
    char *root = pippa_filepicker_copy_path(path, path_len);
    if (root != NULL) {
        if (pippa_filepicker_test_fixture_path_valid(root) &&
            pippa_filepicker_test_fixture_forget(root)) {
            pippa_filepicker_remove_test_fixture(root);
        }
        free(root);
    }
}

static int pippa_filepicker_should_skip(const char *name) {
    return strcmp(name, ".") == 0 || strcmp(name, "..") == 0;
}

static int pippa_filepicker_add_field_size(int *total, size_t len) {
    if (len > (size_t)INT_MAX || *total > INT_MAX - (int)len - 1) {
        return -1;
    }
    *total += (int)len + 1;
    return 0;
}

static int pippa_filepicker_entry_serialized_size(
    const pippa_filepicker_entry_meta *meta,
    const char *name,
    int *total
) {
    if (pippa_filepicker_add_field_size(total, 1) != 0 ||
        pippa_filepicker_add_field_size(total, 1) != 0 ||
        pippa_filepicker_add_field_size(total, strlen(meta->permissions)) != 0 ||
        pippa_filepicker_add_field_size(total, strlen(meta->size)) != 0 ||
        pippa_filepicker_add_field_size(total, 1) != 0 ||
        pippa_filepicker_add_field_size(total, strlen(name)) != 0) {
        return -1;
    }
    return 0;
}

static int pippa_filepicker_write_field(
    unsigned char *out_buf,
    int out_len,
    int *pos,
    const char *field,
    size_t len
) {
    if (len > (size_t)INT_MAX || out_len - *pos < (int)len + 1) {
        return -1;
    }
    memcpy(out_buf + *pos, field, len);
    *pos += (int)len;
    out_buf[(*pos)++] = '\0';
    return 0;
}

static int pippa_filepicker_write_entry(
    unsigned char *out_buf,
    int out_len,
    int *pos,
    const pippa_filepicker_entry_meta *meta,
    const char *name
) {
    char kind[2] = { meta->kind, '\0' };
    char symlink[2] = { meta->is_symlink ? '1' : '0', '\0' };
    char hidden[2] = { meta->hidden ? '1' : '0', '\0' };
    if (pippa_filepicker_write_field(out_buf, out_len, pos, kind, 1) != 0 ||
        pippa_filepicker_write_field(out_buf, out_len, pos, symlink, 1) != 0 ||
        pippa_filepicker_write_field(out_buf, out_len, pos, meta->permissions, strlen(meta->permissions)) != 0 ||
        pippa_filepicker_write_field(out_buf, out_len, pos, meta->size, strlen(meta->size)) != 0 ||
        pippa_filepicker_write_field(out_buf, out_len, pos, hidden, 1) != 0 ||
        pippa_filepicker_write_field(out_buf, out_len, pos, name, strlen(name)) != 0) {
        return -1;
    }
    return 0;
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
        pippa_filepicker_entry_meta meta;
        if (pippa_filepicker_fill_metadata(dir_path, entry, &meta) != 0 ||
            pippa_filepicker_entry_serialized_size(&meta, entry->d_name, &total) != 0) {
            closedir(dir);
            free(dir_path);
            return -1;
        }
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
        pippa_filepicker_entry_meta meta;
        if (pippa_filepicker_fill_metadata(dir_path, entry, &meta) != 0 ||
            pippa_filepicker_write_entry(out_buf, out_len, &pos, &meta, entry->d_name) != 0) {
            closedir(dir);
            free(dir_path);
            return -1;
        }
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
        pippa_filepicker_entry_meta meta;
        if (pippa_filepicker_fill_metadata(scanner->dir_path, entry, &meta) != 0 ||
            pippa_filepicker_entry_serialized_size(&meta, entry->d_name, &total) != 0) {
            seekdir(scanner->dir, marker);
            return -1;
        }
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
        pippa_filepicker_entry_meta meta;
        if (pippa_filepicker_fill_metadata(scanner->dir_path, entry, &meta) != 0 ||
            pippa_filepicker_write_entry(out_buf, out_len, &pos, &meta, entry->d_name) != 0) {
            return -1;
        }
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
