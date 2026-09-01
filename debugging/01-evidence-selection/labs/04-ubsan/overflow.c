#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
static int parse(const char*s,int*out){char*end;errno=0;long v=strtol(s,&end,10);if(errno||*end!='\0'||v<INT_MIN||v>INT_MAX)return -1;*out=(int)v;return 0;}
int main(int argc,char**argv){int x;if(argc!=2||parse(argv[1],&x)){fprintf(stderr,"usage: %s INT\n",argv[0]);return 2;}x=x+1;printf("result=%d\n",x);return 0;}
