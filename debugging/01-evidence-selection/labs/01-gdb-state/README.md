# Lab — GDB State Inspection

## Objective

Use a deterministic semantic boundary bug to decide where state diverges.

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
    ./state_bug
    then on a host with GDB: gdb ./state_bug

## Expected Observation

Observed source-level symptom is result=9 expected=10. In GDB, use break/run/step-or-next/print/backtrace/frame; do not jump directly to a fix.

## Actual Verification Status

**PARTIALLY VERIFIED** — strict build and wrong result executed; GDB execution UNVERIFIED because tool is not installed.

## Questions

1. What exact question are you asking the tool?
2. What hypothesis did the evidence eliminate?
3. What evidence would force you to switch domains/tools?

## Failure Modes

Opening every tool at once; treating a tool label as root cause; treating absence of a sanitizer report as correctness; assuming syscall spelling equals libc API spelling.

## Debug Strategy

Start with the question “where does current stop matching the intended boundary contract?” Use GDB only because the hypothesis is C state/control flow.

## Challenge

After finding the branch, explain how optimization could change observability without changing the language-level bug.

## Cleanup

    make clean

(if no Makefile exists, no cleanup is required.)

## Sources

M08-S01/S04; see ../../SOURCE_LEDGER.md.
