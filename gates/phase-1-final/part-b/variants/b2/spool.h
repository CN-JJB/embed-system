#ifndef B2_SPOOL_H
#define B2_SPOOL_H

#include <stddef.h>

struct spool_manager {
    int current_fd;
    size_t total_written;
    char current_path[128];
};

int spool_init(struct spool_manager *mgr, const char *initial_path);
int spool_write(struct spool_manager *mgr, const char *data, size_t len);
int spool_rotate(struct spool_manager *mgr, const char *new_path);
void spool_close(struct spool_manager *mgr);

#endif /* B2_SPOOL_H */
