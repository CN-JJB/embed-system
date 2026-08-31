
# P1-M06 Lab 07 — `strace -f` Lifecycle

## Objective

把 source-level pipe/fork/dup2/close/exec/read/write/wait/signal contract 与实际 syscall evidence 对齐；**不背 exact syscall spelling**。

## Prerequisites

Labs 04–06；会读最小 strace output。

## Environment

Linux/WSL；`strace` installed；M06 Lab 04/06 binaries。

## Estimated Time

30–40 min.

## AI Mode

首次 trace classification AI-Free；strace man page allowed。

## Build

```sh
make -C ../04-exec-pipeline clean all
make -C ../06-signal-stop clean all
```

## Procedure

Pipeline:

```sh
cd ../04-exec-pipeline
strace -f -o pipeline.trace ./pipeline
```

找 evidence category：

- pipe creation；
- process creation；
- descriptor duplication；
- closes；
- exec；
- reads/writes；
- waits。

Signal:

```sh
cd ../06-signal-stop
strace -f -o signal.trace ./signal_stop
# another shell: kill -TERM <pid>
```

找 signal delivery + interrupted/restarted interface + normal exit。

**不要要求 trace 必须出现 literal `fork` 或某个 fixed syscall name。** libc/kernel/arch 可以映射成不同 lower boundary。

## Expected Observation

Trace 应能支持 lifecycle ordering 与 failure hypothesis；它不是 source replacement。`dup2()` source-level call 与 observed lower syscall name 可能一致，也可能受 libc/arch 路径影响。

## Actual Verification Status

**UNVERIFIED** on authoring runtime: `strace` is not installed. No transcript is copied/fabricated. Learner/Leader environment must execute before promotion.

## Questions

1. 如果 trace shows clone-like process syscall，是否推翻 `fork()` source contract？
2. 哪些 close events 与 EOF hypothesis 直接相关？
3. signal handler source 合法性是否能仅靠“trace 没崩”证明？

## Failure Modes

复制网上 trace；把 PID/FD number freeze 成 expected literal；只按 syscall name 数量评分，不解释 relation。

## Debug Strategy

`source contract → expected event categories → trace evidence → discrepancy → narrower hypothesis`.

## Challenge

从 Lab 05 seeded hang 抓 trace；在不看 source fix 的情况下，用 trace + `/proc` 指出哪个 process 仍有 write endpoint。

## Cleanup

```sh
rm -f ../04-exec-pipeline/pipeline.trace ../06-signal-stop/signal.trace
```

## Sources

`strace(1)` / strace 7.2 release; `pipe(7)`, `dup(2)`, `sigaction(2)`; chapter ledger.
