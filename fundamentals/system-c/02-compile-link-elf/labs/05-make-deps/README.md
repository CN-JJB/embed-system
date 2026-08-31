# Lab 05 — Make Dependencies Are Observable Behavior

## Objective

通过实际 rebuild set 理解 target/prerequisite/recipe/variables/pattern rule/`.PHONY`/header dependencies，而不是背 Make syntax。

## Prerequisites

能读一个简单 Makefile；Lab 01 multi-file build。

## Environment

Linux/WSL；GNU Make 4.4.1；GCC 14.2.0。

## Estimated Time

50–65 min。

## AI Mode

AI-Free first rebuild experiment；GNU make/GCC docs allowed。

## Build

```sh
make clean
make
```

## Procedure

依次执行并记录真正运行的 recipes：

1. 第一次 `make`；
2. 不改任何东西再次 `make`；
3. `touch src/stats.c && make`；
4. `touch include/format.h && make`；
5. 查看 `build/*.d`。

Makefile 中逐项解释：

```make
OBJ = ...                 # variable
build/%.o: src/%.c ...    # pattern rule
.PHONY: all clean         # non-file goals
-MMD -MP                  # compiler emits user-header deps + phony header guards
-include $(DEP)           # Make consumes generated dependency files
```

不要把 flags 当 magic incantation：`-MMD` 让 GCC 生成 dependency info（排除 system headers 的常见 use）；`-MP` 生成 phony header targets，降低删除 header 后旧 `.d` 导致的 “No rule to make target” friction。

## Expected Observation

第一次全编；第二次 no-op；只改 `stats.c` 时重建 `stats.o` + relink；改 `format.h` 时，只有实际 include 它的 `main.o`/`format.o` 重建，再 relink。

## Actual Verification Status

**VERIFIED.** GNU Make 4.4.1 上实际观察：second run `Nothing to be done`; touching `src/stats.c` only recompiled `stats.o`; touching `include/format.h` recompiled `main.o` and `format.o`, not `stats.o`; `.d` files由 GCC 14.2.0 生成。

## Questions

1. target 为什么因 prerequisite timestamp/newness 变成 out-of-date？
2. recipe 是 shell command text 还是 dependency fact？
3. 为什么 header dependency 缺失会产生 stale object，而不一定产生 compiler error？
4. `.PHONY` 解决的是什么命名/目标语义问题？

## Failure Modes

用 `make clean && make` 掩盖 dependency bug；把 recipe 与 prerequisite 混为一谈；所有 header 修改都无条件 rebuild 全部 objects。

## Debug Strategy

只看 Make 实际打印了哪些 compile/link commands。遇到“改 header 但 behavior 不变”，先检查 `.d` 与 `make -n`，再改 source。

## Challenge

新建 `include/version.h` 只让 `main.c` include；观察正确 dependency generation 是否只重编 `main.o`。

## Cleanup

```sh
make clean
```

## Sources

GNU Make 4.4.1 manual; GCC 14.2 dependency options; chapter ledger。
