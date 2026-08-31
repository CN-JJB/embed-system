# Lab 03 — Relocations: Prove the Unresolved Call

## Objective

在真正的 `main.o` 中观察 function call placeholder + relocation record，并与 final executable 的 linked call 对比。

## Prerequisites

Labs 01–02；知道 symbol reference。

## Environment

Linux/WSL；GCC；binutils。exact instruction/relocation name host-specific。

## Estimated Time

55–70 min。

## AI Mode

AI-Free first evidence collection；official binutils/ABI docs allowed。

## Build

```sh
make clean && make
./relocation_app
```

## Procedure

先只看 object：

```sh
nm main.o
readelf -r main.o
objdump -dr main.o
```

定位 `main` 中对 `stats_update(11)` 的 call。不要背 relocation enum；写一句：**这个 relocation 在这个 program 里要让 linker 最终把 call 与 `stats_update` definition 对上。**

再看 linked executable：

```sh
objdump -d relocation_app | sed -n '/<main>:/,+25p'
nm relocation_app | grep stats_update
```

比较 call 附近 bytes/annotation。

## Expected Observation

authoring x86-64 object 中 `objdump -dr main.o` 显示 `call` 的 displacement field 为 placeholder-like zero bytes，同时紧邻 relocation annotation 指向 `stats_update`; final executable 中 call 已指向 linked `stats_update` address。具体 `R_X86_64_PLT32` 名称是 host psABI evidence。

## Actual Verification Status

**VERIFIED.** `readelf -r main.o` 对 `stats_update`/`stats_total` 各有 relocation；`objdump -dr` 中 call 附近可见 unresolved encoding + relocation；final disassembly 中 `call 1147 <stats_update>`（address 仅为本次 run evidence，不是 golden value）。

## Questions

1. `.o` 已经有 call instruction，为什么仍需要 relocation？
2. relocation record 关联哪个 symbol？
3. final link 后发生的变化是什么？
4. 为什么不要求记住 `R_X86_64_PLT32`？换 ARM/RISC-V 哪部分 mental model 仍成立？

## Failure Modes

把 relocation 当成“linker 再编译 instruction”；把 exact relocation enum 当 portable API；只看 final executable 而没证明 object-stage uncertainty。

## Debug Strategy

如果 `readelf -r` 输出很多 debug relocations，先聚焦 `.rela.text` 和你的 named symbol。用 `objdump -dr` 把 relocation 与具体 instruction 放在同一视图。

## Challenge

在 `main.c` 再加一次对另一个 external function 的 call；先预测新增哪个 symbol/relocation，再 build 验证。

## Cleanup

```sh
make clean
```

## Sources

GNU binutils 2.44; ELF relocation sections; x86-64 psABI only for host-specific name interpretation。
