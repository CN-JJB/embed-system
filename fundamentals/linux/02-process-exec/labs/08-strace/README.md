# Lab 08 — `strace -f`: Source API vs Observed Syscalls

## Objective

用 `strace -f` 观察 fork/exec/wait/exit lifecycle，并建立“libc source API 名称不一定等于 observed kernel syscall 名称”的 debugging transfer。

## Prerequisites

Labs 01–05。

## Environment

Linux/WSL；**strace required for learner execution**。

## Estimated Time

35–45 min。

## AI Mode

AI-Free prediction and evidence collection。

## Build

```sh
# binaries come from earlier labs
cd ../01-fork-values && make
strace -f -o fork.trace ./fork_values

cd ../03-exec && make
strace -f -o exec.trace ./exec_demo
```

## Procedure

从 trace 中找：

- creation event：可能呈现 `clone`/`clone3`/fork-equivalent，而不一定 literal `fork`；
- `execve`；
- wait-related syscall；
- child/parent exit。

把每个 observed syscall line 对应回 source-level concept，但不要要求 name 1:1。若 host trace 与教材预期不同，先记录 libc/kernel/architecture versions。

## Expected Observation

你应能给出一条 process lifecycle timeline，而不是 syscall encyclopedia。source `fork()` 不保证 trace literal `fork`; source `waitpid()` 也可能映射到不同 underlying wait syscall。

## Actual Verification Status

**UNVERIFIED** in authoring runtime because `strace` is not installed。Commands/source semantics are grounded in upstream docs；no transcript is fabricated。Learner/Leader WSL first execution must record actual syscall names before promoting status。

## Questions

1. 哪个 trace event 对应 process creation concept？
2. successful exec 在 trace 的哪个位置改变后续 program behavior？
3. 为什么不能从“没有 literal fork syscall”得出 source 没调用 fork？
4. musl `waitpid.c` source reading 如何帮助你接受 API/syscall boundary 不一一同名？

## Failure Modes

grep 只找 `fork` 然后宣布“trace 不对”；把 libc wrapper 与 kernel ABI 当同一层；复制别人的 trace 当本机 evidence。

## Debug Strategy

保留完整 `-f` trace，再按 PID/thread prefix 与 lifecycle concept筛选；先标版本。

## Challenge

在 Gate fixed supervisor 上运行 `strace -f`，验证两个 children 的 exec/wait/exit timeline；不要引入 pipe filters。

## Cleanup

```sh
rm -f ../01-fork-values/fork.trace ../03-exec/exec.trace
```

## Sources

strace upstream manual；`fork(2)`, `execve(2)`, `wait(2)`；musl `waitpid.c`。
