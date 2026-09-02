#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <assert.h>

/*
 * M10 Fault Station F3: Owned File Descriptor Leak
 *
 * Seeded bug:
 * Function process_telemetry_file() opens an input file (owned FD).
 * When it encounters an error or EOF condition, it returns early
 * WITHOUT calling close(fd), leaking the file descriptor.
 */

static int count_open_fds(void) {
    DIR *d = opendir("/proc/self/fd");
    if (!d) {
        return -1;
    }
    int count = 0;
    struct dirent *de;
    while ((de = readdir(d)) != NULL) {
        if (de->d_name[0] != '.') {
            count++;
        }
    }
    closedir(d);
    return count;
}

static int process_telemetry_file_leaky(const char *path) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        return -1;
    }

    char buf[64];
    ssize_t n = read(fd, buf, sizeof(buf));
    if (n <= 0) {
        /* SEEDED BUG: Returns error without closing owned fd! */
        return -1;
    }

    /* Simulate validation error on contents */
    if (strncmp(buf, "VALID", 5) != 0) {
        /* SEEDED BUG: Returns error without closing owned fd! */
        return -2;
    }

    close(fd);
    return 0;
}

int main(void) {
    printf("=== M10 Fault Station F3: Owned File Descriptor Leak ===\n");

    /* Create temporary invalid file */
    char tmp_path[] = "/tmp/telemetry_f3_XXXXXX";
    int tmp_fd = mkstemp(tmp_path);
    assert(tmp_fd >= 0);
    write(tmp_fd, "MALFORMED_DATA", 14);
    close(tmp_fd);

    int before_fds = count_open_fds();
    printf("Open FDs before calls: %d\n", before_fds);

    /* Perform 5 leaky calls */
    for (int i = 0; i < 5; i++) {
        int rc = process_telemetry_file_leaky(tmp_path);
        assert(rc < 0);
    }

    int after_fds = count_open_fds();
    printf("Open FDs after 5 failed calls: %d\n", after_fds);

    unlink(tmp_path);

    if (after_fds > before_fds) {
        printf(">>> F3 REPRODUCED: Owned file descriptors leaked! Leaked count=%d <<<\n",
               after_fds - before_fds);
        return 1;
    } else {
        printf("No FD leak detected.\n");
        return 0;
    }
}
