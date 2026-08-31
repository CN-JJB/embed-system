# Lab 04 — `.text/.rodata/.data/.bss` as Evidence

## Objective

用 function、string literal、initialized global、zero-initialized global、file-static object 建立 section evidence，并纠正 `.bss` “文件里存很多 0”误解。

## Prerequisites

Labs 01–03。

## Environment

Linux/WSL；GCC；binutils `readelf/nm/objdump/size`。

## Estimated Time

45–55 min。

## AI Mode

AI-Free first pass。

## Build

```sh
make clean && make
./sections
```

## Procedure

```sh
readelf -S sections.o
nm -S sections.o
objdump -s -j .rodata sections.o
objdump -s -j .data sections.o
size sections.o sections
```

对以下 source object 各记录 binary evidence：`initialized_global`, `zero_global`, `zero_buffer`, `file_static_initialized`, `thresholds`, function code, string literal。

## Expected Observation

常见 verified placement：initialized writable data → `.data`；large zero buffer → `.bss`; const array/string bytes → `.rodata`; functions → `.text`。`readelf -S sections.o` 显示 `.bss` 为 `NOBITS`; `size` 仍报告其 memory-size contribution。

## Actual Verification Status

**VERIFIED.** `sections.o`: `.text PROGBITS`, `.data PROGBITS`, `.bss NOBITS`, `.rodata PROGBITS`; `size` 实际显示 object `bss=4128` bytes，而 `.bss` 并非同等大小的 file payload bytes。`nm` 显示 `zero_buffer`/`zero_global` 为 B-class evidence；addresses/sizes host-specific。

## Questions

1. `.bss NOBITS` 与 `size` 中非零 bss 如何同时成立？
2. 为什么不能说“所有 `const` 一定在 `.rodata`”？
3. file-static object 与 `.data/.bss` 是同一个分类维度吗？
4. final ELF 的 sections 与 running process mappings 是不是同一个概念？

## Failure Modes

把 C keyword 直接映射为 fixed section；认为 `.bss` runtime 不占空间；把 section table 当 process address-space map。

## Debug Strategy

先用 `nm -S` 找 symbol，再用 `readelf -S` 确认 containing section semantics；不要根据 variable name 推断。

## Challenge

把 `zero_buffer` 改成显式非零初始化一个 element，预测 `.data/.bss` size 变化再验证。

## Cleanup

```sh
make clean
```

## Sources

ELF gABI sections; GNU binutils 2.44; chapter ledger。
