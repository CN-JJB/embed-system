# F13 — 用户态解引用内核地址 (Kernel-Address Deref) / 特权+翻译 Fault

**Family:** Memory space / privilege · **Introduced:** P3-M07 ·
**Gate competency:** Phase 3 Final Gate Part D（架构特权与 MMU）

> 这是 **worked tutorial fault**。假设链写出来是为了教诊断方法。
> Scored material（Challenge、Module Gate）从不预写假设，也不复用本 fault 的具体地址。

---

## 1. 机制 (Mechanism)

冻结切分（`CONFIG_VMSPLIT_3G=y`，`PAGE_OFFSET=0xC0000000`，`TASK_SIZE=0xBF000000`）把 4GB 虚地址一分为二：下半用户（`0x00000000–0xBEFFFFFF`），上半内核。用户态 (PL0, User mode) 的页表条目不允许解引用内核半区；访问 `>= 0xC0000000`（本 fault 演示 `0xC0008000`）触发翻译/权限 fault，内核以 `SIGSEGV` 交付给进程。候选程序见 `labs/07.3-kernel-boundary-fault/src/kfault.c`。

### 1.1 切分数字卡（冻结值，先背再用）

```text
CONFIG_VMSPLIT_3G=y  →  PAGE_OFFSET = 0xC0000000
TASK_SIZE = PAGE_OFFSET − 16M = 0xBF000000   （顶部 16M 为 module space）
用户教学范围 = 0x00000000–0xBEFFFFFF          （即 TASK_SIZE；不是 0xBFFFFFFF）
演示地址 = 0xC0008000                         （>= PAGE_OFFSET，内核半区）
```

有效配置以 effective `.config` 为准，不以注释为准。

## 2. 复现 (Reproduce)

```bash
arm-none-linux-gnueabihf-gcc -march=armv7-a -O0 -g -o kfault.elf labs/07.3-kernel-boundary-fault/src/kfault.c
./kfault.elf; echo "exit=$?"
```

## 3. 诊断链 (Diagnostic chain)

### Symptom（症状）

```text
VERIFIED — real capture on the CANONICAL Linux 6.18.50 guest
           (pinned commit 7cfc41f8…b79c7, built from the frozen Phase 3 config:
            CONFIG_ARM_LPAE=n, CONFIG_VMSPLIT_3G=y)
           actual-host qemu-system-arm 8.2.2, frozen machine contract
pid=47 attempting controlled read of 0xc0008000 (>= PAGE_OFFSET 0xC0000000)
caught SIGSEGV: userspace fault on kernel-range access (EXPECTED)
exit=42
```

### Own Description（自己的描述）

程序不是随机崩溃：每次都精确停在那一次受控读上，handler 接住 `SIGSEGV` 后按预期路径退出。问题在“这次访问的地址归属”，不在堆栈溢出或野指针漫游。

### 3–5 Hypotheses（假设）

1. 地址常量写错，实际访问的是用户半区野指针。
2. 切分假设错：当前内核不是 `VMSPLIT_3G`，`0xC0008000` 另有归属。
3. 权限边界机制：PL0 解引用内核半区被翻译/权限拒绝（候选根因）。
4. 二进制传错：在主机上跑了另一个 `kfault`，观测与候选不一致。
5. 信号行为被误读：`SIGSEGV` 来自 handler 之前的栈破坏，而非这次读。

### Experiment（实验）

```bash
# 地址归属：常量是否真在内核半区？
grep -n "KFAULT_DEMO_ADDR" labs/07.3-kernel-boundary-fault/src/kfault.c
# 切分有效性：读有效内核配置（effective frozen config，不是注释）
grep -E "CONFIG_VMSPLIT_3G|CONFIG_PAGE_OFFSET|CONFIG_ARM_LPAE" <effective .config>
# 用户半区对照：maps 里有无内核半区行？
cat /proc/self/maps | grep -i c000 || echo "no kernel-half line (EXPECTED)"
# 二进制身份：是否真在目标上跑的这个候选？
file ./kfault.elf
```

### Evidence（证据）

```text
VERIFIED（本机实测，canonical Linux 6.18.50 客机）
#define KFAULT_DEMO_ADDR ((volatile unsigned char *)0xC0008000UL)
CONFIG_VMSPLIT_3G=y                       （冻结配置；该次启动 cr=10c5387d → TRE=1, AFE=0）
no kernel-half line in /proc/self/maps    （EXPECTED：maps 只展示用户半区）
kfault.elf: ELF 32-bit LSB executable, ARM, EABI5
caught SIGSEGV: userspace fault on kernel-range access (EXPECTED)
exit=42
```

`dmesg`（如能捕获）只做存在性检查，不匹配固定字符串（内核日志文本仍 **UNVERIFIED**：本机未做 `dmesg` 文本捕获）。
运行维度边界：内核为 **canonical 6.18.50**，但 QEMU 为 **actual-host 8.2.2** → `canonical QEMU 11.1.1 runtime: UNVERIFIED`。

### Narrow Scope（缩小范围）

* 常量确为 `0xC0008000`，`>= PAGE_OFFSET`——假设 1 出局。
* 有效配置确为 `VMSPLIT_3G`——假设 2 出局。
* ELF 确为 ARM target 且在目标上运行——假设 4 出局。
* fault 地址与 handler 路径精确对应，无栈破坏迹象——假设 5 出局。剩下假设 3。

### Root Cause（根因）

进程虚地址 (process VA) `0xC0008000` 落在冻结内核半区；PL0 权限不允许该映射的解引用；MMU 翻译/权限检查 fault，内核交付 `SIGSEGV`。“地址看起来很大”只是表象，切分值 + 权限边界才是证明。

### Fix（修复）

本 fault 是教学演示，不存在“让用户态读内核”的正确修复。正确动作是**不读**：把待测逻辑改成访问用户半区，或经 `svc` 请内核代劳。回归标准是原候选每次都走 handler 路径，而修正后的程序不再 fault。

### Regression（回归）

```bash
./kfault.elf; echo "exit=$?"
# EXPECTED: exit=42 且 handler 行出现（ILLUSTRATIVE，未执行见 §4）
```

## 4. Observation / Interpretation / Non-Proof

* **Observation（观察）：** 进程收到 `SIGSEGV`，handler 路径退出；maps 无内核半区行。
* **Interpretation（解释）：** 用户虚地址越过 `PAGE_OFFSET`，PL0 权限拒绝。
* **Non-Proof（非证明）：** 不证明该虚地址背后有/无物理页；不证明任意内核物理内存内容；不证明某行固定 `dmesg` 文本。

目标运行与日志捕获：**UNVERIFIED**。

## 5. Transfer to the Final Gate

Gate 用 unfamiliar 变体：不同地址、不同证据组合，不 replay 本 fault 的 `0xC0008000`。方法迁移，答案不迁移。
