#include <stdio.h>
struct sample { int current; int limit; };
static int update(struct sample *s,int delta){s->current+=delta;if(s->current>=s->limit)s->current=s->limit-1;return s->current;}
static int run_case(void){struct sample s={7,10};return update(&s,3);}
int main(void){int result=run_case();printf("result=%d expected=10\n",result);return result==10?0:1;}
