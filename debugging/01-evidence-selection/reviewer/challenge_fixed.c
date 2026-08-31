#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
static uint32_t le32(const unsigned char*p){return(uint32_t)p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
static int read_exact_file(const char*path,unsigned char*b,size_t n){int fd=open(path,O_RDONLY);if(fd<0){fprintf(stderr,"open: %s\n",strerror(errno));return -1;}size_t off=0;while(off<n){ssize_t r=read(fd,b+off,n-off);if(r<0){if(errno==EINTR)continue;perror("read");close(fd);return -1;}if(r==0){fprintf(stderr,"short input\n");close(fd);return -1;}off+=(size_t)r;}if(close(fd)<0){perror("close");return -1;}return 0;}
int main(int argc,char**argv){const unsigned char g[12]={1,2,0x34,0x12,0x78,0x56,0x34,0x12,0xef,0xcd,0xab,0x90};if(argc==1){printf("value=0x%08x sequence=0x%08x\n",le32(g+4),le32(g+8));return le32(g+4)==0x12345678?0:1;}unsigned char b[12];return read_exact_file(argv[1],b,sizeof b)==0?0:1;}
