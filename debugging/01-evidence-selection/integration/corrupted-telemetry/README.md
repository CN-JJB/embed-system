# M07 ↔ M08 Integration — Corrupted Telemetry Record Investigation

## Objective

Keep the program and 12-byte telemetry contract constant while changing the fault domain. The learner must predict the **first evidence source** before running a mode.

Pipeline:

    known bytes
    ↓
    decoder
    ↓
    record
    ↓
    validation / later state
    ↓
    output

## Prerequisites

M07 explicit codec + golden bytes; M08 evidence taxonomy.

## Environment

C17 / GCC 14.2.0. ASan available. GDB absent in authoring runtime.

## Estimated Time

**25–30 min**, counted inside M08 5 h.

## AI Mode

**AI-Free first pass.**

## Build

    make
    make asan

## Prediction table

| Mode | Primary evidence |
|---|---|
| `good` | golden bytes + expected decoded fields |
| `short` | input length/bounds; ASan for seeded invalid access |
| `wrong-endian` | golden byte sequence + decode arithmetic |
| `memory-fault` | ASan |
| `state-change` | GDB watchpoint |

## Procedure

Run one mode at a time. Before each run write:

    symptom class
    first hypothesis
    first evidence source
    expected observation that would falsify it

Then collect only that evidence.

## Expected Observation

- good decodes flags/value/sequence correctly;
- short performs an invalid read in the seeded fault;
- wrong-endian yields a deterministic wrong value;
- memory-fault dereferences freed storage;
- state-change zeroes sequence after valid decode.

## Actual Verification Status

- `good`: **VERIFIED**;
- `wrong-endian`: **VERIFIED** (`0x78563412` vs contract `0x12345678`);
- `short` under ASan: **VERIFIED** heap-buffer-overflow;
- `memory-fault` under ASan: **VERIFIED** heap-use-after-free;
- `state-change` symptom: **VERIFIED**;
- GDB watchpoint execution for state-change: **UNVERIFIED**.

Overall: **PARTIALLY VERIFIED** because the GDB path cannot be executed here.

## Questions

1. Why would sanitizer silence on wrong-endian be expected?
2. Why is the same byte dump useful for wrong-endian but insufficient for state overwrite?
3. What changes if `short` is repaired to reject length before decoding?

## Failure Modes

Starting every mode under GDB; treating ASan as protocol validator; changing the golden vector to match buggy code.

## Debug Strategy

Use the mode table only as a first-tool hypothesis. If evidence falsifies it, document why and change tool.

## Challenge

Repair all four seeded faults without adding threads, sockets, variable-length protocols, or M10 service machinery.

## Cleanup

    make clean

## Sources

M07 SOURCE_LEDGER + M08-S02/S04.
