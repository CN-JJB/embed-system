# Lab 04 — Exec Failure and Child Failure Paths

## Objective

制造 missing executable / permission denied，并解释 successful exec 不返回、failure 才返回；理解 fork 后 child exec failure path 为什么通常应 `_exit(...)`。

## Prerequisites

Lab 03。

## Environment

Linux/WSL；GCC。

## Estimated Time

40–50 min。

## AI Mode

AI-Free。

## Build

```sh
make clean && make
./exec_failure ./does-not-exist
./exec_failure ./not_executable.sh
./exec_failure ./does-not-exist --bad-return
```

## Procedure

比较 normal failure branch 与 deliberate `--bad-return`：helper 在 `execv` failure 后 `return 127`，caller 随后继续执行 `BUG: child continued...`。正确 branch 在 `perror` 后 `_exit(127)`。

## Expected Observation

不存在路径 → `ENOENT` / “No such file or directory”；存在但 non-executable file → `EACCES` / “Permission denied”；两者的 exec 都失败并返回。`--bad-return` 显式展示 child 跌回 caller control flow。

## Actual Verification Status

**VERIFIED.** GCC 14.2 build；missing path 与 permission denied 均观察到；bad-return mode 实际打印 `BUG: child continued in caller after exec failure...`。Parent 用 wait macros 观察 reserved 127。

## Questions

1. 为什么 successful exec 之后不会走到 `perror`？
2. `_exit` 在这里解决的核心 control-flow 问题是什么？
3. 为什么不把 stdio-buffer duplication 扩成此 lab 主专题？
4. 127 能否在没有额外 protocol 时与“target program legit returned 127”绝对区分？

## Failure Modes

把 exec return -1 与 child exit status 混同；child failure `return` 后继续 caller logic；假设 127 天然 globally reserved/无歧义。

## Debug Strategy

failure path 应非常短：capture/report errno → `_exit`。若需要 unambiguous parent-side exec failure protocol，留到 later pipe/CLOEXEC design；本章不偷学 pipe。

## Challenge

增加一个 invalid directory path case，记录它与 permission case 的 errno distinction。

## Cleanup

```sh
make clean
```

## Sources

`execve(2)`, `_exit(2)`, `errno(3)`；chapter ledger。
