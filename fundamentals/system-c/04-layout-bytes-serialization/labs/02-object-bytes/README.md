# Lab — Object Bytes

## Objective

合法观察 object representation，并把 host observation 与 wire contract 分开。

## Prerequisites

M01 object/extent + M07 README corresponding mental model.

## Environment

C17; GCC 14.2.0 authoring baseline; Linux x86-64. Host layout/bytes are observations only.

## Estimated Time

**15 min**

## AI Mode

**AI-Free first pass.** Standards/docs allowed.

## Build

    make

## Procedure

make && ./object_bytes

## Expected Observation

authoring host 对 0x11223344 观察为 44 33 22 11；host-specific。

## Actual Verification Status

**VERIFIED — strict build/runtime executed.**

## Questions

1. 这份 evidence 证明什么？
2. 它不能证明什么？
3. object representation 与 external byte contract 在哪一步分叉？

## Failure Modes

把 host 数字当 universal；忽略 bounds/version；把“能跑”当 portability proof。

## Debug Strategy

只用 character-byte observation；不要 pointer-pun 做 endian trick。

## Challenge

换 uint16_t/uint64_t non-palindromic value。

## Cleanup

    make clean

## Sources

M07-S01/S04/S07; see ../../SOURCE_LEDGER.md.
