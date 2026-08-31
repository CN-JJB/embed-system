#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static int apply_override(const char *text)
{
    const char *eq=strchr(text,'='); if(!eq || eq==text) return -1;
    size_t n=(size_t)(eq-text); char *name=malloc(n+1); if(!name) return -1;
    memcpy(name,text,n); name[n]='\0'; int rc=setenv(name,eq+1,1); free(name); return rc;
}
int main(int argc,char **argv)
{
    if(argc<3){fprintf(stderr,"usage: %s NAME=VALUE COMMAND [ARGS...]\n",argv[0]);return 2;}
    pid_t c=fork(); if(c==-1){perror("fork");return 1;}
    if(c==0){
        if(apply_override(argv[1])==-1){fprintf(stderr,"invalid environment override\n");_exit(125);}
        execvp(argv[2],&argv[2]);
        perror("execvp");
        _exit(127); /* challenge contract reserves 127 for exec failure */
    }
    int st; if(waitpid(c,&st,0)==-1){perror("waitpid");return 1;}
    if(WIFEXITED(st)){printf("child=%ld exited code=%d\n",(long)c,WEXITSTATUS(st));return 0;}
    if(WIFSIGNALED(st)){printf("child=%ld terminated signal=%d\n",(long)c,WTERMSIG(st));return 0;}
    printf("child=%ld changed state\n",(long)c); return 0;
}
