# Lab — UBSan

## Objective

Connect a signed-overflow runtime diagnostic to the C-level numeric rule.

## Prerequisites

M01–M07 relevant contracts; M03 tools for build/ELF domain; M04/M06 process/FD model where relevant.

## Environment

Linux userspace, GCC 14.2.0 authoring baseline. GDB/strace availability is stated in verification, never assumed.

## Estimated Time

**15 min**

## AI Mode

**AI-Free first pass.** Official manuals/man-pages allowed.

## Build / Procedure

    make ubsan
    ./overflow_ubsan 2147483647

## Expected Observation

Instrumented execution diagnoses signed integer overflow; UBSan is partial coverage, not proof of all UB.

## Actual Verification Status

**VERIFIED** — GCC 14.2.0 UBSan executed.

## Questions

1. What exact question are you asking the tool?
2. What hypothesis did the evidence eliminate?
3. What evidence would force you to switch domains/tools?

## Failure Modes

Opening every tool at once; treating a tool label as root cause; treating absence of a sanitizer report as correctness; assuming syscall spelling equals libc API spelling.

## Debug Strategy

First validate input parsing; then distinguish valid INT_MAX input from invalid x+1 operation.

## Challenge

Add a checked-add path that reports overflow without triggering UB.

## Cleanup

    make clean

(if no Makefile exists, no cleanup is required.)

## Sources

M08-S02; see ../../SOURCE_LEDGER.md.
