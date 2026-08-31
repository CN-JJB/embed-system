# P1-M05 Lab 01 — Ownership Contract Audit

## Objective

在运行前先给 `create / borrow / take / release` 画 owner/borrower/lifetime/cleanup table，再用最小 fixture 验证 transfer 会改变 caller ownership state。

## Prerequisites

M01 lifetime；M02 ownership vocabulary。

## Environment

Linux/WSL；GCC；GNU Make。

## Estimated Time

30–35 min。

## AI Mode

首次 table + prediction AI-Free。

## Build

```sh
make clean && make
./ownership_audit
```

## Procedure

不要先运行。逐个 API 写：谁拥有 object、谁只是 borrower、谁可 retain、cleanup point。然后运行并比较 table 与 output。

## Expected Observation

Borrow 不改变 owner；`take(&owner)` 的 selected contract 把 owner pointer 清 NULL 并把 release responsibility 交给返回值；最终只 release 一次。

## Actual Verification Status

Strict build + run: **VERIFIED**.

## Questions

1. `const struct box *` 为什么不自动等于 borrowed？
2. `box_take(struct box **)` 的 transfer 来自哪里：type 还是 contract？

## Failure Modes

把所有 pointer 都标 owned；borrower 调 `free`；transfer 后旧 owner 继续 cleanup。

## Debug Strategy

画 ownership table → 标 object lifetime events → 再看 pointer values。

## Challenge

增加 `replace` API，并写清 replacement 成功/失败时 old/new object ownership。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`.
