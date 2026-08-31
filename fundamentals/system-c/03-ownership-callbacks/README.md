# P1-M05 — Ownership, Pointer-to-Pointer, Callback, `void *ctx`

> Phase 1 / M05  
> Target: **L3**, with **L4-local** ownership/debug chains  
> AI mode: first fault diagnosis, Challenge, Gate, and D+7 reconstruction are **AI-Free**; standards/upstream source/docs are allowed.  
> Planned learner time: **5.5 h MUST**. REQUIRED external reading target: **~55–65 min**.

## Why

系统 C 的难点往往不是 pointer syntax，而是跨 API boundary 后的 contract：

```text
Who owns this object?
Who may mutate it?
Who may retain the pointer?
How long is it valid?
Who releases it?
What is the output state on partial failure?
What exactly does T ** mean in this API?
How long must callback context stay alive?
```

本课程用 **owned / borrowed / transferred / caller-owned / callee-owned** 作为 engineering reasoning vocabulary。它们不是 ISO C 内建的 ownership type system。

## Prerequisites

- M01 object/storage/lifetime/extent；
- M02 resource ownership/error boundary；
- 能读基本 struct/function pointer declaration。

## Mental Model 1 — lifetime ≠ ownership

一个 pointer 可以合法指向一个仍活着的 object，但 caller 未必拥有它；也可能“概念上是 owner”，却已经错误地结束了 object lifetime。

| Question | Meaning |
|---|---|
| lifetime | object 在这次访问时是否仍可合法存在/访问？ |
| ownership | 哪一方负责最终 release / cleanup？ |
| borrow | 暂时观察/使用，不获得 release responsibility |
| transfer | release responsibility 从一方移动到另一方 |
| shared observation | 多方都能看，不代表多方都能 `free` |

## Mental Model 2 — `T **` 只提供 caller-state mutation capability

```c
int frame_create(size_t len, struct frame **out);
```

本模块选定 contract：

```text
precondition: out != NULL && *out == NULL
success:      *out owns one valid frame
failure:      *out remains NULL
```

`T **` 本身**不表达** ownership transfer。它只让 callee 有能力修改 caller 的 pointer object；ownership/failure state 必须由 API contract 定义。

`frame_destroy(struct frame **p)` 是本模块为了训练 caller-state mutation 选的 API design，不宣称它是唯一正确 destroy signature。

## Mental Model 3 — callback behavior 与 context object 是两条线

```c
typedef int (*record_sink_fn)(
    const struct record *record,
    void *ctx
);
```

```text
function pointer → behavior
void *ctx        → state/object context
```

它们不是一种“万能 pointer”。本模块严格区分 **function pointer** 与 **object pointer / `void *`**。

Baseline callback contract：

- synchronous invocation；
- `record` is borrowed for the duration of the call only；
- callback must not retain `record *`；
- caller owns `ctx` unless API explicitly says otherwise；
- `ctx` lifetime must cover every callback invocation；
- callback return is propagated by dispatcher/emitter；
- during dispatch callback must **not** mutate registration set or destroy dispatcher。

## Minimal Theory

### 1. `void *ctx`

`void *` 没有运行时类型 metadata。Cast 只是告诉 compiler 你要按哪个 object type 访问；它不是 validation。Producer/caller 与 callback 必须共享 contract：

```c
struct stats_ctx stats = {0};
emit_records(stats_sink, &stats);
```

Stack context 完全可以合法，只要 callback invocation 都发生在 stack object lifetime 内；不能把 `&stats` 保存到更晚再调用。

### 2. allocate-and-return 与 partial failure

可靠 output contract 的重点是：失败后 caller 是否能确定 ownership state。

推荐 pattern：先在 local pointer 上完成 allocation/initialization；全部成功后才 publish 到 `*out`。失败时 local cleanup，`*out` 不被污染。

### 3. destroy-and-clear

```c
void frame_destroy(struct frame **p);
```

可以把：

```text
release owned object
+
mutate caller pointer to NULL
```

放在一个 selected API 中，方便训练 double-destroy safety contract。但这不是 C 语言要求；`frame_destroy(struct frame *)` 也可能是合理设计，只要 contract coherent。

### 4. callback error propagation

同步 callback 返回 nonzero 时，caller 必须定义：停止还是继续？本模块 baseline：**first nonzero stops dispatch and propagates unchanged**。这样 fault investigation 能把 symptom 追到 callback boundary。

### 5. callback mutation/reentrancy

本模块 baseline 明确禁止 dispatch 中 add/remove/destroy dispatcher。不是因为 C “做不到”，而是因为一个小 fixed-capacity dispatcher 需要明确 contract，避免 reviewer 用未声明行为评分。

## Experiment Map

| Lab | Boundary | Evidence |
|---|---|---|
| [01 Ownership Contract Audit](labs/01-ownership-audit/) | owned / borrowed / transferred | ownership table + runtime cleanup counters |
| [02 Pointer-to-Pointer](labs/02-pointer-to-pointer/) | success/failure output state | `*out` assertions + injected allocation failure |
| [03 Callback + `void *ctx`](labs/03-callback-ctx/) | behavior vs state | two distinct context objects, no globals |
| [04 Lifetime Failure](labs/04-lifetime-failure/) | callback retains borrowed pointer | ASan when available + semantic contract |
| [05 Integration Contract](labs/05-integration-contract/) | owned input → borrowed record → callback | ownership/lifetime table + stats |

## Official Source Walkthrough — WG14 N1570 baseline

教程 C semantic baseline 继续 pin **WG14 N1570**：

- §6.2.4 object lifetime/storage duration；
- §6.3.2.3 pointer conversions: object pointer ↔ `void *`；function pointer conversions are a separate rule；
- §6.5.2.2 function calls；
- §6.7.6.3 function declarators / pointer-to-function signatures。

重要边界：**不要声称 `void *` 是 function pointer 的 portable generic storage。** 本模块 callback function pointer 和 `void *ctx` 分开处理。

## Open-source Walkthrough — BusyBox `recursive_action()`

Pinned source family follows M02:

```text
BusyBox 1.38.0 release
exact-byte cross-check: maintainer mirror commit
fc71374dfccd46448c62947269a35f1420d7ee28
```

Guided paths：

- `include/libbb.h`：`recursive_state` 中 `void *userData` 与 `fileAction` / `dirAction` function pointers 是不同 members；
- `libbb/recursive_action.c`：public `recursive_action(..., fileAction, dirAction, userData)` 构造 local state，再同步递归调用 callbacks。

教学问题：

1. behavior pointer 与 user state 是如何分别 transport 的？
2. `userData` 谁拥有？source 是否自动帮你管理 lifetime？
3. local `recursive_state` lifetime 覆盖哪些 callback invocations？
4. callback return 如何影响 traversal status？

不要复制大量 BusyBox code；只定位 interface + state flow。

## Observation → Explanation

完成 labs 后应能解释：

- sanitizer silence 不能证明 ownership contract 正确；
- `const struct record *` 限制通过这个 access path 修改，不赋予 retain 权利；
- `T **` 不是 transfer annotation；
- callback + stack `ctx` 可以正确，也可以因为“保存以后用”变成 dangling；
- partial failure 最大风险之一是 publish 一个 caller 不知道该不该 free 的半初始化 pointer。

## Debug Workflow

```text
Symptom
↓
Own Description
↓
3–5 Hypotheses
↓
ownership/lifetime table
↓
experiment + sanitizer/watchpoint where useful
↓
Evidence
↓
Narrow Scope
↓
Root Cause (contract violation, not merely crash site)
↓
minimal fix
↓
Regression
```

## Common Misconceptions

| Misconception | Correction |
|---|---|
| pointer exists → object valid | pointer value may outlive object |
| `T **` means callee owns result | ownership comes from contract |
| `const T *` means callback may retain forever | const says mutation path, not lifetime |
| `void *` knows original type at runtime | no runtime type tag; cast is not validation |
| callback is only “advanced syntax” | callback crosses behavior/state/lifetime/error boundaries |
| two observers = shared ownership | shared observation can still have one owner |
| sanitizer passed = ownership correct | semantic retain/release rules may be invisible to sanitizer |

## Fault Injection

[`faults/`](faults/) covers:

- borrowed pointer freed by callee；
- dangling callback context；
- broken `T **` failure-state contract；
- callback retains a forbidden borrowed record pointer；
- partial initialization cleanup as an additional path。

## Challenge — Small Synchronous Record Dispatcher

[`challenge/`](challenge/) implements fixed-capacity callback slots only: no list, threads, locks, async dispatch, plugin framework, or event loop。

Canonical challenge contract：

- registration order = callback order；
- first callback nonzero stops emit and propagates；
- dispatcher borrows ctx and never frees it；
- record is borrowed for one `dispatcher_emit()` call；
- callbacks may not retain record pointer；
- callback set may not mutate during dispatch。

## Gate — Ownership Boundary Audit

[`gate/`](gate/) is **60–90 min AI-Free**. Before edits, draw ownership/lifetime table and write at least three hypotheses. Gate includes borrowed/owned confusion, broken output failure state, dangling callback ctx, and one semantic retain violation that sanitizer need not detect.

## Spaced Review

### D+1 — 10 min, AI-Free

Given five API signatures, annotate owner/borrower/lifetime/cleanup and explicitly write “unknown from type alone” where contract is missing。

### D+3 — 20 min, AI-Free

From memory implement `frame_create(size_t, struct frame **)` with failure leaves output NULL and a matching selected `frame_destroy(struct frame **)`。

### D+7 — 35–45 min, AI-Free

From empty file rebuild callback + ctx API with two contexts, write ownership table, then inject one forbidden retain bug and explain why sanitizer may or may not expose it。

## Career Relevance

```text
callback + ctx
→ driver callbacks
→ subsystem APIs
→ event handling
→ BSP abstraction boundaries
```

Userspace callback contracts are preparation for those patterns, not a claim that kernel driver callbacks have identical lifetime/reentrancy rules。

## Scope Boundary

No linked-list course, generic container framework, smart-pointer imitation, C++ RAII, threads/locks, async dispatch, ring buffer, serialization, sockets, event loops, or M09/M10 integration。

## Sources

Exact pins, paths, license/provenance, teaching questions, and version risk: [`SOURCE_LEDGER.md`](SOURCE_LEDGER.md).
