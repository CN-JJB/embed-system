# P1-M06 Lab 03 — `dup2` Redirection

## Objective

用 byte flow 证明 descriptor number 1 在 child 中经 `dup2()` 改为引用 pipe write endpoint；然后关闭 original duplicated descriptor。

## Prerequisites

Lab 01–02；M02 FD model。

## Environment

Linux/WSL；GCC；GNU Make；`/proc` where noted。

## Estimated Time

30–35 min。

## AI Mode

首次预测、FD matrix、root-cause explanation **AI-Free**；evidence chain 完成后可 AI Review。

## Build

```sh
make clean && make
./dup2_demo
```

## Procedure

画 `p[1]` 与 FD 1 的 binding before/after。重点回答：成功 `dup2(p[1], 1)` 后 `p[1]` 是否自动消失？为什么随后仍要 `close(p[1])`？

可选 evidence window：在 `dup2` 后临时加一个 `getchar()` checkpoint，并从另一个 shell 看 `/proc/<child>/fd`；不要固定 FD number。

## Expected Observation

Child 对 FD 1 的 write 从 pipe 到达 parent。Original `p[1]` 必须显式 close；`dup2` 改的是 descriptor binding，不复制 byte stream resource。

## Actual Verification Status

Strict build + byte-flow run: **VERIFIED**. `/proc` optional checkpoint path: **UNVERIFIED** as a learner modification.

## Questions

1. `dup2` 为什么不能描述为“copy stdout”？
2. 若 `oldfd == newfd`，为什么手写 `close(newfd); dup(oldfd)` 不是可靠等价替代？

## Failure Modes

dup2 direction 写反；dup 后忘关 original；把 newfd 当新 resource owner 而忽略 shared underlying endpoint。

## Debug Strategy

画 descriptor-number arrows，不画“两个 pipe copies”。

## Challenge

把 child stderr 保持原样，证明 stdout redirection 不等于整个 process output 都被 pipe 捕获。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`.
