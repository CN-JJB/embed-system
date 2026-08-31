#ifndef FDCOPY_LIMIT_H
#define FDCOPY_LIMIT_H
#include <stdint.h>
int copy_fd_limit(int in_fd, int out_fd, uintmax_t limit, uintmax_t *copied);
#endif
