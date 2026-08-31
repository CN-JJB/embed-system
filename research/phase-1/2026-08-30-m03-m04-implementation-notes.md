# P1-M03 + P1-M04 Implementation & Verification Notes

> Role: Tutorial Author + Lab Designer + Technical Researcher  
> Checked / executed: **2026-08-30** (America/Los_Angeles)  
> Design baseline: Leader-approved Phase 1 design @ `43d73631522ccfa7adeb7c7b0a7b91e3fe9a5af0`  
> Dependency implementation baseline: `tutorial/p1-m01-m02` @ `3ad64eec899106fd9c086e4a0df6a325c62c5c5c` when work began  
> Intended branch: `tutorial/p1-m03-m04` (stacked on latest Leader-approved M01/M02 branch)  
> Editorial authority: none; Leader review required.

## Scope preserved

Implemented only:

- P1-M03 — Translation Pipeline, Linkage, Symbols, Relocations, ELF, Make;
- P1-M04 — Process, fork, exec, waitpid, Environment;
- one explicit M03+M04 integration lab.

Did **not** formally teach dynamic linker internals, GOT/PLT, PIC/PIE theory, shared libraries, loader internals, page tables/COW internals, scheduler internals, namespaces/cgroups, signals, pipes, `dup2`, pthread, daemonization, systemd, or kernel process implementation. Host PIE/dynamic-link properties are recorded only as evidence properties, not lesson scope.

## Dependency / PR state at implementation start

Checked PRs #2/#3/#4 on 2026-08-30 local time:

- PR #2 Phase 0 Baseline: open, base `main`;
- PR #3 Phase 1 design: open, Leader review **APPROVED WITH MINOR FIXES APPLIED**;
- PR #4 M01/M02: open stacked on PR #3, Leader review **APPROVED WITH MINOR FIXES APPLIED**.

Therefore M03/M04 was designed from PR #4 head rather than `main`, and new PR should be stacked on `tutorial/p1-m01-m02` so earlier content is not copied into this diff.

## Deliverables

```text
fundamentals/system-c/02-compile-link-elf/
  README.md
  SOURCE_LEDGER.md
  diagrams/
  labs/01-build-every-stage/
  labs/02-symbols/
  labs/03-relocations/
  labs/04-sections/
  labs/05-make-deps/
  challenge/
  faults/
  gate/
  reviewer/

fundamentals/linux/02-process-exec/
  README.md
  SOURCE_LEDGER.md
  diagrams/
  labs/01-fork-values/
  labs/02-proc-state/
  labs/03-exec/
  labs/04-exec-failure/
  labs/05-wait-zombie/
  labs/06-environment/
  labs/07-build-exec-integration/
  labs/08-strace/
  challenge/
  faults/
  gate/
  reviewer/
```

## Actual authoring / verification environment

```text
Linux 6.18.35 x86_64
GCC 14.2.0 (Debian 14.2.0-19)
GNU Make 4.4.1
GNU ld / nm / readelf / objdump / size 2.44
GDB: NOT INSTALLED
strace: NOT INSTALLED
```

All commands labeled VERIFIED below were actually executed. No GDB/strace output is fabricated.

## M03 verification record

| Object | Actual command / evidence | Actual result | Status |
|---|---|---|---|
| Lab 01 stages | `make stages && make && ./app.elf`; `file`, `wc`, `nm` | `.i/.s/.o/app.elf` generated; `main.o` identified as `ELF 64-bit ... relocatable`; output `run=1 translation-pipeline total=13 samples=2`; `main.o` has `U stats_update/stats_total/format_summary` | **VERIFIED** |
| Lab 01 host final ELF | `file app.elf` | x86-64 PIE executable, dynamically linked on this Debian default | **VERIFIED host-specific**; dynamic linker/PIC not taught |
| Lab 02 symbols | `nm` + `readelf -s` | external definitions GLOBAL; file-static function/global LOCAL; `undefined_only.o` has `U not_defined_here` | **VERIFIED** |
| Lab 03 relocation | `readelf -r main.o`; `objdump -dr main.o`; final `objdump -d` | `.rela.text` references `stats_update/stats_total`; object call displacement shows unresolved placeholder + relocation; final call targets linked symbol | **VERIFIED**, x86-64 enum host-specific |
| Lab 04 sections | `readelf -S`, `nm -S`, `size` | `.bss` = `NOBITS`; object bss 4128 bytes; zero buffer/global B-class; initialized globals data; `.text/.rodata/.data/.bss` observed | **VERIFIED** |
| Lab 05 first/no-change | `make`; `make` | first full compile/link; second `Nothing to be done` | **VERIFIED** |
| Lab 05 `.c` change | `touch src/stats.c && make` | only `stats.o` recompiled, then relink | **VERIFIED** |
| Lab 05 `.h` change | `touch include/format.h && make` | `main.o` + `format.o` recompiled, `stats.o` unchanged, then relink | **VERIFIED** |
| F1 undefined | `make f1` | linker `undefined reference to missing_calibration` after object build | **VERIFIED** |
| F2 multiple definition | `make f2` | linker identifies two `shared_mode` definitions from `a.o/b.o` | **VERIFIED** |
| F3 wrong linkage | `make f3` | consumer unresolved `exported_reading`; provider local definition | **VERIFIED** |
| F4 stale header | build SCALE=2; edit header SCALE=7; `make`; clean rebuild | stale build stayed `scaled=10`; Make no-op; clean rebuild `scaled=35` | **VERIFIED** |
| M03 challenge | seeded objects/link + reviewer fixed tree | seeded default unresolved `registry_limit` + `format_report`; all-object link exposes multiple `report_width`; fixed output `total=9 samples=2 width=48` | **VERIFIED seeded + fixed** |
| M03 Gate seeded | `make objects`; `nm`; `readelf -r`; `make` | local `sampler_scale`, consumer `U sampler_scale`; main relocations; default link unresolved `report_emit` | **VERIFIED** |
| M03 Gate fixed | reviewer tree `make && ./gate_app`; binary tools | output `gate total=12 dropped=1`; `sampler_scale` external; final sections observed | **VERIFIED** |
| GDB disassembly path | `gdb` commands in tutorial | tool unavailable | **UNVERIFIED** |

### M03 architecture-specific observation

`objdump -dr main.o` on x86-64 showed call bytes such as `e8 00 00 00 00` plus `R_X86_64_PLT32 stats_update-0x4`, then final ELF disassembly showed a concrete call target. The transferable claim is unresolved machine-code location + relocation → linker-resolved relation; exact opcode, `%rip`, addend, enum are not portable learning requirements.

## M04 verification record

| Object | Actual evidence | Actual result | Status |
|---|---|---|---|
| Lab 01 fork | `./fork_values` | child saw return 0; parent saw child PID; wait decoded child exit 7 | **VERIFIED** |
| Lab 02 `/proc` + FD | held checkpoint; `ps`, `/proc/<child>/fd`, cmdline | child state S; fd entries 0/1/2/3; fd 3 pointed to `inherited.log`; cmdline `./proc_state` | **VERIFIED** |
| Lab 03 exec | `./exec_demo` | before/after child PID identical in run; new image argv/token observed; exit 23 decoded | **VERIFIED** |
| Lab 04 missing exec | `./exec_failure ./does-not-exist` | `No such file or directory`; parent reserved 127 | **VERIFIED** |
| Lab 04 permission exec | non-executable fixture | `Permission denied`; parent reserved 127 | **VERIFIED** |
| Lab 04 fallthrough | `--bad-return` | explicit `BUG: child continued in caller...` observed | **VERIFIED** |
| Lab 05 zombie | deterministic `/proc` poll + external `ps`; then wait | child state `Z`; after wait exit 42 decoded and `/proc/<child>` gone | **VERIFIED** |
| Lab 06 environment | `./env_parent` | parent local variable printed only by old program; exec image saw `DEMO_COLOR` via environment | **VERIFIED** |
| Lab 07 integration | binary inspect + parent/child checkpoint + `/proc` | before/after exec PID same; cmdline `child_image from-parent`; `/proc/exe` pointed to linked child ELF | **VERIFIED** |
| Lab 08 strace | `strace -f` commands | tool not installed | **UNVERIFIED** |
| Challenge starter | strict build | TODO starter builds | **VERIFIED** |
| Challenge reviewer | env + exits 7/127 + missing path | env override and correct wait decode observed; legitimate target 127 and exec-failure 127 demonstrate declared ambiguity | **VERIFIED** |
| F1 zombie | deterministic fixture + external `ps`/`/proc` | child state `Z` independently observed before checkpoint release | **VERIFIED** |
| F2 fallthrough | `./process_faults fallthrough` | child continued caller logic after exec failure | **VERIFIED** |
| F3 raw status | child exits 7 | seeded output `1792` on authoring host, proving raw status != exit code | **VERIFIED host-specific value** |
| F4 inherited FD | `./process_faults fd` | exec helper reported inherited FD open | **VERIFIED** |
| M04 Gate seeded | deterministic checkpoint; `ps`; `/proc`; log | both good/missing children state Z; worker reported log FD inherited/open and wrote log; exec failure fell through | **VERIFIED** |
| M04 Gate fixed | compile reviewer source + run | worker reports inherited=no; parent reports good exit 7, missing exec reserved 127 | **VERIFIED** |
| Gate strace | required learner evidence | tool unavailable | **UNVERIFIED** |
| GDB process path | optional commands | tool unavailable | **UNVERIFIED** |

## Source pins / version notes

### Toolchain

- GCC docs pinned to 14.2.0 for executed tutorial baseline; current upstream release at check date is **16.2 (2026-08-07)**.
- binutils docs pinned to 2.44; current upstream release is **2.47 (2026-07-26)**.
- GNU Make manual baseline/current upstream is **4.4.1**.
- ELF generic concepts cross-checked against System V gABI; x86-64 psABI used only for host-specific relocation interpretation.

### Linux man-pages

- Tutorial API snapshot remains **man-pages 6.18**, matching M02 and the rendered cited man7 pages.
- **man-pages 6.19 was released 2026-08-25** and is current upstream at authoring time; this is recorded separately rather than silently changing the tutorial pin.

### musl

- release **1.2.6**, 2026-03-20;
- commit `9fa28ece75d8a2191de7c5bb53bed224c5947417` (same pin already approved in M01 source work);
- REQUIRED source paths: `src/process/waitpid.c`, `src/process/execv.c`;
- SHOULD: `src/process/execve.c`;
- official upstream: `git.musl-libc.org`; GitHub mirror blob IDs used only for byte/path cross-check;
- license/provenance: musl COPYRIGHT, MIT-style permissive terms.

## Learner load / reading budget

- M03: approved module budget **~7 h MUST**; REQUIRED reading implementation target **65–75 min**.
- M04: approved module budget **~5.5 h MUST**; REQUIRED reading implementation target **65–75 min**.
- Combined M03+M04 required reading: **~2 h 15–2 h 30 min**, under the brief’s 2.5–3 h ceiling.
- Combined module work remains **~12.5 h MUST**; no curriculum architecture change.

## Deviations / design choices

1. Added a separate M04 Lab 08 for `strace -f` so syscall-boundary evidence is explicit instead of being decorative text in another lab. Runtime is UNVERIFIED because tool unavailable.
2. Added deterministic `/proc` state polling inside zombie fixtures/Gate solely to establish a guaranteed inspection checkpoint. This is lab synchronization, not taught as production process supervision.
3. `run_one` reserves exit 127 for exec failure because an actually unambiguous general-purpose protocol normally needs an extra channel/CLOEXEC discipline, which would prematurely enter pipe/FD_CLOEXEC engineering. The ambiguity is documented rather than hidden.
4. M04 source reading includes musl `waitpid.c` + `execv.c` as REQUIRED because both are tiny, pinned, low-noise wrappers that directly clarify libc/process boundary. `execve.c` is SHOULD.
5. Phase 0 Baseline already tested multi-file link failure and a fork/pipe/dup2 pipeline/zombie+FD fixture. M03/M04 contexts therefore use different projects, forbid pipe/dup2 in M04, and require deeper evidence/transfer rather than replaying Baseline.

## Known limitations / Leader review focus

1. **GDB UNVERIFIED**: tool absent. M03 commands are restricted to `disassemble`, `info registers`, `x/i`, stepping around calls; no advanced fork config required.
2. **strace UNVERIFIED**: tool absent. No trace output fabricated. Gate requires learner/Leader execution on target WSL before promotion.
3. `/proc` is Linux-specific; PID/FD/address values are intentionally not golden literals.
4. Authoring GCC defaults final executable to PIE/dynamically linked; tutorial records this as host evidence without teaching PIE/dynamic linker internals.
5. Exact relocation names/opcodes are x86-64 evidence only; Gate does not grade enum spelling.
6. `run_one` reserved-127 protocol is deliberately not general-purpose; later pipe/CLOEXEC module can introduce robust exec-failure signaling.
7. M04 Gate uses `/proc` polling to guarantee both seeded children reach zombie state before inspection; this extra fixture mechanism should not be mistaken for recommended supervisor implementation.
