/*
 * SYNTHETIC PEDAGOGICAL FIXTURE — NOT BUSYBOX (M03)
 *
 * Minimal hermetic static ARM multi-call executable for fast
 * component/static teaching tests only. It is NOT BusyBox 1.36.1,
 * does NOT implement ash/init/ps/mount semantics, and MUST NOT be
 * mistaken for real BusyBox runtime evidence.
 *
 * - Multi-call dispatch via argv[0] (init, sh, ps, mount, ls, echo, cat)
 * - PID 1 initialization: mounts /proc, /sys, /dev
 * - /proc validation: ps verifies procfs is mounted
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <errno.h>

static void do_mount_pseudofs(void)
{
    mkdir("/proc", 0755);
    mkdir("/sys", 0755);
    mkdir("/dev", 0755);

    if (mount("proc", "/proc", "proc", 0, NULL) < 0) {
        if (errno != EBUSY) {
            perror("[INIT] mount(/proc)");
        }
    } else {
        printf("[INIT] Mounted /proc (procfs)\n");
    }

    if (mount("sysfs", "/sys", "sysfs", 0, NULL) < 0) {
        if (errno != EBUSY) {
            perror("[INIT] mount(/sys)");
        }
    } else {
        printf("[INIT] Mounted /sys (sysfs)\n");
    }

    if (mount("devtmpfs", "/dev", "devtmpfs", 0, NULL) < 0) {
        if (errno != EBUSY) {
            perror("[INIT] mount(/dev)");
        }
    } else {
        printf("[INIT] Mounted /dev (devtmpfs)\n");
    }
}

static int cmd_ps(void)
{
    if (access("/proc/1", F_OK) != 0) {
        fprintf(stderr, "ps: /proc: No such file or directory (procfs is not mounted!)\n");
        return 1;
    }
    printf("  PID TTY          TIME CMD\n");
    printf("    1 ?        00:00:00 init\n");
    printf("    2 ?        00:00:00 kthreadd\n");
    printf("   10 ttyAMA0  00:00:00 sh\n");
    return 0;
}

static int cmd_mount(void)
{
    FILE *fp = fopen("/proc/mounts", "r");
    if (!fp) {
        perror("mount: /proc/mounts");
        return 1;
    }
    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        fputs(line, stdout);
    }
    fclose(fp);
    return 0;
}

static int cmd_sh(void)
{
    printf("\n=== SYNTHETIC Pedagogical Shell (NOT BUSYBOX, M03) ===\n");
    printf("Type 'exit' to quit or run commands (ls, ps, mount, cat, echo).\n");
    printf("/ # ");
    fflush(stdout);

    char buf[256];
    while (fgets(buf, sizeof(buf), stdin)) {
        char *p = strchr(buf, '\n');
        if (p) *p = '\0';
        while (*buf == ' ') memmove(buf, buf + 1, strlen(buf));

        if (strcmp(buf, "exit") == 0) {
            break;
        } else if (strcmp(buf, "ps") == 0) {
            cmd_ps();
        } else if (strcmp(buf, "mount") == 0) {
            cmd_mount();
        } else if (strncmp(buf, "cat ", 4) == 0) {
            FILE *f = fopen(buf + 4, "r");
            if (f) {
                char cbuf[256];
                while (fgets(cbuf, sizeof(cbuf), f)) fputs(cbuf, stdout);
                fclose(f);
            } else {
                perror(buf + 4);
            }
        } else if (strncmp(buf, "echo ", 5) == 0) {
            printf("%s\n", buf + 5);
        } else if (strcmp(buf, "ls") == 0) {
            int ret = system("ls -la / 2>/dev/null || echo bin sbin etc dev proc sys tmp run mnt root");
            (void)ret;
        } else if (strlen(buf) > 0) {
            printf("sh: %s: not found\n", buf);
        }
        printf("/ # ");
        fflush(stdout);
    }
    printf("[SH] Shell exited.\n");
    return 0;
}

#include <sys/reboot.h>

static int cmd_init(void)
{
    pid_t pid = getpid();
    printf("====================================================\n");
    printf("=== SYNTHETIC PID 1 Init (NOT BUSYBOX, PID=%d) ===\n", (int)pid);
    printf("====================================================\n");

    do_mount_pseudofs();

    printf("[INIT] Userspace initialization complete. Spawning interactive shell...\n");
    cmd_sh();

    printf("[INIT] Shell exited. Triggering clean system poweroff...\n");
    reboot(RB_POWER_OFF);
    return 0;
}

int main(int argc, char **argv)
{
    char *prog = strrchr(argv[0], '/');
    prog = prog ? prog + 1 : argv[0];

    if (strcmp(prog, "init") == 0 || getpid() == 1) {
        return cmd_init();
    } else if (strcmp(prog, "sh") == 0) {
        return cmd_sh();
    } else if (strcmp(prog, "ps") == 0) {
        return cmd_ps();
    } else if (strcmp(prog, "mount") == 0) {
        return cmd_mount();
    } else {
        if (argc > 1) {
            if (strcmp(argv[1], "sh") == 0) return cmd_sh();
            if (strcmp(argv[1], "ps") == 0) return cmd_ps();
            if (strcmp(argv[1], "mount") == 0) return cmd_mount();
        }
        printf("SYNTHETIC PEDAGOGICAL FIXTURE v0.1 (ARM static) -- NOT BUSYBOX\n");
        printf("Currently defined functions:\n");
        printf("  cat, echo, init, ls, mount, ps, sh\n\n");
        return 0;
    }
}
