#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
static int memory_fault(void){struct holder{int*p;}h={0};int*p=malloc(sizeof*p);if(!p)return 1;*p=99;h.p=p;free(p);return *h.p==99?0:1;}
static int byte_fault(void){unsigned char b[4]={0x78,0x56,0x34,0x12};uint32_t v=((uint32_t)b[0]<<24)|((uint32_t)b[1]<<16)|((uint32_t)b[2]<<8)|b[3];printf("decoded=0x%08x contract=0x12345678\n",v);return v==0x12345678?0:1;}
static int fd_fault(void){int p[2];if(pipe(p)<0)return 1;pid_t c=fork();if(c<0)return 1;if(c==0){char x;close(p[1]);while(read(p[0],&x,1)>0){}close(p[0]);_exit(0);}printf("supervisor=%ld child=%ld; writer accidentally remains open\n",(long)getpid(),(long)c);fflush(stdout);return waitpid(c,NULL,0)<0?1:0;}
static int file_fault(const char*path){int fd=open(path,O_RDONLY);if(fd<0){fprintf(stderr,"read path failed: %s\n",strerror(errno));return 1;}close(fd);return 0;}
int main(int argc,char**argv){if(argc<2){fprintf(stderr,"modes: memory bytes fd file PATH\n");return 2;}if(!strcmp(argv[1],"memory"))return memory_fault();if(!strcmp(argv[1],"bytes"))return byte_fault();if(!strcmp(argv[1],"fd"))return fd_fault();if(!strcmp(argv[1],"file")&&argc==3)return file_fault(argv[2]);return 2;}
