# Lab 02 — Storage Duration / Lifetime

## Objective

把 automatic、static-storage 与 dynamically allocated storage 放进同一个可观察程序：记录 address、lifetime event，并把地址定位到 `/proc/self/maps` mapping。

## Prerequisites

M01 storage duration / lifetime；基本 `malloc/free`。

## Environment

Linux / WSL-compatible；GCC；GNU Make；`/proc` mounted。

## Estimated Time

40–50 min。

## AI Mode

首次预测与解释：**AI-Free**。

## Build

```sh
make clean && make
```

默认 `-O0` 是为了让第一轮地址观察更直接；这不是在声明 optimized program 一定保留同样 storage slots。

## Procedure

1. 预测 automatic、local static、global、allocation 分别可能落在哪类 mapping。
2. 运行 `./storage_lifetime`，记录每个 address 与程序打印的 mapping line。
3. 把事件时间线写成：enter scope → allocation → free → leave scope → process exit。
4. 回答：哪个事件结束 allocated storage 的可用 lifetime？哪个事件结束 automatic object 的 lifetime？static-storage object 何时结束？
5. **SHOULD**：改用 `CFLAGS='-std=c11 -Wall -Wextra -g3 -O2' make clean all`。不要要求所有 local 仍可被 debugger/地址观察成独立 stack slot；只比较行为与 binary observation。

## Expected Observation

常见 Linux x86_64 环境下，automatic object 地址会落在 `[stack]` mapping，allocation 常落在 `[heap]` 或其他 writable anonymous mapping，static/global 落在 executable image 的 writable mapping。**这些是 host observations，不是 C 标准对物理布局的保证。**

## Actual Verification Status

**VERIFIED** for `-O0` build/run and `/proc/self/maps` lookup on Linux 6.18.35 x86_64, GCC 14.2.0。`-O2` debugger-level object-location claims 未做，因为当前环境无 GDB；相关路径标为 **UNVERIFIED**。

## Questions

1. storage duration 与 lifetime 为什么不能简单等同于“在哪个段”？
2. `free()` 后 pointer variable 为什么还可能保存原数值？为什么这不使 dereference 合法？
3. 为什么不能从本次实验推出“所有 local 永远在 stack”？
4. 为什么 allocation 不应被定义成“`[heap]` 里的东西”？

## Failure Modes

- 把一次 ASLR 地址当作固定地址；
- 把 `[heap]` 当作 `malloc` 的语言定义；
- 用 optimizer 后“看不到变量”推导 object 从来不存在过，而不区分抽象机语义与机器实现。

## Debug Strategy

若 mapping lookup 没找到：先打印完整 `/proc/self/maps`，确认 `/proc` 可用；再检查地址解析和权限。若 optimized build 下 GDB 无法显示 local，先回到 `-O0` 复现，再把“debug info/optimization 改变可观察性”作为 hypothesis，而不是先怀疑 lifetime 规则。

## Challenge

增加一个 block-scope nested automatic array，保存其地址值但**不要在 lifetime 结束后解引用**。只打印数值并解释：保存一个数值与合法访问 pointed-to object 是两件不同的事。

## Cleanup

```sh
make clean
```

## Sources

- WG14 N1570 §6.2.4；
- Linux `proc_pid_maps(5)`；
- 本章 [SOURCE_LEDGER.md](../../SOURCE_LEDGER.md)。
