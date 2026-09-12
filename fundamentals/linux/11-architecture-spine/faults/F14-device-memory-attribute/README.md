# F14 — Device 内存属性错配 (Device-Memory Attribute Mismatch, Controlled Fixture)

**Family:** Architecture / memory attributes · **Introduced:** P3-M07 ·
**Gate competency:** Phase 3 Final Gate Part D（内存属性与排序）

> 这是 **worked tutorial fault**。全部推理在受控描述符 fixture 上完成，
> **绝不要求修改 live 内核页表**。Scored 变体不复用本 fault 的具体字段值。

---

## 1. 机制 (Mechanism)

地址映射正确 ≠ 内存语义正确。MMIO（如 PL011 `0x09000000`）必须用 Device Memory（不可缓存、保留副作用、保序）；配成 Normal Memory（可缓存、可推测）会导致访问合并/重排/推测，外设行为错乱。本 fault 的载体是 `fixtures/descriptor_taught.json` 的 L2 small-page 条目，假设戳 `TRE=1,AFE=0,PRRR=0xff0a81a8,NMRR=0x40e040e0,DACR=Client`。

### 1.1 字段位置卡（L2 small page，`0b1x`）

```text
raw  = 0x09000453 = ...0100 0101 0011
bit0 = 1 ........... XN（bit0 就是 XN 位；0b11 即 XN=1）
bit[1] = 1 ......... 类位（0b1x = small page）
bit[2] = B = 0 ..... Bufferable
bit[3] = C = 0 ..... Cacheable
bit[5:4] = AP[1:0] = 01, bit[9] = AP[2] = 0 → AP = 001（PL1-only）
bit[8:6] = TEX = 001 → n = {TEX0,C,B} = 100 → Shareable Device
bit[10] = S = 1 .... Shareable（记录；不做 Normal 判决）
bit[11] = nG = 0 ... global
bit[31:12] = base = 0x09000 → 0x09000000（PL011 MMIO 概念地址）
无 domain 字段 ..... L2 没有 domain，不要编造
```

## 2. 复现 (Reproduce)

取 taught L2 条目 `(L2,0x09000453)` 的正确解（Shareable Device，见 Lab 7.4），构造它的错配孪生：地址、`AP=001`、`XN=1` 保持不变，仅把 `TEX/C/B` 从 `001/0/0`（`n=100` Device）改成 `001/1/1`（`n=111` Normal WBWA）。该孪生是纸面 fixture，不写入任何页表。

## 3. 诊断链 (Diagnostic chain)

### Symptom（症状）

```text
EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED
UART 行为异常：轮询发送偶发丢字节/乱序，而地址 0x09000000 与权限 AP=001 看起来都对。
（本 fault 无需真实外设故障；症状是纸面设定的教学起点。）
```

### Own Description（自己的描述）

地址对、权限对，但语义错：这是一个属性 fault，不是映射 fault。排查方向是 `TEX/C/B/S` 字段，而不是基址。

### 3–5 Hypotheses（假设）

1. 基址错：根本没指到 `0x09000000`。
2. 权限错：`AP` 把 PL0/PL1 搞反，导致 fault 而非行为异常。
3. 类错：L2 `bits[1:0]` 不是 small page，解码前提错。
4. 属性错：`n={TEX0,C,B}` 解出 Normal，MMIO 被当普通可缓存内存（候选根因）。
5. 工具错：decoder 自身崩溃报 ERROR，被误读成语义 REJECT。

### Experiment（实验）

```text
1. 读 bits[1:0]：0b11 → L2 small page（类成立，假设 3 出局）。
2. 读 base[31:12]：0x09000 → 0x09000000（地址成立，假设 1 出局）。
3. 读 AP：001 → PL1-only（权限成立，假设 2 出局；且 L2 无 domain，不编造）。
4. 组 n={TEX0,C,B}：错配孪生 n=111 → PRRR/NMRR 查表得 Normal WBWA（假设 4 命中）。
5. 确认工具退出码：正常输出 verdict，无崩溃（假设 5 出局）。
```

### Evidence（证据）

```text
L2 raw=0x09000453 taught   : n=100 → Shareable Device, AP=001, XN=1 (ACCEPT)
L2 twin (C=B=1)            : n=111 → Normal WBWA (ATTRIBUTE MISMATCH for MMIO)
bit0 IS XN; L2 has NO domain; TEX[2:1] ignored under TRE=1; S recorded, not decisive.
```

### Narrow Scope（缩小范围）

地址、权限、类、工具行为四项全部 healthy，唯一分歧是 `C/B` 两位决定的 `n`。范围收缩到内存类型字段，与 Phase 2 的 MMIO 直觉衔接：外设副作用不能被缓存/合并。

### Root Cause（根因）

MMIO 映射用了 Normal 可缓存属性。正确语义是 Shareable Device（`n=100`）；`n=111` 的 Normal WBWA 对 DRAM 正确、对 MMIO 错误。`S` 位不参与此判决（UP 策略）。

### Fix（修复）

把孪生的 `C/B` 改回 `0/0`（回到 `n=100` Shareable Device），保持地址/AP/XN 不变。修复必须改字段，不改地址——改地址是换话题，不是修属性。

### Regression（回归）

* taught 条目 verdict `ACCEPT`（Device，PL1-only，XN）。
* 错配孪生 verdict `ATTRIBUTE MISMATCH`（或等价语义拒绝），且 `110` / L1 `0b11` 类输入仍 `EXPECTED-REJECT`。
* 工具崩溃报 `ERROR`，不与上述语义 verdict 混淆。

## 4. Observation / Interpretation / Non-Proof

* **Observation（观察）：** 地址/AP/XN 相同，仅 `C/B` 不同即翻转内存类型判决。
* **Interpretation（解释）：** Device 语义保护 MMIO 副作用与顺序；Normal 语义为 DRAM 吞吐而生。屏障（`DMB`/`DSB`/`ISB`）概念见 README §5.5，本 fault 不做屏障 API 教学。
* **Non-Proof（非证明）：** fixture 判决不证明 live 内核用过该描述符；不证明任何真实外设故障波形。

Fixture 静态语义：**VERIFIED**（写作完成）；live 页表/GDB/运行时：**UNVERIFIED**。

## 5. Transfer to the Final Gate

Gate 用 unfamiliar 属性变体：不同地址、不同错配字段组合。判分看字段级 Normal vs Device 推理，不看是否背出本 fault 的 `0x09000453`。
