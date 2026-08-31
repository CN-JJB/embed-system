# P1-M04 Challenge — `run_one NAME=VALUE COMMAND [ARGS...]`

## Objective

实现一个最小 process launcher：

```text
run_one NAME=VALUE COMMAND [ARGS...]
```

必须：fork → child environment override → child exec → parent waitpid → correct status decode；禁止 `system()` / `popen()`。

## Prerequisites

M04 Labs 01–06。

## Environment

Linux/WSL；GCC；`fork/execvp/waitpid/setenv`。

## Estimated Time

55–70 min。

## AI Mode

首次实现 AI-Free；official man-pages allowed。

## Build

```sh
make clean && make
```

Starter intentionally returns TODO。Test helper `show_env` prints `RUN_ONE_TOKEN` and exits with numeric first argument。

## Procedure

Implement `run_one` contract:

```sh
./run_one RUN_ONE_TOKEN=green ./show_env 7
./run_one RUN_ONE_TOKEN=blue ./show_env 0
./run_one RUN_ONE_TOKEN=x ./missing-command
```

Requirements：

- parent environment need not be mutated；override in child before exec；
- child exec success never falls through；
- child exec failure reports diagnostic then `_exit(127)`；
- parent `waitpid(child, &status, 0)` and uses `WIFEXITED/WEXITSTATUS` or `WIFSIGNALED/WTERMSIG`；
- print a normalized result line including PID and termination category。

## Expected Observation

Reviewer solution **VERIFIED**: `RUN_ONE_TOKEN=green ./show_env 7` produces helper env evidence and parent reports exit code 7；missing target reports exec failure and parent sees reserved 127。

### Important boundary: “distinguish exec failure” at this module depth

Without an additional out-of-band protocol (commonly a dedicated pipe with close-on-exec discipline), a target program that legitimately exits **127** is observationally ambiguous with this challenge’s reserved exec-failure code. Pipes/`FD_CLOEXEC` protocol belongs to later modules and is **not** introduced here.

Therefore this challenge’s explicit contract is:

> **127 is reserved by `run_one` for exec failure; commands launched in this exercise must not use 127 as an application result if the caller needs an unambiguous distinction.**

Recognizing this limitation is part of the challenge; do not secretly solve it with pipe/`dup2`。

## Actual Verification Status

Starter build **VERIFIED**; reviewer solution strict-warning build + env override + normal exit 7 + legitimate 127 ambiguity demonstration + missing exec path **VERIFIED**。`strace` optional evidence remains **UNVERIFIED** on authoring host。

## Questions

1. parent 为什么不能直接调用 exec if it still needs to report status？
2. child exec failure 为什么 `_exit`？
3. raw wait `status` 为什么不能直接输出为 exit code？
4. 为什么本 challenge reserve 127 仍不等价于 general-purpose unambiguous launcher design？

## Failure Modes

`system()` shortcut；exec failure `return`；parent waits wrong PID；raw status；修改 parent environment instead of child launch contract；偷偷进入 pipe/dup2 scope。

## Debug Strategy

先打印 PID + branch；exec failure 看 errno；parent-side result只通过 wait macros解释。需要 syscall evidence再用 `strace -f`（authoring UNVERIFIED）。

## Challenge

让 helper `return 127`，证明你能解释为什么与 missing executable 在当前 protocol 下 ambiguous，而不是声称可区分。

## Cleanup

```sh
make clean
```

## Sources

`fork(2)`, `execve(2)`, `wait(2)`, `environ(7)`；chapter ledger。
