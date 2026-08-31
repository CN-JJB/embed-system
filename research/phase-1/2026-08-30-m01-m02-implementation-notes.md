# P1-M01 + P1-M02 Implementation & Verification Notes

> Role: Tutorial Author + Lab Designer + Technical Researcher  
> Checked / executed: **2026-08-30** (America/Los_Angeles)  
> Design baseline: `curriculum/phase-1-foundations` @ `43d73631522ccfa7adeb7c7b0a7b91e3fe9a5af0`  
> Implementation branch target: `tutorial/p1-m01-m02`  
> Editorial authority: none; Leader review remains required.

## Scope preserved

Implemented only:

- P1-M01 — Objects, Storage, Extent, and Linux Process Memory;
- P1-M02 — Files, Permissions, Descriptors, and Error Boundaries.

No formal M03/ELF chapter, `fork/exec`, pipe, signal, pthread, RTOS, Kernel, Driver, VFS internals, page-table internals, allocator internals, or mmap internals were added. Forward references remain one-line orientation only.

## Deliverables

```text
fundamentals/system-c/01-objects-lifetime/
  README.md
  SOURCE_LEDGER.md
  diagrams/
  labs/01-array-pointer/
  labs/02-storage-lifetime/
  labs/03-asan-ubsan/
  labs/04-proc-maps/
  challenge/
  faults/
  gate/
  reviewer/

fundamentals/linux/01-files-fd/
  README.md
  SOURCE_LEDGER.md
  diagrams/
  labs/01-fdcopy/
  labs/02-proc-fd/
  labs/03-strace/
  labs/04-permissions/
  challenge/
  faults/
  gate/
  reviewer/
```

## Authoring / verification environment

Actual environment used for executable verification:

```text
Linux 6.18.35 x86_64
GCC 14.2.0 (Debian 14.2.0-19)
GNU Make 4.4.1
GNU binutils ld 2.44
AddressSanitizer: available / executed
UndefinedBehaviorSanitizer: available / executed
GDB: NOT INSTALLED
strace: NOT INSTALLED
```

Because GDB and strace are absent, no GDB/strace transcript is claimed. Tutorial command paths are retained for the target learner environment and marked **UNVERIFIED** until executed there.

## Code verification record — M01

| Object | Build / run command | Expected result | Actual result | Status |
|---|---|---|---|---|
| Lab 01 array vs pointer | `make clean && make && ./array_pointer` | GCC warns about `sizeof` array parameter; caller array size differs from pointer/parameter size | warning `-Wsizeof-array-argument` observed; x86_64 run printed 40-byte `int[10]` and 8-byte pointer/parameter; addresses showed array value vs pointer-parameter object | **VERIFIED** |
| Lab 02 storage/lifetime | `make clean && make && ./storage_lifetime` | print automatic/static/global/allocated addresses and find containing `/proc/self/maps` regions | automatic address found in `[stack]` on this O0 run; allocated address in `[heap]`; static/global in writable image mapping; lifecycle events printed | **VERIFIED** for O0 run |
| Lab 03 ASan/UBSan | `make clean && make`; run normal/ASan/UBSan cases | ASan catches OOB/UAF; UBSan catches signed overflow and invalid signed shift; normal run may appear to continue | heap-buffer-overflow, heap-use-after-free, signed-overflow and signed-left-shift diagnostics all observed | **VERIFIED** |
| Lab 04 `/proc/self/maps` | `make clean && make && ./proc_maps` | locate one function, static/global, stack local, heap allocation; then dump maps | all four categories located; real maps also showed libc, loader, vdso/vvar and anonymous regions | **VERIFIED** |
| `span_u8` challenge reference | compile `reviewer/span_u8_solution.c` with `challenge/test_span.c` | all contract tests pass | `span_u8 tests passed` | **VERIFIED** (reference only; learner starter intentionally incomplete) |
| M01 fault F1 | `./faults-asan dangling` | ASan UAF evidence | heap-use-after-free observed | **VERIFIED** |
| M01 fault F2 | `./faults-asan wrong-extent` | logical extent wrong but all accesses remain within 16-byte object; ASan should not directly identify semantic error | process exited without ASan diagnostic; printed `logical_len=4 advertised_len=16`, checksum mismatch | **VERIFIED** |
| M01 fault F3 | `./faults-ubsan signed` | signed overflow diagnosed | runtime signed-overflow diagnostic observed | **VERIFIED** |
| M01 Gate seeded | `./frame-gate-sanitize extent|lifetime|ub|legal` | three fault cases produce evidence; legal one-past case remains legal | ASan stack-buffer-overflow; ASan stack-use-after-return; UBSan signed-overflow; legal case exited 0 | **VERIFIED** |
| M01 Gate fixed reviewer | compile with `-fsanitize=address,undefined`; run all cases | invalid extent rejected; lifetime fixed; UB avoided; legal case passes | all intended regressions behaved as designed; invalid frame returns failure rather than OOB | **VERIFIED** |
| M01 GDB workflow | `gdb ...` | breakpoint/backtrace/locals/memory/watchpoint evidence | tool unavailable | **UNVERIFIED** |

Note: GCC compile-time `-Wuse-after-free` also fired on deliberate UAF examples. This is useful evidence but is not presented as a replacement for runtime/lifetime reasoning.

## Code verification record — M02

| Object | Build / run command | Expected result | Actual result | Status |
|---|---|---|---|---|
| Lab 01 `fdcopy` | `make clean && make`; file→file, stdin→file, file→stdout, missing input | byte-identical copies; borrowed stdio not closed; failure reports source error | all copy directions passed `cmp`; missing input returned failure with `No such file or directory` | **VERIFIED** |
| Lab 02 `/proc/<pid>/fd` | run `fd_hold` and inspect `/proc/<pid>/fd` at two pauses | opened descriptors appear, then disappear after close | open phase FDs `[0,1,2,3,4]`; close phase `[0,1,2]` in verification run | **VERIFIED** |
| Lab 03 strace | `strace -e trace=%file,%desc ...` | bind trace to open/read/write/close failure; source `open()` may appear as `openat()` | strace tool unavailable; no transcript fabricated | **UNVERIFIED** |
| Lab 04 permissions — file read | run as unprivileged `nobody` against mode `000` file | `open` fails `EACCES` | `errno=13 (Permission denied)` observed; mode restore then success | **VERIFIED** |
| Lab 04 permissions — directory search | remove parent directory search permission, run as `nobody` | pathname resolution fails `EACCES` | `errno=13` observed | **VERIFIED** |
| `--limit` challenge reference | compile reviewer solution; limit 5/999/0, stdin/stdout, huge parse | bounded output, EOF before N normal, invalid overflow parse rejected | all boundary/cmp cases passed; huge value rejected | **VERIFIED** (reference only) |
| M02 fault F1 leak | pause `fd-faults leak`; inspect `/proc/<pid>/fd` | 3 leaked descriptors observable | `[0,1,2,3,4,5]` observed | **VERIFIED** |
| M02 fault F2 ownership | `fd-faults ownership input.bin` | helper closes borrowed FD; caller gets bad descriptor | caller `read` reported `errno=9 (Bad file descriptor)` | **VERIFIED** |
| M02 fault F3 short write | deterministic capped writer | program may exit but output truncates | 17-byte input became 4-byte output; `cmp` failed | **VERIFIED** |
| M02 fault F4 error propagation | unprivileged permission failure followed by bad cleanup | original `EACCES` gets overwritten by cleanup `EBADF` | reported `errno=9`, despite permission setup being `EACCES` | **VERIFIED** |
| M02 Gate short write | `LOG_COPY_WRITE_CAP=5 ./log_copy ...` | seeded program drops unwritten remainder | 37-byte input became 10-byte output | **VERIFIED** |
| M02 Gate error ownership | `./log_copy input.bin /dev/full` | write failure plus double-close symptom | `close output: Bad file descriptor`; original copy error `No space left on device` also observed | **VERIFIED** |
| M02 Gate leak | `--leak-demo` + `/proc/<pid>/fd` | repeated output-open failure accumulates input descriptors | `[0,1,2,3,4,5]` observed | **VERIFIED** |
| M02 Gate fixed reviewer | caps `1,5,32`; `/dev/full`; leak-demo | all caps `cmp`; no EBADF double-close; no leaked >=3 FDs | all caps passed; `/dev/full` retained ENOSPC without EBADF; leak phase only `[0,1,2]` | **VERIFIED** |
| M02 Gate strace evidence | `%file,%desc` trace on `/dev/full` and bad output path | runtime syscall sequence evidence | tool unavailable | **UNVERIFIED** |

### Verification harness note

Pause-based `/proc` programs initially relied on terminal line buffering. Automated pipe-driven verification exposed that the prompt could remain buffered, so explicit `fflush(stdout)` was added immediately before `getchar()`. The lab semantics did not change; reproducibility improved for both interactive and automated runs.

## Source-reading pins

### musl `memmove.c`

- release: **musl 1.2.6**, 2026-03-20;
- commit: `9fa28ece75d8a2191de7c5bb53bed224c5947417`;
- path: `src/string/memmove.c`;
- actual physical line count: **42**;
- license: musl COPYRIGHT / MIT-style permissive terms;
- canonical upstream: `git.musl-libc.org`;
- exact bytes/line count cross-checked against mirror tag `v1.2.6`, blob `5dc9cdb924218cb10f284d013984797e03fd4e19`.

### BusyBox `cat`

- release: **BusyBox 1.38.0**, 2026-05-13;
- release artifact pin: `busybox-1.38.0.tar.bz2`;
- contemporaneous upstream note: `1_38_0` tag was absent at release time, so no nonexistent tag is claimed;
- exact source cross-check: maintainer mirror commit `fc71374dfccd46448c62947269a35f1420d7ee28`;
- license: GPL-2.0-only for this release;
- `coreutils/cat.c`: **217** physical lines, blob `558869b2a721998d410183b0ef4714d6f3848060`;
- `libbb/bb_cat.c`: **33** physical lines, blob `0a4a350fb3f22a6397b09f33a325b32dd1f88c90`;
- `libbb/copyfd.c`: **162** physical lines, blob `7f9d92ea95db796efd30ea1acca6797d63f3b1b4`.

Tutorial copy does not reproduce either upstream implementation; it gives exact paths plus guided questions.

## Reading / learner budget

- M01 required reading target: **45–55 min**; module design budget **6.5 h MUST + ~1 h SHOULD**.
- M02 required reading target: **55–65 min**; module design budget **5.5 h MUST**.
- Combined REQUIRED reading target: **~1 h 40 min–2 h**, below the brief's 2.5–3 h ceiling.
- Combined approved module MUST budget remains **~12 h**; this implementation does not alter curriculum hours.

## Known limitations / Leader review points

1. **GDB unverified in authoring runtime.** Commands are deliberately scoped to current needs (`run`, breakpoint, `bt`, `frame`, `info locals`, `print`, `x`, basic watchpoint; registers SHOULD), but first learner/reviewer run must capture real evidence before status changes.
2. **strace unverified in authoring runtime.** Lab/Gate commands are source-grounded, but no synthetic trace is included.
3. **Permissions verification used root container + explicit unprivileged `nobody`.** Learner instructions prefer normal non-root shell; root bypass behavior is called out.
4. `/proc` addresses and FD numbers are deliberately not frozen as expected literals; ASLR/runtime context changes them.
5. musl/BusyBox source pins should be rechecked at canonical publication/upgrade review per VERSION_POLICY; BusyBox 1.38.0 tag caveat is recorded rather than hidden.
6. Gate fixed code lives only under `reviewer/`; learner-facing Gate does not reveal bug line numbers or patches.
7. No claim is made that sanitizer silence proves correctness; M01 F2 exists specifically to force semantic-contract reasoning beyond sanitizer output.

## Suggested PR title / base

- Title: `tutorial: implement P1 M01-M02 foundations`
- Head: `tutorial/p1-m01-m02`
- Base: `curriculum/phase-1-foundations` (stacked PR because Phase 1 design is not yet on `main` at implementation time).
