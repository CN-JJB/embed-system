# Lab 01 — `fork` Return Values and Scheduling

## Objective

实际观察 parent/child 的 PID/PPID 与 `fork()` return values；区分 API invariants 与 print scheduling order。

## Prerequisites

M02/M03；basic process vocabulary。

## Environment

Linux/WSL；GCC；`waitpid` available。

## Estimated Time

35–45 min。

## AI Mode

AI-Free first prediction/run；`fork(2)`/`wait(2)` docs allowed。

## Build

```sh
make clean && make
./fork_values
```

## Procedure

运行前先写预测表：

```text
line/event                 fixed fact?        order guaranteed?
before fork                one pre-fork line ...
parent return              child PID         ...
child return               0                 ...
parent wait result          exit 7            ...
```

运行 5 次。不加 `sleep`。记录 parent/child lines 哪些可能交换顺序。

## Expected Observation

parent receives positive child PID；child receives 0；PID distinct。parent/child output order may vary because scheduling is not specified by your print statements；`waitpid` ensures parent observes child termination before reporting status, not that earlier prints happen in a fixed order。

## Actual Verification Status

**VERIFIED** on Linux 6.18.35 x86_64。Example run: parent PID 1000, child 1001；child `fork_return=0`; parent `fork_return=1001`; parent decoded `child exit=7`。PID values/order are not golden output。

## Questions

1. 哪些 facts 不因 scheduling 改变？
2. 为什么 `sleep(1)` 不是正确的 ordering proof？
3. child `_exit(7)` 后 raw wait status 为什么不能直接打印为 7？

## Failure Modes

假设 parent line 总在 child line 前；用 sleeps 固定顺序；child/parent 都继续走同一 branch。

## Debug Strategy

先检查 `fork()` return value branch，再看 `waitpid` target/status macros。不要调 scheduler。

## Challenge

把 child exit code 改为 23，预测 parent output；再让 child normal `return 23` 对比（只观察，不扩展 stdio buffering 专题）。

## Cleanup

```sh
make clean
```

## Sources

`fork(2)`, `wait(2)` man-pages 6.18；chapter ledger。
