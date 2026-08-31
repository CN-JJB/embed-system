# P1-M08 Source Ledger

> Checked **2026-08-31**. Execution baseline: GCC **14.2.0**, binutils **2.44**. GDB and strace are **NOT INSTALLED** in the authoring runtime; their manuals/source are pinned separately from runtime verification.

| ID | Source | Organization | Tier | Version/tag/commit | Exact path/section | URL | Checked date | License/provenance | Teaching question | REQUIRED/SHOULD | Version risk |
|---|---|---|---|---|---|---|---|---|---|---|---|
| M08-S01 | GCC Debugging Options | GNU Project | T2 official docs | GCC 14.2.0 | Debugging Options: `-g` / optimization interaction | https://gcc.gnu.org/onlinedocs/gcc-14.2.0/gcc/Debugging-Options.html | 2026-08-31 | GNU official manual | why debug info and why O0 is a teaching simplification, not a law? | REQUIRED | Low at pin |
| M08-S02 | GCC Instrumentation Options | GNU Project | T2 | GCC 14.2.0 | AddressSanitizer, UndefinedBehaviorSanitizer, alignment/signed-overflow options | https://gcc.gnu.org/onlinedocs/gcc-14.2.0/gcc/Instrumentation-Options.html | 2026-08-31 | GNU official manual | what instrumented runtime evidence can/cannot establish? | REQUIRED | Medium; coverage evolves |
| M08-S03 | GDB 17.2 release | GNU Project / GDB | T2 official release | **17.2**, 2026-05-10 | release archive | https://ftp.gnu.org/gnu/gdb/gdb-17.2.tar.xz | 2026-08-31 | GNU GPLv3+ project distribution | pin manual/tool family without pretending it was executed locally | REQUIRED metadata | Low at release pin |
| M08-S04 | Debugging with GDB | GNU Project | T2 official manual | GDB **17.2** manual checked with release | §5.1 Breakpoints/Watchpoints/Catchpoints; §5.1.2 watchpoints; Ch.8 stack; Ch.10 data; §10.6 memory | https://sourceware.org/gdb/current/onlinedocs/gdb.html/ | 2026-08-31 | GNU official manual; online URL may move | what question does breakpoint/watchpoint/print/x/frame answer? | REQUIRED | Online rendering may move |
| M08-S05 | strace v7.2 tag | strace project | T2 official/upstream | v7.2, 2026-08-18; tag object `8c49c884a2c64061cdd810e3c2b6e0f1dfc3e743`; commit `195ac8ddbf6fad16ff1ff125b0feb725b6c46dcf` | annotated tag / NEWS payload | https://github.com/strace/strace/releases/tag/v7.2 | 2026-08-31 | upstream project | exact release pin | REQUIRED metadata | Low |
| M08-S06 | strace manual source | strace project | T2/T1 upstream docs | v7.2 same commit | `doc/strace.1.in`: DESCRIPTION, `-f`, `-e trace=%file/%process/%desc`, NOTES | https://github.com/strace/strace/blob/v7.2/doc/strace.1.in | 2026-08-31 | file SPDX LGPL-2.1-or-later | timeline/filter semantics and wrapper/syscall-name caveat? | REQUIRED | Low at pin |
| M08-S07 | strace COPYING | strace project | T1 provenance | v7.2 | `COPYING` | https://github.com/strace/strace/blob/v7.2/COPYING | 2026-08-31 | strace LGPL-2.1-or-later; test suite/bundled exceptions documented | provenance | REQUIRED metadata | Low |
| M08-S08 | `proc_pid_fd(5)` | Linux man-pages | T2 upstream docs | Phase-1 baseline 6.18 | descriptor symlinks | https://man7.org/linux/man-pages/man5/proc_pid_fd.5.html | 2026-08-31 | Linux man-pages upstream docs | current-state FD snapshot? | REQUIRED | Linux-specific |
| M08-S09 | `open(2)` | Linux man-pages | T2 | baseline 6.18 | RETURN VALUE / ERRORS | https://man7.org/linux/man-pages/man2/open.2.html | 2026-08-31 | upstream docs | why return/errno precede strace? | REQUIRED | Low |
| M08-S10 | `read(2)` / `write(2)` | Linux man-pages | T2 | baseline 6.18 | return values / short I/O / errors | https://man7.org/linux/man-pages/man2/read.2.html ; https://man7.org/linux/man-pages/man2/write.2.html | 2026-08-31 | upstream docs | program error handling vs traced boundary? | SHOULD | Low |
| M08-S11 | GNU Binutils manuals | GNU Project | T2 | runtime binutils 2.44 | `nm`, `readelf`, `objdump` selected M03 bridge | https://sourceware.org/binutils/docs/ | 2026-08-31 | GNU official docs | build/ELF fault should stay in correct evidence domain | SHOULD | Online current docs may move |
| M08-S12 | The Linux Programming Interface | Michael Kerrisk | T3 classic | 2010 edition | selected file/process/debugging context only | https://man7.org/tlpi/ | 2026-08-31 | copyrighted book; selective reading | stable system-call/process mental model | SHOULD | Low concept risk |
| M08-S13 | Computer Systems: A Programmer's Perspective | Bryant/O'Hallaron | T3 classic | 3rd ed. | selected machine/link/debug bridges only | https://csapp.cs.cmu.edu/3e/home.html | 2026-08-31 | copyrighted book/site; selective reference | bridge M03 machine/link evidence to debugger | SHOULD | Low |
| M08-S14 | Phase 1 roadmap | repository | canonical | main @ implementation start | P1-M08 | ../../roadmap/phase-1-foundations.md | 2026-08-31 | repository-controlled | scope/depth/budget = 5 h | REQUIRED | repo-controlled |

## Runtime distinction

    gcc --version     → 14.2.0 (executed)
    ld --version      → binutils 2.44 (executed)
    gdb --version     → NOT INSTALLED
    strace --version  → NOT INSTALLED
    ASan              → available / executed
    UBSan             → available / executed

Official documentation is evidence for tool semantics. It does **not** convert an unexecuted local GDB/strace path into VERIFIED.

## Reading budget

REQUIRED ~55–65 min: GDB selected sections ~20; GCC sanitizer docs ~15; strace selected manual ~15; `/proc` + error-boundary man-page lookup ~10. Combined M07+M08 REQUIRED external reading target is roughly **1.8–2.1 h**.
