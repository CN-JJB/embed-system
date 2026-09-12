#ifndef SVC_GETPID_H
#define SVC_GETPID_H

/* 直接执行 svc 的裸系统调用 (raw syscall), 不经过 libc. */
long svc_getpid_raw(void);

#endif
