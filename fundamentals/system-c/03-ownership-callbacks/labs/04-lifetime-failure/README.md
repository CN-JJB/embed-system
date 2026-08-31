# P1-M05 Lab 04 — Lifetime Failure

## Objective

故意让 callback-like sink retain 一个 contract 上仅 borrowed 的 record pointer；owner release 后 later use becomes dangling。

## Prerequisites

M01 ASan/lifetime；Lab 03 callback contract。

## Environment

Linux/WSL；GCC；ASan when available。

## Estimated Time

30–35 min。

## AI Mode

首次 diagnosis AI-Free。

## Build

```sh
make clean && make san
./lifetime_failure_san
```

也可 normal build；normal execution “看起来能打印”不代表合法。

## Expected Observation

ASan-capable authoring/learner build may report heap-use-after-free at later dereference. Root cause 必须写 **callback retain contract violation → pointer outlives owned record lifetime**，不能只写 “free 后崩”。

## Actual Verification Status

Strict normal compile + ASan heap-use-after-free: **VERIFIED** on authoring runtime.

## Questions

1. 若 sanitizer 没报警，semantic contract 是否自动正确？
2. `const struct record *` 是否允许 retain？为什么答案来自 contract？

## Failure Modes

只修 crash site；删除 free 造成 leak 而不修 ownership；声称 sanitizer silence proves correctness。

## Debug Strategy

先画 owner/free event 与 retained pointer lifetime，再看 ASan supporting evidence。

## Challenge

把 sink 改成只在 synchronous call 中复制 `record->value`，不保存 pointer，证明 contract 可在无 dynamic copy 的情况下满足。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`.
