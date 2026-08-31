# Lab 02 — Symbols: Source Guess vs Binary Evidence

## Objective

用 external function、`static` function、external global、file-static global、undefined reference 建立 declaration/definition/linkage 与 symbol table evidence 的对应关系。

## Prerequisites

Lab 01。

## Environment

Linux/WSL；GCC；GNU `nm`/`readelf`。

## Estimated Time

45–55 min。

## AI Mode

AI-Free first pass；official tool docs allowed。

## Build

```sh
make clean && make objects && make
./symbols_app
```

## Procedure

```sh
nm symbols.o
nm main.o
nm undefined_only.o
readelf -s symbols.o
readelf -s main.o
```

建立两栏 notebook：

```text
Source hypothesis          Binary evidence
-----------------          ---------------
external_global external   nm/readelf says ...
static_helper internal     nm/readelf says ...
...
```

必须单独指出 `undefined_only.o` 的 `not_defined_here`。

## Expected Observation

在 verified x86-64 ELF object 中，`external_global/public_add/public_probe` 为 global definitions；`file_static_global/static_helper` 为 local definitions；`main.o` 对 external API 为 undefined；`undefined_only.o` 对 `not_defined_here` 为 undefined。`nm` 的大小写是 tool convention，不要把它当 C standard wording。

## Actual Verification Status

**VERIFIED.** `nm symbols.o` 实际显示 `D external_global`, `d file_static_global`, `T public_add`, `T public_probe`, `t static_helper`；`readelf -s` 分别显示 `GLOBAL`/`LOCAL`；`undefined_only.o` 显示 `U not_defined_here`。

## Questions

1. `static_helper` 的 source declaration/definition 与 ELF `LOCAL` evidence 各证明什么？
2. `U` symbol 是否自动是 bug？在哪个阶段才知道？
3. declaration 存在为什么不等于 linker 一定能找到 definition？
4. “symbol name == C scope” 为什么过度简化？

## Failure Modes

只凭 header 猜 symbol；把 `static` 与 static storage duration 混为一谈；认为 local symbol 完全不存在于 object file。

## Debug Strategy

先比较 `nm main.o symbols.o`；再用 `readelf -s` 看 `Bind`/`Ndx`。不要用 final executable 的优化/strip side effects 替代 object-stage evidence。

## Challenge

把 `public_probe` 临时改成 `static`，先预测 compile/link/tool output，再执行验证；恢复后 cleanup。

## Cleanup

```sh
make clean
```

## Sources

GNU binutils 2.44 `nm`/`readelf`; ELF symbol table; chapter ledger。
