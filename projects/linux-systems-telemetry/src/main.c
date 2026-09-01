#define _POSIX_C_SOURCE 200809L
#include "parser.h"
#include "queue.h"
#include "stats.h"
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static volatile sig_atomic_t stop_requested=0;
static void on_stop(int signo){int saved=errno;(void)signo;stop_requested=1;errno=saved;}
struct worker_ctx { struct record_queue *queue; struct telemetry_stats stats; int failed; };
static void *worker_main(void *arg){struct worker_ctx *w=arg;struct telemetry_record r;telemetry_stats_init(&w->stats);for(;;){int rc=record_queue_pop(w->queue,&r);if(rc==QUEUE_CLOSED)break;if(rc!=QUEUE_OK||telemetry_stats_add(&w->stats,&r)!=0){w->failed=1;break;}}return 0;}
static int sink_record(const struct telemetry_record *r,void *ctx){return record_queue_push((struct record_queue*)ctx,r)==QUEUE_OK?0:-1;}
static int install_signal_contract(sigset_t *set){struct sigaction sa;if(sigemptyset(set)||sigaddset(set,SIGINT)||sigaddset(set,SIGTERM))return -1;if(pthread_sigmask(SIG_BLOCK,set,0)!=0)return -1;memset(&sa,0,sizeof(sa));sa.sa_handler=on_stop;sigemptyset(&sa.sa_mask);sa.sa_flags=0;if(sigaction(SIGINT,&sa,0)||sigaction(SIGTERM,&sa,0))return -1;return 0;}
int main(int argc,char **argv){const char *path="-";int fd=STDIN_FILENO,owned=0,prc=0,exit_code=1,q_ready=0,worker_started=0;struct record_queue q;struct worker_ctx w;pthread_t worker;sigset_t stopset;
    if(argc==3 && strcmp(argv[1],"--input")==0)path=argv[2];else if(argc!=1){fprintf(stderr,"usage: %s [--input PATH|-]\n",argv[0]);return 2;}
    if(strcmp(path,"-")!=0){fd=open(path,O_RDONLY|O_CLOEXEC);if(fd<0){perror("open input");return 2;}owned=1;}
    if(install_signal_contract(&stopset)!=0){fprintf(stderr,"signal setup failed\n");goto cleanup;}
    if(record_queue_init(&q)!=QUEUE_OK){fprintf(stderr,"queue init failed\n");goto cleanup;}q_ready=1;w.queue=&q;w.failed=0;
    if(pthread_create(&worker,0,worker_main,&w)!=0){fprintf(stderr,"pthread_create failed\n");goto cleanup;}worker_started=1;
    if(pthread_sigmask(SIG_UNBLOCK,&stopset,0)!=0){fprintf(stderr,"signal unblock failed\n");goto shutdown;}
    fprintf(stderr,"ready\n");
    fflush(stderr);
    prc=parse_text_fd(fd,sink_record,&q,&stop_requested);
    if(prc!=PARSER_OK && prc!=PARSER_STOPPED){fprintf(stderr,"input parse failed: %d\n",prc);goto shutdown;}
    exit_code=0;
shutdown:
    if(q_ready && record_queue_close(&q)!=QUEUE_OK){fprintf(stderr,"queue close failed\n");exit_code=1;}
    if(worker_started){if(pthread_join(worker,0)!=0){fprintf(stderr,"pthread_join failed\n");exit_code=1;}worker_started=0;}
    if(w.failed){fprintf(stderr,"worker failed\n");exit_code=1;}
    if(exit_code==0){if(w.stats.count==0)printf("count=0 sum=0 min=n/a max=n/a mean=0.000\n");else printf("count=%llu sum=%lld min=%d max=%d mean=%.3f\n",(unsigned long long)w.stats.count,(long long)w.stats.sum,w.stats.min,w.stats.max,telemetry_stats_mean(&w.stats));}
cleanup:
    if(worker_started){record_queue_close(&q);pthread_join(worker,0);}
    if(q_ready && record_queue_destroy(&q)!=QUEUE_OK)exit_code=1;
    if(owned && close(fd)!=0)exit_code=1;
    return exit_code;
}
