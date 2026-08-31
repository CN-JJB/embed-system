# P1-M04 Source Ledger

> Checked: **2026-08-30**. API teaching baseline stays on **Linux man-pages 6.18**, matching M02. Upstream **man-pages 6.19 was released 2026-08-25**; it is recorded as current upstream but does not retroactively change verified tutorial evidence.

| ID | Source | Organization / Author | Type | Exact section/path | Version/tag/commit | URL | Checked | Teaching use | Version risk |
|---|---|---|---|---|---|---|---|---|---|
| M04-S01 | `fork(2)` | Linux man-pages / Michael Kerrisk et al. | official/upstream docs | DESCRIPTION / RETURN VALUE / NOTES | **man-pages 6.18** pinned | https://man7.org/linux/man-pages/man2/fork.2.html | 2026-08-30 | parent/child semantics; COW only as implementation note | Medium; libc implementation details can vary |
| M04-S02 | `execve(2)` | Linux man-pages | official/upstream docs | DESCRIPTION / RETURN VALUE / ERRORS | **6.18** | https://man7.org/linux/man-pages/man2/execve.2.html | 2026-08-30 | process-image replacement; argv/env; success does not return | Low–Medium |
| M04-S03 | `wait(2)` / `waitpid` | Linux man-pages | official/upstream docs | DESCRIPTION; status macros; NOTES | **6.18** | https://man7.org/linux/man-pages/man2/waitpid.2.html | 2026-08-30 | reap, encoded wait status, zombie | Low–Medium |
| M04-S04 | `environ(7)` | Linux man-pages | official/upstream docs | DESCRIPTION | **6.18** | https://man7.org/linux/man-pages/man7/environ.7.html | 2026-08-30 | inherited process environment | Low |
| M04-S05 | `/proc/pid/status` | Linux man-pages | official/upstream docs | selected Name/State/Pid/PPid fields | **6.18** | https://man7.org/linux/man-pages/man5/proc_pid_status.5.html | 2026-08-30 | process-state observation | Medium; Linux-specific fields evolve |
| M04-S06 | `/proc/pid/fd` | Linux man-pages | official/upstream docs | descriptor entries | **6.18** | https://man7.org/linux/man-pages/man5/proc_pid_fd.5.html | 2026-08-30 | inherited FD evidence | Medium; Linux-specific |
| M04-S07 | `/proc/pid/cmdline` | Linux man-pages | official/upstream docs | complete command line semantics | **6.18** | https://man7.org/linux/man-pages/man5/proc_pid_cmdline.5.html | 2026-08-30 | argv evidence after exec | Medium; process can modify visible argv area |
| M04-S08 | Linux man-pages release archive | kernel.org | upstream release index | tarball index | current upstream **6.19, 2026-08-25** | https://www.kernel.org/pub/linux/docs/man-pages/ | 2026-08-30 | explicit current-vs-pinned version record | Moving |
| M04-S09 | `strace(1)` | strace project | upstream manual | `-f`, output/filter basics | current upstream **strace 7.1 (2026-06-15)**; runtime tool unavailable | https://strace.io/ | 2026-08-30 | process syscall evidence | Medium; exact syscall names depend on libc/kernel/arch |
| M04-S10 | musl `waitpid.c` | musl project | upstream source | `src/process/waitpid.c` | **musl 1.2.6**, commit `9fa28ece75d8a2191de7c5bb53bed224c5947417`; mirror blob `8023186228e097d1b0bf63e5dea055726a9e0310` | https://git.musl-libc.org/cgit/musl/tree/src/process/waitpid.c?h=v1.2.6 | 2026-08-30 | REQUIRED tiny libc/process-boundary reading | Low for pinned source |
| M04-S11 | musl `execv.c` | musl project | upstream source | `src/process/execv.c` | **1.2.6**, same commit; mirror blob `2ac0dec0139a0b1e349d2e23df936d029ab3627d` | https://git.musl-libc.org/cgit/musl/tree/src/process/execv.c?h=v1.2.6 | 2026-08-30 | REQUIRED: `execv` delegates to `execve` using environment | Low for pinned source |
| M04-S12 | musl `execve.c` | musl project | upstream source | `src/process/execve.c` | **1.2.6**, same commit; mirror blob `70286a17397da61e6dc31ff6db7f0c4dd2e77ef4` | https://git.musl-libc.org/cgit/musl/tree/src/process/execve.c?h=v1.2.6 | 2026-08-30 | SHOULD: direct syscall boundary | Medium if generalized beyond musl/arch |
| M04-S13 | musl COPYRIGHT | musl project | license/provenance | COPYRIGHT | **1.2.6** | https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT?h=v1.2.6 | 2026-08-30 | MIT-style permissive terms / attribution record | Low |
| M04-S14 | The Linux Programming Interface | Michael Kerrisk | classic book | selected process creation, monitoring children, program execution chapters | 2010 edition | https://man7.org/tlpi/ | 2026-08-30 | stable process mental model | Low concept risk; API details cross-check man-pages |
| M04-S15 | Operating Systems: Three Easy Pieces | Remzi H. Arpaci-Dusseau / Andrea C. Arpaci-Dusseau | classic/open teaching text | Processes + Process API | current online text; concept supplement | https://pages.cs.wisc.edu/~remzi/OSTEP/ | 2026-08-30 | SHOULD mental-model supplement | Low; not Linux API authority |
| M04-S16 | Phase 1 Foundations Curriculum Design | this repository | Leader-approved design input | P1-M04 | design SHA `43d73631522ccfa7adeb7c7b0a7b91e3fe9a5af0` | ../../../research/phase-1/2026-08-31-foundations-curriculum-design.md | 2026-08-30 | approved scope/depth/budget | Repository-controlled |

## musl source-reading record

Official upstream is `git.musl-libc.org`. GitHub mirror `ifduyue/musl` was used only to cross-check exact v1.2.6 bytes/blob identities during authoring; tutorial links point to official upstream.

Focused implementations are deliberately tiny:

- `waitpid.c`: one wrapper body delegating toward wait4 syscall path;
- `execv.c`: one wrapper body calling `execve(path, argv, __environ)`;
- `execve.c`: one direct syscall wrapper (SHOULD only).

They clarify libc/source boundary without asking the learner to read glibc `fork` internals. No upstream implementation is copied into tutorial prose.

## Reading budget

M04 REQUIRED target: **65–75 min**:

- selected man-pages: ~20 min guided lookup;
- TLPI selected process/fork/wait/exec reading: ~45–50 min;
- musl two tiny files: ~5 min.

OSTEP Process / Process API is SHOULD ~15–20 min. Combined with M03 required reading, planned REQUIRED total stays around **2 h 15–2 h 30 min**.
