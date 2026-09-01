# Challenge — Evidence Triage: Broken Binary Reader

> **AI-Free first pass.** Suggested **40–50 min**.

## Objective

One small reader exposes different fault domains. Before running a debugging tool, classify the symptom and write 3–5 hypotheses.

## Modes

    ./broken_reader memory
    ./broken_reader endian
    ./broken_reader state
    ./broken_reader file PATH

| Mode | Fault domain | Best first evidence |
|---|---|---|
| memory | heap lifetime | ASan |
| endian | byte-format semantic | golden bytes / `od` / decode reasoning |
| state | C state overwrite | GDB watchpoint |
| file | OS/file boundary | return + errno, then strace |

## Prerequisites

M07 codec boundary, M01/M05 lifetime, M02 errno/FDs, M03 evidence for build issues.

## Environment

C17; GCC 14.2.0 authoring baseline. GDB/strace not installed in authoring runtime.

## Build

    make
    make asan

## Procedure

For each mode submit:

    Symptom
    Own Description
    3–5 Hypotheses
    First evidence source + why
    Observation
    Hypothesis eliminated
    Root contract
    Minimal fix
    Regression

Do not use “every problem → GDB” or “ASan clean → correct.”

## Expected Observation

- memory mode: invalid retained heap pointer;
- endian mode: value byte order is wrong while access remains in-bounds;
- state mode: decoded-like state is overwritten later;
- file mode: caller observes a file error path.

Exact sanitizer addresses, source-line formatting, FDs, and syscall spelling are non-golden.

## Actual Verification Status

- strict build and semantic endian/state/file paths: **VERIFIED**;
- ASan memory mode: **VERIFIED** heap-use-after-free;
- GDB state investigation: **UNVERIFIED**;
- strace file investigation: **UNVERIFIED**.

Overall challenge: **PARTIALLY VERIFIED** because two primary-tool workflows require unavailable tools.

## Questions

1. Why is ASan a poor first tool for the endian mode?
2. Why does `errno` evidence precede strace for the file mode?
3. What exact memory location would you watch in the state mode?
4. Which mode could “run normally” while its contract is already wrong?

## Failure Modes

Tool shotgun; quoting report labels as root cause; changing bytes before writing wire contract; ignoring return values.

## Debug Strategy

Use one primary tool until it answers or falsifies the first hypothesis. Expand only after recording what remains unknown.

## Challenge

After repair, run normal + invalid input + repeated execution. Relevant sanitizer paths should be clean.

## Cleanup

    make clean

## Sources

M08-S01/S02/S04/S06/S09; M07 wire-format contract.
