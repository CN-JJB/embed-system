# M01 Fault Injection — Lifetime, Extent, UB

**Objective:** 对三个独立 fault 建立 `Symptom → Hypotheses → Evidence → Root Cause → Fix → Regression`。  
**Prerequisites:** M01 labs。  
**Environment:** Linux/WSL, GCC, Make；GDB optional。  
**Estimated Time:** 35–50 min。  
**AI Mode:** initial diagnosis **AI-Free**；记录 hypothesis + first evidence 后才可看 reviewer hints。

## Build / Procedure

```sh
make clean && make
```

每个 fault 先跑 normal binary，再选择 evidence tool：

```sh
./faults-normal dangling
./faults-asan dangling

./faults-normal wrong-extent
./faults-asan wrong-extent

./faults-normal signed
./faults-ubsan signed
```

### F1 — dangling pointer

回答：哪个 object 拥有 storage？哪一刻 lifetime/allocated-storage validity 结束？为什么 pointer value 自身仍存在不代表可解引用？

### F2 — wrong extent

这里的 allocation 有 16 bytes，但 protocol 的 logical payload 只有 4 bytes。**ASan 可能完全沉默**，因为 checksum 仍在 allocation 内。用以下 evidence 证明 bug：

- 程序打印的 `logical_len` 与 `advertised_len`；
- 代码中的 protocol contract；
- GDB 可用时在 `checksum` breakpoint，`print v.len`、`x/16bx v.data`。

### F3 — signed integer UB

先预测 normal output，再用 UBSan。解释：一次机器上的 wrap 结果为什么不能成为 C semantics contract。

## Expected Observation

F1 可被 ASan 识别为 use-after-free；F3 可被 UBSan 识别为 signed overflow；F2 的错误是 **semantic extent**，即使 memory access 仍在 allocation 内也已经违反 caller/callee contract。

## Actual Verification Status

**PARTIALLY VERIFIED** on GCC 14.2.0：build、ASan F1、UBSan F3、F2 ASan-silent behavior 已执行。GDB evidence path **UNVERIFIED**，因为 authoring environment 未安装 GDB。

## Questions / Failure Modes / Debug Strategy

- “sanitizer 没报错”是否能排除 F2？
- 如果 F1 normal run 恰好打印 73，是否更接近“正确”？
- 修 F2 时应该缩 allocation，还是修 advertised extent？为什么？

失败模式：只根据 crash/no-crash 分类；不写 ownership/lifetime contract；把 sanitizer report 当 root-cause explanation 本身。

## Challenge

让 F2 的后 12 bytes 随运行改变，但仍保持 allocation 内。观察 checksum symptom 变得不稳定，而 ASan 仍可能无报告；写出为什么这是“wrong data boundary”而非 allocator bug。

## Cleanup / Sources

```sh
make clean
```

Sources: GCC sanitizer docs, WG14 N1570 selected clauses, chapter `SOURCE_LEDGER.md`。
