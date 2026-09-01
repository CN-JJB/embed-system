#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
struct record{uint8_t version,kind;uint16_t flags;uint32_t value,sequence;};
static uint32_t bad_be32(const unsigned char*p){return((uint32_t)p[0]<<24)|((uint32_t)p[1]<<16)|((uint32_t)p[2]<<8)|p[3];}
static int read_exact_file(const char*path,unsigned char*b,size_t n){int fd=open(path,O_RDONLY);if(fd<0){fprintf(stderr,"open: %s\n",strerror(errno));return -1;}ssize_t r=read(fd,b,n);int saved=errno;if(close(fd)<0&&r>=0){perror("close");return -1;}errno=saved;if(r<0){perror("read");return -1;}if((size_t)r!=n){fprintf(stderr,"short read: %zd/%zu\n",r,n);return -1;}return 0;}
static void overwrite(struct record*r){if(r->kind==2)r->sequence=0;}
static int memory_mode(void){struct{char*label;}s={0};char*p=malloc(8);if(!p)return 1;memcpy(p,"reader",7);s.label=p;free(p);printf("label=%s\n",s.label);return 0;}
int main(int argc,char**argv){if(argc<2){fprintf(stderr,"modes: memory endian state file PATH\n");return 2;}if(strcmp(argv[1],"memory")==0)return memory_mode();const unsigned char golden[12]={1,2,0x34,0x12,0x78,0x56,0x34,0x12,0xef,0xcd,0xab,0x90};if(strcmp(argv[1],"endian")==0){printf("value=0x%08x expected=0x12345678\n",bad_be32(golden+4));return 1;}if(strcmp(argv[1],"state")==0){struct record r={1,2,0x1234,0x12345678,0x90abcdef};overwrite(&r);printf("sequence=0x%08x expected=0x90abcdef\n",r.sequence);return 1;}if(strcmp(argv[1],"file")==0){if(argc!=3)return 2;unsigned char b[12];return read_exact_file(argv[2],b,sizeof b)==0?0:1;}return 2;}
