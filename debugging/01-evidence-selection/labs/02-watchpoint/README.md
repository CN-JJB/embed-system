# Lab — Watchpoint

## Objective

Find who writes a field that mysteriously becomes zero.

## Prerequisites

M01–M07 relevant contracts; M03 tools for build/ELF domain; M04/M06 process/FD model where relevant.

## Environment

Linux userspace, GCC 14.2.0 authoring baseline. GDB/strace availability is stated in verification, never assumed.

## Estimated Time

**15–20 min**

## AI Mode

**AI-Free first pass.** Official manuals/man-pages allowed.

## Build / Procedure

    make
    ./watch_bug
    then GDB: break main, run, watch s.count, continue

## Expected Observation

Program observes count=0 expected=5. A watchpoint should stop on the write rather than requiring guesses about callers.

## Actual Verification Status

**PARTIALLY VERIFIED** — symptom executed; GDB watchpoint path UNVERIFIED.

## Questions

1. What exact question are you asking the tool?
2. What hypothesis did the evidence eliminate?
3. What evidence would force you to switch domains/tools?

## Failure Modes

Opening every tool at once; treating a tool label as root cause; treating absence of a sanitizer report as correctness; assuming syscall spelling equals libc API spelling.

## Debug Strategy

The primary question is “who writes this memory location?” That is stronger than single-stepping every function.

## Challenge

Add one legitimate count write and distinguish it from the corrupting one.

## Cleanup

    make clean

(if no Makefile exists, no cleanup is required.)

## Sources

M08-S04; see ../../SOURCE_LEDGER.md.
