# P1-M05 Gate — Ownership Boundary Audit

> **AI-Free.** Standards, GCC/sanitizer docs, upstream source, and debugger docs are allowed. Do not open `../reviewer/` first.

## Objective

Diagnose four independent ownership/lifetime faults in an unfamiliar small C API. Passing means you can state the contract and prove the root cause, not merely make ASan quiet.

## Estimated Time

60–90 min。

## Build

```sh
make clean && make san
```

## Station A — ownership/lifetime table

Before running, list every object/pointer/context in each mode: owner, borrower, may-retain?, valid lifetime, cleanup point, failure output state。

## Station B — hypotheses

For each symptom write at least 3 hypotheses before opening sanitizer output。

## Station C — run seeded modes

```sh
./ownership_gate_san owned
./ownership_gate_san output
./ownership_gate_san ctx
./ownership_gate_san retain
```

The final `retain` case may have no memory-safety report; evaluate its stated synchronous callback contract semantically。

## Station D — contracts to identify

- borrowed record must not be freed by callee；
- `frame_create` failure must leave `*out == NULL`；
- callback ctx must outlive invocation；
- callback must not retain borrowed `record *` beyond call。

## Station E — minimal fix + regression

Fix each fault without redesigning API into framework. Regression must test success and failure output states, repeated cleanup, valid ctx lifetime, and no retained record pointer。

## Actual Verification Status

- seeded strict/sanitized build: **VERIFIED**;
- seeded owned UAF: **VERIFIED** with ASan;
- seeded output dangling failure state: **VERIFIED** with ASan when dereferenced;
- seeded dangling ctx: **VERIFIED** with ASan;
- seeded retain case completes without sanitizer requirement while violating semantic contract: **VERIFIED**;
- reviewer fixed strict build + all four regression modes: **VERIFIED**.

## Questions

1. 哪个 fault sanitizer silence 不能排除？
2. `T **` 在 output fault 中提供了什么 capability，但没提供什么 semantics？
3. 为什么把 ctx 改成 global 不是理想修复？
4. 为什么 F1 root cause 不是“free 崩了”？

## Debug Strategy

Symptom → own description → hypotheses → ownership table → ASan/return-value evidence → root contract → fix → regression。

## Cleanup

```sh
make clean
```

## Sources

Chapter ledger.
