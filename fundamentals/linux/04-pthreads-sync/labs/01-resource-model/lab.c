#include <pthread.h>
#include <stdio.h>
struct ctx{int shared;}; static void *worker(void *p){struct ctx*c=p;c->shared+=1;printf("worker shared=%d addr=%p\n",c->shared,(void*)&c->shared);return 0;}int main(void){struct ctx c={41};pthread_t t;if(pthread_create(&t,0,worker,&c))return 1;if(pthread_join(t,0))return 1;printf("main shared=%d addr=%p\n",c.shared,(void*)&c.shared);return c.shared==42?0:1;}
