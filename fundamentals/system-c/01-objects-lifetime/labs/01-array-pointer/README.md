# Lab 01 — Array vs Pointer

## Objective

用 compiler warning、真实 `sizeof` 和地址观察证明：array object 与 pointer object 不同；函数参数 `int a[10]` 不会让函数收到一个 10-element array object。

## Prerequisites

M01 Mental Model 1–2；知道 `sizeof` 与 `%p` 的基本用法。

## Environment

Linux / WSL-compatible；GCC；GNU Make。

## Estimated Time

30–40 min。

## AI Mode

第一次实验与问题回答：**AI-Free**。官方 GCC/C 文档允许。

## Build

```sh
make clean && make
```

注意 build output。GCC 应对函数参数里的 `sizeof a` 给出 array-argument 相关 warning；warning 文案可能随版本略变。

## Procedure

1. **先预测**：假设 host 是 64-bit，写下你认为 `sizeof(array)`、`sizeof(pointer)`、函数内 `sizeof(a)` 的结果；不要先运行。
2. build，保存 compiler warning。
3. 运行：

   ```sh
   ./array_pointer
   ```

4. 比较 `array`、`&array`、`pointer` 所代表的地址值，以及 `&pointer` / 函数中 `&a` 这些 pointer-variable object 的地址。
5. 修改 array element count 为 17，重新 build/run。哪些 `sizeof` 变了，哪些没有？

## Expected Observation

- `sizeof(array)` 随 array extent 改变；
- `sizeof(pointer)` 反映 pointer object 大小；
- 函数 parameter `a` 被调整为 pointer parameter，因此函数内 `sizeof a` 是 pointer size；
- `array` 与 `&array` 常打印相同数值地址，但类型和 pointer arithmetic 语义不同；“地址打印相同”不代表它们是同一个类型/对象。

## Actual Verification Status

**VERIFIED** on repository authoring environment：Linux x86_64, GCC 14.2.0, GNU Make 4.4.1。实际 warning 与 runtime size/address relations 已执行检查；具体 ASLR 地址不写死到教程。

## Questions

1. 为什么 `void f(int a[10])` 的 `10` 不能让 `sizeof(a)` 得到 10 个 `int`？
2. 为什么 `array` 与 `&array` 打印值可能相同，但 `array + 1` 与 `&array + 1` 的步长不同？
3. `&pointer` 指向什么 object？它与 `pointer` 保存的地址是什么关系？
4. 哪一项 evidence 最直接反驳“pointer 自带 array length”？

## Failure Modes

- 用“我的机器 pointer 是 8 bytes”替代模型：这是 host observation，不是所有 ABI 的恒定值。
- 看到两个 `%p` 数值相同就断言类型/extent 相同。
- 忽略 build warning，只看 runtime output。

## Debug Strategy

如果结果与预测不同：先保留 warning，再用 `gdb`（若环境可用）在 `inspect_parameter` breakpoint；`print sizeof(a)`、`print a`、`print &a`，把 parameter object 与 pointed-to array bytes 分开。

## Challenge

把函数改成同时接收 `int *a, size_t len`，打印并验证 caller 提供的 extent contract。不要在函数里用 `sizeof(a) / sizeof(a[0])` 猜长度。

## Cleanup

```sh
make clean
```

## Sources

- WG14 N1570: array/function parameter declarator 与 array-to-pointer conversion 相关条款；
- GCC warning options；
- 本章 [SOURCE_LEDGER.md](../../SOURCE_LEDGER.md)。
