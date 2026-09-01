# Lab — Explicit Encoder / Decoder

## Objective

把 declared offsets + LE byte order 实现为固定 12-byte codec。

## Prerequisites

M01 object/extent + M07 README corresponding mental model.

## Environment

C17; GCC 14.2.0 authoring baseline; Linux x86-64. Host layout/bytes are observations only.

## Estimated Time

**25–30 min**

## AI Mode

**AI-Free first pass.** Standards/docs allowed.

## Build

    make

## Procedure

make && ./codec

## Expected Observation

non-palindromic deterministic golden vector + round trip pass。

## Actual Verification Status

**VERIFIED — strict build/runtime + golden regression executed.**

## Questions

1. 这份 evidence 证明什么？
2. 它不能证明什么？
3. object representation 与 external byte contract 在哪一步分叉？

## Failure Modes

把 host 数字当 universal；忽略 bounds/version；把“能跑”当 portability proof。

## Debug Strategy

先验证 length/version，再读写；失败不发布 partial output。

## Challenge

增加 invalid-version + short-output sentinel tests。

## Cleanup

    make clean

## Sources

M07-S07/S11; see ../../SOURCE_LEDGER.md.
