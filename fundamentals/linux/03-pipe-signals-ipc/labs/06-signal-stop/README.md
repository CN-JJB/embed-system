# P1-M06 Lab 06 — `sigaction` Stop Flag

## Objective

安装 SIGINT/SIGTERM handler；handler 只写 `volatile sig_atomic_t` stop request；normal control flow 完成 cleanup/report。

## Prerequisites

M04 process basics；M06 signal mental model。

## Environment

Linux/WSL；GCC；GNU Make；`/proc` where noted。

## Estimated Time

35–40 min。

## AI Mode

首次预测、FD matrix、root-cause explanation **AI-Free**；evidence chain 完成后可 AI Review。

## Build

```sh
make clean && make
./signal_stop
```

## Procedure

启动后从另一 shell：

```sh
kill -TERM <pid>
```

对照 source：handler 没有 stdio/malloc/free/callback dispatch；`pause()` 被 signal 唤醒后 control flow 回到 loop，看到 flag，再在 normal context 打印 cleanup result。

## Expected Observation

收到 SIGTERM 后进程从 normal control flow 输出 cleanup message 并退出。不要伪造 handler 与 stdio 输出的精确 scheduling order。

## Actual Verification Status

Strict build + external SIGTERM + normal-context cleanup: **VERIFIED**.

## Questions

1. 为什么 `printf` 放在 handler 外面？
2. `pause()` 返回 EINTR 与 stop flag 如何一起解释？
3. `volatile sig_atomic_t` 为什么不能拿去当 M09 thread synchronization？

## Failure Modes

handler 里 close entire application state；handler 里 callback dispatch；误写 `SA_RESTART` 后声称所有 calls 一定 restart。

## Debug Strategy

handler 只记录 intent；所有 resource ownership 决策回 normal flow。

## Challenge

把 `sa_flags` 设 `SA_RESTART` 再观察你选择的接口实际 behavior；只根据 return/errno 下结论，不背“restart everything”。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`.
