# Lab — strace / errno

## Objective

Use program error handling first, then OS-boundary tracing as supplemental evidence.

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
    ./open_failure
    then where available: strace -e trace=%file ./open_failure

## Expected Observation

Program reports ENOENT on seeded missing path. Trace should supplement return/errno, not replace them.

## Actual Verification Status

**PARTIALLY VERIFIED** — strict build + ENOENT path executed; strace UNVERIFIED.

## Questions

1. What exact question are you asking the tool?
2. What hypothesis did the evidence eliminate?
3. What evidence would force you to switch domains/tools?

## Failure Modes

Opening every tool at once; treating a tool label as root cause; treating absence of a sanitizer report as correctness; assuming syscall spelling equals libc API spelling.

## Debug Strategy

State hypothesis from return/errno first. Ask what file-boundary event a trace could confirm/falsify.

## Challenge

Try an existing file and compare program-level result before tracing.

## Cleanup

    make clean

(if no Makefile exists, no cleanup is required.)

## Sources

M08-S06/S09; see ../../SOURCE_LEDGER.md.
