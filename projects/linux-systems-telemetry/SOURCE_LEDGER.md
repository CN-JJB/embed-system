# M10 Source Ledger
Checked 2026-09-01.

| ID | Source | Organization | Tier | Version | Section/path | URL | License/provenance | Teaching question | Priority | Risk |
|---|---|---|---|---|---|---|---|---|---|---|
| M10-S1 | read(2), open(2), close(2) | Linux man-pages | T0 | man-pages 6.18 | syscall pages | https://man7.org/linux/man-pages/ | man-pages | FD ownership, EINTR, EOF | REQUIRED | low |
| M10-S2 | sigaction(2), signal-safety(7) | Linux man-pages | T0 | man-pages 6.18 | handler + async-signal-safe contract | https://man7.org/linux/man-pages/man2/sigaction.2.html | man-pages | What may the handler do? | REQUIRED | low |
| M10-S3 | pthread_sigmask(3) | Linux man-pages | T0 | man-pages 6.18 | thread signal mask inheritance/use | https://man7.org/linux/man-pages/man3/pthread_sigmask.3.html | man-pages | How to control eligible signal delivery across threads? | REQUIRED | low |
| M10-S4 | pthread create/join/mutex/cond | Linux man-pages/POSIX refs | T0 | man-pages 6.18 | relevant pthread pages | https://man7.org/linux/man-pages/man7/pthreads.7.html | man-pages | Worker lifecycle and predicates | REQUIRED | low |
| M10-S5 | GCC instrumentation options | GCC project | T0 | GCC 14.2.0 authoring | ASan/UBSan/TSan options | https://gcc.gnu.org/onlinedocs/gcc/Instrumentation-Options.html | GNU docs | Separate sanitizer evidence | REQUIRED | medium |
| M10-S6 | GNU make manual | GNU | T0 | Make 4.4.1 authoring | rules, variables, phony targets | https://www.gnu.org/software/make/manual/ | GNU docs | Reproducible multi-file build | REQUIRED | low |

The Phase 1 Linux man-pages teaching baseline remains 6.18 for consistency with canonical M08. Newer releases are not silently mixed into this project evidence.
