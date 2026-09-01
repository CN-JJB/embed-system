# P1-M07 Source Ledger

> Checked **2026-08-31**. C baseline remains **WG14 N1570**. x86-64 psABI is host-specific supporting evidence, never a universal C rule.

| ID | Source | Organization | Tier | Version/tag/commit | Exact path/section | URL | Checked date | License/provenance | Teaching question | REQUIRED/SHOULD | Version risk |
|---|---|---|---|---|---|---|---|---|---|---|---|
| M07-S01 | ISO/IEC 9899:2011 draft N1570 | WG14 | T0 | N1570 | §6.2.6.1 p4,p6 | https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf | 2026-08-31 | WG14 public draft; linked/paraphrased | object representation/padding? | REQUIRED | Low |
| M07-S02 | N1570 alignment | WG14 | T0 | N1570 | §6.2.8; §6.3.2.3 p7 | https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf | 2026-08-31 | same primary draft | alignment and correctly aligned pointer conversion? | REQUIRED | Low |
| M07-S03 | N1570 sizeof/_Alignof | WG14 | T0 | N1570 | §6.5.3.4 p2–p4 | https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf | 2026-08-31 | same | what does size include? | REQUIRED | Low |
| M07-S04 | N1570 character/effective-type access | WG14 | T0 | N1570 | §6.5 p7; §6.3.2.3 p7 | https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf | 2026-08-31 | same | why inspect object bytes with character type? | REQUIRED | Low |
| M07-S05 | N1570 struct members | WG14 | T0 | N1570 | §6.7.2.1 p14–p17 | https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf | 2026-08-31 | same | member order/padding vs implementation detail? | REQUIRED | Low |
| M07-S06 | N1570 offsetof | WG14 | T0 | N1570 | §7.19 | https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf | 2026-08-31 | same | member offset evidence? | REQUIRED | Low |
| M07-S07 | N1570 exact-width integers | WG14 | T0 | N1570 | §7.20.1.1 | https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf | 2026-08-31 | same | are intN_t types mandatory and what do they guarantee? | REQUIRED | Low |
| M07-S08 | System V AMD64 psABI source | x86 psABIs | T0/T2 host ABI | master UI revision `e1ce0983`, 2025-03-12 | `x86-64-ABI/low-level-sys-info.tex`, Aggregates and Unions | https://gitlab.com/x86-psABIs/x86-64-ABI | 2026-08-31 | upstream ABI source; UI exposed abbreviated revision; paraphrased | explain observed x86-64 aggregate layout without generalizing? | SHOULD | Moving master; host-specific |
| M07-S09 | Linux unaligned helpers | Linux kernel | T1 | v6.18; commit `7d0a66e4bb9081d75c82ec4957c50034cb0ea449` | `include/linux/unaligned.h` | https://github.com/torvalds/linux/blob/v6.18/include/linux/unaligned.h | 2026-08-31 | file SPDX GPL-2.0 | why make endian/unaligned intent explicit? | REQUIRED guided source reading | Kernel-specific |
| M07-S10 | Linux licensing | Linux kernel | T1 provenance | v6.18 | `COPYING` | https://github.com/torvalds/linux/blob/v6.18/COPYING | 2026-08-31 | project GPL-2.0 WITH Linux-syscall-note; files may differ | provenance | REQUIRED metadata | Low |
| M07-S11 | GCC Warning Options | GNU | T2 | GCC 14.2.0 | Warning Options | https://gcc.gnu.org/onlinedocs/gcc-14.2.0/gcc/Warning-Options.html | 2026-08-31 | GNU docs | strict build evidence? | SHOULD | Low at pin |
| M07-S12 | GCC Instrumentation Options | GNU | T2 | GCC 14.2.0 | ASan/UBSan/alignment | https://gcc.gnu.org/onlinedocs/gcc-14.2.0/gcc/Instrumentation-Options.html | 2026-08-31 | GNU docs | bounds/alignment runtime evidence? | SHOULD | Coverage evolves |
| M07-S13 | Phase 1 roadmap | repository | canonical | main @ implementation start | P1-M07 | ../../../roadmap/phase-1-foundations.md | 2026-08-31 | repository-controlled | scope/depth/budget | REQUIRED | repo-controlled |

## Reading budget

REQUIRED ~50–60 min: N1570 selected clauses ~25–30; codec/golden contract ~15; Linux helper source reading ~10. psABI comparison is SHOULD.
