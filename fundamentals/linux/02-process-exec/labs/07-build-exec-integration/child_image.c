#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
static const char build_id[] = "integration-child-v1";
int main(int argc, char **argv)
{
    printf("child image pid=%ld ppid=%ld build_id=%s argc=%d argv0=%s\n",
           (long)getpid(), (long)getppid(), build_id, argc, argv[0]);
    printf("inspection checkpoint; inspect /proc/%ld/cmdline then press Enter\n", (long)getpid());
    fflush(stdout);
    (void)getchar();
    return getenv("INTEGRATION_TOKEN") ? 0 : 3;
}
