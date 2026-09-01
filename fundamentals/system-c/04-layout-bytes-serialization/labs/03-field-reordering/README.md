# Lab — Field Reordering

## Objective

观察 member order 改变 offsets/size，同时避免过早 micro-optimization。

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

make && ./field_reorder

## Expected Observation

当前 host semantic_one=12, semantic_two=8。

## Actual Verification Status

**VERIFIED — strict build/runtime executed.**

## Questions

1. 这份 evidence 证明什么？
2. 它不能证明什么？
3. object representation 与 external byte contract 在哪一步分叉？

## Failure Modes

把 host 数字当 universal；忽略 bounds/version；把“能跑”当 portability proof。

## Debug Strategy

必须解释这是 implementation/ABI storage concern，不只是“省 4 bytes”。

## Challenge

设计一个可读性优先版本并说明选择。

## Cleanup

    make clean

## Sources

M07-S03/S05/S08; see ../../SOURCE_LEDGER.md.
