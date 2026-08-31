#define _POSIX_C_SOURCE 200809L
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>
static pid_t spawn_one(const char *path,const char *code,int log_fd)
{
    pid_t pid=fork(); if(pid==-1)return -1;
    if(pid==0){
        close(log_fd);
        char *const av[]={(char*)path,(char*)code,NULL}; execv(path,av); perror("execv"); _exit(127);
    }
    return pid;
}
static void report_status(pid_t pid,int st)
{
    if(WIFEXITED(st)) printf("child %ld exited code=%d\n",(long)pid,WEXITSTATUS(st));
    else if(WIFSIGNALED(st)) printf("child %ld signal=%d\n",(long)pid,WTERMSIG(st));
}
int main(void)
{
    int fd=open("supervisor.log",O_CREAT|O_TRUNC|O_WRONLY,0644); if(fd<0){perror("open");return 1;}
    char t[32]; snprintf(t,sizeof t,"%d",fd); setenv("SUPERVISOR_FD",t,1);
    pid_t a=spawn_one("./worker_image","7",fd); pid_t b=spawn_one("./worker_missing","3",fd);
    if(a<0||b<0){perror("fork");close(fd);return 1;}
    int sa,sb; if(waitpid(a,&sa,0)==-1||waitpid(b,&sb,0)==-1){perror("waitpid");close(fd);return 1;}
    report_status(a,sa); report_status(b,sb); close(fd); return 0;
}
