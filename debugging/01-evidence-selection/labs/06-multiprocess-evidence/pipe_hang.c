#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
int main(void){int p[2];if(pipe(p)<0){perror("pipe");return 1;}pid_t child=fork();if(child<0){perror("fork");return 1;}if(child==0){char b[8];(void)close(p[1]);while(read(p[0],b,sizeof b)>0){}(void)close(p[0]);_exit(0);}/* Seeded fault: parent intentionally keeps p[1] open while waiting. */printf("parent=%ld child=%ld write_fd=%d; inspect /proc/<pid>/fd, then terminate fixture\n",(long)getpid(),(long)child,p[1]);fflush(stdout);if(waitpid(child,NULL,0)<0){perror("waitpid");return 1;}return 0;}
