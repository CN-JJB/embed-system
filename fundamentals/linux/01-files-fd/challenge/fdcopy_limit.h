#ifndef FDCOPY_LIMIT_H
#define FDCOPY_LIMIT_H
#include <stdint.h>
/* On return, *copied is the number of bytes successfully written to out_fd,
 * including partial progress if the function later fails.
 */
int copy_fd_limit(int in_fd, int out_fd, uintmax_t limit, uintmax_t *copied);
#endif
