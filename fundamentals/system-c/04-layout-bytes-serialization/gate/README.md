# Gate — Binary Record Boundary Audit

> **AI-Free**, docs allowed. Suggested **65–90 min**.

Seeded codec mixes raw object serialization, wrong endian, bounds-before-check, partial destination publication, and a packed-struct distraction.

## Station A — Wire contract

Fill Offset / Size / Meaning / Byte Order before tools.

## Station B — Hypotheses

Write 3–5 hypotheses; at least one must distinguish object layout from wire semantics.

## Station C — Bytes

Use at least one common byte-dump path:

    od -An -tx1 -v FILE

hexdump/xxd optional if installed.

## Station D — Host layout

Use `sizeof`, `_Alignof`, and `offsetof` to prove current object layout, then state why it is not protocol truth.

## Station E — Repair

Explicit get/put bytes; bounds/version before access; no packed/raw-cast shortcut.

## Station F — Golden regression

Zero + one non-palindromic vector.

## Station G — Invalid regression

Invalid version + short buffer + unchanged failure output state.

## Actual Verification

- seeded strict build/wrong-endian/raw-copy path: **VERIFIED**;
- short path ASan stack-buffer-overflow: **VERIFIED**;
- reviewer fixed golden/short/invalid/output-state regressions: **VERIFIED**.

Submit Question → Evidence → Eliminated hypothesis → Root cause → Fix → Regression.
