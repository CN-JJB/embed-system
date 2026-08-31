# P1-M03 Gate — Binary Boundary Audit

> **AI-Free. Official GCC / GNU binutils / GNU make / ELF documentation allowed.**  
> Do not open `../reviewer/` before submission.

## Objective

在陌生 5-file C project 中修复 build，并证明你理解 object/symbol/relocation/section/dependency chain。**只让 `make` 成功不算 Gate 通过。**

## Prerequisites

全部 M03 labs + fault campaign。

## Environment

Linux/WSL；GCC；GNU Make；`nm`, `readelf`, `objdump`, `size`。GDB optional evidence only。

## Estimated Time

70–90 min。

## AI Mode

AI-Free；official documentation allowed。

## Build

```sh
make clean
make objects
make
```

## Procedure / Required Evidence

### Station 1 — classify build failures

保存 default link diagnostic。不要先编辑。列出至少 3 个 hypotheses，并说明 each belongs to compile/link/dependency layer。

### Station 2 — object evidence

```sh
nm build/main.o build/sampler.o build/report.o
readelf -s build/sampler.o
readelf -r build/main.o
objdump -dr build/main.o
```

必须证明：

- one unresolved reference；
- one misleading `static` / wrong linkage fact；
- `main.o` 至少一个 relocation 对应哪个 source-level call。

### Station 3 — repair source + link

修复最小 source/link contract，得到 `gate_app`。Expected functional output：

```text
gate total=12 dropped=1
```

### Station 4 — data-section reasoning

对 final ELF：

```sh
readelf -S gate_app
nm -S gate_app | grep -E 'sample_limit|sample_dropped'
size gate_app
```

解释 initialized global 与 zero-initialized global 的 evidence；不要只说“全局变量在 data”。

### Station 5 — Make dependency regression

修改 `include/format.h` 中一个 harmless interface-related dependency（例如 touch header，不改变 API）并运行 `make`。证明哪些 `.o` 应 rebuild。若现有 Makefile没有这条 dependency edge，修复它；推荐 `-MMD -MP` 但必须说明两者用途。

### Station 6 — regression

```sh
make clean && make
./gate_app
make
```

第二次 no-change build 应无不必要 rebuild。再修改 header，验证 dependency behavior。

## Expected Observation

Seeded objects **VERIFIED**；`sampler.o` 有 local `sampler_scale`，`report.o` 对它是 undefined；`main.o` 有指向 `sampler_record`/`report_emit` 的 relocations。Seeded default link 还故意遗漏 `report.o`，因此 first linker symptom 包含 `report_emit` unresolved。修一个表面 symptom 后，必须继续用 symbols/evidence 找完 root causes。

## Actual Verification Status

- Seeded object generation: **VERIFIED**。
- Seeded default link failure: **VERIFIED**。
- Reviewer fixed tree: **VERIFIED**, output `gate total=12 dropped=1`。
- Fixed `sampler_scale` becomes external/global definition: **VERIFIED** by `nm`。
- Final `.text/.rodata/.data/.bss` evidence: **VERIFIED** by `readelf -S`。
- GDB path: **UNVERIFIED** (GDB unavailable in authoring runtime)。

## Questions

1. 为什么 `sampler.o` 有一个同名 local symbol 仍不能满足另一个 object 的 external reference？
2. `main.o` 的 relocation 在 link 前说明什么 uncertainty？
3. final ELF section evidence 与 C source guess 有何不同？
4. header changed but object not rebuilt 属于 linker bug 吗？

## Failure Modes

只改 Makefile object list；把所有 `static` 无脑删除；不检查 `readelf -r`；每次 clean build 掩盖 dependency bug；把 x86-64 relocation enum 当 Gate 背诵项。

## Debug Strategy

`diagnostic → nm/readelf symbols → relocation → link object set → source linkage → Make dependency regression`。每个 root cause 都要至少一个独立 evidence source。

## Challenge

在不改变 observable output 的情况下，把一个 private helper 明确改成 internal linkage，并证明它不会重新造成 public API unresolved symbol。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`。
