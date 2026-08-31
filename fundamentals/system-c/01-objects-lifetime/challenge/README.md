# Challenge — `span_u8`: Make Extent Explicit

**Objective:** 实现一个很小的 non-owning byte span，让 pointer、extent、bounds 与 ownership contract 同时可见。  
**Prerequisites:** M01 Labs 01–04。  
**Environment:** Linux/WSL, GCC, GNU Make。  
**Estimated Time:** 35–45 min。  
**AI Mode:** 第一次实现 **AI-Free**；official docs allowed。

## Contract

`struct span_u8` **borrow** 底层 storage；它从不 `malloc/free`。实现 `make/slice/copy/compare`：

- `len == 0` 时允许 `data == NULL`；`len > 0` 时 `data` 必须 non-NULL；
- `slice` 必须避免 `offset + len` overflow：优先用 `offset <= src.len && len <= src.len - offset`；
- `copy` 只有在 destination extent 足够时成功，并写出 `copied`；底层区域可能 overlap，因此选择符合 contract 的 copy primitive；
- `compare` 做 lexicographic byte comparison，公共前缀相同后再比较 length。

## Build / Procedure

```sh
make clean && make
./test_span
```

starter 会编译但 tests 预期失败；这是题目，不是 VERIFIED solution。先补自己的 edge cases：empty span、zero-length slice、one-past empty slice、insufficient destination、prefix comparison。

## Expected Observation

一个 pointer value 单独不足以验证访问；一旦 API 同时传递 `data + len`，bounds contract 才能在接口层被检查。但 `span_u8` 仍不证明 pointed-to object lifetime，也不拥有 storage。

## Actual Verification Status

**VERIFIED (reference solution only)** on GCC 14.2.0。learner starter intentionally incomplete；reviewer solution 已实际通过 `test_span`。

## Questions / Failure Modes / Debug Strategy

1. 为什么 `offset + len <= src.len` 是不理想的 overflow check？
2. `data == NULL, len == 0` 为什么可以作为 empty view，而不能被 dereference？
3. 哪一层负责保证底层 object 在 span 使用期间仍 alive？

若 test fail，先定位是哪条 contract 被违反；再用 GDB `break span_u8_slice`, `print offset`, `print len`, `print src.len`（当前 authoring 环境未安装 GDB，命令路径 **UNVERIFIED**）。

## Challenge Extension

写出 API comment，逐函数标注输入是 borrowed 还是 output value，以及 failure 是否修改 `*out` / `*copied`。

## Cleanup / Sources

```sh
make clean
```

Sources: WG14 N1570 selected pointer/additive rules；本章 `SOURCE_LEDGER.md`。Hints/solution 在 `../reviewer/`，第一次实现前不要打开。
