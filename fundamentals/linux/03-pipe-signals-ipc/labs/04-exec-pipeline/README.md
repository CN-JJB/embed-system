# P1-M06 Lab 04 — Two-Process Exec Pipeline

## Objective

自己实现 `producer stdout → pipe → consumer stdin`：2 children、`dup2`、完整 close discipline、exec failure `_exit`、parent reap both。

## Prerequisites

M04 fork/exec/waitpid；M06 Labs 01–03。

## Environment

Linux/WSL；GCC；GNU Make；`/proc` where noted。

## Estimated Time

45–55 min。

## AI Mode

首次预测、FD matrix、root-cause explanation **AI-Free**；evidence chain 完成后可 AI Review。

## Build

```sh
make clean && make
./pipeline
```

## Procedure

先画 fork 后 FD matrix，再分别写 **consumer child**, **producer child**, **parent** 最终需要保留/关闭什么。读 `pipeline.c` 时检查：

1. consumer fork failure；
2. producer fork failure after consumer already exists；
3. child `dup2` 后 original descriptors；
4. parent copies；
5. every child reap。

然后运行。

## Expected Observation

`producer` bytes 经 pipe 进入 `consumer`；parent 关闭自己的 copies 后，consumer 能得到 EOF；parent decode/reap both child statuses。Partial second-fork failure path 也不会遗留 consumer zombie。

## Actual Verification Status

Strict build + happy-path run: **VERIFIED**. Fault-injected actual `fork()` failure: **UNVERIFIED** (code-reviewed only; no artificial fork failure shim).

## Questions

1. 为什么 consumer 先 fork 让第二次 fork failure cleanup 更简单？
2. child exec failure 为什么 `_exit(127)`？
3. 为什么 parent 应关 read **和** write copies？

## Failure Modes

用 shell `|` 代替 implementation；忘 original fds；只 wait one child；child exec failure return。

## Debug Strategy

matrix → `dup2` arrows → close calls → exec → wait list。

## Challenge

把 producer executable 临时改成 missing path，证明 parent 仍 reap consumer 且 producer status 按 reserved 127 表示；再恢复。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`.
