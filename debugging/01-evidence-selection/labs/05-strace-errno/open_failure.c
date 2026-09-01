#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
int main(int argc,char**argv){const char*path=argc>1?argv[1]:"./definitely-missing-m08-file";int fd=open(path,O_RDONLY);if(fd<0){int x=errno;fprintf(stderr,"open(%s): %s (errno=%d)\n",path,strerror(x),x);return 1;}if(close(fd)<0){perror("close");return 1;}return 0;}
