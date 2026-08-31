# P1-M03 — Translation Pipeline, Linkage, Symbols, Relocations, ELF, and Make

> **Target depth:** L3；常见 link failure 达到 L4-local。  
> **Prerequisites:** P1-M01；基本 shell/C 多文件编译经验。  
> **Module budget:** 约 7 h MUST；REQUIRED reading 约 65–75 min。  
> **AI Mode:** core experiments / challenge / Gate 首次执行 AI-Free；official docs allowed；完成自己的 evidence chain 后才进入 AI-Hint / review。

## Why

以后看到 U-Boot、Kernel、Driver、Buildroot 或 BSP source tree 时，你不会只看到“很多 `.c` + 一个神秘 Makefile”。你需要能回答：**这个 translation unit 生成了哪个 object file？这个 `.o` 还缺哪个 symbol？哪个 relocation 需要 linker 修补？最后 ELF 中证据在哪里？**

本章主线不是 GCC flags catalog，而是：

```text
source.c
   ↓ preprocess
translation unit / preprocessed source
   ↓ compile
assembly
   ↓ assemble
relocatable object (.o)
   ↓ symbols + relocations
link
   ↓
ELF executable
```

下一章会把最后一个 artifact 接到 `exec`，形成：

```text
source → object → ELF → exec → process
```

## Mental Model

### Diagram A — Translation Pipeline

```text
main.c
  │
  ├─ preprocessor
  ▼
main.i
  │
  ├─ compiler
  ▼
main.s
  │
  ├─ assembler
  ▼
main.o
  │
  │ symbols + relocations
  ▼
 linker
  ▼
app.elf
```

源文件：[`diagrams/translation-pipeline.mmd`](diagrams/translation-pipeline.mmd)。

三个不可混淆的事实：

1. `.o` **已经是 machine code 的容器之一**，不是“还没编译的文本”；
2. relocatable `.o` 可以合法地保留 unresolved references；
3. linking 是把 object files / libraries 中的定义与引用组织、解析并 relocation，**不是再次编译 C source**。

### Diagram B — Symbols

```text
main.o
  calls foo
     │
     └── UND foo

foo.o
     └── GLOBAL foo

          linker
             ↓
        resolve + relocate
```

源文件：[`diagrams/symbol-resolution.mmd`](diagrams/symbol-resolution.mmd)。

源码里的 **declaration** 是“这里声明一个 entity 的接口/类型信息”；**definition** 提供该 entity 的定义（对 object/function 具体规则不同）。但“我觉得它应该 external”不是 binary evidence。`nm` / `readelf -s` 才能告诉你这个 object file 中实际留下的是 `UND`、`LOCAL`、`GLOBAL` 等 symbol-table evidence。

`static` 在 file scope 这里首先要想到 **linkage**，不要把它自动翻译成“lives forever”。storage duration 与 linkage 是不同维度；M01 已经建立过 lifetime/storage mental model。

### Diagram C — ELF Sections

```text
ELF
├── .text
├── .rodata
├── .data
├── .bss
├── symbol table
└── relocation info (object stage)
```

源文件：[`diagrams/elf-sections.mmd`](diagrams/elf-sections.mmd)。

在本章深度，常见 mental model 是：

- `.text`：machine instructions 等可执行内容；
- `.rodata`：常见 read-only data，例如某些 string literals / `const` objects；
- `.data`：需要在 file image 中携带 initialized bytes 的可写数据；
- `.bss`：常用于需要 memory image 空间、但不需要在 ELF file 中逐 byte 存放初值的 zero-initialized / uninitialized data；ELF 中常见类型是 `SHT_NOBITS`。

但 **section 是 object/binary-format 概念，不是 C 变量类别的一一映射魔法**。编译器、linker、target ABI、优化与 attributes 都可能改变实际 placement；所以本章总是要求 `readelf` / `nm` evidence。

## Minimal Theory

### 1. translation unit

对本章实验来说，可以把一个 `.c` 经 preprocessing 后形成的输入理解为一个 translation unit。`#include` 不是把 header 变成独立 `.o`；它使 header 内容参与 preprocessing 后的 translation unit。

### 2. declaration / definition / linkage

需要同时分开三个问题：

- **declaration**：当前 source context 知道这个 name/type 吗？
- **definition**：是否真的提供 object/function 的定义？
- **linkage**：不同 translation units 中同名 declaration 是否指向同一个 entity？

本章只使用足够解释常见 multi-file build 的 **external linkage** 与 file-scope `static` 带来的 **internal linkage**。不做完整 C standard linkage taxonomy 专题。

### 3. symbol / undefined symbol

`main.o` 调用另一个 translation unit 的 `stats_update()` 时，assembler 可以先生成调用位置附近的 machine code，同时留下 symbol reference + relocation。于是 **undefined symbol 不等于 compilation 必须失败**。它在 relocatable object 阶段可能完全正常；若最终 link 时仍找不到满足条件的 definition，才会出现 `undefined reference` link failure。

### 4. relocation

不要把 relocation 背成“重定位 = 改地址”。更有用的问题是：

> **某个已生成的 machine-code/data 位置，还不知道最终应该引用哪里；object file 用 relocation record 说明 linker 之后要根据哪个 symbol / section 关系修正这个位置。**

在 x86-64 host 上你会看到 `R_X86_64_PLT32`、`R_X86_64_PC32` 等具体 enum。它们是 **Host-specific Evidence**，不是本章记忆目标。你必须能说“这个 relocation 对应 `stats_update` 的 call target”，而不是背 enum 数字。

### 5. linker

本章只建立静态 link mental model：输入 relocatable objects，解析需要互相匹配的 symbol references，布局输出内容并应用 relocations，得到可执行 ELF。dynamic linker、GOT/PLT、PIC/PIE 原理、shared library engineering 均留到以后。

### 6. Make

Make 的核心问题不是 syntax trivia，而是：

> **当某个 prerequisite 变了，哪个 target 已经 out-of-date，哪些 recipe 应该重新执行？**

本章只覆盖：target、prerequisite、recipe、variable、pattern rule、`.PHONY`、simple header dependencies。Lab 05 使用 `-MMD -MP` 是因为 compiler 可以把真实 `#include` dependencies 写入 `.d` 文件；flags 会逐项解释，不要求盲贴。

## Experiment Map

| Lab | Observable question | Evidence |
|---|---|---|
| [01 Build Every Stage](labs/01-build-every-stage/README.md) | source 到 `.i/.s/.o/ELF` 每一步实际是什么？ | `gcc -E/-S/-c`, `file`, `nm` |
| [02 Symbols](labs/02-symbols/README.md) | source guess 与 symbol-table proof 有什么差别？ | `nm`, `readelf -s` |
| [03 Relocations](labs/03-relocations/README.md) | unresolved call 在 `.o` 中怎样留下“待修补证据”？ | `readelf -r`, `objdump -dr` |
| [04 Sections](labs/04-sections/README.md) | function/string/global/static/zero storage 实际在哪里？ | `readelf -S`, `nm`, `objdump`, `size` |
| [05 Make Dependencies](labs/05-make-deps/README.md) | 修改 `.c/.h` 后 rebuild set 如何变化？ | Make recipe execution + `.d` files |

完成 Labs 后进入 [Challenge](challenge/README.md)、[Fault Campaign](faults/README.md) 和 [Gate](gate/README.md)。

## Observation → Explanation

你应该能独立解释以下 evidence chain：

```text
main.c says: stats_update(11)
        ↓
main.o: U stats_update
        ↓
readelf -r main.o: relocation references stats_update
        ↓
objdump -dr main.o: call encoding has unresolved/placeholder field + relocation annotation
        ↓
link with stats.o
        ↓
final ELF disassembly: call now targets stats_update at a concrete linked address
```

这条链比“linker 把文件连起来”更重要，因为以后 module/kernel/bootloader link failure 的调试仍会回到 symbol + relocation evidence。

## Source / Tool Walkthrough

### Primary — REQUIRED

1. **GCC 14.2.0 manual**：`Options Controlling the Kind of Output`，只读 `-E/-S/-c/-o/-v` 与 stage distinction。
2. **GNU binutils 2.44**：`nm`, `readelf`, `objdump`, `size` 中本章使用的 symbol/section/relocation/disassembly options。
3. **GNU make 4.4.1 manual**：rule anatomy、variables、pattern rule intro、`.PHONY`、automatic prerequisite generation idea。
4. **System V ABI / ELF selected**：section headers、symbol table、relocation，目标是理解 file-format evidence，不读完整 ABI。

### Classic book — REQUIRED / SHOULD / skipped

**CS:APP 3e Ch. 7**：

- **REQUIRED:** §§7.1–7.7（compiler driver、static linking、object files、relocatable objects、symbols/symbol tables、symbol resolution、relocation）；约 40–50 min，按本章实验问题读；
- **SHOULD:** 回看 §7.10 memory mapping / loading 的大图，只作为 M04 bridge，不要求细节；
- **skipped on first pass:** shared libraries、PIC/GOT/PLT 深挖、library interposition 等后续内容。

不要复制书中图或段落；用本章自己生成的 `.o` 做 evidence。

## Debug

### Compiler vs linker diagnostic

先分类 failure 在哪一层：

- `.c → .o` 都没完成：先看 compiler diagnostic；
- `.o` 都有，final executable 失败：先看 linker diagnostic + `nm/readelf`；
- link 成功但 behavior 错：link success 只证明 binary relation 满足了 link 条件，不证明 program semantics 正确。

### GDB disassembly bridge

目标命令：

```gdb
disassemble main
break main
run
x/i $pc
info registers
stepi
```

在当前 authoring runtime **GDB unavailable → UNVERIFIED**。Learner/Leader WSL 首次执行后才可提升状态。`%rip/%rsp` 等 register name 属于 x86-64 host evidence；换 ARM/RISC-V 不应期待相同名字。

## Common Misconceptions

- **compiler == linker** → GCC driver 可以协调 stages，但 compilation 与 linking 是不同工作。
- **`.o` 只是 source-text intermediate** → `.o` 是 object-format container，已包含 machine code/data/symbol/relocation 等。
- **undefined symbol means compilation always fails** → relocatable object 可以合法保留 unresolved reference。
- **`static` always means “lives forever”** → file-scope `static` 在这里关键是 internal linkage；storage duration 是另一个概念。
- **`.bss` = executable 里存一大片 0** → 常见 ELF `.bss` 是 `NOBITS`，表达 memory-size requirement 而非逐 byte file payload。
- **successful link = program correct** → linker 不验证你的 algorithm / lifetime / bounds semantics。
- **symbol name directly equals C scope semantics in all cases** → binary symbol tables 是 compiler/object-format 输出；source scope/linkage 与 symbol visibility/binding 要用 evidence 谨慎对应。

## Transferable Concept vs Host-specific Evidence

| Transferable Concept | Host-specific Evidence on authoring host |
|---|---|
| function call needs a resolvable target | x86-64 `call` encoding |
| unresolved reference can carry relocation | `R_X86_64_PLT32` / `R_X86_64_PC32` names |
| relocations identify places/symbol relationships to fix | exact offset/addend encoding |
| sections organize object-file contents | exact section set/order/addresses |
| linker creates final binary relations | authoring output is x86-64 PIE ELF by distro default |

不要把右栏当成 ARM/RISC-V universal truth。

## Fault Injection

见 [`faults/README.md`](faults/README.md)。四个 MUST faults：

- F1 Undefined Reference
- F2 Multiple Definition
- F3 Wrong Linkage
- F4 Stale / Missing Header Dependency

每个必须提交：`Symptom → Hypotheses → Evidence → Root Cause → Fix → Regression`。

## Gate

[`gate/README.md`](gate/README.md) 是 AI-Free。陌生 5-file project 包含 undefined reference、misleading `static`、data-section reasoning、relocation evidence、Make dependency issue。**只让 `make` 绿不算通过**。

## Spaced Review

### D+1 — mental-model recall（AI-Free, 10 min）

不看 notes，画出 `source → .i → .s → .o → ELF`；在 `.o` 旁写出 `symbol + relocation`；口述 declaration/definition/linkage 三者区别。

### D+3 — changed-context transfer（AI-Free, 20 min）

给一个从没见过的 2-object program：只用 linker diagnostic + `nm` + `readelf -r` 判断是“缺 definition”还是“definition 被 internal linkage 隔离”。先写 hypothesis，再执行 tool。

### D+7 — blank-directory reconstruction（AI-Free, 35–45 min）

从空目录写一个 3-file C project + Makefile：至少一个 header、一个 external function、一个 file-static helper。第一次 build、no-change build、改 `.h` 后 build；再对一个 `.o` 展示一个 symbol 和一个 relocation。

## Career Relevance

- **Build/link → firmware/kernel/module/toolchain:** source tree 中每个 object 的来源和 link boundary 是 bring-up 基础。
- **ELF → boot/kernel/module/BSP:** 后续读 image/layout/module evidence 时不再把 binary 当黑盒。
- **symbols → driver/module debugging:** unresolved/multiple symbol failures 可以从 object evidence 开始定位。
- **relocation → later kernel/module/bootloader:** 后续遇到 module relocation / boot image placement 时已有正确概念入口。
- **Make → embedded source-tree literacy:** 你能从 dependency behavior 理解“为什么改这个 header 会重编这些 objects”。

## Scope Boundary / Forward References

本章不正式教学 dynamic linker internals、GOT/PLT、PIC/PIE 原理、shared-library engineering、loader source internals。authoring host 的 final executable 默认可能是 PIE/dynamically linked；这里只把它当 host property 记录，不展开实现。

## Sources

精确版本、URL、章节、teaching use 与 version risk 见 [`SOURCE_LEDGER.md`](SOURCE_LEDGER.md)。
