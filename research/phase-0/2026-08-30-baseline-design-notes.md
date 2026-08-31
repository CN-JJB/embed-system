# Phase 0 Baseline Assessment — Design Notes

> Role: Assessment Designer + Technical Exercise Author  
> Design date: 2026-08-30  
> Implementation verification refreshed: 2026-08-31  
> Status: PR candidate — Leader review required  
> Scope source: `research/phase-0/2026-08-30-curriculum-research-validation.md` v1.2

## 1. Design constraints preserved from approved Phase 0 research

This implementation does **not** reopen the approved career route. It converts the v1.2 Baseline proposal into executable diagnostic material.

Preserved decisions:

- ~8 hour AI-Free Baseline;
- System C + toolchain = 25 points in aggregate;
- Linux = 20;
- Debugging = 25 and is a hard Gate;
- Computer Systems = 15;
- STM32 = 15;
- no FreeRTOS knowledge test;
- documentation lookup is allowed;
- a fix without root-cause evidence is not a debugging pass;
- STM32 reasoning uses official device documentation.

The implementation separates System C (15) and Compile/Link/ELF (10) into directories for cleaner evidence/review, while preserving the approved 25-point aggregate.

## 2. Time allocation

| Module | Time | Why this amount |
|---|---:|---|
| System C | 90 min | enough for one realistic bug hunt plus a small callback component; prevents turning the Gate into a full C exam |
| Compile/Link/ELF | 60 min | enough to inspect intermediate artifacts and repair two linkage failures |
| Linux | 80 min | pipeline implementation plus live process/FD investigation |
| Debugging | 105 min | largest practical block because evidence-chain quality is the highest-value diagnostic signal |
| Computer Systems | 65 min | machine-state reasoning + control transfer + one measured locality experiment |
| STM32 | 65 min | manual navigation and bare-metal reasoning without requiring a board build |
| **Total** | **465 min / 7 h 45 min** | inside the requested 6–8 hour window |

The assessment can be split across 2–4 days. Time-box overrun is itself useful diagnostic information, so the learner records actual active minutes.

## 3. What each module diagnoses

### A — System C

A1 intentionally combines a small number of high-value C failure classes in one plausible telemetry program:

- automatic-storage lifetime;
- pointer/array extent;
- bounds;
- signed shift UB;
- struct padding/endian serialization assumptions;
- heap ownership.

A2 checks whether function pointers and `void *ctx` can be used to design an API with explicit ownership/lifetime rather than merely recognized syntactically.

### B — Compile / Link / ELF

The multi-file fixture compiles objects but fails at final link due to:

- a header that defines an external object in every translation unit;
- a provider function with internal linkage while another object requires an external definition.

The learner must create/inspect `.i`, `.s`, `.o`, and ELF artifacts and connect symbols/relocations/sections to this program.

### C — Linux

C1 diagnoses process creation, exec, FD duplication, close discipline, EOF semantics, and child status.

C2 seeds both unreaped children and parent-side pipe FD leaks. The task requires process/FD evidence before code edits, using `ps`, `/proc`, and `strace` where available.

### D — Debugging

Four faults cover:

1. segmentation fault / invalid lookup result handling;
2. delayed subobject memory corruption;
3. real pthread data race;
4. build/link symbol-binding failure.

Every fault uses the same postmortem structure:

```text
Symptom -> Initial hypotheses -> Evidence -> Experiment
-> Hypotheses rejected -> Root cause -> Fix -> Regression test
```

At least 3/4 actual root causes are required. Sleep/delay/timeout masking does not count as a fix.

### E — Computer Systems

The learner must connect C to x86-64 machine state using disassembly/GDB, distinguish transferable call-stack concepts from ABI details, reason across syscall/IRQ/CPU exception control transfers, and perform a cache/TLB-locality prediction/measurement loop.

### F — STM32

The selected MCU is **STM32F103C8T6**. This avoids guessing which device was meant by the learner's other “ZET6” board description.

Tasks diagnose:

- reset/vector/startup/linker integration;
- timer clock-tree/interrupt derivation;
- MMIO/volatile/RMW reasoning;
- timer-triggered ADC/DMA debug planning.

The DMA task uses a configuration snapshot with multiple software mistakes; it does not require destructive fault injection or a working hardware setup.

## 4. Scoring calibration

Pass requirements:

- total >= 70/100;
- A+B >= 17/25;
- D >= 17/25;
- every module >= 50%;
- Debugging reaches actual root cause on >=3/4 faults;
- scored work follows AI-Free rules.

The module-floor rule prevents a strong hardware background or one strong domain from hiding severe Linux/C/system-model gaps.

Placement:

- Fast Track: >=85, every module >=70%, Debug 4/4;
- Normal: all pass rules;
- Remediation Required: 60–69 or any Gate condition failure;
- Foundation Rebuild: <60 or broad failure across >=3 modules.

A Debug Gate failure blocks later Linux Driver main-line entry regardless of total.

## 5. Verification environment

Authoring/verification container:

```text
gcc (Debian 14.2.0-19) 14.2.0
GNU Make 4.4.1
GNU ld (GNU Binutils for Debian) 2.44
Linux 6.18.35 x86_64
GDB: unavailable in authoring container
strace: unavailable in authoring container
```

The learner environment remains Windows 11 + WSL2 + Linux + GCC/GDB/Make/binutils/strace as specified by the task.

## 6. Host verification record

The following records distinguish actual execution from planned observations. Outputs are summarized rather than presented as fabricated transcript text.

| Area | Build/run command | Expected | Actual observation | Status |
|---|---|---|---|---|
| A1 warning build | `make bug-hunt` | build succeeds with evidence-relevant warning(s) | GCC built starter and warned about returning address of local storage | **VERIFIED** |
| A1 sanitizer build/run | `make bug-hunt-san && ./telemetry_bug_hunt_san` | at least one real memory/UB symptom is observable; exact first report may vary | AddressSanitizer reported a stack-buffer-overflow from the seeded bounds defect | **VERIFIED** |
| A2 starter | `make event-bus-test` before implementation | supplied test fails | starter returns `ENOSYS`; fixture fails as intended | **VERIFIED** |
| A2 reviewer reference | compile reviewer reference with supplied fixture | `event_bus tests: PASS` | supplied fixture passed | **VERIFIED** |
| B objects | `make clean && make objects` | individual objects compile | all four objects built | **VERIFIED** |
| B broken link | `make` | multiple definition + undefined reference | both independent link failures reproduced | **VERIFIED** |
| B symbols/relocations | `nm`, `readelf -s`, `readelf -r` | duplicate global + local provider + UND consumer visible | expected symbol-binding/relocation evidence observed | **VERIFIED** |
| B reviewer repair | repaired reference build | `baseline total=7 dropped=0` | expected output observed | **VERIFIED** |
| C fixtures | `make` | producer/filter/lab/starter build | built successfully | **VERIFIED** |
| C fixture shell pipe | `./producer | ./filter` | KEEP alpha / KEEP gamma | expected two lines observed | **VERIFIED** |
| C reviewer pipeline | compile/run reviewer reference pipeline | same two KEEP lines, clean exit | expected output and exit observed | **VERIFIED** |
| C2 live state | run `fd_zombie_lab`, inspect with `ps` and `/proc/<pid>/fd` | unreaped children + leaked pipe FDs | five zombie children observed; parent showed 13 FDs (3 standard + 10 leaked pipe FDs) in the tested run | **VERIFIED** |
| C2 strace | `strace ...` | syscall evidence | tool absent in authoring container | **UNVERIFIED — tool unavailable** |
| D1 | `./fault_seg` | segmentation fault | SIGSEGV reproduced | **VERIFIED** |
| D1 GDB evidence | GDB backtrace/frame inspection | `u == NULL` evidence | GDB absent in authoring container | **UNVERIFIED — tool unavailable** |
| D2 | `./fault_corruption` | later guard validation fails | guard corruption reproduced | **VERIFIED** |
| D3 repeated race | `fixtures/repeat_race.sh` | at least some runs can mismatch | lost-update mismatches reproduced | **VERIFIED** |
| D3 TSan | `make tsan && ./fault_race_tsan` | race report if runtime supported | ThreadSanitizer reported the seeded data race in authoring run | **VERIFIED** |
| D4 | `make fault-link` | unresolved checksum symbol | link failure reproduced | **VERIFIED** |
| E1 | `make call_trace && objdump -d call_trace` | runnable program + inspectable call | program produced `result=51`; disassembly available | **VERIFIED** |
| E1 GDB | inspect registers/frames | host-specific evidence | GDB absent in authoring container | **UNVERIFIED — tool unavailable** |
| E3 | `./locality_bench` x3 | host-dependent timings; generally sequential expected faster | three authoring runs completed; sequential was materially faster than the seeded ~4 KiB stride on this host | **VERIFIED (host-specific)** |
| F linker fixture | host `ld`/syntax-oriented review only | teaching excerpt is internally coherent | syntax/layout reviewed; not linked as an ARM firmware image | **PARTIALLY VERIFIED** |
| F MMIO fixture | host C compile/syntax check | snippet compiles | syntax checked | **PARTIALLY VERIFIED** |
| F hardware | real board run/SWD/scope | no result claimed | not performed | **UNVERIFIED — hardware execution required** |

No GDB output, strace output, STM32 register dump, board waveform, or benchmark “golden number” is invented.

## 7. Official STM32 baseline

Checked against ST documentation:

| Source | Revision | Use |
|---|---|---|
| DS5319 — STM32F103x8/xB datasheet | Rev 20 | selected device capabilities and memory |
| RM0008 — STM32F10x reference manual | Rev 21 | RCC/timer/ADC/DMA/interrupt behavior |
| PM0056 — Cortex-M3 programming manual | Rev 7 | exception/core/NVIC mental model |

The learner is allowed and expected to consult these documents during the scored STM32 tasks.

## 8. Known risks / limitations

1. **GDB and strace not installed in authoring container.** The source tasks that require these tools are designed and code paths are built, but the exact debugger/trace command path needs Leader/learner WSL validation.
2. **No STM32 board execution.** All board-dependent claims remain unverified. The assessment intentionally scores manual-backed reasoning without pretending hardware evidence exists.
3. **Race symptoms are scheduler/toolchain dependent.** The fault is a real C data race even if a particular run happens to print the expected count. The rubric scores causal evidence, not a mandatory mismatch every run.
4. **ASan may not diagnose D2.** D2 is intentionally a subobject overwrite inside one enclosing struct, so the learner may need a watchpoint/source reasoning rather than assuming sanitizer silence means safety.
5. **ELF relocation names vary.** Rubric requires interpreting the relocation's role, not memorizing one x86-64 relocation enum.
6. **Cache benchmark magnitude is host-dependent.** There is no numeric golden threshold; the diagnostic evaluates prediction, measurement hygiene, and explanation.
7. **Event bus token wraparound is not a production-grade ID allocator.** The reference is intentionally bounded for a baseline exercise; exhaustive long-run uniqueness is not the skill being tested.
8. **F4 contains multiple simultaneous configuration errors.** This is deliberate to test hypothesis ordering; if Leader finds the task too dense for 25 minutes, reduce to three seeded mistakes while preserving stage-by-stage diagnosis.

## 9. Future adjustment points after first learner run

Record, do not guess:

- actual completion time per task;
- which bugs are found only because a sanitizer points directly at them;
- whether A1 has too many independent defects for 55 minutes;
- whether C2 ptrace restrictions in WSL make attach-mode `strace` awkward;
- whether D3 is sufficiently reproducible on the learner's WSL kernel/toolchain;
- whether E3 array size/stride needs tuning on the learner machine;
- whether F4 manual lookup takes too much of the 25-minute time box;
- score distribution and remediation usefulness after one real attempt.

Any change to difficulty or pass thresholds should be driven by actual first-run evidence and Leader review, not by post-hoc score inflation.

## 10. Source use

Primary facts are based on GNU tool documentation, Linux man-pages, and ST primary manuals. CS:APP, TLPI, OSTEP, and CS61C are used for stable mental models/teaching shape. No random STM32 blog is used as the factual baseline.

This document records assessment-design evidence only; it does not change the approved Phase 0 career roadmap.
