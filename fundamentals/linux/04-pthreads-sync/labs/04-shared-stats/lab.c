#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
struct stats{uint64_t count;int64_t sum;pthread_mutex_t m;};static struct stats s={0,0,PTHREAD_MUTEX_INITIALIZER};static void *worker(void*p){int v=*(int*)p;for(int i=0;i<1000;i++){pthread_mutex_lock(&s.m);s.count++;s.sum+=v;pthread_mutex_unlock(&s.m);}return 0;}int main(void){int a=2,b=3;pthread_t x,y;pthread_create(&x,0,worker,&a);pthread_create(&y,0,worker,&b);pthread_join(x,0);pthread_join(y,0);pthread_mutex_lock(&s.m);printf("count=%llu sum=%lld\n",(unsigned long long)s.count,(long long)s.sum);int ok=s.count==2000&&s.sum==5000;pthread_mutex_unlock(&s.m);pthread_mutex_destroy(&s.m);return ok?0:1;}
