#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: %s FILE...\n", argv[0]);
        return 2;
    }

    int *fds = calloc((size_t)(argc - 1), sizeof *fds);
    if (fds == NULL) {
        perror("calloc");
        return 1;
    }

    printf("pid=%ld\n", (long)getpid());
    for (int i = 1; i < argc; ++i) {
        fds[i - 1] = open(argv[i], O_RDONLY);
        if (fds[i - 1] < 0) {
            perror(argv[i]);
            for (int j = 1; j < i; ++j) close(fds[j - 1]);
            free(fds);
            return 1;
        }
        printf("opened %s -> fd=%d\n", argv[i], fds[i - 1]);
    }

    puts("phase=open; inspect /proc/<pid>/fd, then press Enter");
    fflush(stdout);
    (void)getchar();

    for (int i = 1; i < argc; ++i) {
        if (close(fds[i - 1]) < 0) perror("close");
    }
    puts("phase=closed; inspect again, then press Enter to exit");
    fflush(stdout);
    (void)getchar();
    free(fds);
    return 0;
}
