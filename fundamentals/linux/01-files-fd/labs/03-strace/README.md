# Lab 03 — `strace` Bound to a Real Failure

## Objective

用一个“`fdcopy` 打不开 input”的真实问题练 syscall evidence；观察 source API `open()` 与 trace 中可能出现的 `openat()` 不一一同名。

## Prerequisites

完成 Lab 01；理解 return value / errno。

## Environment

Linux/WSL；`strace`；Lab 01 `fdcopy` binary。

## Estimated Time

20–30 min。

## AI Mode

第一次 diagnosis **AI-Free**；man page/strace option docs allowed。

## Build

先在相邻 lab：

```sh
make -C ../01-fdcopy
```

## Procedure

先不用 trace：

```sh
../01-fdcopy/fdcopy definitely-missing out.bin
```

写 hypothesis：是 source path、permission、read 还是 write failure？然后 trace：

```sh
strace -e trace=%file,%desc ../01-fdcopy/fdcopy definitely-missing out.bin
```

再做一次 success case：

```sh
printf 'ok\n' > input.bin
strace -e trace=%file,%desc ../01-fdcopy/fdcopy input.bin out.bin
```

只记录与问题有关的 calls：open/openat-family evidence、read/write/close 与 return/errno。不要把 startup noise 全部抄进报告。

## Expected Observation

failing pathname 应在 trace 中出现一个 file-related call 返回 failure（常见为 `ENOENT`）。尽管 C source 调 `open()`，strace 在常见 libc/Linux 组合上**可能**观察到 `openat()`；这是 libc/kernel interface 实现层的 seed，不代表你写了 `openat()`。M02 不展开 wrapper internals。

## Actual Verification Status

**UNVERIFIED** in the authoring runtime：`strace` 未安装。命令与 expected semantics 已依据 `strace(1)` / Linux man-pages 设计；**没有伪造 syscall transcript**。Leader/learner environment 首次运行后应更新 evidence/status。

## Questions

1. program error text 与 trace failure return 如何互相支持？
2. 为什么 syscall name 不同不等于 source code “偷偷变了”？
3. 哪些 trace lines 是 loader/runtime noise，而不是本 fault 的 root cause？

## Failure Modes

- 从上百行 trace 中找“看起来复杂”的行，而不是先有 hypothesis；
- 把 `openat()` 当成本章必须新学 API；
- 只看 syscall 名，不看 return value / errno。

## Debug Strategy

先收窄问题到 file/descriptor operations，再用 `-e trace=%file,%desc`。若 trace 不含预期 pathname，回头检查你实际执行的 binary/arguments。

## Challenge

让 output path 指向不存在的 parent directory；在 program error 与 trace 中区分 input-open success 和 output-open failure，确认 owned input 在错误 cleanup 后被 close。

## Cleanup

```sh
rm -f input.bin out.bin
```

## Sources

`strace(1)`, `open(2)`, `read(2)`, `write(2)`, `close(2)`；chapter `SOURCE_LEDGER.md`。
