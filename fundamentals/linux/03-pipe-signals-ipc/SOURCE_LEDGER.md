
# P1-M06 Source Ledger

> Checked: **2026-08-30**. Tutorial API baseline remains **Linux man-pages 6.18**, matching P1-M02/P1-M04. Kernel.org shows current upstream **man-pages 6.19 (2026-08-25)**; this is recorded separately and does not relabel 6.18 tutorial/runtime evidence. musl source remains pinned to **1.2.6** commit `9fa28ece75d8a2191de7c5bb53bed224c5947417`.

| ID | Source | Organization | Tier | Version / tag / commit | Exact path / section | URL | Checked date | License / copyright note | Teaching question | REQUIRED / SHOULD | Version risk |
|---|---|---|---|---|---|---|---|---|---|---|---|
| M06-S01 | `pipe(2)` | Linux man-pages project | T2 official/upstream docs | **6.18** tutorial baseline | DESCRIPTION / RETURN VALUE / EXAMPLES as needed | https://man7.org/linux/man-pages/man2/pipe.2.html | 2026-08-30 | Linux man-pages licensing per upstream page/source | What descriptors are created and what are failure semantics? | REQUIRED | Low–Medium |
| M06-S02 | `pipe(7)` | Linux man-pages project | T2 official/upstream docs | **6.18** | I/O on pipes/FIFOs; pipe capacity only as non-golden concept; EOF/SIGPIPE paragraphs | https://man7.org/linux/man-pages/man7/pipe.7.html | 2026-08-30 | upstream docs | Why does EOF depend on closing all write-end references? Why not assume message boundaries/capacity? | REQUIRED | Medium; Linux-specific details evolve |
| M06-S03 | `dup(2)` / `dup2()` | Linux man-pages project | T2 official/upstream docs | **6.18** | DESCRIPTION / dup2 replacement / oldfd==newfd / ERRORS | https://man7.org/linux/man-pages/man2/dup.2.html | 2026-08-30 | upstream docs | How does descriptor-number rebinding differ from copying a resource? | REQUIRED | Low–Medium |
| M06-S04 | `read(2)` | Linux man-pages project | T2 official/upstream docs | **6.18** | RETURN VALUE / `0` / `EINTR` | https://man7.org/linux/man-pages/man2/read.2.html | 2026-08-30 | upstream docs | What evidence means EOF vs interruption? | REQUIRED | Low |
| M06-S05 | `write(2)` | Linux man-pages project | T2 official/upstream docs | **6.18** | RETURN VALUE / ERRORS; `EPIPE` as context only | https://man7.org/linux/man-pages/man2/write.2.html | 2026-08-30 | upstream docs | What happens at writer boundary and why must caller inspect return values? | SHOULD | Low–Medium |
| M06-S06 | `sigaction(2)` | Linux man-pages project | T2 official/upstream docs | **6.18** | DESCRIPTION; `sa_handler`, flags, mask; `SA_RESTART` awareness | https://man7.org/linux/man-pages/man2/sigaction.2.html | 2026-08-30 | upstream docs | How is handler disposition installed and what does `SA_RESTART` actually scope? | REQUIRED | Medium |
| M06-S07 | `signal-safety(7)` | Linux man-pages project / POSIX mapping | T2 official/upstream docs | **6.18** | async-signal-safety overview/list | https://man7.org/linux/man-pages/man7/signal-safety.7.html | 2026-08-30 | upstream docs | Why must handler remain minimal; why is “worked once” not evidence of legal design? | REQUIRED | Medium; standards/API lists may evolve |
| M06-S08 | `signal(7)` | Linux man-pages project | T2 official/upstream docs | **6.18** | signal disposition/delivery basics only | https://man7.org/linux/man-pages/man7/signal.7.html | 2026-08-30 | upstream docs | Minimal SIGINT/SIGTERM mental model | SHOULD | Medium |
| M06-S09 | `wait(2)` | Linux man-pages project | T2 official/upstream docs | **6.18** | `waitpid`, status macros | https://man7.org/linux/man-pages/man2/waitpid.2.html | 2026-08-30 | upstream docs | Reap both pipeline children and decode termination | REQUIRED | Low |
| M06-S10 | `/proc/pid/fd` | Linux man-pages project | T2 official/upstream docs | **6.18** | descriptor entries/symlinks | https://man7.org/linux/man-pages/man5/proc_pid_fd.5.html | 2026-08-30 | upstream docs | Which process still has which endpoint open? | REQUIRED | Medium; Linux-specific |
| M06-S11 | Linux man-pages release archive | kernel.org | T2 upstream release index | current **6.19**, 2026-08-25 | release tarball index | https://www.kernel.org/pub/linux/docs/man-pages/ | 2026-08-30 | upstream archive | Separate current upstream from tutorial 6.18 baseline | SHOULD metadata | Moving |
| M06-S12 | musl `pipe.c` | musl libc | T1 upstream source | **1.2.6**, commit `9fa28ece75d8a2191de7c5bb53bed224c5947417` | `src/unistd/pipe.c`, mirror blob `d07b8d24ae3b1f55126700e64994ab55d453fb16` | https://git.musl-libc.org/cgit/musl/tree/src/unistd/pipe.c?h=v1.2.6 | 2026-08-30 | musl COPYRIGHT: standard MIT license for project as a whole | One concrete libc wrapper chooses pipe/pipe2 syscall boundary | REQUIRED | Low at pin; architecture/syscall availability varies |
| M06-S13 | musl `dup2.c` | musl libc | T1 upstream source | **1.2.6**, same commit | `src/unistd/dup2.c`, mirror blob `8f43c6ddfe8983e9565d6a14a10f423c9fd55f05` | https://git.musl-libc.org/cgit/musl/tree/src/unistd/dup2.c?h=v1.2.6 | 2026-08-30 | musl MIT terms | See real handling around old==new / lower syscall choices without generalizing to all libc | REQUIRED | Medium if overgeneralized beyond musl/arch |
| M06-S14 | musl `sigaction.c` | musl libc | T1 upstream source | **1.2.6**, same commit | `src/signal/sigaction.c`, mirror blob `e45308fae5fbf5cc30198c648ecc3b872583c5ed` | https://git.musl-libc.org/cgit/musl/tree/src/signal/sigaction.c?h=v1.2.6 | 2026-08-30 | musl MIT terms; internal implementation has project-private concerns | Why can libc wrapper be richer than public `sigaction()` contract? | SHOULD | High if learner mistakes internal state for POSIX API semantics |
| M06-S15 | musl COPYRIGHT | musl libc | T1 license/provenance | **1.2.6** | `COPYRIGHT`, mirror blob `2f15edc7a17936b15d563363a1e9b70aa3bcbc2b` | https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT?h=v1.2.6 | 2026-08-30 | project MIT license + documented third-party exceptions | Provenance for guided source paths | REQUIRED metadata | Low |
| M06-S16 | strace 7.2 release | strace project | T2 official tool docs/release | **7.2**, 2026-08-18 current checked release | `-f`, FD/process tracing; exact syscall spelling non-golden | https://strace.io/files/7.2/ | 2026-08-30 | LGPL-2.1-or-later project; docs/tool output used as evidence | How to observe fork/dup/close/exec/read/write/wait/signal boundary? | SHOULD tool | Moving; authoring runtime lacks tool |
| M06-S17 | The Linux Programming Interface | Michael Kerrisk | T3 classic systems teaching | 2010 edition | selected pipe/FIFO, FD duplication, signals, child/process IPC sections | https://man7.org/tlpi/ | 2026-08-30 | copyrighted book; selective reading only | Stable mental model cross-check | REQUIRED selected | Low concept risk; APIs cross-check man-pages |
| M06-S18 | Phase 1 Foundations Curriculum Design | this repository | repository canonical design | canonical file on `main` | P1-M06 | ../../../research/phase-1/2026-08-31-foundations-curriculum-design.md | 2026-08-30 | repository-controlled | Scope/depth/budget: 6 h MUST | REQUIRED | Repository-controlled |

## musl exact-source cross-check

The pinned commit was re-read through the established GitHub mirror only to cross-check exact bytes/blob identities; tutorial links point to official musl upstream.

- `pipe.c`: tiny wrapper with `SYS_pipe` vs `SYS_pipe2(...,0)` conditional.
- `dup2.c`: concrete implementation with direct `SYS_dup2` path when available and a fallback that explicitly treats `old == new`; it also handles an internal `EBUSY` retry case.
- `sigaction.c`: maps userspace action structure to kernel ABI structure and contains musl-internal bookkeeping. That complexity is **implementation evidence**, not a new M06 pthread curriculum.

## Current-upstream distinction

- Tutorial/runtime man-page baseline: **6.18**.
- Current man-pages archive checked 2026-08-30: **6.19**, dated 2026-08-25.
- Current strace release checked 2026-08-30: **7.2**, dated 2026-08-18.
- Authoring runtime: `strace` not installed, so no trace output is marked VERIFIED.

## Reading budget

M06 REQUIRED target: **~65–75 min**:

- man-pages guided sections: ~30–35 min;
- TLPI selected pipe/dup/signal pages: ~25–30 min;
- musl `pipe.c` + `dup2.c`: ~5 min; `sigaction.c` guided glance SHOULD ~5–10 min.

M05 + M06 REQUIRED external reading target remains roughly **2–2.3 h**, within the batch budget.
