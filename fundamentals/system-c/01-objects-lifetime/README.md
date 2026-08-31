# P1-M01 — Objects, Storage, Extent, and Linux Process Memory

> Phase 1 / M01  
> Target: **L3**, with **L4-local** diagnosis for dangling/OOB/UB faults  
> AI mode: first implementation, fault diagnosis, D+7 reconstruction, and Gate are **AI-Free**; official docs are allowed.  
> Planned learner time: **6.5 h MUST + ~1 h SHOULD**.

## Why

系统代码里最危险的错误，往往不是“不会写 pointer 语法”，而是把几件不同的事混成一件事：

- 一个 pointer value 只是一个值；
- 一个 object 是一段具有类型、大小和 lifetime 的存储实例；
- pointer 本身通常不携带 pointed-to object 的合法 extent；
- storage duration 决定存储何时存在，lifetime 决定 object 何时可以被合法访问；
- ownership 是 API/程序约定，不是 C pointer 类型自动表达的事实；
- Linux `/proc/self/maps` 展示的是 address-space mappings，而不是 C 标准的 object model。

后续 buffer、DMA、callback context、driver resource、userspace daemon 都会反复遇到这些边界。M01 的目标不是“复习 C”，而是建立以后能 Debug 的系统模型。

## Prerequisites

- 能读写基本 C 函数、循环、数组、pointer；
- 会使用 shell、GCC、GNU Make；
- 已完成或至少尝试 Phase 0 baseline。

## Mental Model 1 — pointer 不是 object

```mermaid
flowchart LR
    P["pointer variable\n自身也是一个 object"] -->|"contains an address value"| O["pointed-to object\nbytes + type + lifetime"]
```

关键句：**pointer 本身不是 pointed-to object。**

`int *p` 这个变量有自己的地址、大小、storage duration 和 lifetime。`p` 保存的 value 可能指向另一个 object，也可能是 null、dangling，甚至根本不是一个可合法解引用的地址。

## Mental Model 2 — extent 不藏在 pointer 里

```text
ptr
 │
 ▼
[0][1][2][3]
<--- extent --->
```

如果上图是 4 个 `uint8_t` 的 object extent，那么 `ptr + 0` 到 `ptr + 3` 可以指向元素，`ptr + 4` 可以形成 one-past pointer 但不能解引用。仅看一个普通 C pointer，通常无法知道“这里到底有几个合法元素”。

因此系统 API 常常需要显式携带 extent：

```c
struct span_u8 {
    uint8_t *data;
    size_t len;
};
```

这不是为了“面向对象”，而是把 pointer value 与 bounds contract 放回同一个接口。

## Mental Model 3 — C object model 与 Linux mapping model 相连，但不相等

```text
high address
┌──────────────────────┐
│ stack-like mapping   │  ← 常见，但 automatic object 不保证总有物理 stack slot
├──────────────────────┤
│ ...                  │
├──────────────────────┤
│ shared/file mappings │  ← loader / shared libraries / mmap regions 等
├──────────────────────┤
│ heap-ish mapping     │  ← malloc 实现细节此处不展开
├──────────────────────┤
│ writable image data  │  ← 常与 .data/.bss 相关；M03 再正式学 ELF
├──────────────────────┤
│ executable/ro image  │
└──────────────────────┘
low address
```

这是 **mental model，不是地址空间的真实模板**。ASLR、loader、shared libraries、匿名 mappings、不同 libc/allocator 和编译器优化都会让 `/proc/self/maps` 更复杂。不要把“stack / heap / data / text”示意图当成 Linux 实际 mapping 清单。

## Minimal Theory

### 1. object、size、extent

C object 是执行环境中的一块数据存储实例。对数组：

```c
int a[10];
```

`sizeof a` 是整个 array object 的字节数。表达式在多数上下文中会发生 array-to-pointer conversion，但 **`sizeof` 是关键例外之一**，所以 `sizeof a` 仍观察整个数组。

而：

```c
int *p = a;
```

`sizeof p` 只得到 pointer object 的大小，不是数组大小。

### 2. 函数参数中的 `int a[10]`

下面两个 parameter declaration 在函数类型层面等价：

```c
void f(int a[10]);
void f(int *a);
```

函数真正收到的是 pointer value，不是“复制进来的 10 元素 array object”。`10` 可以帮助人理解 intended contract，也能在部分带 `static` 的形式里表达更强前置条件，但普通 `int a[10]` 不会让 `sizeof a` 变成 10 个 `int`。

Lab 01 会要求你用 warning、`sizeof` 和地址实测，而不是背结论。

### 3. storage duration 与 lifetime

本章只建立四类常见对象：

- block-scope non-`static` local：通常是 automatic storage duration；
- `static` local：static storage duration；
- file-scope global/static object：static storage duration；
- `malloc()` 成功返回的 allocated storage：由分配/释放事件定义可用期，必须通过明确 ownership contract 管理。

不要把“automatic”直接翻译成“永远存在物理 stack slot”。在优化后，compiler 可能把值留在 register、常量传播掉，甚至完全消除某个 object 的可观察存储位置。本章只需要知道：**语言语义与最终机器布局不是一回事。**

### 4. dangling pointer 与 use-after-lifetime

pointer value 可以在 pointed-to object lifetime 结束后继续存在。此时 pointer 变成 dangling；“地址数值看起来还一样”不代表访问仍合法。

典型来源：

- block 结束后保存了 local object 地址；
- `free(p)` 后继续解引用 `p`；
- owner 释放资源，但 borrower 还在使用。

### 5. ownership

C 没有内建“owned pointer”类型。本课程使用简单文字 contract：

- **owned**：当前代码负责最终 release；
- **borrowed**：可暂时使用，但不能擅自 release；
- **transferred**：ownership 从一方移交给另一方。

M01 的 `span_u8` 默认是 **non-owning view**：它描述 `data + len` 的可访问范围，但不自动 `free(data)`。

### 6. `const` 的边界

`const T *p` 约束的是“通过这个 expression 修改 `T`”的能力，不等于“底层 object 在宇宙中永远不会变化”。例如同一个 non-const object 可能还存在其他可写 alias。

所以不要把 `const` 理解成 ownership、immutability protocol 或线程同步。

### 7. `volatile` 的第一阶段边界

本章只记住：`volatile` 用于要求某些访问保持为可观察访问，常见于 hardware/特殊执行环境边界；**它不是 thread-safe、不是 atomic、不是 mutex，也不自动提供 inter-thread ordering。** 并发语义后面再学。

### 8. fixed-width integers、signed overflow 与 shift UB

`uint8_t`、`uint32_t` 等 fixed-width types 在协议/buffer/register 边界很有价值，因为宽度是 contract 的一部分。

但 signed arithmetic 不是“数学整数自动无限扩展”。例如 signed overflow 是 undefined behavior；shift 也有 operand/range/representability 约束。不要用“在我机器上 wrap 了”作为正确性证明。

## Experiment Map

| Lab | 你要亲眼看到什么 | 主要证据 |
|---|---|---|
| [01 Array vs Pointer](labs/01-array-pointer/) | array object 与 pointer parameter 的 `sizeof` 不同 | compiler warning + addresses + runtime sizes |
| [02 Storage / Lifetime](labs/02-storage-lifetime/) | automatic/static/allocated objects 的事件与地址不同 | runtime addresses + mapping lookup |
| [03 ASan / UBSan](labs/03-asan-ubsan/) | normal run 可以“看似工作”，sanitizer 只覆盖特定 fault | normal vs ASan/UBSan |
| [04 `/proc/self/maps`](labs/04-proc-maps/) | C object addresses 落在 Linux mappings 中 | object addresses + `/proc/self/maps` |

实验顺序固定为：**Predict → Run → Observe → Explain**。不要先看 reviewer answer。

## Observation — 你应该形成的解释

完成 labs 后，应该能解释以下四个句子为什么可以同时成立：

1. `sizeof(array)` 可以给出整个 array object 大小；传进函数后 `sizeof(parameter)` 却只观察 pointer。
2. 一个 local object 常常出现在 stack mapping 附近，但语言并不承诺所有 local 都有 stack slot。
3. 一个 heap allocation 常落在 `[heap]` 或其他 writable mapping，但 C `malloc` contract 不等价于 Linux `[heap]` mapping 规则。
4. ASan/UBSan 报告是“这个 instrumented execution 检测到了某类问题”的证据；**沉默不是程序正确性的证明**。

## Source Walkthrough — musl `memmove.c`

**Pinned reading:** musl **v1.2.6**, upstream path `src/string/memmove.c`, 42 physical lines in the pinned file; project license: MIT. Canonical upstream is musl cgit; an unofficial GitHub mirror was used only to cross-check exact tagged bytes/line count. See [SOURCE_LEDGER.md](SOURCE_LEDGER.md).

不要复制整份源码。打开 upstream file 后，只跟踪以下局部：

1. `dest/src/n` 进入后如何形成 `d`、`s`；
2. 无 overlap 时为什么可以交给 `memcpy`；
3. overlap 时，`d < s` 与 `d > s` 为什么对应不同 copy direction；
4. `d++ / s++`、`d[n] / s[n]` 在哪里体现 pointer arithmetic；
5. word-at-a-time / alignment branch 为什么是 implementation optimization。

**Portability warning:** 这是 libc implementation source，不是普通应用 C 的“可直接照抄范式”。Pinned musl 代码包含 address-to-integer reasoning，并在受控路径里使用 pointer ordering 来决定方向；这些写法依赖 musl 支持的 compiler/ABI implementation assumptions。不要从这里推出“任意两个无关 object pointer 都可以在 strictly portable ISO C 中随意做 `<` / `>` 比较”。

阅读问题：

- 为什么 overlap 会改变 copy direction？
- `memcpy` 和 `memmove` 的 contract 差异是什么？
- 哪些行依赖 pointer range/extent reasoning？
- 哪些写法是 libc implementation 为性能/别名规则服务，不是普通应用代码必须模仿的风格？

**本章不要求理解所有优化技巧。** 你的目标是读出 contract、范围和方向，而不是复刻 libc。

## Common Misconceptions

| 错误 mental model | 修正 |
|---|---|
| pointer == object | pointer 是一个值；pointed-to object 是另一件事 |
| pointer knows array length | 普通 pointer 通常不携带 extent |
| local variable == physical stack slot | automatic semantics 不等于必须有 stack slot |
| ASan silent == program correct | sanitizer coverage 与执行路径有限，沉默不是证明 |
| `const` means object can never change | `const` 限制通过特定 lvalue/expression 的修改能力 |
| `volatile` means thread safe | 不提供 atomicity / mutual exclusion / synchronization |
| signed/unsigned arithmetic is “just math” | C integer operations受 width、conversion 和 UB 规则约束 |

## GDB — 本章只学够用的证据动作

当前课程需要的命令：

```text
break function_name
run
bt
frame 0
info locals
print variable
x/16bx pointer
watch variable
info registers   # SHOULD
```

建议在 [faults/](faults/) 的 `wrong-extent` 情况里：

1. breakpoint 停在消费 `span.len` 的函数；
2. `print span.len` 与真实 logical data length 对比；
3. `x/16bx span.data` 看 bytes 仍在合法 allocation 内——这也是为什么 ASan 可能沉默；
4. 对修改 `len` 的变量尝试 basic watchpoint，回答“错误 extent 是在哪里被制造的”。

这不是 GDB 命令背诵。每个命令都要服务一个 hypothesis。

## Challenge — `span_u8`

进入 [challenge/](challenge/) 完成一个很小的 non-owning API：

- construct / validate；
- slice；
- copy；
- compare。

必须写清楚：

- `data == NULL` 与 `len` 的合法组合；
- slice 的 overflow/bounds 检查；
- copy 的 destination extent；
- API 谁拥有底层 storage。

第一次实现 **AI-Free**。分级 hints 和 solution 在 `reviewer/`，不要与题目同时打开。

## Fault Injection

[faults/](faults/) 至少包含三类：

- F1 dangling pointer；
- F2 wrong extent；
- F3 signed integer UB。

其中 **F2 故意让 allocation 足够大，但 logical extent 错了**。这样程序访问仍可能落在合法 allocation 内，ASan 不会自动告诉你“业务边界写错了”。你需要 hypothesis + GDB/memory inspection + reasoning。

## Gate

[gate/](gate/) 是 AI-Free transfer Gate。它不是 Phase 0 telemetry bug hunt 的改名版，而是一个新的 frame/parser 小程序，包含：

- one extent contract bug；
- one lifetime bug；
- one integer UB；
- one misleading-but-legal pointer line。

提交证据必须使用：

```text
Symptom
Hypotheses
Evidence
Root Cause
Fix
Regression
```

只“把 sanitizer 报错消掉”不算通过。你还要指出那一行看起来危险但实际上合法的代码，并解释理由。

## Spaced Review

### D+1 — 5–8 min recall

不看笔记画出：pointer variable → pointed-to object；然后用一句话分别定义 extent、storage duration、lifetime、ownership。

### D+3 — changed context

给定：

```c
void consume(const uint8_t *p, size_t n);
```

一个 caller 传入 `malloc(64)` 得到的 buffer，但 `n=96`。回答：pointer value、allocated object extent、API extent contract、ownership 分别是什么；哪个事实 sanitizer 可能在“尚未越界访问”时无法替你证明？

### D+7 — blank-file reconstruction

从空文件写一个最小 `span_u8`，只实现 `make`、`slice` 和 `copy`，并写 5 个 bounds tests。AI-Free。

## Career Relevance

- **lifetime → driver callback context**：callback 被触发时 context object 是否仍活着，比函数指针语法更重要。
- **extent → DMA/buffer boundary**：descriptor 里的 length 与真实 buffer extent 不一致会成为硬件/软件边界 bug。
- **UB → firmware/kernel reliability**：优化器可以利用语言语义；“debug build 看起来没事”不能作为可靠性依据。
- **address-space model → process/MMU bridge**：M01 只建立 mapping 观察能力，后面 ELF、`exec`、`mmap`、Kernel/MMU 会继续把图变具体。

## Required Reading Budget

总计目标 **~45–55 min**：

- WG14 N1570 §6.2.4（storage duration / lifetime）与 §6.5.6（additive operators）选读：~20 min；
- GCC warnings + sanitizer overview：~10 min；
- musl `memmove.c` guided walkthrough：~15–20 min。

CS:APP / 其他书籍在本章都是 selective reference，不是课前整章任务。

## Further Reading

- N1570 §6.7.3：type qualifiers，配合本章 `const` / `volatile` 边界；
- CS:APP 3e §3.7 与 selected Ch. 9 figures：仅用于交叉 mental model，不替代 C/Linux primary sources；
- GCC instrumentation docs：当你需要确认某 sanitizer 实际覆盖什么。

完整来源与版本见 [SOURCE_LEDGER.md](SOURCE_LEDGER.md)。
