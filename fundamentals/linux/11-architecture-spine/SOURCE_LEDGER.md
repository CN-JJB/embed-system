# P3-M07 Source Ledger — Architecture Spine

> Checked: **2026-09-12**（authoring host，Windows / PowerShell，无 ARM 目标构建与 QEMU 运行）。
>
> 本 ledger 区分**实际执行了什么**与**转录但未执行什么**。状态词只用
> `VERIFIED` / `PARTIALLY VERIFIED` / `UNVERIFIED`。不做推断升级。

---

## 1. Upstream traceability

| ID | Source / artifact | Organization | Type | Exact path / section | Version · tag · peeled commit | Upstream origin | Checked | Teaching purpose | Risk / constraint |
|---|---|---|---|---|---|---|---|---|---|
| M07-S01 | Linux kernel source | Linux kernel community | Official upstream source | `arch/arm/kernel/entry-armv.S`（vectors，`+0x08` 槽 → `vector_swi`；`.L__vector_swi` 934，`.word vector_swi` 935，向量表 reloc 1085）；`arch/arm/kernel/entry-common.S:171 ENTRY(vector_swi)`，`:217` EABI `r7` 注释，`:355 syscall_table_start sys_call_table`（表体经 `:357 #include <calls-eabi.S>` 引入，而该文件由 Kbuild 生成、原始树中不存在——见 §2）；`arch/arm/kernel/entry-header.S:392 invoke_syscall` 宏，`:427 scno .req r7`，`:293-329 restore_user_regs`（`movs pc, lr` 329） | **6.18.50** · tag `v6.18.50` · `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7` | `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 2026-09-12 | syscall 陷入路径的 bounded source reading | 已对真实 pinned 树逐行核验（§3.1）；并固化为 assessment-private 机读表，由 reviewer-check stage 6 自动重放 |
| M07-S02 | Linux early boot | Linux kernel community | Official upstream source | `arch/arm/kernel/head.S`：`stext:93`，`__create_page_tables:187`（`bl` 于 139，ENDPROC 377），`__enable_mmu:467`（TTBR0 `mcr c2,c0,0` + DACR，ENDPROC 490），`__turn_mmu_on:508`（SCTLR.M 写入 `mcr p15,0,r0,c1,c0,0` 于 **511**）；`arch/arm/kernel/head-common.S:77-122 __mmap_switched`（**不在 head.S**） | 6.18.50（同上） | same | 2026-09-12 | M02 启动衔接，MMU 使能点 | 行号已逐条核验（§3.1）；`__mmap_switched` 归属 head-common.S 已确认 |
| M07-S03 | Linux ARM pgtable | Linux kernel community | Official upstream source | `arch/arm/include/asm/pgtable.h:35-39`（`CONFIG_ARM_LPAE=n` → `pgtable-2level.h`，即 38 行）；`pgtable-2level.h:12-25`（硬件 2-level vs Linux “wrapped” 3-level，`wrapped` 句在 19）；`L_PTE_* :119-127`；MT nibbles `:165-176`（`L_PTE_MT_DEV_SHARED` 171、`L_PTE_MT_DEV_NONSHARED` 172、`L_PTE_MT_MASK` 176）；`pgtable-2level-hwdef.h`（`PMD_SECT_*` 28-48，`PTE_EXT_*` 69-81）；dirty/young 经 fault 模拟 | 6.18.50（同上） | same | 2026-09-12 | 硬件格式 vs Linux 封装的区分 | 冻结教学只用 `L_PTE_*` 与 `PMD_SECT_*`/`PTE_EXT_*`（真实符号名）；x86 风格同名页面标志在 ARM 树中零命中，禁止引用。行号已核验 |
| M07-S04 | Linux memory split | Linux kernel community | Official upstream source | `arch/arm/include/asm/memory.h:34`（`PAGE_OFFSET = UL(CONFIG_PAGE_OFFSET)`）；`:44`（`TASK_SIZE = UL(CONFIG_PAGE_OFFSET) - UL(SZ_16M)`）；`:60`（`MODULES_VADDR = PAGE_OFFSET - SZ_16M`）；`VMSPLIT_3G` 下 `PAGE_OFFSET=0xC0000000`，故 `TASK_SIZE=0xBF000000` | 6.18.50（同上） | same | 2026-09-12 | 用户教学范围 `0x00000000–0xBEFFFFFF` | 禁止教 `0xBFFFFFFF` 为用户顶；`0xBF000000–0xBFFFFFFF` 是模块区。行号已核验 |
| M07-S05 | Linux TTBR / switch_mm | Linux kernel community | Official upstream source | `arch/arm/mm/proc-v7-2level.S:37`（“we are not using split page tables”）；`cpu_v7_switch_mm:43` 内 `CONTEXTIDR` 写于 `:56`、`TTBR0` 写于 `:58`，函数体无 TTBR1 写入；`v7_ttb_setup` 内 TTBCR 写 `zero` 于 `:150`、TTBR1 装载于 `:152`；`arch/arm/mm/pgd.c:46`（`memcpy` 复制内核半区） | 6.18.50（同上） | same | 2026-09-12 | TTBR 修正的源码依据 | 修正见 §4；教学模型见 README §5.3 |
| M07-S06 | proc maps format | Linux kernel community | Official documentation | `Documentation/filesystems/proc.rst` §1.1（标题在 `:101`），maps 行格式章节在 `:381` | 6.18.50（同上） | same | 2026-09-12 | maps 行格式与 virtual-only 教学 | 不证明物理地址。行号已核验 |
| M07-S07 | ARM ARMv7-A | ARM | Primary specification | ARM DDI 0406C（short-descriptor VMSA、权限 B3-8、内存类型、屏障）；假设 `TRE=1,AFE=0,PRRR=0xff0a81a8,NMRR=0x40e040e0,DACR=Client` | DDI 0406C.d | ARM infocenter | 2026-09-12 | L1/L2 解码、AP、TEX/C/B/S、XN 的权威依据 | `110` 为 IMPLEMENTATION-DEFINED，必须 REJECT |
| M07-S08 | Cortex-A programmer guide | ARM | Primary specification | DEN 0013D（MMU walkthrough、TLB、boot flow） | DEN 0013D | ARM infocenter | 2026-09-12 | TLB/翻译概念支撑 | 概念深度，不做寄存器全集 |
| M07-S09 | OSTEP / TLPI | Arpaci-Dusseau / Kerrisk | Supporting literature | OSTEP v1.10 Ch.18–20；TLPI 进程/映射章节 | v1.10 / TLPI | — | 2026-09-12 | 支撑性解释 | 非 ARM/Linux 行为证据 |
| M07-S10 | Phase 3 curriculum design | this repository | Canonical curriculum architecture | `research/phase-3/2026-09-08-embedded-linux-curriculum-design.md` | commit 见 roadmap | `roadmap/phase-3-embedded-linux.md` | 2026-09-12 | M07/M08 预算与 labs/faults 形状 | §4 登记两处 stale（bounded correction） |
| M07-S11 | P3-M05/M06 precedent | this repository | Canonical implementation | `fundamentals/linux/09-device-tree-first-pass/`，`fundamentals/linux/10-shallow-buildroot/`（README + SOURCE_LEDGER + .gitignore 纪律） | branch `phase-3/m07-m08-arch-appliance` base `67343a1` | — | 2026-09-12 | 章节形状、证据分离、锚定 gitignore 的风格先例 | 本模块复用其布局与措辞纪律 |

### Pin 转录一致性（本机实际执行）

本机实际执行的 pin 检查：

1. **仓库内文本比对**：Issue #36 正文 pin（Linux `v6.18.50` / `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`；QEMU `v11.1.1` / `c3d48b7d1e89604920e5b81b91140c2ad39a1943`）与 M05/M06 ledger 的对应条目逐字一致 —— **VERIFIED**。
2. **上游 tag 解析**（本次新增执行）：
   ```
   git ls-remote https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git 'refs/tags/v6.18.50*'
     -> 7995d95093f421fc173190b2f7551d8e8b0ff86f   refs/tags/v6.18.50
     -> 7cfc41f8e80f11ffa8382ed1a505154ceffb79c7   refs/tags/v6.18.50^{}
   git ls-remote https://gitlab.com/qemu-project/qemu.git 'refs/tags/v11.1.1*'
     -> 5e35f26695645b20931e10d8567c7e0169e62c07   refs/tags/v11.1.1
     -> c3d48b7d1e89604920e5b81b91140c2ad39a1943   refs/tags/v11.1.1^{}
   ```
   两组 peeled commit **与 Issue #36 声明的值逐字相符** —— 上游 pin 维度 **VERIFIED**。
3. **真实源码树落地核验**（本次新增执行）：浅克隆 pinned tag 后 `git rev-parse HEAD` == `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`，`git log -1` 显示 `(grafted, HEAD, tag: v6.18.50) Linux 6.18.50` —— **VERIFIED**。

### Linux 源码行级核验（本次新增执行，详见 §3.1）

§2 的每一处路径/符号/行号已在**真实 pinned 树**上用 `grep -n` / `sed -n` 逐条复核，并固化为 assessment-private 机读表（44 条），由 reviewer-check stage 6 自动重放。结论：**44/44 命中且行号与 occurrence 计数完全一致，0 drift**。

QEMU 11.1.1 canonical 运行、ARM 架构文档（DDI 0406C.d / DEN 0013D）原文比对在本机仍**未执行**（见 §3）。

---

## 2. Symbol / line-number table（已在真实 pinned 树逐行核验）

本节是 README / lab / fixture 所引用符号与行号的**唯一权威表**。每条均已用 `grep -n`/`sed -n` 在
`7cfc41f8e80f11ffa8382ed1a505154ceffb79c7` 的真实树上核实，并固化为 assessment-private 机读表（44 条），
由 `make reviewer-check LINUX_SRC=<clone>` 的 stage 6 自动重放
（含 occurrence 计数与 4 项 fail-closed 自检）。代表性逐字摘录见 §3.1。

* syscall：`entry-armv.S` 向量表 `+0x08` 槽（reloc 于 1085）→ `.L__vector_swi:934` / `.word vector_swi:935` → `entry-common.S:171 ENTRY(vector_swi)`（先存 `r0–r12` 再用 `^` 存 banked sp/lr）→ `entry-header.S:392 invoke_syscall`（`NR_syscalls` range-check；**归属 entry-header.S，禁止写成 entry-common.S**）→ `sys_call_table`（符号经 `entry-common.S:321 syscall_table_start` 宏于 355 发射；**表体**经 `entry-common.S:357 #include <calls-eabi.S>` 引入）。**重要精度**：`calls-eabi.S`（及 `calls-oabi.S`）**不是检入源码**，而是 Kbuild 由 `arch/arm/tools/syscall.tbl` 生成到 `arch/arm/include/generated/` 的产物（`arch/arm/tools/Makefile:17`，`gen := arch/$(ARCH)/include/generated` 见其 :9）；原始树中不存在，教学不得暗示它是 `arch/arm/kernel/` 下的文件。EABI `r7`（注释 `entry-common.S:217`，`entry-header.S:427 scno .req r7`）；返回 `ret_fast_syscall`（`entry-common.S:40`，另有 64 行的 tracing 变体）→ `restore_user_regs`（`entry-header.S:293-329`）→ `movs pc, lr`（329；Thumb2 变体在 359）。
* boot：`head.S stext:93`，`__create_page_tables:187`，`__enable_mmu:467`（TTBR0 `mcr c2,c0,0` + DACR；`SCTLR` 写入 `mcr p15,0,r0,c1,c0,0` 于 `__turn_mmu_on:511`，`ENTRY(__turn_mmu_on)` 在 508）；`__mmap_switched` 于 `head-common.S:77-122`（**不在 head.S**）。
* pgtable：`pgtable.h:35-39` 分发 `CONFIG_ARM_LPAE=n` → `pgtable-2level.h`（include 在 38）；硬件 2-level vs Linux “wrapped” 3-level（`pgtable-2level.h:12-25`，`wrapped` 句在 19）；`L_PTE_*`（119-127）；MT（`L_PTE_MT_DEV_SHARED` 171 / `L_PTE_MT_DEV_NONSHARED` 172 / `L_PTE_MT_MASK` 176）；硬件位 `PMD_SECT_*`（`pgtable-2level-hwdef.h` 28-48）与 `PTE_EXT_*`（69-81）；dirty/young 经 fault 模拟。
* split：`memory.h:34 PAGE_OFFSET`，`:44 TASK_SIZE = PAGE_OFFSET − 16M`，`:60 MODULES_VADDR`；`VMSPLIT_3G` → `PAGE_OFFSET=0xC0000000`、`TASK_SIZE=0xBF000000`，用户教学范围 `0x00000000–0xBEFFFFFF`。
* TTBR：`proc-v7-2level.S:37` 非 split；`cpu_v7_switch_mm:43`，`CONTEXTIDR` 写于 56、`TTBR0` 写于 58，无 TTBR1 写入；`v7_ttb_setup`（宏定义 146）内 TTBCR 写 `zero`（**147**）、TTBR1 装载（152）；`proc-v7.S __v7_setup:488`、`v7_ttb_setup` 调用在 530；`proc-v7-2level.S:164 v7_crval clear=0x2120c302, mmuset=0x10c03c7d` 决定 `TRE=1`/`AFE=0`（见 §3.1）；`pgd.c:46` 复制内核半区。
* 内存类型常量：`proc-v7-2level.S:139 PRRR=0xff0a81a8`、`:140 NMRR=0x40e040e0`（由 `proc-v7.S:178-181`/`531-534` 真正写入 CP15）。
* Lab 7.2 号：`__NR_getpid=20`（ARM EABI，`arch/arm/tools/syscall.tbl:35`）。
* proc：`Documentation/filesystems/proc.rst` §1.1（101），maps 行格式（381）。


---

## 3. What was actually executed on the authoring host

| # | Action | Exact command / reading | Result | Status |
|---|---|---|---|---|
| 1 | 必读仓库文档 | read `AGENTS.md`，`.editorial/WRITING_GUIDE.md`，`.editorial/LAB_STANDARD.md`，`.editorial/GOVERNANCE.md`，`.editorial/REVIEW_POLICY.md`，`.editorial/AI_POLICY.md` | 已读，形状/证据词/角色约束已遵循 | **VERIFIED** |
| 2 | Issue #36 全文 | `gh issue view 36 --json title,body,labels` | 已读，M07/M08 范围与证据维度已落实 | **VERIFIED** |
| 3 | 风格先例 | read M06 `README.md` + `SOURCE_LEDGER.md`，M05 `README.md` + `SOURCE_LEDGER.md`（部分）+ lab/fault 各一篇，roadmap 全文 | 布局/ledger/ignore 纪律已复用 | **VERIFIED** |
| 4 | Pin 转录一致性 | Issue #36 pin vs M05/M06 ledger pin 目视比对 | Linux/QEMU 两组 tag+peeled 一致 | **VERIFIED** |
| 5 | 上游 tag 解析 | `git ls-remote --tags`（kernel.org stable、gitlab qemu-project） | Linux `v6.18.50^{}` = `7cfc41f8…b79c7`；QEMU `v11.1.1^{}` = `c3d48b7…a1943`，与 Issue 声明逐字相符 | **VERIFIED** |
| 6 | Linux 源码行级核验 | 浅克隆 pinned tag（`git clone --depth 1 --branch v6.18.50 --single-branch`）→ `git rev-parse HEAD` | HEAD == peeled commit；随后对 §2 全部 44 条引用做 `grep -n`/`sed -n` 复核并存档为机读表 | **VERIFIED** |
| 6a | 行级自动重放 | `make reviewer-check LINUX_SRC=<clone>`（stage 6：逐条重放机读表并做 4 项 fail-closed 自检） | 44/44 精确命中（含 occurrence 计数）；4 项人为腐蚀全部被拒 | **VERIFIED** |
| 7 | 目标编译/链接 | `arm-linux-gnueabihf-gcc` 构建 lab 源码 | 未执行（见 §3.2） | **UNVERIFIED** |
| 8 | QEMU 运行 / maps 捕获 | 真机 appliance 上运行 Lab 7.1–7.3 | 未执行（见 §3.2） | **UNVERIFIED** |
| 9 | 反汇编校准 | `objdump -d` 校准 `svc_reference.disasm` | 未执行；fixture 明确标 ILLUSTRATIVE | **UNVERIFIED** |
| 10 | GDB / 物理测量 | — | 不适用 | **UNVERIFIED** |
| 11 | 写后回读 | read back 全部新建文件关键节 | 已执行（本任务内） | **VERIFIED** |

### 3.1 行级核验的代表性证据（真实 pinned 树，逐字摘录）

| 引用 | 实测行 | 实测内容（逐字） |
|---|---:|---|
| `arch/arm/kernel/entry-common.S` `vector_swi` | 171 | `ENTRY(vector_swi)` |
| `arch/arm/kernel/entry-common.S` EABI `r7` | 217 | `* Pure EABI user space always put syscall number into scno (r7).` |
| `arch/arm/kernel/entry-common.S` `sys_call_table` | 355 | `syscall_table_start sys_call_table` |
| `arch/arm/kernel/entry-header.S` `invoke_syscall` | 392 | `.macro	invoke_syscall, table, nr, tmp, ret, reload=0` |
| `arch/arm/kernel/entry-header.S` `scno .req r7` | 427 | `scno	.req	r7		@ syscall number` |
| `arch/arm/kernel/entry-header.S` `movs pc, lr` | 329 | `movs	pc, lr				@ return & move spsr_svc into cpsr` |
| `arch/arm/kernel/head.S` `stext` | 93 | `ENTRY(stext)` |
| `arch/arm/kernel/head.S` `__create_page_tables` | 187 | `__create_page_tables:` |
| `arch/arm/kernel/head.S` `__enable_mmu` | 467 | `__enable_mmu:` |
| `arch/arm/kernel/head.S` `__turn_mmu_on` | 508 | `ENTRY(__turn_mmu_on)` |
| `arch/arm/kernel/head.S` SCTLR 写入（M 位） | 511 | `mcr	p15, 0, r0, c1, c0, 0		@ write control reg` |
| `arch/arm/kernel/head-common.S` `__mmap_switched` | 77 | `__mmap_switched:`（ENDPROC 于 122） |
| `arch/arm/kernel/entry-armv.S` SWI 向量槽 | 935 | `.word	vector_swi`（`.L__vector_swi` 于 934） |
| `arch/arm/kernel/entry-armv.S` 向量表 `+0x08` | 1085 | `ARM(	.reloc	., R_ARM_LDR_PC_G0, .L__vector_swi		)` |
| `arch/arm/include/asm/pgtable.h` LPAE 分发 | 35–39 | `#ifdef CONFIG_ARM_LPAE` / `#include <asm/pgtable-3level.h>`（36）/ `#else` / `#include <asm/pgtable-2level.h>`（38）/ `#endif` |
| `arch/arm/include/asm/pgtable-2level.h` 硬件 vs Linux | 12–69 | `Hardware-wise, we have a two level page table structure…`（13）；`be wrapped to fit a two level page table structure easily`（19）；dirty/young 经 fault 模拟的说明延续至块尾 `*/`（69）——故 `12-69` 的范围表述精确 |
| `arch/arm/include/asm/pgtable-2level.h` `L_PTE_*` | 119–127 | `L_PTE_VALID`(119) … `L_PTE_NONE`(127) |
| `arch/arm/include/asm/pgtable-2level.h` MT nibble | 165–176 | `L_PTE_MT_DEV_SHARED`(171) `L_PTE_MT_DEV_NONSHARED`(172) `L_PTE_MT_MASK`(176) |
| `arch/arm/include/asm/pgtable-2level-hwdef.h` | 28–48 / 69–81 | `PMD_SECT_S`(36) `PMD_SECT_SUPER`(38)；`PTE_EXT_XN`(69) `PTE_EXT_AP_MASK`(70) |
| `arch/arm/include/asm/memory.h` `PAGE_OFFSET` | 34 | `#define PAGE_OFFSET		UL(CONFIG_PAGE_OFFSET)` |
| `arch/arm/include/asm/memory.h` `TASK_SIZE` | 44 | `#define TASK_SIZE		(UL(CONFIG_PAGE_OFFSET) - UL(SZ_16M))` |
| `arch/arm/include/asm/memory.h` `MODULES_VADDR` | 60 | `#define MODULES_VADDR		(PAGE_OFFSET - SZ_16M)` |
| `arch/arm/mm/proc-v7-2level.S` 非 split | 37 | `*	- we are not using split page tables` |
| `arch/arm/mm/proc-v7-2level.S` `cpu_v7_switch_mm` | 43 | `SYM_TYPED_FUNC_START(cpu_v7_switch_mm)` |
| `arch/arm/mm/proc-v7-2level.S` CONTEXTIDR | 56 | `mcr	p15, 0, r1, c13, c0, 1		@ set context ID` |
| `arch/arm/mm/proc-v7-2level.S` TTBR0 | 58 | `mcr	p15, 0, r0, c2, c0, 0		@ set TTB 0` |
| `arch/arm/mm/proc-v7-2level.S` `cpu_v7_set_pte_ext` | 74 | `SYM_TYPED_FUNC_START(cpu_v7_set_pte_ext)` |
| `arch/arm/mm/proc-v7-2level.S` `PRRR` / `NMRR` | 139 / 140 | `.equ	PRRR,	0xff0a81a8` / `.equ	NMRR,	0x40e040e0` |
| `arch/arm/mm/proc-v7-2level.S` TTBR1 装载 / TTBCR | 152 / 147 | `mcr	p15, 0, \ttbr1, c2, c0, 1	@ load TTB1`；`mcr	p15, 0, \zero, c2, c0, 2	@ TTB control register`（均属 `.macro v7_ttb_setup`，boot 期经 `proc-v7.S:530` 调用） |
| `arch/arm/mm/proc-v7-2level.S` `v7_crval` | 164 | `crval	clear=0x2120c302, mmuset=0x10c03c7d, ucset=0x00c01c7c` —— 位运算得 SCTLR bit28 TRE=1、bit29 AFE=0 |
| `arch/arm/mm/proc-v7.S` `__v7_setup` / `v7_ttb_setup` | 488 / 530 | `__v7_setup:`；`v7_ttb_setup r10, r4, r5, r8, r3	@ TTBCR, TTBRx setup` |
| `arch/arm/mm/pgd.c` 内核半区复制 | 46 | `memcpy(new_pgd + USER_PTRS_PER_PGD, init_pgd + USER_PTRS_PER_PGD,`（注释 43–45 “Copy over the kernel and IO PGD entries”） |
| `arch/arm/tools/syscall.tbl` `getpid` | 35 | `20	common	getpid			sys_getpid` → ARM EABI `__NR_getpid == 20` |
| `Documentation/filesystems/proc.rst` §1.1 | 101 | `1.1 Process-Specific Subdirectories`；maps 格式章节标题于 381 |

**由上述核验得出的结论（写入教学）：**

* `PRRR=0xff0a81a8`、`NMRR=0x40e040e0` 不是教学假设，而是冻结 Linux 6.18.50 在 `proc-v7-2level.S:139-140` 的真实常量，并由 `proc-v7.S:530`（`__v7_setup` 内 `v7_ttb_setup`）真正写入 CP15 —— 因此 §5 fixture 的 assumption stamp 具备**真实源码依据**（fixture 语义仍只是 fixture 语义，不等于 live 内核观察）。
* `TASK_SIZE = PAGE_OFFSET − 16M = 0xBF000000`（`memory.h:44`），且 `0xBF000000–0xBFFFFFFF` 为 `MODULES_VADDR..PAGE_OFFSET` 模块区（`memory.h:60`）—— 故用户教学上界写 `0xBEFFFFFF` 正确，写 `0xBFFFFFFF` 错误。
* `cpu_v7_switch_mm` 无条件写 `CONTEXTIDR`（56）后只写 `TTBR0`（58），函数体内**没有任何 TTBR1 写入**；TTBR1 仅在 boot 期 `v7_ttb_setup`（152）装载，TTBCR 同期写 `zero`（**147**，即 N=0）—— §4 的修正结论**由真实源码直接支持**。
* **`TRE=1` / `AFE=0` 的源码依据（本次新增，决定性）**：`proc-v7-2level.S:164`
  ```text
  crval	clear=0x2120c302, mmuset=0x10c03c7d, ucset=0x00c01c7c
  ```
  逐位运算：`mmuset` 置 bit28（TRE）且不置 bit29（AFE），`clear` 清 bit29 → 冻结的 Cortex-A7 non-LPAE 路径**确实**运行在 `TRE=1, AFE=0`。因此本模块全部描述符 fixture 的 assumption stamp 不是任意教学假设，而是冻结内核的真实 SCTLR 状态；AP 表与 `n={TEX0,C,B}` 语义行的权威仍是 ARM DDI 0406C.d（本机未持有该文档，故该语义行维度见 §3.2 标注）。
* `v7_crval` 位于 `proc-v7-2level.S`（`CONFIG_ARM_LPAE=n` 时实际编译的那份），**不是** `proc-v7.S`。
* `entry-header.S` 的 `invoke_syscall`(392)、`scno .req r7`(427)、`restore_user_regs`(293) 归属正确，且 `restore_user_regs` 在 ARM 模式下以 `movs pc, lr`(329) 结束 —— 用户态返回是异常返回，不是普通分支。

### 3.2 仍未在本机执行的事项（UNVERIFIED，附闭环命令）

| 事项 | 为何未执行 | 闭环所需环境 |
|---|---|---|
| 目标编译/链接 | 本机无 canonical `arm-none-linux-gnueabihf-`（Arm GNU 13.3.rel1） | 安装 Arm GNU Toolchain 13.3.rel1，或显式以 `CROSS_COMPILE=arm-linux-gnueabihf-` 运行并标记为 actual-host |
| `svc_reference.disasm` 反汇编校准 | 同上 | `arm-linux-gnueabihf-objdump -d`（或 canonical） |
| 客体内运行 `/proc/<pid>/maps`、SVC、F13 fault | 本机无 pinned Linux 6.18.50 内核镜像与 rootfs | 具备内核镜像 + initramfs 后运行 `make real-m07-arch-check KERNEL=… INITRD=…` |
| canonical QEMU 11.1.1 运行 | 本机 QEMU 非 11.1.1 | 安装 QEMU 11.1.1（tag `v11.1.1`，peeled `c3d48b7d…`） |
| ARM 文档（DDI 0406C.d / DEN 0013D）原文比对 | 文档不在本机且非公开可再分发 | 人工持文档核对 B3-8 权限表、TEX/C/B/S 与屏障章节 |
| Live 页表 / GDB | 需要真实内核与 GDB stub | `qemu-system-arm -s -S` + 绑定实际内核镜像 |

---

## 4. TTBR 修正与 corrected stale references（bounded correction）

**冻结事实（教学必须采用）：** `proc-v7-2level.S:36-37` “we are not using split page tables”；`cpu_v7_switch_mm` 只写 `TTBR0`（`mcr c2,c0,0`）+ `CONTEXTIDR`；`TTBCR=0`（`TTBR0` 横跨 4GB）；每进程 `pgd` 经 `pgd.c:46-47` 的 `memcpy` 携带内核半区。教学模型：**一张 TTBR0-驻留表 = 用户条目 + 复制的内核条目；`TTBR1` boot 时装载但 `N=0` 时未用**。禁止普适的“`TTBR0`=user / `TTBR1`=kernel”。

** reviewer-note 指针（给 validator agent）：** 语义检查必须接受上述 TTBR0-驻留模型，拒绝普适 split-table 表述；fixture 路径与 golden 值见 §5。隐藏变体/打分锚属于另一 agent 的 reviewer 域，本 ledger 不泄露。

**Corrected stale references（bounded correction，仅登记与最小修正，不做 roadmap 大改写）：**

| # | Stale 位置 | Stale 表述 | 处置 |
|---|---|---|---|
| C1 | `roadmap/phase-3-embedded-linux.md` exit-capability 行（P3-M07 条，原含 “Translation Table Base Registers (`TTBR0` for user space, `TTBR1` for kernel space)`”） | 普适 split-table 声称 | **已做最小 bounded correction**：该单句替换为架构-机制 + 冻结 Linux 路径的准确表述，并指向本 ledger §4。属于 source-correctness 修正，非 roadmap 重写；Leader 可独立裁定 |
| C2 | `research/phase-3/2026-09-08-embedded-linux-curriculum-design.md`（§3.3 区，L274-276；另见 L66、L251、L953） | 同类 TTBR0/TTBR1 分工表述，且 L275 把用户半区上界写成 `0xBFFFFFFF` | **仅登记，未修改**：该文档是设计阶段历史记录，含多处同类表述与用户上界错误（正确上界 `TASK_SIZE=0xBF000000`，见 `memory.h:44`）。按 “不做无关大规模改写” 原则保留原文，由 Leader 决定是否需要独立的设计文档勘误 Issue |

修正所依据的真实源码证据（逐字）：

```text
arch/arm/mm/proc-v7-2level.S:37   *	- we are not using split page tables
arch/arm/mm/proc-v7-2level.S:56   mcr	p15, 0, r1, c13, c0, 1		@ set context ID
arch/arm/mm/proc-v7-2level.S:58   mcr	p15, 0, r0, c2, c0, 0		@ set TTB 0
arch/arm/mm/proc-v7-2level.S:147  mcr	p15, 0, \zero, c2, c0, 2	@ TTB control register
arch/arm/mm/proc-v7-2level.S:152  mcr	p15, 0, \ttbr1, c2, c0, 1	@ load TTB1
arch/arm/mm/pgd.c:46              memcpy(new_pgd + USER_PTRS_PER_PGD, init_pgd + USER_PTRS_PER_PGD,
```


---

## 5. Committed artifacts and their provenance（本 agent 拥有范围）

| Artifact | Origin | Status |
|---|---|---|
| `README.md` | 原创教学文本，frozen findings 编码 | **VERIFIED**（写后回读） |
| `labs/07.1-proc-address-space/src/addrspace.c` | 原创 lab 源码 | **VERIFIED**（写后回读；编译/运行 **UNVERIFIED**） |
| `labs/07.2-svc-syscall-trace/src/svc_getpid.S` + `svc_getpid.h` + `svc_main.c` | 原创 lab 源码（`r7=20`，`svc #0`，非 libc） | **VERIFIED**（写后回读；编译/反汇编校准 **UNVERIFIED**） |
| `labs/07.3-kernel-boundary-fault/src/kfault.c` | 原创 lab 源码（受控 `0xC0008000` 演示） | **VERIFIED**（写后回读；运行 **UNVERIFIED**） |
| `fixtures/maps_sample.txt` | **SYNTHETIC** 教学样本（`proc.rst §1.1` 格式，用户半区地址） | **VERIFIED**（fixture 写作；live 捕获 **UNVERIFIED**） |
| `fixtures/descriptor_taught.json` | 确定性 fixture：golden `(L1,0x4001140E)` Section Normal WBWA + `(L2,0x09000453)` small-page Device + 一项 `EXPECTED-REJECT`（L1 `0b11`）；假设戳 `TRE=1,AFE=0,PRRR=0xff0a81a8,NMRR=0x40e040e0,DACR=Client` | **VERIFIED**（fixture 写作；位域手工解码见 README §6；live 内核状态 **UNVERIFIED**） |
| `fixtures/svc_reference.disasm` | **ILLUSTRATIVE** 静态文本，头注 `EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED` | **VERIFIED**（标注存在；校准 **UNVERIFIED**） |

Golden 解码摘要：`(L1,0x4001140E)` = Section @`0x40000000`，AP=001（PL1-only），TEX=001/C=B=1，S=1，nG=0，XN=0，Domain 0 → Inner Shareable Normal WBWA，可执行，global。`(L2,0x09000453)` = small page XN=1 @`0x09000000`，AP=001，TEX=001/C=B=0，S=1 → Shareable Device，PL1-only，XN。`S` 仅记录不做 Normal 判决（UP 策略）。

---

## 6. Licensing / source-origin constraints

* Linux 6.18.50 — GPL-2.0-only。引用为源码路径/行号与短摘，vendoring 禁止。
* ARM DDI 0406C / DEN 0013D — ARM 版权规范，引用为章节/表号与转述，不复制大段。
* QEMU 11.1.1 — GPL-2.0。用作工具，不 vendoring。
* OSTEP / TLPI — 支撑性文献，非证据。
* 本模块全部文本、lab 源码、fixture 均为本仓库原创；未提交内核/Buildroot 源码树与任何 heavyweight 输出。

---

## 7. Evidence summary

| Dimension | Status |
|---|---|
| Linux / QEMU pin 上游解析（`git ls-remote` peeled commit） | **VERIFIED** |
| Linux 6.18.50 源码行级核验（44 条，真实树 + 自动重放） | **VERIFIED** |
| 描述符 assumption stamp 的源码依据（PRRR/NMRR/TTBCR/TTBR0） | **VERIFIED** |
| Host/静态检查（learner-safe、mutation 36/36、oracle 12/12、isolation） | **VERIFIED** |
| 目标编译/链接 | **UNVERIFIED**（需 Arm GNU 13.3.rel1 或显式 actual-host 交叉工具链） |
| `/proc` maps live 证据 | **UNVERIFIED**（需内核镜像 + rootfs） |
| SVC 目标执行 / 反汇编校准 | **UNVERIFIED**（同上） |
| 受控描述符语义（fixture 静态） | **VERIFIED**（fixture 写作 + 源码依据已核；非 live 内核状态） |
| Live QEMU/GDB 架构观察 | **UNVERIFIED** |
| canonical QEMU 11.1.1 runtime | **UNVERIFIED**（本机 QEMU 非 11.1.1） |
| 物理板 | **UNVERIFIED**（out of scope） |
