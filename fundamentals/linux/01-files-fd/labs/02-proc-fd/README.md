# Lab 02 — Observe `/proc/<pid>/fd`

## Objective

预测并观察 process FD entries 在 `open()` / `close()` 前后的变化，建立 “FD table is per-process observable state” 的模型。

## Prerequisites

M02 FD mental model；会用 `ls -l`。

## Environment

Linux/WSL with `/proc`；GCC；GNU Make；两个 terminals 最方便。

## Estimated Time

25–35 min。

## AI Mode

Prediction 和第一次解释 **AI-Free**。

## Build

```sh
make clean && make
printf a > a.txt
printf b > b.txt
```

## Procedure

Terminal A：

```sh
./fd_hold a.txt b.txt
```

在按 Enter 前，先写下你预测会看到哪些 FD numbers。Terminal B：

```sh
ls -l /proc/<printed-pid>/fd
```

回到 A 按 Enter，让程序 close；再次在 B 执行同一 `ls -l`。最后回 A 按 Enter 退出。

## Expected Observation

通常能看到 0/1/2 与新 opened FDs；close 后新 entries 消失。具体 FD number 不应硬编码成“必然 3/4”，因为 process 可能已有其他 descriptors。

## Actual Verification Status

**VERIFIED** on Linux 6.18.35：authoring run 在 open phase 观察到新增 FD symlinks，close phase 后对应 entries 消失。

## Questions

1. `/proc/<pid>/fd/3 -> /path/file` 能证明什么？不能证明什么？
2. 为什么 FD number 不等于 filesystem inode 或 pathname？
3. 为什么本 lab 不应该推出“`/proc/<pid>/fd` 展示整个 kernel open-file graph”？

## Failure Modes

- 程序太快退出，来不及观察；
- 把 symlink target 当成 FD 自身；
- 假设 0/1/2 永远都指 terminal；它们也可能被 shell/environment 重定向。

## Debug Strategy

确认 PID 是目标进程而不是 shell；先 `ls /proc/<pid>` 确认进程仍在。若 entries 与预测不同，先记录额外 FD，再追查是谁打开的，不要强行套 3/4。

## Challenge

让 stdout 先被 shell 重定向再启动：`./fd_hold a.txt b.txt > log.txt`。观察 FD 1 symlink target 有何变化；不要引入 `dup2` 教学。

## Cleanup

```sh
make clean
```

## Sources

`proc_pid_fd(5)`；chapter `SOURCE_LEDGER.md`。
