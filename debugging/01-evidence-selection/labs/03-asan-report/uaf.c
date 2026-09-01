#include <stdio.h>
#include <stdlib.h>
struct slot { int *borrowed; };
static void retain(struct slot *s,int *p){s->borrowed=p;}
static int consume(const struct slot *s){return *s->borrowed;}
int main(void){struct slot s={0};int*p=malloc(sizeof *p);if(!p)return 1;*p=42;retain(&s,p);free(p);printf("value=%d\n",consume(&s));return 0;}
