# Reviewer Rubric — Phase 0 Baseline

> Reviewer-only. Do not expose during the scored session.

## A — System C (15)

### A1 Bug Hunt (10)

- 2.0 lifetime/dangling pointer: identifies return of local array address; explains automatic storage lifetime and fixes ownership/lifetime coherently.
- 1.5 bounds: identifies `i <= count` read beyond valid samples and repairs boundary; regression covers exact count.
- 1.5 `sizeof(pointer)`: explains parameter adjustment/pointer size and passes capacity explicitly or uses an array-aware API.
- 1.0 signed shift UB: recognizes left-shifting a negative signed value is UB; chooses defined arithmetic/range policy.
- 2.0 struct/wire layout: recognizes padding + host endian/representation assumption; decodes by explicit byte offsets/widths with stated endian.
- 1.0 ownership: recognizes allocated summary ownership is hidden/ambiguous; fixes contract and frees exactly once.
- 1.0 evidence quality: warning/sanitizer/GDB/regression evidence mapped to causes rather than tool-output dumping.

Do not require every bug to manifest at runtime.

### A2 Callback Event Bus (5)

- 1.0 create/destroy + pointer-to-pointer + NULL/error handling.
- 1.5 register/capacity/token semantics.
- 1.0 unregister semantics and slot reuse.
- 0.75 emit to active handlers with correct `(event,data,size,ctx)`.
- 0.75 lifetime/ownership explanation (`ctx` borrowed, data borrowed/read-only, bus owned).

## B — Compile/Link/ELF (10)

- 2.0 diagnoses multiple global definition of `sample_count` from header definition.
- 2.0 diagnoses unresolved `format_total` because provider has local/internal linkage (`static`).
- 1.5 correct minimal fixes (`extern` declaration + one definition; external `format_total` declaration/definition consistency).
- 1.5 `nm/readelf` evidence correctly interprets GLOBAL/LOCAL/UND.
- 1.0 relocation evidence tied to call site/symbol resolution.
- 1.0 `.text/.data/.bss` tied to concrete project symbols.
- 1.0 source→preprocessed `.i`→assembly `.s`→relocatable `.o`→ELF explanation tied to produced artifacts, plus successful run.

## C — Linux (20)

### C1 Pipeline (12)

- 2.0 `pipe()` + error handling.
- 2.0 two correct `fork()` branches and exec error paths.
- 2.0 correct `dup2()` mapping stdout/stdin.
- 3.0 closes every unused pipe FD in producer, filter, and parent; EOF explanation is correct.
- 2.0 `waitpid()` both children; parent exit reflects child/exec failure reasonably.
- 1.0 expected output + FD table/evidence.

A timeout-based workaround for leaked write FDs earns no close/EOF credit.

### C2 Investigation (8)

- 2.0 `ps` evidence identifies exited-but-unreaped children/zombies.
- 2.0 `/proc/<pid>/fd` evidence identifies accumulating pipe FDs.
- 2.0 `strace` evidence connects `pipe/fork/read/close/wait*` behavior to diagnosis.
- 1.0 explains EOF reference-count semantics for pipe writers.
- 1.0 minimal placement of parent `close()` + `waitpid()` fixes.

## D — Debugging (25)

Each fault requires the diagnostic template. A guessed correct patch gets at most half of that fault's points.

### D1 Segfault (5)
- 2 evidence: backtrace/frame/pointer state.
- 2 root cause: lookup can return NULL; caller dereferences without checking/contract handling.
- 1 fix + regression missing-ID case.

### D2 Corruption (7)
- 2 evidence: guard changes; watchpoint/source boundary evidence identifies earlier write.
- 3 root cause: 16-byte payload indexed through `i <= n` for a 16-byte string, writing terminator into `guard` subobject; boundary/API policy explained.
- 2 fix + boundary regressions (15/16/oversize behavior defined).

### D3 Race (8)
- 2 repeat/TSan/assembly or other credible evidence of unsynchronized read-modify-write.
- 3 root cause: `++counter` is not atomic; `volatile` is not inter-thread synchronization and data race is invalid C execution.
- 2 correct fix via mutex or C atomic with appropriate operation/order rationale.
- 1 repeated regression under concurrency; no sleep-based masking.

### D4 Link (5)
- 2 `nm/readelf` shows consumer `U checksum_word` while provider symbol is local (`t`/LOCAL).
- 2 root cause correctly explains internal vs external linkage.
- 1 fix + successful run.

### Root-cause Gate

Count a fault as “true root cause” only if evidence identifies the causal mechanism and the fix removes that mechanism. Need >=3/4.

## E — Computer Systems (15)

- E1 5: actual disassembly/GDB evidence (2), PC/SP/args/local/return reasoning (2), ARM/RISC-V transferable-vs-ABI-specific distinction (1).
- E2 4: trigger (1), privilege/control-transfer + PC selection (1.5), saved state/return (1), distinctions among syscall/IRQ/exception (0.5).
- E3 4: prediction before run (1), measured repeated evidence (1), cache-line/prefetch/TLB explanation tied to observation (2).
- E4 2: correct per-thread/process sharing model with `fork()` nuance.

## F — STM32 (15)

- F1 4: vector initial SP/reset PC (1), `.data` load-vs-run and copy (1), `.bss` zero + linker symbols (1), SystemInit/main and architecture-vs-runtime distinction (1).
- F2 4: derives TIM2 clock 72 MHz from APB1 /2 → timer x2 (1), valid PSC/ARR pair e.g. PSC=71 ARR=999 (1), RCC/TIM DIER/SR/CR1 + NVIC flow (1.5), ISR flag-clear reasoning (0.5).
- F3 2: volatile MMIO (0.5), RMW hazards/register semantics (0.5), correctly states volatile does not give atomicity/thread-safety/general ordering (1).
- F4 5: finds primary RM evidence (1), prioritizes trigger and DMA mapping/direction/width faults (2), register/flag observations discriminate timer vs ADC vs DMA stages (1), safe SWD/scope instrumentation plan (1).

Hardware execution is not required for baseline scoring unless the Leader separately requests it. Fabricated hardware evidence is unacceptable.
