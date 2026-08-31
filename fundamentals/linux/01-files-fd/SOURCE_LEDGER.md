# P1-M02 Source Ledger

> Checked: **2026-08-30**. Linux API facts are grounded in current Linux man-pages; source reading pins a release/commit instead of following moving master.

| ID | Title | Organization / Author | Type | URL | Version / exact section/path | Why used |
|---|---|---|---|---|---|---|
| M02-S01 | `open(2)` | Linux man-pages / Michael Kerrisk et al. | official/upstream docs | https://man7.org/linux/man-pages/man2/open.2.html | man-pages **6.18**; DESCRIPTION / RETURN VALUE / ERRORS | pathname → FD, open file description terminology, failure contract |
| M02-S02 | `read(2)` | Linux man-pages | official/upstream docs | https://man7.org/linux/man-pages/man2/read.2.html | man-pages 6.18; RETURN VALUE / ERRORS | short read, EOF=`0`, EINTR-at-current-depth |
| M02-S03 | `write(2)` | Linux man-pages | official/upstream docs | https://man7.org/linux/man-pages/man2/write.2.html | man-pages 6.18; RETURN VALUE / ERRORS / NOTES | successful short write, retry remaining bytes |
| M02-S04 | `close(2)` | Linux man-pages | official/upstream docs | https://man7.org/linux/man-pages/man2/close.2.html | man-pages 6.18; DESCRIPTION / NOTES | FD release and close-error boundary |
| M02-S05 | `errno(3)` | Linux man-pages | official/upstream docs | https://man7.org/linux/man-pages/man3/errno.3.html | man-pages 6.18 | inspect errno only after indicated failure; thread-local implementation note |
| M02-S06 | `/proc/pid/fd` | Linux man-pages | official/upstream docs | https://man7.org/linux/man-pages/man5/proc_pid_fd.5.html | man-pages 6.18 | observable per-process FD entries, 0/1/2 |
| M02-S07 | `path_resolution(7)` | Linux man-pages | official/upstream docs | https://man7.org/linux/man-pages/man7/path_resolution.7.html | man-pages 6.18; permission checks | user/group/other selection, directory search permission |
| M02-S08 | `strace(1)` | strace project | upstream manual | https://man7.org/linux/man-pages/man1/strace.1.html | current; filtering `%file`, `%desc` | evidence tied to file/FD failures |
| M02-S09 | BusyBox `cat` | BusyBox project | upstream release + source | https://busybox.net/downloads/busybox-1.38.0.tar.bz2 | **1.38.0 release**, 2026-05-13; paths below | production embedded userspace source reading |
| M02-S10 | BusyBox maintainer mirror snapshot | Denys Vlasenko / BusyBox | source mirror for exact commit pin | https://github.com/vda-linux/busybox_mirror/commit/fc71374dfccd46448c62947269a35f1420d7ee28 | commit `fc71374dfccd46448c62947269a35f1420d7ee28` | exact source byte/path cross-check because release tag was absent at publication time |
| M02-S11 | The Linux Programming Interface | Michael Kerrisk | classic book | https://man7.org/tlpi/ | Ch. 4; Ch. 5 §5.4 selected | stable secondary mental model; selective reference only |
| M02-S12 | Phase 1 Foundations Curriculum Design | this repository | Leader-approved design input | ../../../research/phase-1/2026-08-31-foundations-curriculum-design.md | P1-M02 | preserves approved scope/depth/source target |

## BusyBox source-reading record

- Release baseline: **BusyBox 1.38.0**, released 2026-05-13.
- Release artifact: `busybox-1.38.0.tar.bz2` from `busybox.net/downloads/`.
- Upstream-tag caveat: contemporaneous BusyBox mailing-list discussion states the `1_38_0` git tag was not present at release time. This tutorial therefore **does not invent a tag**.
- Exact source cross-check pin: maintainer mirror commit `fc71374dfccd46448c62947269a35f1420d7ee28`.
- License: **GPL-2.0-only** for this release (`LICENSE`).
- `coreutils/cat.c`: 217 physical lines; blob cross-check `558869b2a721998d410183b0ef4714d6f3848060`.
- `libbb/bb_cat.c`: 33 physical lines; actual `bb_cat()` implementation; blob `0a4a350fb3f22a6397b09f33a325b32dd1f88c90`.
- `libbb/copyfd.c`: 162 physical lines; `bb_copyfd_eof()` → copy helper; blob `7f9d92ea95db796efd30ea1acca6797d63f3b1b4`.
- Teaching use: normal `cat_main → bb_cat → bb_copyfd_eof` data/error path only. Kconfig/applet generation, feature-macro matrix, sendfile optimization and build internals are explicitly out of scope.

## Copyright / license note

The tutorial paraphrases man pages and TLPI concepts rather than reproducing text. BusyBox code is not copied into the tutorial; learners are directed to exact upstream paths/version. Source snippets, if Leader later approves any, must remain minimal and GPL attribution-preserving.
