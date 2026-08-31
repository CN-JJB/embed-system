# P1-M05 Lab 03 — Callback + `void *ctx`

## Objective

同一 emitter 使用两个 behavior/context pair：stats 与 text observer；不使用 global state。

## Prerequisites

Function pointer syntax awareness；Lab 01–02。

## Environment

Linux/WSL；GCC；GNU Make。

## Estimated Time

35–40 min。

## AI Mode

首次 implementation/contract explanation AI-Free。

## Build

```sh
make clean && make
./callback_ctx
```

## Procedure

分别画 `record_sink_fn` function pointer lifetime 与两个 context object lifetime。确认 emitter 不知道 context concrete type，callback/caller 通过 contract 知道。

## Expected Observation

相同 records 被两个 callbacks 处理；stats context 聚合 count/sum，text context 写 observer lines；无 globals。

## Actual Verification Status

Strict build + both context paths: **VERIFIED**.

## Questions

1. cast 为什么不是 runtime type validation？
2. stack ctx 什么时候合法？
3. callback return 如何回到 emitter？

## Failure Modes

用 global 偷掉 ctx；callback 假设错误 concrete type；producer 释放 caller-owned ctx。

## Debug Strategy

把 behavior pointer 与 object pointer 分成两列追踪。

## Challenge

增加一个 callback 返回自定义 error，验证 emitter first-error propagation。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`.
