# Phase 6 — Bring-up, Debugging, Tracing, Performance and Real-Time

> **Authoring model:** resource-first. This phase is intentionally evidence-heavy and prose-light: the learner should spend more time measuring real systems than reading generated explanations.

## Exit capability

By the end of Phase 6, the learner should be able to:

- isolate difficult boot, driver, userspace and performance failures efficiently;
- choose the cheapest observation tool that can discriminate hypotheses;
- use kernel logs, dynamic debug, sysfs/proc/debugfs and tracing facilities appropriately;
- use ftrace/tracepoints/perf before escalating to more complex instrumentation;
- orient around kprobes/eBPF/LTTng/KernelShark when needed;
- debug kernel crashes and locking problems at practical depth;
- reason about latency across interrupt, scheduler, driver and userspace boundaries;
- recognize when PREEMPT_RT is relevant and what it changes conceptually;
- measure boot time, CPU load, memory pressure and I/O latency without guessing;
- write an engineering postmortem that separates symptom, hypothesis, evidence, root cause and regression.

---

# P6-1 — Observation hierarchy

Start with the least invasive tool that answers the question.

```text
reproduce reliably
→ logs / exit status / timestamps
→ proc/sysfs/debugfs state
→ strace / userspace GDB
→ dynamic debug / tracepoints / ftrace
→ perf
→ kprobes / eBPF / LTTng
→ crash dump / low-level debugger
→ physical measurement where hardware timing is involved
```

Do not reach for eBPF because it is fashionable when one tracepoint or register read answers the question.

## Primary course

Bootlin Linux debugging, tracing, profiling and performance analysis:
https://bootlin.com/training/debugging/

## Kernel tracing docs

https://docs.kernel.org/trace/

---

# P6-2 — Boot and driver bring-up debugging

## Learn

- early boot logs;
- initcall/probe ordering orientation;
- deferred probe;
- dynamic debug;
- `dmesg` discipline;
- sysfs binding state;
- module/device/driver relationship;
- kernel command line effects;
- comparing working vs failing boot artifacts.

## Suggested exercise

Introduce one controlled failure each in:

- DT resource;
- missing clock/regulator/pinctrl dependency;
- wrong bootarg/rootfs path;
- driver probe path.

For every case, write 3–5 hypotheses before changing code.

---

# P6-3 — ftrace and tracepoints

## Learn

- tracefs;
- function/function-graph tracing at orientation depth;
- event tracepoints;
- filters;
- timestamps;
- tracing scheduler/IRQ/workqueue events;
- overhead and perturbation awareness.

## Suggested experiment

Trace one interrupt-to-userspace or driver-work path and produce a timeline. Explain which segments are directly observed and which are inferred.

---

# P6-4 — perf and system-level performance reasoning

## Learn

- sampling vs tracing;
- `perf stat` vs `perf record/report`;
- CPU cycles/instructions/cache events at orientation depth;
- scheduler profiling;
- call graphs;
- symbolization;
- CPU-bound vs blocked vs I/O-bound distinction.

## Suggested exercise

Take one deliberately inefficient application/driver interaction and answer:

- where is time spent?
- is the process runnable, sleeping or blocked on I/O?
- is the bottleneck CPU, lock, scheduler, I/O, interrupt load or memory?
- what changed after the fix?

Use before/after evidence, not subjective responsiveness.

---

# P6-5 — kprobes / eBPF / LTTng orientation

These are powerful tools, not prerequisites for every bug.

## Learn

- dynamic instrumentation concept;
- kprobe/kretprobe role;
- eBPF program/attachment/map mental model at orientation depth;
- BTF/CO-RE concept later if useful;
- LTTng/system tracing role;
- when a stable tracepoint is better than probing an internal function.

## Suggested practice

Instrument one kernel function or tracepoint to answer a specific existing question. Do not create a generic “learn eBPF” detour unless the target role needs it.

---

# P6-6 — Kernel crash / memory / locking debugging

## Learn as needed

- panic/oops reading;
- call traces;
- symbol resolution;
- lockdep;
- KASAN/KCSAN/UBSAN orientation;
- kmemleak orientation;
- crash dump concepts;
- GDB/vmlinux symbols when appropriate.

## Suggested experiment

Use a deliberately broken test module or debug configuration in a disposable environment. Trigger one bug class, capture the diagnostic, fix it, and prove regression.

Never create unsafe failures on production hardware merely for practice.

---

# P6-7 — Latency and real-time reasoning

## Learn

- latency vs throughput;
- interrupt latency;
- scheduling latency;
- priority inversion;
- kernel preemption models;
- threaded interrupts concept;
- PREEMPT_RT orientation;
- CPU affinity/isolation only when evidence justifies it;
- timer resolution and wake-up latency;
- why “high priority” is not a real-time guarantee.

## Resources

Use current kernel real-time documentation and maintained Bootlin real-time Linux training when this becomes a real project requirement.

## Suggested experiment

Measure latency distribution under controlled load rather than reporting a single best-case number. Record hardware, kernel config, load generator and measurement method.

---

# P6-8 — Boot time optimization

## Learn

- define the boot-time endpoint first;
- firmware/bootloader/kernel/userspace components;
- initcall timing;
- service startup dependencies;
- storage/filesystem effects;
- parallelism vs critical path;
- trade-offs between debug visibility and optimized production startup.

## Suggested exercise

Create a boot timeline and optimize only the dominant critical-path items. Do not disable random components without measuring.

---

# P6-9 — Memory and I/O performance orientation

## Learn

- RSS/PSS and page-cache interpretation;
- memory pressure vs leak;
- reclaim/swapping where applicable;
- block I/O latency/throughput basics;
- filesystem/writeback implications;
- DMA vs CPU copying where relevant;
- cache/coherency effects at practical depth.

## Suggested exercise

Pick one real bottleneck and use at least two independent evidence channels before changing configuration.

---

# Recommended capstone

Take a functioning Phase 4/5 system and inject or identify a realistic degradation. Deliver a compact report:

```text
Symptom
Environment / versions
Reproduction
Initial hypotheses
Measurements / traces
Narrowed scope
Root cause
Fix
Before/after evidence
Regression
Remaining uncertainty
```

The report should be understandable to another engineer without replaying every experiment.

---

# Common traps

- collecting traces without a question;
- confusing correlation with causation;
- benchmarking debug vs release builds without noting it;
- changing multiple variables at once;
- reporting average latency while hiding tail behavior;
- assuming CPU utilization equals useful work;
- blaming the scheduler before checking blocking/I/O/locks;
- using synthetic microbenchmarks to claim product-level performance;
- presenting emulated timing as physical-hardware timing;
- tuning kernel knobs before finding the actual bottleneck.

---

# Optional specialization after Phase 6

Depending on target role:

- embedded networking and Ethernet/PHY/switch drivers;
- DRM/KMS and graphics stack;
- audio/ALSA/ASoC;
- security/verified boot/TEE;
- storage/eMMC/NAND/UBI;
- PCIe;
- advanced power management;
- SoC interconnect/IOMMU/coherency;
- FPGA/custom IP integration;
- upstream contribution and subsystem maintenance.

Choose based on real project/job demand rather than trying to finish every Linux subsystem.
