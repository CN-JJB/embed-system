# P1-M01 Source Ledger

> Checked: **2026-08-30**. Core claims prefer primary/official/upstream sources. Book reading is selective reference, not required reproduction.

| ID | Title | Organization / Author | Type | URL | Version / exact section/path | Why used |
|---|---|---|---|---|---|---|
| M01-S01 | ISO/IEC 9899:2011 draft N1570 | WG14 | primary standard draft | https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf | §§6.2.4, 6.2.5, 6.5.6, 6.7.3; integer clauses as needed | object lifetime/storage duration, pointer arithmetic, qualifiers, C semantic boundary |
| M01-S02 | Warning Options | GNU GCC | official docs | https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html | current docs; `-Wall`, `-Wextra`, array-argument diagnostics | compiler-warning evidence and diagnostic expectations |
| M01-S03 | Instrumentation Options | GNU GCC | official docs | https://gcc.gnu.org/onlinedocs/gcc/Instrumentation-Options.html | current docs; AddressSanitizer / UndefinedBehaviorSanitizer | sanitizer capabilities and limits |
| M01-S04 | `/proc/pid/maps` | Linux man-pages project | official/upstream docs | https://man7.org/linux/man-pages/man5/proc_pid_maps.5.html | man-pages 6.18, `proc_pid_maps(5)` | mapping format, permissions, named regions |
| M01-S05 | musl `memmove.c` | musl libc / Rich Felker et al. | upstream source | https://git.musl-libc.org/cgit/musl/tree/src/string/memmove.c?h=v1.2.6&id=9fa28ece75d8a2191de7c5bb53bed224c5947417 | **v1.2.6**, commit `9fa28ece75d8a2191de7c5bb53bed224c5947417`, `src/string/memmove.c`; 42 physical LOC | overlap, copy direction, pointer arithmetic, alignment optimization reading |
| M01-S06 | musl COPYRIGHT | musl libc | upstream license | https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT?h=v1.2.6&id=9fa28ece75d8a2191de7c5bb53bed224c5947417 | v1.2.6 | license provenance (MIT-style terms in COPYRIGHT) |
| M01-S07 | Computer Systems: A Programmer's Perspective, 3e | Bryant / O'Hallaron | classic book | https://csapp.cs.cmu.edu/3e/ | §3.7; selected Ch. 9 figures only | secondary mental-model cross-check; not source of C/Linux normative behavior |
| M01-S08 | Phase 1 Foundations Curriculum Design | this repository | Leader-approved design input | ../../../research/phase-1/2026-08-31-foundations-curriculum-design.md | P1-M01 | preserves approved scope, depth, source-reading target |

## Upstream source-reading record

### musl `memmove.c`

- Release: **musl 1.2.6**, released 2026-03-20.
- Pinned commit: `9fa28ece75d8a2191de7c5bb53bed224c5947417`.
- Exact path: `src/string/memmove.c`.
- Actual physical line count at pin: **42**.
- Exact-file cross-check: unofficial GitHub mirror `ifduyue/musl`, tag `v1.2.6`, blob `5dc9cdb924218cb10f284d013984797e03fd4e19`; mirror is not treated as canonical upstream.
- License: musl project COPYRIGHT / MIT-style permissive license.
- Teaching use: guided source navigation only; tutorial does not reproduce the file.

## Copyright note

N1570/man pages/GCC docs are linked and paraphrased. CS:APP is cited by section only. musl source is referenced by exact path/version; no large source block is copied into the tutorial.
