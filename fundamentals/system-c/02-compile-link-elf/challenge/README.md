# P1-M03 Challenge — Repair the Sensor Registry Build

> **AI-Free first attempt.** Official GCC/binutils/Make docs allowed.  
> Context intentionally differs from Phase 0 metrics/report baseline：这是一个 sensor registry/report project，bug combination 与 evidence requirements 也不同。

## Objective

从 broken 4-source project 开始：修 Makefile、修 symbol/linkage contract、成功产生 ELF，并用 binary evidence 证明每个修复。只改到“能 link”不够。

## Prerequisites

M03 Labs 01–05。

## Environment

Linux/WSL；GCC；GNU Make；`nm/readelf/objdump`。

## Estimated Time

55–75 min。

## AI Mode

AI-Free；official docs allowed。

## Build

```sh
make clean
make objects
make
```

`make objects` 是为了先得到所有 `.o`，即使 default link recipe 本身有 bug。

## Procedure

1. 保存 linker diagnostic；
2. 用 `nm` 比较 `main.o` 与 `registry.o` 的 `registry_limit`；
3. 用 `nm` 比较 `report.o` 与 `format.o` 的 `report_width`；
4. 检查 Makefile default link object list；
5. 最小 coherent fix：
   - public `registry_limit` 必须满足 header contract；
   - `report_width` 只能有一个 external definition，其他 translation unit 只 declaration；
   - final target 必须 link 所需 object；
   - 添加可靠 header dependencies（推荐 `-MMD -MP`，但必须解释）；
6. rebuild/run；
7. `readelf -r build/main.o` 展示至少一个 pre-link relocation；
8. `readelf -S registry_app` 与 `nm` 做 final proof。

## Expected Observation

Seeded default link **VERIFIED** 会出现 `undefined reference to registry_limit` 与 `undefined reference to format_report`。若你把 `format.o` 只塞回 link list 而没有修 source contract，还会暴露 `multiple definition of report_width`。`nm` 可见 `main.o: U registry_limit`，而 `registry.o` 的同名 definition 是 local (`t`)。

## Actual Verification Status

Seeded object build、default link failures、all-object manual link 的 multiple-definition evidence 均 **VERIFIED** on GCC 14.2/binutils 2.44。Reviewer fixed tree 也已 strict-build/run **VERIFIED**，输出 `total=9 samples=2 width=48`；learner-facing 文件不暴露 patch。

## Questions

1. 哪个 failure 是 missing object，哪个是 wrong linkage，哪个是 multiple definition？
2. 为什么“把 `static` 都删掉”不是一般性修法？
3. 哪个事实是 linker diagnostic，哪个事实被 `nm` 独立证明？
4. header dependency 修复如何用 changed-header regression 证明？

## Failure Modes

- 反复改变 link command 顺序但不看 symbols；
- 把 header 中 definition 当方便的 shared declaration；
- 每次都 `make clean`，因此无法验证 incremental dependency correctness。

## Debug Strategy

先让所有 `.o` 可生成 → symbol table → relocation → link command object set → source contract。一次只消灭一个 hypothesis。

## Challenge

提交一页 evidence map：每个 source-level fix 旁边贴一个 tool/build observation，不能只写“works now”。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`；GCC/binutils/Make official docs。
