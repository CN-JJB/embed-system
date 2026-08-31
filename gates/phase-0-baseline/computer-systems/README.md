# Module E — Computer Systems Reasoning

**Time box:** 65 min  
**Score:** 15 points  
**Mode:** AI-Free; documentation allowed

## E1 — Function call from C to machine state (25 min, 5 pts)

Build `starter/call_trace.c` with the supplied Makefile (`-O0 -fno-omit-frame-pointer`). Use both `objdump` and GDB.

At the entry to `mix()` and around its return, explain using **your actual disassembly/register values**:

- program counter (PC / `$rip` on x86-64);
- stack pointer (SP / `$rsp` on x86-64);
- where function arguments are passed;
- where the local variable is represented (register or stack at the point you inspect);
- where the return address is stored and how control returns.

Then answer:

> Which concepts transfer to ARM/RISC-V, and which observations are x86-64 System V ABI details rather than universal truths?

Do not memorize fixed stack offsets from another machine.

## E2 — Syscall / hardware interrupt / CPU exception (15 min, 4 pts)

For these three scenarios:

1. a Linux userspace program executes a system call;
2. an STM32 timer peripheral asserts an interrupt;
3. a CPU detects an invalid instruction or memory/access fault.

Draw or describe for each:

```text
trigger
  -> privilege/control transfer
  -> destination PC selection
  -> state that must be preserved
  -> handler/kernel work
  -> return path
```

State who/what causes the transition. Avoid ARM-register trivia unless it supports the mechanism.

## E3 — Cache/TLB locality experiment (15 min, 4 pts)

Before running `locality_bench`, predict which pattern will be faster and why:

- sequential `int` accesses;
- a fixed odd stride close to one 4 KiB page (`1021 * sizeof(int)`) over the same array and number of accesses.

Then run the benchmark at least three times. Record your host, observed times, and whether the evidence matches your prediction. Explain plausible cache-line, hardware-prefetch, and TLB effects without claiming exact cycle counts.

Benchmark numbers are machine-dependent. The quality of prediction → observation → explanation is what is scored.

## E4 — Process vs thread resources (10 min, 2 pts)

Two Linux processes each contain two threads. For each item, state whether it is normally shared among threads of one process, shared between unrelated processes, copied/logically inherited across `fork`, or per-thread:

- virtual address space;
- file descriptor table;
- stack;
- CPU register state;
- current working directory;
- heap allocation;
- signal mask.

For any answer that needs nuance (for example `fork()` inheritance vs ongoing sharing), state the nuance.
