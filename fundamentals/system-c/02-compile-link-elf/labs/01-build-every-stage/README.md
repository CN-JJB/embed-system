# Lab 01 — Build Every Stage

## Objective

把一个真实 multi-file C program 沿 preprocessing → compilation → assembly → relocatable object → link 全部停站一次，并把 source text 与 binary evidence 对齐。

## Prerequisites

M01；知道 function/global object/header 的基本 C 语义。

## Environment

Linux/WSL；GCC；binutils；GNU Make。authoring host 是 x86-64。

## Estimated Time

55–70 min。

## AI Mode

第一次执行与问题回答 AI-Free；GCC/binutils official docs allowed。

## Build

```sh
make clean
make stages
make
./app.elf
```

## Procedure

1. 手工重复核心 stages：

```sh
gcc -E -I. main.c -o build/main.i
gcc -S -I. -O0 main.c -o build/main.s
gcc -c -I. -O0 main.c -o build/main.o
gcc build/main.o build/stats.o build/format.o -o app.elf
```

2. 比较 artifact，而不是通读全部 assembly：

```sh
file build/main.i build/main.s build/main.o app.elf
wc -c main.c build/main.i build/main.s build/main.o app.elf
grep -n 'translation-pipeline' build/main.i build/main.s
nm build/main.o | grep stats
```

3. 在 `main.s` 找一个 `stats_update` function call；在 `.i/.s` 找 string literal；在源码与 `nm` 中定位 `stats_total_samples` 与 file-static `run_number`。

## Expected Observation

`.i` 仍是 text；`.s` 是 assembler source；`.o` 在 verified host 被 `file` 识别为 `ELF 64-bit ... relocatable`；final `app.elf` 是 executable ELF。`main.o` 中 `stats_update/stats_total/format_summary` 仍为 undefined references，但 `.o` 已成功生成。

## Actual Verification Status

**VERIFIED** on Linux 6.18.35 x86_64 / GCC 14.2.0 / binutils 2.44。实际生成 `.i/.s/.o/app.elf`；program 输出 `run=1 translation-pipeline total=13 samples=2`；`file` 证明 `main.o` 是 ELF relocatable；`nm main.o` 显示所需 external symbols 为 `U`。final ELF 在该 Debian toolchain 默认是 PIE/dynamically linked；这是 host property，本章不展开 PIE/dynamic loader。

## Questions

1. 哪一步之后已经存在 machine-code container？
2. 为什么 `main.o` 有 `U stats_update` 仍然算成功 object build？
3. 哪些观察是 source-level guess，哪些是 object-file proof？
4. header 本身为什么没有独立 `.o`？

## Failure Modes

把 `-S` 当成“link 前一步的 executable”；看到 `.o` 中 `U` 就认为 compile 失败；试图读完整 assembly 才允许继续。

## Debug Strategy

先用 `file` 分类 artifact，再用 `nm/readelf` 回答 binary 问题。若 stage command 失败，先确认 stop option (`-E/-S/-c`) 与 input/output suffix，不要直接改 linker flags。

## Challenge

用 `gcc -v` 再执行一次 compile，识别 driver 启动的 subprogram/stage evidence；只记录与你的 pipeline mental model 相关的部分。

## Cleanup

```sh
make clean
```

## Sources

GCC 14.2.0 manual；GNU binutils 2.44；chapter `SOURCE_LEDGER.md`。
