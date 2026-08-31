# P1-M05 Lab 05 — Integration / Contract Boundary

## Objective

连接：owned input object → processor → stack-local borrowed record → synchronous callback → caller-owned stats ctx。

## Prerequisites

Labs 01–04。

## Environment

Linux/WSL；GCC；GNU Make。

## Estimated Time

35–40 min。

## AI Mode

首次 ownership table / implementation AI-Free。

## Build

```sh
make clean && make
./integration_contract
```

## Procedure

在运行前给 input、record、ctx 三类 object 分别写 owner/lifetime/retain policy。尤其指出每轮 local `record` 的 lifetime 只覆盖当前 loop iteration/callback call。

## Expected Observation

Owned input remains valid across processing then is explicitly destroyed；callback receives borrowed records and updates caller-owned stats；无 global state。

## Actual Verification Status

Strict build + run: **VERIFIED**.

## Questions

1. callback 为什么不能保留 `&r`？
2. stats ctx 为什么可以是 stack object？
3. input 与 record 的 owner/lifetime 为什么不同？

## Failure Modes

callback frees input；callback retains record；processor frees caller ctx；把 local record address 存在 global。

## Debug Strategy

三个 object 三条 lifetime timeline，不要只画 pointer arrows。

## Challenge

增加第二个 observer context，仍保持 input/record ownership contract 不变。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`.
