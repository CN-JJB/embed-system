#define _POSIX_C_SOURCE 200809L
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

int main(void)
{
    int fd = open("inherited.log", O_CREAT | O_TRUNC | O_WRONLY, 0644);
    if (fd == -1) { perror("open"); return 1; }

    pid_t child = fork();
    if (child == -1) { perror("fork"); close(fd); return 1; }
    if (child == 0) {
        dprintf(fd, "child pid=%ld inherited fd=%d\n", (long)getpid(), fd);
        printf("child checkpoint pid=%ld ppid=%ld inherited_fd=%d; inspect /proc then press Enter\n",
               (long)getpid(), (long)getppid(), fd);
        fflush(stdout);
        (void)getchar();
        close(fd);
        _exit(0);
    }

    printf("parent pid=%ld child=%ld inherited_fd_number=%d\n", (long)getpid(), (long)child, fd);
    fflush(stdout);
    int status;
    if (waitpid(child, &status, 0) == -1) { perror("waitpid"); close(fd); return 1; }
    close(fd);
    return WIFEXITED(status) && WEXITSTATUS(status) == 0 ? 0 : 1;
}
