# Lab 03 — ASan / UBSan: Evidence, Not Proof

## Objective

对 OOB、dangling/use-after-free、signed arithmetic UB 做四步比较：**预测 → normal run → sanitizer run → 解释 sanitizer 的证明边界**。

## Prerequisites

M01 object/extent/lifetime/UB；会读基本 runtime diagnostic。

## Environment

Linux / WSL-compatible；GCC with AddressSanitizer / UndefinedBehaviorSanitizer runtime；GNU Make。

## Estimated Time

45–60 min。

## AI Mode

第一次 fault diagnosis：**AI-Free**；看完自己的 hypothesis/evidence 后才可 AI-Hint。

## Build

```sh
make clean && make
```

## Procedure

每个 case 都先写预测，**不要一次跑完再补预测**。

### Fault A — OOB

```sh
./faults-normal oob
./faults-asan oob
```

### Fault B — dangling / use-after-free

```sh
./faults-normal dangling
./faults-asan dangling
```

### Fault C — signed overflow / shift UB

```sh
./faults-normal signed-overflow
./faults-ubsan signed-overflow

./faults-normal signed-shift
./faults-ubsan signed-shift
```

记录：normal execution 是否退出、打印了什么；sanitizer 的 fault class、source location、stack evidence 是什么。

## Expected Observation

- normal run **可能**继续运行、打印垃圾值或表现不同；这不赋予 UB 合法语义；
- ASan 针对 instrumented memory accesses，可检测这里的 heap OOB/use-after-free；
- UBSan 针对已启用的 UB instrumentation，可分别报告这里的 signed overflow 与 invalid signed shift；
- sanitizer 只说明本次 instrumented execution 中被覆盖/触发的检查。**ASan 没报错 ≠ 程序正确。**

## Actual Verification Status

**VERIFIED** with GCC 14.2.0：三个 binaries 已实际 build；ASan 已实际检测 OOB 与 use-after-free；UBSan 已实际检测 signed overflow 与 invalid signed shift。normal-run 结果只用于对照，不作为正确性证据。

## Questions

1. normal run “成功退出”能证明什么？不能证明什么？
2. ASan report 中哪部分证明了 invalid access 与 allocation lifetime 的关系？
3. 为什么逻辑上的 wrong extent 可能不触发 ASan？
4. UBSan 的一个干净 run 能否证明所有 C UB 都不存在？为什么？

## Failure Modes

- 只截图红色报错，不解释 object/extent/lifetime；
- 把 sanitizer 当成完整形式化证明；
- 一看到 fault 就直接改代码，不先记录 hypothesis。

## Debug Strategy

先按 diagnostic 的 source location 建立 hypothesis，再用 GDB（环境可用时）`bt` / `frame` / `info locals` / `x` 看现场。不要把“加 sanitizer flag”当成唯一 Debug 方法。

## Challenge

写一个 **ASan 不应直接报错** 的 logical-extent bug：allocation 16 bytes，但 API contract 只有前 4 bytes 有效；错误地把 `len=16` 传给 consumer，而 consumer 仍只访问 allocation 内。解释为什么 memory safety instrumentation 与 semantic extent contract 不等价。

## Cleanup

```sh
make clean
```

## Sources

- GCC Instrumentation Options；
- WG14 N1570 signed arithmetic / shift 相关条款；
- 本章 [SOURCE_LEDGER.md](../../SOURCE_LEDGER.md)。
