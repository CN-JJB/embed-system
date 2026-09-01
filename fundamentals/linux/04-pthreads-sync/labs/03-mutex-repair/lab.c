#include <pthread.h>
#include <stdio.h>
#define N 200000
static int counter;static pthread_mutex_t m=PTHREAD_MUTEX_INITIALIZER;static void *worker(void*p){(void)p;for(int i=0;i<N;i++){pthread_mutex_lock(&m);counter++;pthread_mutex_unlock(&m);}return 0;}int main(void){pthread_t a,b;if(pthread_create(&a,0,worker,0)||pthread_create(&b,0,worker,0))return 1;pthread_join(a,0);pthread_join(b,0);printf("counter=%d\n",counter);pthread_mutex_destroy(&m);return counter==2*N?0:1;}
