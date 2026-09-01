#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
struct state{uint32_t count;};
static int uaf(void){int*p=malloc(sizeof*p);if(!p)return 1;*p=7;struct{int*q;}slot={p};free(p);printf("%d\n",*slot.q);return 0;}
static int overwrite(void){struct state s={5};s.count=0;printf("count=%u expected=5\n",s.count);return 1;}
static int open_fault(void){int fd=open("./missing-m08-fault",O_RDONLY);if(fd<0){fprintf(stderr,"open failed: %s\n",strerror(errno));return 1;}close(fd);return 0;}
static int endian(void){unsigned char b[4]={0x78,0x56,0x34,0x12};uint32_t v=((uint32_t)b[0]<<24)|((uint32_t)b[1]<<16)|((uint32_t)b[2]<<8)|b[3];printf("wrong decode=0x%08x\n",v);return 1;}
static int pipe_fault(void){int p[2];if(pipe(p)<0)return 1;pid_t c=fork();if(c<0)return 1;if(c==0){char x;close(p[1]);while(read(p[0],&x,1)>0){}close(p[0]);_exit(0);}printf("pid=%ld write_fd=%d; seeded writer remains open\n",(long)getpid(),p[1]);fflush(stdout);return waitpid(c,NULL,0)<0?1:0;}
int main(int argc,char**argv){if(argc!=2)return 2;if(!strcmp(argv[1],"uaf"))return uaf();if(!strcmp(argv[1],"state"))return overwrite();if(!strcmp(argv[1],"open"))return open_fault();if(!strcmp(argv[1],"endian"))return endian();if(!strcmp(argv[1],"pipe"))return pipe_fault();return 2;}
