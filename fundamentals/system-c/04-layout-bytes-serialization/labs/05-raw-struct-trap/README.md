# Lab — Raw-Struct Trap

## Objective

证明 raw object bytes 恰好相同也不等于 portable serialization。

## Prerequisites

M01 object/extent + M07 README corresponding mental model.

## Environment

C17; GCC 14.2.0 authoring baseline; Linux x86-64. Host layout/bytes are observations only.

## Estimated Time

**20 min**

## AI Mode

**AI-Free first pass.** Standards/docs allowed.

## Build

    make

## Procedure

make && ./raw_struct_trap; od -An -tx1 -v raw.bin; od -An -tx1 -v wire.bin

## Expected Observation

authoring host 上 raw.bin 与 wire.bin 12 bytes 恰好相同。

## Actual Verification Status

**VERIFIED — files + od executed; equality recorded as coincidence only.**

## Questions

1. 这份 evidence 证明什么？
2. 它不能证明什么？
3. object representation 与 external byte contract 在哪一步分叉？

## Failure Modes

把 host 数字当 universal；忽略 bounds/version；把“能跑”当 portability proof。

## Debug Strategy

审计 layout/padding/endian/version/ABI assumptions。

## Challenge

换一个有明显 padding 的 host struct 再比较。

## Cleanup

    make clean

## Sources

M07-S01/S05/S08; see ../../SOURCE_LEDGER.md.
