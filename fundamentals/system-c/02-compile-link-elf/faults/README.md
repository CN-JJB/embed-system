# P1-M03 Fault Campaign — Linkage / Symbol / Dependency Failures

> **AI-Free first diagnosis.** Official GCC/binutils/Make docs allowed.  
> Build: `make f1`, `make f2`, `make f3`; F4 lives under `f4/`.

每个 fault 必须提交：

```text
Symptom
Hypotheses
Evidence
Root Cause
Fix
Regression
```

不要只贴 linker error；至少把 source hypothesis 与 binary/build evidence 串起来。

## F1 — Undefined Reference

```sh
make clean
make f1
nm build/f1/main.o
readelf -r build/f1/main.o
```

**Seeded symptom (VERIFIED):** final link reports `undefined reference to missing_calibration`; object build succeeds。证明 `main.o` 中是 unresolved reference，说明“有 declaration/call”与“有 linkable definition”不是一回事。

Fix 后 regression：clean build + run + `nm` 证明 provider definition 存在。

## F2 — Multiple Definition

`f2/config.h` 故意把 storage definition 放进 header；两个 translation units include 后各产生 global definition。

```sh
make f2
nm build/f2/a.o build/f2/b.o | grep shared_mode
```

**Seeded symptom (VERIFIED):** GNU ld 2.44 报 `multiple definition of shared_mode`，指出 `a.o` 与 `b.o`。修复应建立“一处 definition + header declaration”的 coherent boundary，而不是随便把其中一份改名。

## F3 — Wrong Linkage

provider 将本该 external 的 `exported_reading` 定义为 file-scope `static`。

```sh
make f3
nm build/f3/main.o build/f3/provider.o | grep exported_reading
readelf -s build/f3/provider.o | grep exported_reading
```

**Seeded symptom (VERIFIED):** `main.o` needs symbol，provider object 只有 local definition，final link unresolved。Root cause 是 API boundary/linkage，不是“linker 没找到 source file”。

## F4 — Stale / Missing Header Dependency

```sh
cd f4
make clean && make
./stale_demo
# config.h starts SCALE=2 → scaled=10
```

把 `SCALE` 改成 `7` 后直接：

```sh
make
./stale_demo
```

**Seeded symptom (VERIFIED):** Make 说 `Nothing to be done`; program 仍 `scaled=10`。clean rebuild 后变成 `scaled=35`。这说明 bug 是 dependency graph 缺 header edge，不是 compiler caching magic。

Fix：让 object target 正确依赖 header（手写 prerequisite 或生成 `.d`）；regression 必须证明以后改 header 会自动重建相关 `.o`。

## Debug discipline

- linker diagnostic → 哪些 object/name？
- `nm/readelf -s` → definition 是 LOCAL/GLOBAL/UND？
- `readelf -r` → 哪个 object 有 pending reference？
- Make output / `.d` → dependency edge 是否存在？

不要用“全删 build directory”作为最终 fix；它只能暂时掩盖 F4。
