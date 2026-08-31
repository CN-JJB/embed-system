# Lab 05 — `waitpid`, Exit Status, and a Deterministic Zombie

## Objective

亲眼观察 child terminated → zombie → parent `waitpid` → zombie disappears，且不依赖 fixed sleep 碰运气。

## Prerequisites

Lab 01；知道 `/proc` 与 `ps`。

## Environment

Linux/WSL with `/proc`; GCC；`ps`。

## Estimated Time

45–55 min。

## AI Mode

AI-Free first run。

## Build

```sh
make clean && make
./zombie_lab
```
程序只有在内部已确认 child `/proc/<pid>/stat` state 为 `Z` 后才打印 checkpoint。

## Procedure

停在 checkpoint，在另一个 terminal：

```sh
ps -o pid,ppid,stat,cmd -p <child>
cat /proc/<child>/stat
```

确认 `STAT`/state contains `Z`。回 first terminal 按 Enter；程序调用 `waitpid` 并用 macros decode exit 42。再检查：

```sh
test ! -e /proc/<child> && echo reaped
```

## Expected Observation

checkpoint 前 child 已 terminated，`ps` 显示 zombie (`Z`)；它不再执行 user code。`waitpid` 后 parent 获取 exit 42 且 `/proc/<child>` entry disappears。

## Actual Verification Status

**VERIFIED.** Deterministic checkpoint actual `ps` showed `Z zombie_lab`; `/proc/<pid>/stat` state `Z`; after Enter output `reaped child=... exit=42` and `/proc` child entry was gone。No fixed sleep used to “hope” for zombie。

## Questions

1. zombie 为什么不是“卡住正在运行的 child”？
2. parent 为什么仍需要 wait if child 已经 exit？
3. raw `status` 与 exit 42 的关系是什么？
4. polling `/proc` 是 fixture synchronization，不是 production wait design——为什么？

## Failure Modes

用 sleep 当 synchronization guarantee；把 `Z` 当 runnable state；用 `status == 42` 判断。

## Debug Strategy

先用 `ps`/`/proc` independent proof child is Z；再看 source 是否在 checkpoint 前调用 wait。修复必须增加正确 wait/reap，而非隐藏 process from `ps`。

## Challenge

把 child exit 42 改 5；用 macros 验证。再写一行解释 signal-terminated case需要不同 macro，但不扩展 signals。

## Cleanup

```sh
make clean
```

## Sources

`wait(2)`; `/proc` status/stat selected observation；chapter ledger。
