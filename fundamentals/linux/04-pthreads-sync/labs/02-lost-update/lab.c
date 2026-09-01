#include <pthread.h>
#include <stdio.h>
#define N 200000
static int counter;static void *worker(void*p){(void)p;for(int i=0;i<N;i++)counter++;return 0;}int main(void){pthread_t a,b;if(pthread_create(&a,0,worker,0)||pthread_create(&b,0,worker,0))return 1;pthread_join(a,0);pthread_join(b,0);printf("counter=%d expected=%d (output alone does not define race freedom)\n",counter,2*N);return 0;}
