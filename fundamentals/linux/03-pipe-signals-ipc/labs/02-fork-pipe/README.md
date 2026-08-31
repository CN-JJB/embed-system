# P1-M06 Lab 02 — Pipe Across `fork`

## Objective

观察 fork 后 parent/child 都继承两个 pipe descriptors，并通过 close matrix 缩成 parent-writer / child-reader。

## Prerequisites

M04 fork/waitpid；Lab 01。

## Environment

Linux/WSL；GCC；GNU Make；`/proc` where noted。

## Estimated Time

30–35 min。

## AI Mode

首次预测、FD matrix、root-cause explanation **AI-Free**；evidence chain 完成后可 AI Review。

## Build

```sh
make clean && make
./fork_pipe
```

## Procedure

运行前填：

| Process | read end | write end |
|---|---|---|
| parent after fork | ? | ? |
| child after fork | ? | ? |
| desired parent | close | keep until done |
| desired child | keep until EOF | close |

再读 close calls，运行并解释 child 为什么能最终读到 EOF。

## Expected Observation

Child 输出 parent 写入的 bytes 并正常 exit；parent 关闭 write end 后，child read loop 能结束并被 waitpid reap。

## Actual Verification Status

Strict build + run: **VERIFIED**.

## Questions

1. fork 前创建 pipe 与 fork 后分别创建的资源图有什么不同？
2. parent 不读为何仍必须 close read end？

## Failure Modes

只关“我会用的相反端”其中一边；忘 wait child；用 exit 替代 `_exit` 去讨论未 flush stdio。

## Debug Strategy

先画 fork 后四个 FD entries，再逐个划掉 close。

## Challenge

临时注释 parent 的 `close(p[1])`，预测 child 的 read loop 行为；不要永久保留该改动。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`.
