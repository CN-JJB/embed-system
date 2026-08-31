# P1-M05 Challenge — Small Synchronous Record Dispatcher

## Objective

实现 fixed-capacity synchronous dispatcher，训练 callback/context/record ownership contract，不扩展成 framework。

## Prerequisites

M05 Labs 01–05。

## Environment

Linux/WSL；GCC；GNU Make。

## Estimated Time

50–65 min。

## AI Mode

首次 implementation **AI-Free**；standards/upstream docs allowed。

## Contract

- capacity = 4 fixed slots；
- `dispatcher_add` keeps callback function pointer + **borrowed ctx pointer**；dispatcher never frees ctx；
- registration order is invocation order；
- `dispatcher_emit` borrows `record` for synchronous call only；callbacks must not retain pointer；
- first nonzero callback result stops and propagates；
- add/mutation while `dispatching` is forbidden and returns `EBUSY`；
- no threads, locks, list, dynamic allocation, async dispatch, event loop。

## Build

```sh
make clean && make
```

Starter compiles but returns `ENOSYS`. Implement `dispatcher_add()` and `dispatcher_emit()` without changing public contract.

## Expected Observation

With test fixture, first callback runs then second returns EIO; emit stops and propagates EIO. Context objects remain caller-owned.

## Actual Verification Status

- Starter strict build: **VERIFIED**.
- Reviewer reference strict build + order/error propagation path: **VERIFIED**.

## Questions

1. Dispatcher 为什么不 free ctx？
2. 哪一条 contract 禁止 record retention？
3. `dispatching` guard 解决的是哪类 hidden mutation semantics？

## Failure Modes

Global contexts；free ctx in dispatcher；continue after callback error；allow add during emit without declared snapshot semantics；store record pointer for later。

## Debug Strategy

registration table → dispatch order → ctx owner → record lifetime → error propagation。

## Challenge

增加 capacity-full test 和 callback 内尝试 `dispatcher_add()` 的 test，expected `EBUSY`。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`.
