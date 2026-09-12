# Lab 7.4 — Short-Descriptor 翻译 + 内存属性 Fixture (Descriptor Decode)

**Time:** ~60 min MUST。**Prerequisite:** Lab 7.1；README §6 的描述符速查；QEMU 内存概念（DRAM `0x40000000`，PL011 `0x09000000`）。

---

## 1. 目标 (Objective)

在一个**确定性的受控描述符 fixture**（不是危险的 live 内核修改）上解码有界的 ARMv7 short-descriptor 例子：section/coarse-table 区分、small-page 映射、访问权限/用户可达性、以及区分 taught Normal 与 Device 所需的 TEX/C/B/S 字段。最后把模型概念性地连到 QEMU DRAM vs PL011 MMIO。

## 2. 前置知识 (Prerequisites)

* L1 `bits[1:0]`：`00` fault，`01` 页表指针（`base[31:10]`，仅 domain+NS），`10` section/supersection（bit18 区分），`11` PXN-section-or-reserved（冻结 Linux 不发射）。
* L2：`00` fault，`01` large page（Linux 不发射），`0b1x` small page——**bit0 就是 XN 位**（`0b10` XN=0，`0b11` XN=1），`base[31:12]`；L2 无 domain。
* AP 表（AFE=0，B3-8）：`0,00` none；`0,01` PL1-RW/PL0-none；`0,10` PL1-RW/PL0-RO；`0,11` RW；`1,00` Reserved；`1,01` PL1-RO；`1,10` RO deprecated；`1,11` RO。
* 内存类型（`n={TEX0,C,B}`，本 fixture 假设 `TRE=1,AFE=0,PRRR=0xff0a81a8,NMRR=0x40e040e0,DACR=Client`）：`111` Normal WBWA Inner-Shareable；`100` Device Shareable；`011` Normal WB-noWA；`001` Normal NC；`000` Strongly-ordered；`110` IMPLEMENTATION-DEFINED → 必须 REJECT。`TEX[2:1]` 在 TRE=1 下被 HW 忽略；Normal 上 `S=0` 仍是 Normal（UP 策略），不得硬要求 `S=1`。

## 3. 环境与版本 (Environment)

* 权威：ARM DDI 0406C；Linux 6.18.50 pgtable 头（`pgtable.h:35-39`，`pgtable-2level.h:12-69`，`L_PTE_*` 119-127，MT 165-176，`PTE_EXT_*`/`PMD_SECT_*`）。
* Fixture：`fixtures/descriptor_taught.json`（deterministic，NOT live kernel state）。本机 live 观察 **UNVERIFIED**。

## 4. 步骤 (Procedure)

1. 读 `fixtures/descriptor_taught.json` 的 `assumptions` 戳，确认六元组后再解码。
2. 手工解 `(L1,0x4001140E)`：定类（`0b10` section，bit18=0）→ 基址 `base[31:20]` → AP/TEX/C/B/S/nG/XN/domain → `n` 查表 → 内存类型与可执行性。
3. 手工解 `(L2,0x09000453)`：定类（`0b1x` small page，bit0=XN=1）→ 基址 `base[31:12]` → 同上（无 domain）。
4. 对第三项给出 `EXPECTED-REJECT`  verdict 与理由（L1 `0b11`，冻结 Linux 不发射）。
5. 写出 DRAM vs MMIO 的概念连线（一句话即可，见 §5）。

### 4.1 AP 速查（AFE=0，ARM DDI 0406C 表 B3-8）

| AP[2:1],AP[0] | PL1 | PL0 | 备注 |
|---|---|---|---|
| `0,00` | none | none | 无访问 |
| `0,01` | RW | none | **PL1-only**（两个 golden 都是它） |
| `0,10` | RW | RO | — |
| `0,11` | RW | RW | — |
| `1,00` | — | — | Reserved（见到即 REJECT） |
| `1,01` | RO | none | PL1 只读 |
| `1,10` | RO | RO | deprecated |
| `1,11` | RO | RO | 只读 |

### 4.2 内存类型速查（`n={TEX0,C,B}`，本 fixture 假设下）

| n | PRRR/NMRR 解码 | Shareability |
|---|---|---|
| `111` | Normal WBWA | Inner Shareable |
| `100` | **Device** | Shareable |
| `011` | Normal WB-noWA | — |
| `001` | Normal NC | — |
| `000` | Strongly-ordered | — |
| `110` | IMPLEMENTATION-DEFINED | → 必须 REJECT |

### 4.3 L1/L2 类位速查

```text
L1 bits[1:0]: 00 fault | 01 page-table ptr (base[31:10], domain+NS only)
              10 section (bit18=0, base[31:20]) / supersection (bit18=1, base[31:24], 16MB, domain 0)
              11 PXN-section-or-reserved (frozen Linux never emits → REJECT)
L2 bits[1:0]: 00 fault | 01 large page (Linux never emits → REJECT)
              0b1x small page, bit0 IS XN (0b10 XN=0 / 0b11 XN=1), base[31:12], NO domain
```

## 5. 预期可观察现象 (Expected observable)

* `(L1,0x4001140E)` = Section @`0x40000000`，AP=001（PL1-only），TEX=001/C=B=1，S=1，nG=0，XN=0，Domain 0 → Inner Shareable Normal WBWA，可执行，global。概念连线：QEMU DRAM。
* `(L2,0x09000453)` = small page XN=1 @`0x09000000`，AP=001，TEX=001/C=B=0，S=1 → Shareable Device，PL1-only，XN。概念连线：PL011 MMIO，必须 Device（不可缓存、保副作用、保序）。
* 第三项：`EXPECTED-REJECT`（L1 `0b11` 非教学映射类）。
* 全程是纸面/fixture 解码：**不声称 live 内核用过该描述符**。如加 SHOULD 的 live QEMU/GDB 页表观察，必须另起证据并绑定实际 kernel/runtime。

## 6. 验证方法 (Verification)

1. 两个 golden 的九元组（类/基址/AP/`n`/内存类型/shareability/XN/nG/domain 或无 domain 声明）全对。
2. `110` 与 L1 `0b11` 能正确 REJECT；工具自身失败报 ERROR，不与语义 REJECT 混淆。
3. 能说出 `TEX[2:1]` 忽略与 `S=0` 仍 Normal 两条 UP 规则。

## 7. 典型失败模式 (Failure modes)

* 把 L2 `0b11` 当“保留”拒掉——L2 `0b1x` 都是 small page，bit0 是 XN，不是类位。
* 给 L2 编造 domain——L2 无 domain 字段。
* 用 `TEX=001` vs `101` 争出不同内存类型——TRE=1 下 `TEX[2:1]` 被 HW 忽略，只看 `TEX0`。
* 把 `S=0` 的 Normal 判成 Device——S 只记录，不做 Normal 判决。
* 套用 x86 风格的页面标志宏——该系列符号在 ARM 树中零命中；冻结教学只用 `L_PTE_*` / `PMD_SECT_*` / `PTE_EXT_*`。

## 8. 调试策略 (Debug strategy)

解码卡住时按位重走：先 `bits[1:0]` 定类，再基址，再 AP，再 `n`，再 XN/nG/S/domain。每步把位值写出来，不要心算跳步；`n` 查表错了就回到 `TEX0/C/B` 三位重组。

## 9. 证据状态

Fixture 静态语义：**VERIFIED**（写作完成）。目标编译、live QEMU/GDB 页表观察：**UNVERIFIED**。本实验不产生 live 页表证据。

## 10. 扩展挑战 (Extension, SHOULD)

构造一个“地址对、权限对、但内存类型错”的 MMIO 变体（如把 `0x09000453` 的 `C/B` 改成 Normal），预测外设行为风险（合并/重排/推测），并说明为什么修复必须改字段而不是改地址。这是 F14 的家族，但不得复用 scored 变体的具体值。
