# Lab — Tool Selection Drill

## Objective

Choose one primary evidence source for each symptom and state what observation would falsify the leading hypothesis.

## Prerequisites

M01–M07 relevant contracts; M03 tools for build/ELF domain; M04/M06 process/FD model where relevant.

## Environment

Linux userspace, GCC 14.2.0 authoring baseline. GDB/strace availability is stated in verification, never assumed.

## Estimated Time

**20 min**

## AI Mode

**AI-Free first pass.** Official manuals/man-pages allowed.

## Build / Procedure

    No build required. Fill the worksheet before consulting reviewer material.

## Expected Observation

Different symptoms should select different first tools; there is no universal GDB-first answer.

## Actual Verification Status

**UNVERIFIED** — learner reasoning exercise; no runtime claim.

## Questions

1. What exact question are you asking the tool?
2. What hypothesis did the evidence eliminate?
3. What evidence would force you to switch domains/tools?

## Failure Modes

Opening every tool at once; treating a tool label as root cause; treating absence of a sanitizer report as correctness; assuming syscall spelling equals libc API spelling.

## Debug Strategy

For each case write Question / First tool / Why / Falsifying evidence / Second tool only if needed.

## Challenge

Create two new symptoms where sanitizer is the wrong first choice.

## Cleanup

    make clean

(if no Makefile exists, no cleanup is required.)

## Sources

M08-S01/S02/S04/S06/S08/S11; see ../../SOURCE_LEDGER.md.
