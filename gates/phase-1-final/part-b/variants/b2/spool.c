#define _POSIX_C_SOURCE 200809L
#include "spool.h"
#include <unistd.h>
#include <fcntl.h>
#include <string.h>

int spool_init(struct spool_manager *mgr, const char *initial_path) {
    if (mgr == NULL || initial_path == NULL) {
        return -1;
    }
    memset(mgr, 0, sizeof(*mgr));
    int fd = open(initial_path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (fd < 0) {
        return -1;
    }
    mgr->current_fd = fd;
    strncpy(mgr->current_path, initial_path, sizeof(mgr->current_path) - 1);
    return 0;
}

int spool_write(struct spool_manager *mgr, const char *data, size_t len) {
    if (mgr == NULL || mgr->current_fd < 0 || data == NULL) {
        return -1;
    }
    ssize_t n = write(mgr->current_fd, data, len);
    if (n > 0) {
        mgr->total_written += (size_t)n;
        return 0;
    }
    return -1;
}

int spool_rotate(struct spool_manager *mgr, const char *new_path) {
    if (mgr == NULL || new_path == NULL) {
        return -1;
    }
    int new_fd = open(new_path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (new_fd < 0) {
        return -1;
    }
    mgr->current_fd = new_fd;
    strncpy(mgr->current_path, new_path, sizeof(mgr->current_path) - 1);
    return 0;
}

void spool_close(struct spool_manager *mgr) {
    if (mgr != NULL && mgr->current_fd >= 0) {
        close(mgr->current_fd);
        mgr->current_fd = -1;
    }
}
