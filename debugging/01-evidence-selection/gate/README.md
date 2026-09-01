# Gate — Evidence Selection Gate

> **AI-Free**, official docs/man-pages allowed. Suggested **80–110 min**.

The unfamiliar fixture spans multiple domains: memory safety, semantic byte format, process/FD behavior, and file/OS boundary. M03 build/ELF diagnosis remains part of the taxonomy even though this seeded file compiles.

## Station 1 — Classify before tools

Fill:

| Symptom | 3–5 hypotheses | First tool/evidence | Why this first? |
|---|---|---|---|

No tool execution until the table is written.

## Station 2 — Evidence budget

For each fault, choose **one primary tool/evidence source first**. Only after recording the observation may you expand.

Purpose: avoid opening GDB + strace + ASan + printf + readelf simultaneously.

## Station 3 — Collect evidence

For every fault submit:

    Question
    Chosen tool/evidence
    Observed evidence
    Hypothesis eliminated
    Next action

Seeded modes:

    ./evidence_gate memory
    ./evidence_gate bytes
    ./evidence_gate fd
    ./evidence_gate file PATH

## Station 4 — Root cause

Tool labels are insufficient. Name the violated ownership, byte-order, FD-close/EOF, or file/error contract.

## Station 5 — Regression

At minimum:

- normal input;
- invalid input;
- repeated run;
- sanitizer-clean relevant repaired path;
- process cleanup / EOF / reap relevant repaired path.

## Station 6 — Postmortem

Answer:

> 如果只能保留三个 debugging habits 进入 Embedded Linux，你保留什么？为什么？

No fixed answer. Reviewer scores hypothesis quality, evidence selection, falsification, root-cause wording, and regression.

## Actual Verification Status

- strict build: **VERIFIED**;
- memory mode with ASan: **VERIFIED** heap-use-after-free;
- bytes semantic mismatch: **VERIFIED**;
- FD hang and `/proc` retained-writer evidence: **VERIFIED**;
- missing-file error path: **VERIFIED**;
- GDB execution: **UNVERIFIED**;
- strace execution: **UNVERIFIED**.

Overall: **PARTIALLY VERIFIED** for the complete Gate because required tool-choice paths include unavailable GDB/strace.

## Cleanup

Terminate seeded hanging process trees and verify no fixture child remains. Then `make clean`.
