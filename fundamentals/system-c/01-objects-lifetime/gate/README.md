# P1-M01 Gate — Frame Boundary Audit

> **AI-Free. Official C/GCC/GDB documentation allowed.** Do not open `../reviewer/M01_GATE_SOLUTION.md` before submission.

## Objective

在一个新的 frame-view 程序中区分 **真正 bug** 与 **看起来危险但合法** 的 pointer line，并用 evidence 完成修复与 regression。不是 Phase 0 telemetry 题目的复刻。

## Environment / Time

Linux/WSL, GCC, Make；ASan/UBSan required；GDB if available。目标 60–75 min。

## Build

```sh
make clean && make
```

## Procedure

程序提供四个 case：

```sh
./frame-gate extent
./frame-gate lifetime
./frame-gate ub
./frame-gate legal
```

你必须先为每个 case 写 hypothesis，再使用 normal run、sanitizer、source reasoning；GDB 可用时加入至少一次 `break/run/bt/frame/info locals/print/x` 证据链。

程序包含：

- one extent contract bug；
- one lifetime bug；
- at least one integer UB；
- one misleading-but-legal pointer operation。

不要根据 case 名直接写答案；解释**哪一个 object/extent/lifetime/rule**被违反。

## Required Submission

对每个真正 fault 都提交：

```text
Symptom
Hypotheses
Evidence
Root Cause
Fix
Regression
```

另外单独回答：legal case 中哪一个 pointer operation 合法？它的使用边界是什么？

Regression 至少包括：normal tests、sanitizer rerun，以及一个 boundary test（zero length 或 exact-end extent）。

## Pass Criteria

- 区分 allocation/object extent 与 caller-declared logical extent；
- 能指出 lifetime 何时结束，而不是只说“pointer 坏了”；
- 能用 C semantics 解释 UB；
- 不把 one-past pointer 的“形成”误判为 dereference bug；
- evidence 支持 root cause，不能只贴 sanitizer headline。

## Expected Observation

Gate 中 faults 应能产生可诊断 symptom；legal case 应正常完成。具体 fault locations 与 patch 不在 learner-facing README 中透露。

## Actual Verification Status

**PARTIALLY VERIFIED** on GCC 14.2.0：normal/sanitized binaries、extent/lifetime/UB/legal cases 与 fixed reviewer regression 已执行。GDB path **UNVERIFIED**（authoring environment 未安装 GDB）。

## Failure Modes / Debug Strategy

如果 sanitizer 给出 source location，先把它当 evidence，不要直接把该行删掉。回到 caller/callee contract，画出 object bytes 与 extent。若 GDB 可用，`x` 观察 bytes、`print` 比较 length、`bt/frame` 确定是谁制造了错误状态。

## Cleanup / Sources

```sh
make clean
```

Sources: chapter `SOURCE_LEDGER.md`。Reviewer hints/solution 与 fixed code 位于 `../reviewer/`。
