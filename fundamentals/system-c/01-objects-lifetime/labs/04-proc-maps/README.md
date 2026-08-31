# Lab 04 — `/proc/self/maps`: Object Addresses vs Mappings

## Objective

输出 one function address、static/global object、stack local、heap allocation，并把每个地址定位到 `/proc/self/maps` 的 mapped region。

## Prerequisites

M01 process-memory mental model；Lab 02。

## Environment

Linux / WSL-compatible；GCC；GNU Make；`/proc` mounted。

## Estimated Time

35–45 min。

## AI Mode

**AI-Free** first observation/explanation。

## Build

```sh
make clean && make
```

## Procedure

> **Host/ABI note:** 本实验为了把 function address 与 Linux mapping 对照，会把 function pointer 转成整数地址用于查询。这是 **Linux/WSL target 上的 implementation/ABI-level observation**，不要把它当成 strictly portable ISO C 对 function-pointer representation 的保证。

1. 预测 5 个地址会落在哪类 mapping，特别写下你对 function/static/global 的猜测。
2. 运行：

   ```sh
   ./proc_maps > maps.txt
   ```

3. 阅读顶部的 address → mapping 匹配，再阅读完整 maps。
4. 重跑一次并比较地址。ASLR 下哪些地址可能变化？mapping 的相对性质有哪些仍然可解释？
5. 找出 executable image、shared libraries、`[heap]`、`[stack]` 以及 anonymous regions；不要要求每台机器都有完全同名/同顺序 entries。

## Expected Observation

- function address 通常落在 executable mapping；
- static/global object 通常落在同一 program image 的 writable mapping；
- stack local 常落在 `[stack]`；
- allocation 常落在 `[heap]` 或 anonymous writable mapping；
- real maps 比 textbook stack/heap/data/text 图复杂得多。

核心结论：**C object model ≠ Linux virtual-memory mapping model，但 object 的机器地址必须位于进程可访问的 mapping 中才能完成对应访问。**

## Actual Verification Status

**VERIFIED** on Linux 6.18.35 x86_64。程序已实际定位 function/static/global/stack/heap addresses 并读取 `/proc/self/maps`。具体地址因 ASLR 不写入 expected transcript。

## Questions

1. `/proc/self/maps` 能告诉你 object 的 C lifetime 吗？
2. `[heap]` entry 能证明某个 allocation 的 ownership 吗？
3. 为什么 shared-library mappings 会让简单示意图变复杂？
4. 这个实验如何为后续 ELF、`exec`、`mmap`、Kernel/MMU 建桥，而不提前解释它们的实现？

## Failure Modes

- 把示意图当实际 ordering；
- 看到 `[heap]` 就把所有 dynamic allocation 都等同于该 region；
- 根据一个地址推导固定地址，忽略 ASLR。

## Debug Strategy

若地址 lookup 失败：确认 `/proc/self/maps` 可读；保留 raw maps；检查 address parser。若 mapping 名称与预期不同，先把“libc/loader/allocator implementation difference”作为 hypothesis，而不是硬套 textbook label。

## Challenge

只使用程序打印出的地址与 `/proc/self/maps`，为每个 object 写一行 evidence statement：`address ∈ [lo, hi), permissions=..., pathname/label=...`。不要加入 page table 推断。

## Cleanup

```sh
rm -f maps.txt
make clean
```

## Sources

- Linux `proc_pid_maps(5)`；
- 本章 [SOURCE_LEDGER.md](../../SOURCE_LEDGER.md)。
