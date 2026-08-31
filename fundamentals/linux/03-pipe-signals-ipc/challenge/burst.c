
#include <errno.h>
#include <string.h>
#include <unistd.h>

int main(void)
{
    char block[4096];
    unsigned i;
    memset(block, 'B', sizeof block);
    block[sizeof block - 1] = '\n';

    for (i = 0; i < 512; i++) {
        size_t off = 0;
        while (off < sizeof block) {
            ssize_t n = write(STDOUT_FILENO, block + off, sizeof block - off);
            if (n > 0) { off += (size_t)n; continue; }
            if (n < 0 && errno == EINTR) continue;
            return 2;
        }
    }
    return 7;
}
