# P1-M05 Lab 02 — Pointer-to-Pointer Output Contract

## Objective

实现并验证 selected contract：`frame_create(..., struct frame **out)` success publishes owned object；failure leaves `*out == NULL`；destroy clears caller pointer。

## Prerequisites

Lab 01；allocation/error handling。

## Environment

Linux/WSL；GCC；GNU Make。

## Estimated Time

40–45 min。

## AI Mode

首次 contract table + failure reasoning AI-Free。

## Build

```sh
make clean && make
./frame_contract
```

## Procedure

写出 precondition/success/failure state，再运行 deterministic allocation failure。检查 implementation 是否在 local pointer 完成 initialization 后才 publish。

## Expected Observation

Success 后 caller owns non-null frame；destroy 后 caller pointer 为 NULL；injected allocation failure 返回 ENOMEM 且 output 仍 NULL。

## Actual Verification Status

Strict build + success/failure/double-destroy-safe contract: **VERIFIED**.

## Questions

1. 为什么 `T **` 本身不能说明 transfer？
2. partial init failure 为什么应先 cleanup local temporary，再 publish？
3. `frame_destroy(struct frame **)` 为什么是 selected design 而不是唯一正确 API？

## Failure Modes

failure 写入 dangling pointer；publish before full init；destroy double-free；无 precondition 导致覆盖 caller-owned object。

## Debug Strategy

追踪 `*out` 的每次 write，尤其是 failure path。

## Challenge

给第二次 allocation 也做 deterministic failure injection，证明 partial init cleanup 后 output state 仍 coherent。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`.
