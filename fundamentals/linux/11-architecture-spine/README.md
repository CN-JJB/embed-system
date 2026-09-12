# P3-M07 — Architecture Spine: 特权级 (Privilege), 系统调用陷入 (Syscall Trap), MMU 与地址翻译 (Address Translation)

**Time budget:** 3.5 h MUST（Lab 7.1 ~50 min / 7.2 ~55 min / 7.3 ~45 min / 7.4 ~60 min）
**Prerequisites:** P3-M02（内核构建与启动）、P3-M03（rootfs / PID 1）、P3-M04（QEMU 启动）
**Platform:** ARMv7-A / Cortex-A7，QEMU `virt,highmem=off,gic-version=2`，Linux 6.18.50，`CONFIG_ARM_LPAE=n` + `CONFIG_VMSPLIT_3G=y`

---

## 1. Why（为什么需要这一章）

前面的模块已经让电器工作起来，但没有回答它*为什么是安全隔离的*：用户程序 (userspace) 如何受控地进入内核 (kernel)？虚地址 (virtual address) 如何变成物理地址或设备寄存器访问？为什么用户态碰一下高地址就会 fault？本模块是整条 Phase 3 的架构脊柱 (architecture spine)：

```text
userspace → svc trap → privileged kernel entry → virtual address
  → short-descriptor page-table translation → TLB → physical/device mapping
  → Normal vs Device memory semantics
```

这不是 ARM 全集课程，也不是 Linux `mm/` 深水区：只讲能解释进程隔离与 OS 控制的最小闭环。

---

## 2. 学完你能做什么 / 不做什么

* 区分 User mode / PL0 与特权内核执行 / PL1，解释 `svc` 是异常陷入 (exception/trap)，不是普通函数调用。
* 用 ARM EABI 约定讲清一个确定性例子：`r7` = syscall number，`svc #0`，返回值经 `r0`。
* 讲清异常向量 (exception vector) / 内核入口 (kernel entry)、内核栈与保存的用户寄存器上下文 (saved register context) 的概念层模型。
* 区分虚地址与物理地址，用 `/proc/<pid>/maps` 做用户半区映射证据，且明确它**不证明**物理地址。
* 讲清冻结切分：`PAGE_OFFSET=0xC0000000`，`TASK_SIZE=0xBF000000`（顶部 16M 为 module space），用户教学范围是 `0x00000000–0xBEFFFFFF`。
* 在 `CONFIG_ARM_LPAE=n` 下讲 short-descriptor 两级翻译：L1（一级表）/ L2 coarse table / 4 KiB small page，并区分**硬件描述符格式**与 Linux 软件页表封装。
* 讲清 TLB 的作用：翻译缓存 (translation caching)，上下文切换为什么需要翻译维护。
* 讲清访问权限 (access permission) / user-vs-kernel 映射，以及 Normal Memory vs Device Memory：可缓存性/推测 (cacheability/speculation)、副作用保留 (side-effect preservation)、排序与屏障 (ordering/barrier, `DMB`/`DSB`/`ISB` 概念区分）。

**Explicitly out of scope:** ARMv8/AArch64、LPAE 表、`mm/` 深实现、demand paging、调度器、驱动/`ioremap()`、cache API  survey、推测执行安全研究、物理板 MMU bring-up。

---

## 3. Canonical platform contract（不要 silently 更改）

| Component | Canonical | Identity |
|---|---|---|
| Linux | **6.18.50 LTS** | tag `v6.18.50`，peeled `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7` |
| QEMU | **11.1.1** | tag `v11.1.1`，peeled `c3d48b7d1e89604920e5b81b91140c2ad39a1943` |
| Machine | `virt,highmem=off,gic-version=2` | `cortex-a7`，`-m 512M`，`-smp 1`，`-nographic` |
| Config | `CONFIG_ARM_LPAE=n` + `CONFIG_VMSPLIT_3G=y` | short-descriptor，`PAGE_OFFSET=0xC0000000` |
| Toolchain | Arm GNU 13.3.rel1 `arm-none-linux-gnueabihf-` | Lab 交叉编译基线 |
| Arch docs | ARM DDI 0406C.d + DEN 0013D | short-descriptor / 屏障的权威依据 |

---

## 4. Layout

```text
11-architecture-spine/
  README.md                  this file
  SOURCE_LEDGER.md           pins、执行了什么、证据状态、stale 修正
  Makefile                   all / check / clean + opt-in heavy paths
  .gitignore                 锚定忽略（/build/ /challenge/build/ /gate/build/ *.elf *.o *.log *.argv *.provenance）
  labs/07.1-proc-address-space/     Lab 7.1（~50 min）
  labs/07.2-svc-syscall-trace/      Lab 7.2（~55 min）
  labs/07.3-kernel-boundary-fault/  Lab 7.3（~45 min）
  labs/07.4-short-descriptor-decode/ Lab 7.4（~60 min）
  faults/F13-kernel-address-deref/  worked tutorial fault
  faults/F14-device-memory-attribute/ worked tutorial fault
  fixtures/                  maps_sample.txt | descriptor_taught.json | svc_reference.disasm
  scripts/                   learner-safe semantic checkers（svc / maps / binding / descriptor）
  challenge/                 AI-Free 迁移练习 starter（unfamiliar 变体）
  gate/                      Module Gate starter（combined）
  reviewer (directory)       reviewer-only oracle、hidden seeds、mutation suites；learner 工作流永不调用
```

Learner workflow 只用 `make check` 与各 lab/challenge/gate 自己的 `make`。Reviewer-only authoring regression（`make reviewer-check`）不在 learner 路径上，且由 isolation audit 保证 learner 材料不依赖它。

序列级入口在 `fundamentals/linux/Makefile`：`check`（含 M07）、`mutations`、`reviewer-check`、`real-m07-arch-check`。

---

## 5. Mental model（一页心智模型）

### 5.1 特权与陷入：`svc` 不是调用，是陷阱门

用户态 (PL0) 没有权限执行特权操作。`svc #0` 产生同步异常，CPU 切到 Supervisor / PL1，按向量表进入内核入口。EABI 约定把系统调用号放在 `r7`（本模块冻结例子：`__NR_getpid=20`），参数/返回值走约定的寄存器。内核保存 `r0–r12` 与 banked `sp/lr` 后查表分发，返回经 `ret_fast_syscall` 恢复上下文，以 `movs pc,lr` 回到用户态。

### 5.2 地址空间：一半用户，一半内核，但只有一半对你可见

冻结切分 `VMSPLIT_3G` 下 `PAGE_OFFSET=0xC0000000`，`TASK_SIZE=PAGE_OFFSET−16M=0xBF000000`。教学时用户范围写 `0x00000000–0xBEFFFFFF`（即 `TASK_SIZE`），**不要**写成 `0xBFFFFFFF`。`/proc/<pid>/maps` 只展示用户半区的虚拟映射；高地址不存在于该文件中是**预期的**，不是缺失。

### 5.3 TTBR 修正（CRITICAL，必须按此教）

不要教普适的“`TTBR0`=user / `TTBR1`=kernel”。冻结 Linux 的事实是：`proc-v7-2level.S:36-37` 声明不使用 split page tables；`cpu_v7_switch_mm` 只写 `TTBR0`（`mcr c2,c0,0`）加 `CONTEXTIDR`；`TTBCR=0` 意味着 `TTBR0` 横跨 4GB；每进程 `pgd` 通过 `pgd.c:46-47` 的 `memcpy` 复制内核半区。正确模型：**每个进程一张驻留在 `TTBR0` 的表（用户条目 + 复制来的内核条目）；`TTBR1` 在 boot 时装载但 `N=0` 时不用**。详见 `SOURCE_LEDGER.md` §修正与 reviewer-note 指针。

### 5.4 翻译与 TLB：查表贵，所以缓存

short-descriptor 是两级硬件 walk：L1 决定 section（1MB）还是指向 L2 coarse table；L2 决定 4 KiB small page。TLB 缓存翻译结果；进程切换 (`switch_mm`) 必须做翻译维护，否则旧翻译污染新进程。dirty/young 在 ARM 上经 fault 模拟，不要套用 x86 风格的页面标志命名——该系列符号在 ARM 树中零命中，冻结教学只用 `L_PTE_*` 与 `PMD_SECT_*`/`PTE_EXT_*`。

### 5.5 Normal vs Device：同一地址映射，语义完全不同

DRAM 用 Normal Memory：可缓存、可推测，追求吞吐。MMIO（如 `0x09000000` PL011）必须用 Device Memory：不可缓存、保留副作用、保序。把 MMIO 误配成 Normal 会导致访问合并/重排，外设行为错乱——这正是 F14 的家族。屏障概念：`DMB` 约束访存序，`DSB` 要求完成，`ISB` 冲刷流水线，本模块只到概念区分深度。

---

## 6. 源码导读（bounded source reading，先冻结再教）

系统调用路径（Linux 6.18.50）：`arch/arm/kernel/entry-armv.S` 向量表（`+0x08` 槽：`:1085`/`:1086` 的 `R_ARM_LDR_PC_G0`/`R_ARM_THM_PC12` 重定位指向 `.L__vector_swi:934`，而槽内实际指令是 `:1087` 的 `W(ldr) pc, .` —— **不是 `b vector_swi`**；该槽用 PC 装载走字面量，因为 `.stubs` 段可能超出分支范围）→ `arch/arm/kernel/entry-common.S:171 ENTRY(vector_swi)`（先存 `r0–r12` 再用 `^` 存 banked `sp/lr`）→ `arch/arm/kernel/entry-header.S:392` 的 `invoke_syscall` 宏（对 `NR_syscalls` 做 range-check；**引用归属是 entry-header.S，不是 entry-common.S**）→ `sys_call_table`（符号由 `entry-common.S:321` 的 `syscall_table_start` 宏在 `:355` 发射；**表体**经 `:357` 的 `#include <calls-eabi.S>` 引入 —— 注意 `calls-eabi.S` **不是检入源码**，而是 Kbuild 从 `arch/arm/tools/syscall.tbl` 生成到 `arch/arm/include/generated/` 的产物（`arch/arm/tools/Makefile:17`），在原始树里直接找不到）；EABI `r7` 为调用号（`entry-common.S:217` 注释，`entry-header.S:427 scno .req r7`）；返回经 `ret_fast_syscall`（`entry-common.S:40`）→ `restore_user_regs`（`entry-header.S:293-329`）→ `movs pc,lr`（329）。

启动衔接（M02 回顾）：`arch/arm/kernel/head.S` 的 `stext:93`、`__create_page_tables:187`、`__enable_mmu:467`（`TTBR0 mcr c2,c0,0` + `DACR`）；`__turn_mmu_on` 符号在 `:508`，真正写 SCTLR（`mcr p15,0,r0,c1,c0,0`，置 M 位）在 `:511`；`__mmap_switched` 在 `arch/arm/kernel/head-common.S:77-122`（**不在 head.S，必须引用正确**）。

页表头：`arch/arm/include/asm/pgtable.h:35-39` 按 `CONFIG_ARM_LPAE=n` 分发到 `pgtable-2level.h`；硬件 2-level vs Linux 包裹的 3-level（`pgtable-2level.h:12-69`）；Linux 位用 `L_PTE_*`（119-127）与 `MT` nibble（真实符号名 `L_PTE_MT_DEV_SHARED`:171 / `L_PTE_MT_DEV_NONSHARED`:172 / `L_PTE_MT_MASK`:176，**不要简写成 `DEV_SHARED`**）；硬件位用 `pgtable-2level-hwdef.h` 的 `PTE_EXT_*`（69-81）/`PMD_SECT_*`（28-48）。

描述符速查（ARM DDI 0406C；假设 `TRE=1,AFE=0,PRRR=0xff0a81a8,NMRR=0x40e040e0,DACR=Client`。**该假设有冻结源码依据而非约定**：`proc-v7-2level.S:139-140` 给出 `PRRR`/`NMRR` 真值，`:164` 的 `v7_crval clear=0x2120c302, mmuset=0x10c03c7d` 逐位即 `TRE=1, AFE=0`）：L1 `bits[1:0]`：`00` fault，`01` 页表指针（`base[31:10]`，仅 domain+NS），`10` section（bit18=0，`base[31:20]`）/supersection（bit18=1，`base[31:24]`，16MB，domain 0），`11` 为 PXN-section-or-reserved（冻结 Linux 不发射）。L2：`00` fault，`01` large page（Linux 不发射），`0b1x` small page——**bit0 就是 XN 位**（`0b10` XN=0，`0b11` XN=1），`base[31:12]`；L2 无 domain 字段。AP 表（AFE=0，B3-8）与 `n={TEX0,C,B}` → PRRR/NMRR 解码见 Lab 7.4；`110` 为 IMPLEMENTATION-DEFINED 必须 REJECT；`TEX[2:1]` 在 TRE=1 下被 HW 忽略；Normal 上 `S=0` 仍是 Normal（UP 策略），fixture 不得硬要求 `S=1`。

**证据边界（必须对学习者明说）：** 上段的**字段位置**（XN/AP/TEX/S/nG 的 bit 位）已对冻结源码 `pgtable-2level-hwdef.h` 核实（`PTE_EXT_XN` bit0、`PTE_EXT_AP` bits4-5、`PTE_EXT_TEX` bits6-8、`PTE_EXT_SHARED` bit10、`PTE_EXT_NG` bit11），`TRE/AFE/PRRR/NMRR` 的取值也已核实；但 **AP 权限矩阵的语义行**与 **`n={TEX0,C,B}` → 内存类型表的语义行**来自 ARM DDI 0406C.d，本机未持有该文档，故这两张表的语义权威性在此标注为 **UNVERIFIED**（字段位置 = VERIFIED，语义行 = UNVERIFIED）。评审若持有 DDI 0406C.d，应按其 B3-8 / B3-13 章节复核这两张表。

`/proc` 格式以 `Documentation/filesystems/proc.rst §1.1` 为准（章节标题 `:101`；列头 `address perms offset dev inode pathname` 在 `:386`）。

---

## 7. Labs（合计 3.5 h MUST）

| Lab | Title | Time | Deliverable |
|---|---|---:|---|
| 7.1 | 观察一个进程的地址空间 | 50 min | 四类地址打印 + maps 对照表 + 非证明声明 |
| 7.2 | 追踪一条确定性的 `svc` 系统调用 | 55 min | 含 `svc #0` 的反汇编证明 + 运行对照 |
| 7.3 | 内核/用户边界与受控地址 fault | 45 min | `>=0xC0000000` 受控 fault + 信号/日志证据链 |
| 7.4 | Short-descriptor 翻译 + 内存属性 fixture | 60 min | 两个 golden 解码 + 一个 EXPECTED-REJECT |

---

## 8. Controlled faults

| ID | Fault | Family | Detection |
|---|---|---|---|
| **F13** | 用户态解引用内核地址 / 特权+翻译 fault | privilege + translation | 信号 + 切分/权限推理 + 内核日志（如有） |
| **F14** | 受控描述符 fixture 中的 device 属性错配 | memory attribute | 字段级 Normal vs Device 语义判定 |

均为 worked tutorial。Challenge / Module Gate 用不泄漏映射与描述符值的 unfamiliar 变体（learner-facing starter 只携带被测 artifact 与中性结构元数据；答案只存在于 assessment-private seed mapping）。

---

## 9. Verification 与证据边界

* 本机已执行：
  * 仓库文档阅读（`AGENTS.md`、`.editorial/*`、Issue #36、M05/M06 precedent）；
  * **上游 pin 解析**：`git ls-remote` 得 Linux `v6.18.50^{}` = `7cfc41f8…b79c7`、QEMU `v11.1.1^{}` = `c3d48b7…a1943`，与 Issue #36 声明逐字相符 —— **VERIFIED**；
  * **真实源码行级核验**：浅克隆 pinned tag（HEAD 实测等于上述 peeled commit），§6/§2 全部源码引用的路径、符号、行号逐条核实并固化为 assessment-private 机读表，由 `make reviewer-check LINUX_SRC=<clone>` stage 6 自动重放（51/51 精确命中，含 occurrence 计数与 4 项 fail-closed 自检）—— **VERIFIED**；
  * **静态语义检查**：learner-safe check、36 项对抗 mutation、12 项 oracle 回归、isolation audit（含 starter 泄漏回归）—— **VERIFIED**。
  * **canonical 内核构建**：Linux **6.18.50** 由 pinned commit（`7cfc41f8…b79c7`）以本仓冻结配置（`multi_v7_defconfig` + `phase3_delta.config`，`CONFIG_ARM_LPAE=n` / `CONFIG_VMSPLIT_3G=y`）本地构建成功，产出真实 `zImage`（sha256 `46e75c3d…f0b0`）—— **VERIFIED**。
  * **canonical 内核客机运行**：以冻结机器契约在 **actual-host QEMU 8.2.2** 上真实启动该 6.18.50 客机，三个 lab 二进制在真实内核上运行：
    * Lab 7.1：真实 `/proc/self/maps` 捕获，3G/1G 切分直接观察到（stack `0xbedc4b90` < `TASK_SIZE` `0xBF000000`，无 `0xCxxxxxxx` 行）；
    * Lab 7.2：`raw svc getpid : 46` == `libc getpid : 46`，即真实用户态 `svc` 陷入路径；
    * Lab 7.3：受控读 `0xc0008000` → 真实 `SIGSEGV`，`exit=42`。
    该次启动的 `cr=10c5387d`（**TRE=1、AFE=0**）**证实该内核跑的正是非 LPAE short-descriptor 模型** —— 与 `proc-v7-2level.S:164` 的 `v7_crval` 预测逐位吻合。以上 **VERIFIED**（actual-host QEMU 维度）。
* **仍为 UNVERIFIED**：`canonical QEMU 11.1.1 runtime`（本机为 8.2.2）、canonical Arm GNU Toolchain 13.3.rel1（本机为 distro 13.3.0）、GDB、`dmesg` 文本捕获、物理测量、以及 AP/`n` 语义行。闭环命令见 `SOURCE_LEDGER.md` §3.2。
* 描述符 **字段位置** 与 `TRE/AFE/PRRR/NMRR` 取值 = **VERIFIED**（冻结源码，且 6.18.50 客机 `cr` 实测吻合）；AP 权限矩阵与 `n={TEX0,C,B}` 内存类型表的 **语义行** = **UNVERIFIED**（需 ARM DDI 0406C.d 原文）。详见 §6 证据边界段。
* fixture/静态解码证据不得升级为 live 页表/GDB/运行时声明；`actual-host` ≠ `canonical`。
* 证据词只用 `VERIFIED` / `PARTIALLY VERIFIED` / `UNVERIFIED`。

---

## 10. 已知 stale 引用修正（bounded correction）

Roadmap 中 “`TTBR0` for user / `TTBR1` for kernel” 一行与 research-doc §3.3 lines 274-276 的同类表述已被冻结实现证伪。**处置：** roadmap 那一句已做**最小 bounded correction**（改为架构-机制 + 冻结路径的准确表述并指向 `SOURCE_LEDGER.md` §4）；research-doc 作为设计阶段历史记录**仅登记、未修改**（同类表述另见其 L66/L251/L953，且 L275 把用户半界写成 `0xBFFFFFFF`，正确值 `TASK_SIZE=0xBF000000`）。本模块按 §5.3 教学，不做大范围文档改写。修正的真实源码证据见 `SOURCE_LEDGER.md` §4。

---

## 11. Career relevance / Further reading

 bring-up 与驱动调试中，一半以上的“灵异”问题最终是地址翻译或内存属性问题：踩到内核半区、把 MMIO 当普通内存、TLB 维护缺失。本章的回报是把这些问题从玄学变成可查表、可复现的推理。

* ARM DDI 0406C.d（VMSA、权限、内存类型、屏障）；DEN 0013D（MMU walkthrough）。
* Linux 6.18.50 上述 entry/pgtable/head 路径（行号见 §6）。
* OSTEP v1.10 Ch.18–20（SHOULD，支撑性解释，非 ARM 证据）；TLPI 进程/映射章节。

详细 pin 与证据拆分见 `SOURCE_LEDGER.md`。
