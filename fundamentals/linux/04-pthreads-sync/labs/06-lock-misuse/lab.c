#define _GNU_SOURCE
#include <errno.h>
#include <pthread.h>
#include <stdio.h>
int main(void){pthread_mutexattr_t a;pthread_mutex_t m;if(pthread_mutexattr_init(&a))return 1;if(pthread_mutexattr_settype(&a,PTHREAD_MUTEX_ERRORCHECK)){pthread_mutexattr_destroy(&a);return 1;}if(pthread_mutex_init(&m,&a)){pthread_mutexattr_destroy(&a);return 1;}pthread_mutexattr_destroy(&a);if(pthread_mutex_lock(&m))return 1;int rc=pthread_mutex_lock(&m);printf("second lock rc=%d expected EDEADLK=%d on this diagnostic mutex\n",rc,EDEADLK);pthread_mutex_unlock(&m);pthread_mutex_destroy(&m);return rc==EDEADLK?0:1;}
