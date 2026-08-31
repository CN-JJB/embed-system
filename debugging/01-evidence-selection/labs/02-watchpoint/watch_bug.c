#include <stdint.h>
#include <stdio.h>
struct record_state { uint32_t count; uint32_t sequence; };
static void normalize(struct record_state *s){ if(s->sequence==0)s->count=0; }
static void process(struct record_state *s){ s->count+=1; normalize(s); }
int main(void){struct record_state s={4,0};process(&s);printf("count=%u expected=5\n",s.count);return s.count==5?0:1;}
