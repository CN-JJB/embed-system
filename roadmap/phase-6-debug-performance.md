# Phase 6 — Bring-up, Debugging, Tracing, Performance and Real-Time

> **Authoring model:** resource-first. This phase is deliberately evidence-heavy and prose-light: spend more time measuring real systems than reading generated explanations.

## How to navigate this phase

Use the same IDs in:

- [`../START_HERE.md`](../START_HERE.md) — order and next action;
- [`../resources/TOPIC_RESOURCE_INDEX.md`](../resources/TOPIC_RESOURCE_INDEX.md) — exact docs/tools/experiments;
- this file — phase scope and dependency context.

```text
P6.1 reproducible symptom + cheapest observation
→ P6.2 dynamic debug + bind/probe diagnosis
→ P6.3 tracefs / ftrace / tracepoints
→ P6.4 perf
→ P6.5 kprobes / eBPF / LTTng orientation
→ P6.6 panic/oops + memory/locking diagnostics
→ P6.7 latency + PREEMPT_RT
→ P6.8 boot-time measurement/optimization
→ P6.9 memory + I/O performance
→ P6.10 evidence-backed capstone
```

## Exit capability

By the end of Phase 6, the learner should be able to:

- isolate difficult boot, driver, userspace and performance failures efficiently;
- choose the cheapest observation tool that can discriminate hypotheses;
- use logs, dynamic debug, sysfs/proc/debugfs and tracing appropriately;
- use ftrace/tracepoints/perf before escalating to more complex instrumentation;
- orient around kprobes/eBPF/LTTng when needed;
- debug kernel crashes and locking/memory problems at practical depth;
- reason about latency across IRQ/scheduler/driver/userspace boundaries;
- recognize when PREEMPT_RT is relevant and what it changes;
- measure boot time, CPU load, memory pressure and I/O latency without guessing;
- write an engineering postmortem that separates symptom, evidence, root cause and regression.

---

## P6.1 — Reproducible symptom and cheapest observation channel

Start with the least invasive tool that can answer the current question:

```text
reproduce reliably
→ exit status / logs / timestamps
→ proc / sysfs / debugfs state
→ strace / userspace GDB
→ dynamic debug / tracepoints / ftrace
→ perf
→ kprobes / eBPF / LTTng
→ crash dump / low-level debugger
→ physical measurement for real hardware timing
```

### Exact resource entry

Use **P6.1** in [`../resources/TOPIC_RESOURCE_INDEX.md`](../resources/TOPIC_RESOURCE_INDEX.md), anchored by Bootlin's Linux debugging/tracing/performance course and the man-pages/interfaces relevant to the actual symptom.

### Rule

Write 3–5 hypotheses before turning on expensive tracing. Choose the first observation by **discrimination value**, not novelty.

---

## P6.2 — Dynamic debug, driver bind/probe and boot diagnosis

### Learn

- dynamic debug;
- boot/probe logs;
- sysfs binding state;
- module/device/driver distinction;
- deferred probe orientation;
- command-line effects;
- working-vs-failing artifact comparison.

### Exact resource entry

Use **P6.2**: kernel **Dynamic Debug HOWTO**, driver-model/platform docs from Phase 4 and kernel-parameter documentation relevant to the failure.

### Suggested experiment

Enable dynamic debug for one probe path and classify a controlled failure as one of:

```text
never matched
probe entered and failed
probe succeeded, runtime path failed
```

---

## P6.3 — tracefs, ftrace and tracepoints

### Learn

- tracefs;
- function/function-graph tracing at orientation depth;
- event tracepoints;
- filters;
- scheduler/IRQ/workqueue events;
- timestamps;
- overhead and observer effects.

### Exact resource entry

Use **P6.3**: kernel tracing index, starting with **ftrace — Function Tracer** and **Event Tracing**, plus Bootlin tracing material.

### Suggested experiment

Trace one IRQ/workqueue/scheduler-to-userspace path and draw a timeline. Mark direct observations separately from inference.

---

## P6.4 — `perf` and system-level performance reasoning

### Learn

- sampling vs event counting/tracing;
- `perf stat`;
- `perf record/report`;
- call graphs and symbols;
- CPU-bound vs runnable vs sleeping/blocked distinctions;
- basic hardware events only where they answer the question.

### Exact resource entry

Use **P6.4**: installed `perf` man-pages and matching kernel `tools/perf/` material, plus Bootlin performance sections.

### Suggested experiment

Characterize one workload with `perf stat`, then locate hot code using `perf record/report`; independently determine whether wall-clock delay includes blocked time.

---

## P6.5 — kprobes, eBPF and LTTng orientation

These are escalation tools, not prerequisites for every bug.

### Learn

- dynamic instrumentation;
- kprobe/kretprobe roles;
- eBPF program/attachment/map mental model;
- BTF/CO-RE orientation when needed;
- LTTng's whole-system/long-duration role;
- why stable tracepoints are preferable when sufficient.

### Exact resource entry

Use **P6.5**: kernel kprobes/tracing docs, kernel BPF/libbpf docs and official LTTng docs only when the question justifies them.

### Suggested experiment

Instrument one path for one unanswered question, collect the discriminating data, then remove the probe.

---

## P6.6 — Panic/oops, memory bugs and locking diagnostics

### Learn as needed

- panic/oops reading;
- call traces and symbol resolution;
- KASAN;
- KCSAN;
- lockdep;
- UBSAN/kmemleak orientation;
- crash-dump/GDB concepts where appropriate.

### Exact resource entry

Use **P6.6**: kernel KASAN, KCSAN and lockdep documentation plus matching debugging docs for the kernel version used.

### Suggested experiment

In a disposable test kernel/module environment, trigger one bounded memory or locking bug, capture the diagnostic, fix it and rerun the same reproducer.

---

## P6.7 — Latency and PREEMPT_RT

### Learn

- latency vs throughput;
- interrupt and scheduling latency;
- priority inversion;
- kernel preemption models;
- threaded interrupts;
- PREEMPT_RT orientation;
- timer/wakeup behavior;
- affinity/isolation only after evidence justifies them.

### Exact resource entry

Use **P6.7**: current kernel real-time/PREEMPT_RT documentation and Bootlin **Real-time Linux with PREEMPT_RT**.

### Suggested experiment

Measure a latency **distribution** under declared load; record board/CPU, kernel/config, load generator and method. Do not report one best-case number as “the latency”.

---

## P6.8 — Boot-time measurement and optimization

### Learn

- define the endpoint first;
- firmware/bootloader/kernel/userspace contributions;
- initcall/service timing;
- storage/filesystem effects;
- dependency critical path;
- measurement stability;
- debug-vs-production trade-offs.

### Exact resource entry

Use **P6.8**: Bootlin's current **Embedded Linux boot time optimization** materials and the bootloader/kernel/userspace timing facilities implicated by evidence.

### Suggested experiment

Measure a boot timeline, identify the dominant critical-path contributor, change only that contributor, and measure again using the same endpoint.

---

## P6.9 — Memory and I/O performance

### Learn

- RSS/PSS and page-cache interpretation;
- memory pressure vs leak;
- reclaim/swapping where applicable;
- block-I/O latency/throughput basics;
- filesystem/writeback implications;
- CPU copying vs DMA where relevant;
- cache/coherency effects at practical depth.

### Exact resource entry

Use **P6.9**: current `/proc` documentation/man-pages and system tools such as `vmstat`, `pidstat`, `iostat`/block tools/perf; descend into MM/block-layer docs only when evidence points there.

### Suggested experiment

Pick one real bottleneck and require at least two independent evidence channels before changing configuration.

---

## P6.10 — Evidence-backed debug/performance capstone

Take a functioning Phase 4/5 system and inject or identify one realistic failure or degradation. Deliver:

```text
Symptom
Environment / exact versions
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

Use **P6.10** in the topic index for the final exit criterion.

Another engineer should be able to understand and challenge your reasoning without rerunning every exploratory command.

---

# Common traps

- collecting traces without a question;
- confusing correlation with causation;
- changing several variables at once;
- hiding tail latency behind an average;
- assuming CPU utilization means useful work;
- blaming the scheduler before checking blocking/I/O/locks;
- claiming product performance from an unrepresentative microbenchmark;
- presenting emulator timing as physical-hardware timing;
- tuning kernel knobs before identifying the bottleneck.

# Optional specialization after Phase 6

Choose by project/job demand:

- networking / PHY / switch / DSA;
- DRM/KMS graphics;
- ALSA/ASoC audio;
- security / verified boot / TEE;
- storage / eMMC / NAND / UBI;
- PCIe;
- advanced power management;
- interconnect/IOMMU/coherency;
- FPGA/custom-IP integration;
- upstream contribution/subsystem maintenance.
