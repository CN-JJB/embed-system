# Lab 02 — Process State, `/proc`, and Inherited FD

## Objective

在明确 checkpoint 观察 child PID/PPID/process state、cmdline 与 fork-inherited FD entry，把 M02 FD mental model 扩展到 multiple processes。

## Prerequisites

M02 FD ownership；M04 Lab 01。

## Environment

Linux/WSL with `/proc`; GCC；`ps`。

## Estimated Time

45–60 min。

## AI Mode

AI-Free evidence collection。

## Build

```sh
make clean && make
./proc_state
```
保持 child checkpoint 不按 Enter，在第二个 terminal 操作。

## Procedure

从 program output 取得 child PID：

```sh
ps -o pid,ppid,stat,cmd -p <child>
grep -E '^(Name|State|Pid|PPid):' /proc/<child>/status
ls -l /proc/<child>/fd
tr '\0' ' ' < /proc/<child>/cmdline; echo
```

特别记录 `inherited_fd` number 对应的 symlink target。再回 first terminal 按 Enter，让 child close/exit，parent wait。

## Expected Observation

child `/proc/<pid>/fd` 应包含 0/1/2 加 parent 在 fork 前 open 的 file descriptor（actual number runtime-dependent）；cmdline 指向当前 program；PPID matches parent while parent alive。

## Actual Verification Status

**VERIFIED.** Authoring inspection window 中 child state `S`, FD entries `0,1,2,3`; FD 3 symlink 指向本 lab `inherited.log`; `/proc/<child>/cmdline` 为 `./proc_state`; parent then waits and exits cleanly。Exact FD/PID values非 golden。

## Questions

1. inherited FD 是“同一个 integer value”还是“same conceptual ownership contract”？
2. child 为什么能在 fork 后使用 parent pre-opened FD？
3. `/proc/<pid>/fd` 证明了什么，没证明什么？
4. 如果 parent/child 都有 entry，是否意味着两者都必须在你的 API contract 中负责最终 cleanup？

## Failure Modes

把 `/proc` 当 portable Unix API；把 inherited FD 与 automatic ownership transfer 混同；按 Enter 后才试图观察已退出 child。

## Debug Strategy

先用 output PID 定位 process，再看 `/proc/status`/`fd`；不要猜 FD number。若没有 `/proc`，本 lab 不可直接等价替代，标环境限制。

## Challenge

在 parent 再 open 第二个 file，预测 child `/proc/<pid>/fd` entries；不研究 shared offset。

## Cleanup

```sh
make clean
rm -f inherited.log
```

## Sources

`proc_pid_status(5)`, `proc_pid_fd(5)`, `proc_pid_cmdline(5)`, `fork(2)`。
