# Lab — Layout Audit

## Objective

预测并验证 struct offsets/alignment/padding，而不是背固定 layout。

## Prerequisites

M01 object/extent + M07 README corresponding mental model.

## Environment

C17; GCC 14.2.0 authoring baseline; Linux x86-64. Host layout/bytes are observations only.

## Estimated Time

**15–20 min**

## AI Mode

**AI-Free first pass.** Standards/docs allowed.

## Build

    make

## Procedure

make && ./layout_audit

## Expected Observation

当前 x86-64 authoring host: sample_a 12 bytes; reordered variants 8 bytes. 这些数字不是 universal golden。

## Actual Verification Status

**VERIFIED — strict build/runtime executed.**

## Questions

1. 这份 evidence 证明什么？
2. 它不能证明什么？
3. object representation 与 external byte contract 在哪一步分叉？

## Failure Modes

把 host 数字当 universal；忽略 bounds/version；把“能跑”当 portability proof。

## Debug Strategy

若预测错，分别标出 member size / offset / internal padding / tail padding；不要先优化。

## Challenge

加入 uint64_t 的第四个 struct，先预测再测。

## Cleanup

    make clean

## Sources

M07-S02/S03/S05/S06; see ../../SOURCE_LEDGER.md.
