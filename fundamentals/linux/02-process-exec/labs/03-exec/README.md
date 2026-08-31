# Lab 03 — `exec`: Same PID, New Program Image

## Objective

用自己编译的 `child_image` 证明 successful exec 前后 child PID 不变，而 program image / argv / environment 改变。

## Prerequisites

Labs 01–02；M03 executable artifact mental model。

## Environment

Linux/WSL；GCC。

## Estimated Time

40–50 min。

## AI Mode

AI-Free prediction/first run。

## Build

```sh
make clean && make
./exec_demo
```

## Procedure

`exec_demo` fork 一个 child。child 在 exec 前打印 PID，然后：

```c
execve("./child_image", argv, envp);
```

`child_image` 打印 PID/PPID、`argc/argv` 与 `M04_TOKEN`。记录 before/after PID；标出 output 哪一行来自旧 image、哪一行来自新 image。

## Expected Observation

before exec child PID 与 child_image PID 相同；`argv` 变为 explicitly supplied vector；environment 由 passed `envp` 控制；parent 最终用 waitpid 看到 child_image exit 23。

## Actual Verification Status

**VERIFIED.** One authoring run child PID 1003 before/after exec 相同；`argv = child_image, alpha, beta`; token `from-explicit-envp`; parent decoded exit 23。

## Questions

1. 哪条 evidence 反驳“exec creates another process”？
2. old program code 在 successful exec 后为什么没有打印“returned from exec”？
3. argv/env 是由谁给 new program image 的？

## Failure Modes

把 fork 和 exec 当同一个 API action；认为 exec 成功后会返回 0；只根据 program name 判断是否是 same process。

## Debug Strategy

在 `execve` 后留的 code 只应该属于 failure path。若它执行，第一 hypothesis 应是 exec failed；先看 `errno/perror`。

## Challenge

把 `argv[0]` 改成另一个字符串，观察 `/proc/cmdline`/program output 的变化，但不要把 argv0 当 executable identity guarantee。

## Cleanup

```sh
make clean
```

## Sources

`execve(2)`, `wait(2)`, `environ(7)`。
