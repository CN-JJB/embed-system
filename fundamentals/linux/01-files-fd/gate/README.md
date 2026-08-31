# P1-M02 Gate — `log_copy` Resource Boundary Audit

> **AI-Free. Official Linux man pages / strace documentation allowed.** Do not open reviewer solution before submission.

## Objective

修复一个新的 `log_copy` 小程序中的 **resource leak、error-path ownership bug、short-write bug**，并用 `/proc` + strace + regression 证明，而不是只让 output “看起来能跑”。

## Environment / Time

Linux/WSL, GCC, Make, `/proc`, **strace required for learner Gate**。目标 60–75 min。`/dev/full` 用作 Linux write-failure injection。

## Build

```sh
make clean && make
printf 'abcdefghijklmnopqrstuvwxyz0123456789\n' > input.bin
```

## Procedure

### Station A — short write

```sh
LOG_COPY_WRITE_CAP=5 ./log_copy input.bin out.bin
wc -c input.bin out.bin
cmp input.bin out.bin
```

Environment variable 只是 deterministic test injection：它让内部 write wrapper 最多请求 5 bytes。**不要通过删除 injection 来“修复” Gate。**

### Station B — error-path ownership

```sh
./log_copy input.bin /dev/full
```

记录 write failure 与 cleanup symptom。用：

```sh
strace -e trace=%desc,%file ./log_copy input.bin /dev/full
```

证明是哪个 FD 被谁关闭、是否出现重复 close，以及原始 write error 是否被保留。

### Station C — leak

```sh
./log_copy --leak-demo input.bin /definitely/missing/parent/out.bin
```

程序暂停时在另一个 terminal：

```sh
ls -l /proc/<pid>/fd
```

再用 strace 对同一 failure path 确认 open/close sequence。修复后重复 Station C，除 inherited 0/1/2 与环境自身 descriptors 外，不应看到每次失败累计的 input FD。

## Required Submission

对三个 faults 分别写：

```text
Symptom
Hypotheses
Evidence
Root Cause
Fix
Regression
```

必须包含：

- `/proc/<pid>/fd` before/after evidence for leak；
- strace evidence for error-path open/write/close sequence；
- byte-count + `cmp` regression under `LOG_COPY_WRITE_CAP=1,5,32`；
- ownership contract：`copy_payload` 的 parameters 是 owned 还是 borrowed，谁最终 close。

## Pass Criteria

- short write loop 根据 returned count 写 remaining bytes；
- failed output-open 不泄漏已 owned input FD；
- borrowed FD 不在 helper error path 被 close；
- original error 能跨 cleanup 被正确传播；
- success + failure regressions 都通过。

只展示正常 output 不通过。

## Expected Observation

Seeded program 的三个 station 都应暴露不同 resource/data-boundary symptom。具体 patch 不在 learner-facing 文件给出。

## Actual Verification Status

**PARTIALLY VERIFIED** on Linux 6.18.35 / GCC 14.2.0：short-write truncation、`/dev/full` error/double-close symptom、`/proc` leak accumulation、fixed reviewer regression 已实际执行。**strace Gate evidence UNVERIFIED** because strace is not installed in the authoring runtime；没有伪造 trace output。

## Failure Modes / Debug Strategy

不要把三个 symptoms 全归因于“close 有问题”。先根据 return value/errno 区分 data completion、ownership、resource lifetime。`/proc` 证明 process-level descriptor accumulation；strace 证明 syscall sequence；source contract 解释 root cause。

## Cleanup / Sources

```sh
make clean
```

Sources: `open(2)`, `write(2)`, `close(2)`, `errno(3)`, `proc_pid_fd(5)`, `strace(1)`；chapter `SOURCE_LEDGER.md`。
