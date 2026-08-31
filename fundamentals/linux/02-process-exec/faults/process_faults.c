#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static int state_is_z(pid_t pid)
{
    char path[64], comm[256], st; long seen;
    snprintf(path, sizeof path, "/proc/%ld/stat", (long)pid);
    FILE *fp=fopen(path,"r"); if(!fp) return 0;
    int ok=fscanf(fp,"%ld %255s %c",&seen,comm,&st)==3 && st=='Z';
    fclose(fp); return ok;
}
static void wait_z(pid_t pid)
{
    struct timespec ts={0,10*1000*1000};
    for(int i=0;i<500 && !state_is_z(pid);++i) nanosleep(&ts,NULL);
}
static int exec_bad_helper(void)
{
    char *const av[]={"missing",NULL};
    execv("./definitely-missing",av);
    perror("execv");
    return 127;
}

int main(int argc, char **argv)
{
    if(argc!=2){fprintf(stderr,"usage: %s zombie|fallthrough|status|fd\n",argv[0]);return 2;}
    if(strcmp(argv[1],"zombie")==0){
        pid_t c=fork(); if(c==0)_exit(0); if(c<0){perror("fork");return 1;}
        wait_z(c); printf("zombie fault parent=%ld child=%ld; inspect then Enter\n",(long)getpid(),(long)c); fflush(stdout);
        (void)getchar(); /* deliberate: no waitpid before checkpoint */
        return 0;
    }
    if(strcmp(argv[1],"fallthrough")==0){
        pid_t c=fork(); if(c<0){perror("fork");return 1;}
        if(c==0){int rc=exec_bad_helper(); printf("BUG child continued caller logic pid=%ld rc=%d\n",(long)getpid(),rc); return rc;}
        int st; waitpid(c,&st,0); return 0;
    }
    if(strcmp(argv[1],"status")==0){
        pid_t c=fork(); if(c<0){perror("fork");return 1;} if(c==0)_exit(7);
        int st; if(waitpid(c,&st,0)==-1){perror("waitpid");return 1;}
        printf("BUG raw status reported as exit code: %d\n",st); return 0;
    }
    if(strcmp(argv[1],"fd")==0){
        int fd=open("fault.log",O_CREAT|O_TRUNC|O_WRONLY,0644); if(fd<0){perror("open");return 1;}
        char value[32]; snprintf(value,sizeof value,"%d",fd); setenv("FAULT_FD",value,1);
        pid_t c=fork(); if(c<0){perror("fork");return 1;}
        if(c==0){char *const av[]={"fd_probe",NULL}; execv("./fd_probe",av); perror("execv"); _exit(127);}
        int st; waitpid(c,&st,0); close(fd); return 0;
    }
    return 2;
}
