# Baseline Rules

## Scored mode: AI-Free

The scored portion measures independent capability.

### Allowed

- `man` and Linux man-pages
- GCC documentation and compiler diagnostics
- GDB built-in `help` and official GDB documentation
- GNU binutils documentation
- local shell tools and `/proc`
- STM32F103C8T6 datasheet (DS5319)
- STM32F10x reference manual (RM0008)
- STM32 Cortex-M3 programming manual (PM0056)
- supplied starter code, fixtures, and system documentation
- sanitizers and debugger instrumentation

### Not allowed

- ChatGPT, Claude, Gemini, Copilot, coding agents, or other solution-generating AI
- searching the exact exercise text or a complete solution
- copying a Stack Overflow answer or another learner's solution
- reading `reviewer/` before scoring is complete

**AI-Free does not mean documentation-free.** Looking up an API contract, register behavior, ABI detail, or tool option in authoritative documentation is normal engineering work and is encouraged.

## Evidence integrity

Do not fabricate terminal output, sanitizer reports, debugger observations, benchmark numbers, register values, or hardware measurements. If a tool cannot run, record `UNVERIFIED` or the failure and continue with the remaining reasoning.

## Timing

- Target total: 7 h 45 min.
- Stop the timer for meals and long external interruptions, not for documentation lookup.
- Record actual time per module.
- A module may be stopped at its time box; unfinished work is still useful diagnostic evidence.

## Build environment

Target host environment:

```text
Windows 11
WSL2
Linux userspace
GCC
GDB
GNU Make
GNU binutils
strace
```

Exact local versions are not prescribed for the learner. Record the versions actually used:

```sh
gcc --version | head -n1
gdb --version | head -n1
make --version | head -n1
ld --version | head -n1
strace --version | head -n1
uname -a
```

## Debug report format

For D1–D4, submit one record each:

```text
Symptom:

Initial hypotheses:

Evidence:

Experiment:

Hypotheses rejected:

Root cause:

Fix:

Regression test:
```

A correct patch with no evidence chain does not receive full Debugging credit.

**Changing sleeps, timeouts, loop counts, or delays until a race/hang disappears is not a root-cause fix.** Such a change may alter scheduling and hide the symptom without explaining the defect.

## STM32 hardware safety

The STM32 section is reasoning-first. No dangerous voltage, mains wiring, or destructive fault injection is required. If the learner chooses to run code on a board, use normal low-voltage development practices and a known-good SWD/debug setup.
