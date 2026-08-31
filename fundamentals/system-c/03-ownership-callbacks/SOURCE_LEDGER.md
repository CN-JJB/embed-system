# P1-M05 Source Ledger

> Checked: **2026-08-30**. C semantics pin **WG14 N1570**. BusyBox source reading keeps the same **1.38.0 release family** already used by M02 and re-checks exact bytes against maintainer mirror commit `fc71374dfccd46448c62947269a35f1420d7ee28`.

| ID | Source | Organization | Tier | Version / tag / commit | Exact path / section | URL | Checked date | License / provenance | Teaching question | REQUIRED / SHOULD | Version risk |
|---|---|---|---|---|---|---|---|---|---|---|---|
| M05-S01 | ISO/IEC 9899:2011 draft N1570 | WG14 | T0 standard draft | N1570 | §6.2.4 | https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf | 2026-08-30 | WG14 public draft; linked/paraphrased | When is an object alive and legally accessible? | REQUIRED | Low for pinned language baseline |
| M05-S02 | N1570 pointer conversions | WG14 | T0 | N1570 | §6.3.2.3 | same PDF | 2026-08-30 | same | What conversion rule exists for object pointers and `void *`; why are function pointers separate? | REQUIRED | Low |
| M05-S03 | N1570 function calls | WG14 | T0 | N1570 | §6.5.2.2 | same PDF | 2026-08-30 | same | What does a function call require; callback invocation is ordinary C function-call semantics through a pointer? | REQUIRED | Low |
| M05-S04 | N1570 function declarators | WG14 | T0 | N1570 | §6.7.6.3 | same PDF | 2026-08-30 | same | How are callback signatures / pointer-to-function types declared? | SHOULD | Low |
| M05-S05 | GCC Warning Options | GNU Project | T2 official docs | current checked docs | `-Wall`, `-Wextra`, `-Wpedantic`, relevant lifetime diagnostics | https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html | 2026-08-30 | GNU docs | Which compile-time evidence can support but not replace contract reasoning? | SHOULD | Moving docs |
| M05-S06 | GCC Instrumentation Options | GNU Project | T2 official docs | current checked docs | AddressSanitizer / UndefinedBehaviorSanitizer | https://gcc.gnu.org/onlinedocs/gcc/Instrumentation-Options.html | 2026-08-30 | GNU docs | What classes of runtime fault can sanitizers expose, and what can silence not prove? | REQUIRED | Medium; tool behavior evolves |
| M05-S07 | BusyBox release artifact | BusyBox project | T1 upstream release | **1.38.0**, 2026-05-13 | release tarball | https://busybox.net/downloads/busybox-1.38.0.tar.bz2 | 2026-08-30 | project distribution GPLv2-only; file notices recorded separately | Established embedded source family for callback + user-data reading | REQUIRED metadata | Low at release pin |
| M05-S08 | BusyBox `libbb.h` | BusyBox project / maintainer mirror exact-byte cross-check | T1 upstream-family source | commit `fc71374dfccd46448c62947269a35f1420d7ee28` | `include/libbb.h`; `recursive_state`, `recursive_action()` declaration | https://github.com/vda-linux/busybox_mirror/blob/fc71374dfccd46448c62947269a35f1420d7ee28/include/libbb.h | 2026-08-30 | file header: GPLv2; mirror used to cross-check bytes, not replace release provenance | How are callback function pointers and `void *userData` represented separately? | REQUIRED | Medium if generalized beyond this API |
| M05-S09 | BusyBox `recursive_action.c` | BusyBox project / Erik Andersen et al. | T1 upstream-family source | same commit; blob `b1c4bfad7ccff508e1322bd79c3af9e84e3bcec9` | `libbb/recursive_action.c` | https://github.com/vda-linux/busybox_mirror/blob/fc71374dfccd46448c62947269a35f1420d7ee28/libbb/recursive_action.c | 2026-08-30 | file header says GPLv2 or later; project release LICENSE is GPLv2-only distribution note | How does public callback+userData input become local state and synchronous callback calls? | REQUIRED | Medium; implementation-specific |
| M05-S10 | BusyBox LICENSE | BusyBox project | T1 license/provenance | same release/snapshot | `LICENSE` | https://github.com/vda-linux/busybox_mirror/blob/fc71374dfccd46448c62947269a35f1420d7ee28/LICENSE | 2026-08-30 | release says BusyBox distributed under GPL version 2 only; individual file notices may differ | Preserve exact provenance rather than flattening file notices | REQUIRED metadata | Low |
| M05-S11 | The Linux Programming Interface | Michael Kerrisk | T3 classic systems teaching | 2010 edition | selected API/error handling discussion only | https://man7.org/tlpi/ | 2026-08-30 | copyrighted book; selective reference | Secondary API-contract / C systems style cross-check | SHOULD | Low concept risk |
| M05-S12 | Phase 1 Foundations Curriculum Design | this repository | repository canonical design | canonical `main` file | P1-M05 | ../../../research/phase-1/2026-08-31-foundations-curriculum-design.md | 2026-08-30 | repository-controlled | Scope/depth/budget = 5.5 h MUST | REQUIRED | Repository-controlled |

## BusyBox exact-source record

The 1.38.0 source family was re-read before authoring. In the checked snapshot:

```text
recursive_state
  void *userData
  int (*fileAction)(...)
  int (*dirAction)(...)
```

and `recursive_action()` accepts callback pointers plus `void *userData`, creates a local `recursive_state`, and invokes callbacks synchronously through recursive traversal. This is a concrete production example of **behavior pointer + object context**, not an ownership type system and not proof of a universal callback contract.

The tutorial does not reproduce the implementation; it points to exact paths and asks guided questions.

## Reading budget

M05 REQUIRED target: **~55–65 min**:

- N1570 selected clauses: ~20 min guided lookup;
- project ownership notation + API contracts: ~15–20 min;
- BusyBox `recursive_action` interface/source guided reading: ~15–20 min;
- sanitizer docs lookup: ~5 min.

Combined M05+M06 REQUIRED external reading target stays roughly **2–2.3 h**.
