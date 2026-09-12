# Lab 7.2 — 追踪一条确定性的 `svc` 系统调用 (Syscall Trace)

**Time:** ~55 min MUST。**Prerequisite:** Lab 7.1；EABI 寄存器约定概念；会用 `objdump`。

---

## 1. 目标 (Objective)

用一个**保证走 SVC 路径**的有界目标产物证明：用户态 (PL0) 经 `svc #0` 陷入内核 (PL1)。你将交付两份证据：反汇编里真实存在的 `svc` 指令 (disassembly proof)，以及裸调用与 libc 调用的返回值对照。`strace` 只是附加的用户态观察，不是唯一证明。

## 2. 前置知识 (Prerequisites)

* ARM EABI 系统调用约定 (syscall convention)：`r7` = 调用号，本实验冻结 `__NR_getpid=20`。
* `svc` 是异常/陷入指令 (exception/trap)，不是普通 `bl`。
* 内核入口概念：向量 `+0x08` 槽 → `vector_swi` → `ENTRY(vector_swi)` → `invoke_syscall` 查 `sys_call_table` → `ret_fast_syscall` 返回。

## 3. 环境与版本 (Environment)

* Canonical：Arm GNU Toolchain 13.3.rel1，Linux 6.18.50，QEMU 11.1.1（同 Lab 7.1）。
* 校准所用 actual-host 环境（非 canonical）：`arm-linux-gnueabihf-gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0` + binutils 2.42；`qemu-system-arm 8.2.2`。**内核用的是 canonical Linux 6.18.50**（由 pinned commit 本地构建，冻结配置 `CONFIG_ARM_LPAE=n` / `CONFIG_VMSPLIT_3G=y`）。
* 源码：`src/svc_getpid.S`（`mov r7,#20; svc #0; bx lr`）、`src/svc_getpid.h`、`src/svc_main.c`。
* 绝不使用 libc 包装做被测路径；libc `getpid` 只做对照组。目标执行已 **VERIFIED**（见 §9）。

## 4. 步骤 (Procedure)

```bash
# 硬浮点工具链需补 -mfpu 与 -mfloat-abi=hard（见 Lab 7.1 §4 说明）.
arm-none-linux-gnueabihf-gcc -static -march=armv7-a -mfpu=vfpv4-d16 \
  -mfloat-abi=hard -marm -O0 -g -o svc_getpid.elf src/svc_main.c src/svc_getpid.S
# 核心证据：反汇编必须看到 svc
arm-none-linux-gnueabihf-objdump -d svc_getpid.elf | grep -A6 '<svc_getpid_raw>'
# 在 QEMU appliance 目标上运行
./svc_getpid.elf
# 可选附加观察（不是证明）
strace -e trace=getpid ./svc_getpid.elf
```

`fixtures/svc_reference.disasm` 给出真实捕获（VERIFIED，含实际工具链身份与命令）。

## 5. 预期可观察现象 (Expected observable)

下面是**真实捕获**（actual-host 工具链反汇编 + **canonical Linux 6.18.50 客机**运行；pid 每次会变，相等才是稳定事实）：

```text
VERIFIED — real capture
  disassembly: arm-linux-gnueabihf-gcc 13.3.0 + binutils 2.42 (actual-host toolchain)
  runtime:     CANONICAL Linux 6.18.50 guest (pinned commit 7cfc41f8…b79c7, built from
               the frozen Phase 3 config: CONFIG_ARM_LPAE=n, CONFIG_VMSPLIT_3G=y)
               under actual-host qemu-system-arm 8.2.2 with the frozen machine contract
  000104e0 <svc_getpid_raw>:
     104e0: e3a07014  mov r7, #20
     104e4: ef000000  svc 0x00000000
     104e8: e12fff1e  bx  lr
  raw svc getpid : 46
  libc getpid    : 46
  match          : yes
```

> QEMU 是 **actual-host 8.2.2**；canonical QEMU 11.1.1 未使用 → `canonical QEMU 11.1.1 runtime: UNVERIFIED`。
> 内核是 **canonical 6.18.50**，且该次启动的 `cr=10c5387d`（TRE=1、AFE=0）证实它跑的正是
> non-LPAE short-descriptor 模型。完整证据见 `fixtures/calibration-evidence.md`。

解读：`mov r7,#20` 设定 EABI 调用号（`scno .req r7`，`entry-header.S:427`）；`svc #0` 经 `+0x08` 向量槽进入 `ENTRY(vector_swi)`（`entry-common.S:171`，保存 `r0–r12` 与 banked `sp/lr`），由 `invoke_syscall`（`entry-header.S:392`，对 `NR_syscalls` 做 range-check）分发到 `sys_call_table`（符号由 `entry-common.S:321` 的 `syscall_table_start` 宏在 `:355` 发射；EABI 表体经 `:357` 的 `#include <calls-eabi.S>` 引入——该文件由 Kbuild 从 `arch/arm/tools/syscall.tbl` 生成到 `arch/arm/include/generated/`（`arch/arm/tools/Makefile:17`），原始树中并不存在）；返回经 `ret_fast_syscall` → `restore_user_regs`（`entry-header.S:293-329`）→ `movs pc,lr`。

### 5.1 路径分阶段对照表（观察 vs 解释的边界）

| 阶段 | 可观察的（本实验交付） | 只讲概念的（不要求观测） |
|---|---|---|
| 用户态设号 | `mov r7,#20`（反汇编可见） | `r7` 即 `scno`（`entry-header.S:427`） |
| 陷入 | `svc #0`（反汇编可见） | `+0x08` 槽 → `vector_swi`（`entry-armv.S`） |
| 内核入口保存现场 | — | `ENTRY(vector_swi)` 存 `r0–r12` 与 banked `sp/lr`（`entry-common.S:171`） |
| 分发 | 返回值正确（行为可见） | `invoke_syscall` range-check（`entry-header.S:392`）→ `sys_call_table`（`entry-common.S:355`） |
| 返回 | `bx lr` 后 `r0`=pid（行为可见） | `ret_fast_syscall` → `restore_user_regs`（`entry-header.S:293-329`）→ `movs pc,lr` |

左列是你的证据，右列是你的解释。凡把右列写成“已观测”的报告一律打回。

### 5.2 Checkpoint（过关自查）

1. 背出 `invoke_syscall` 的文件归属（不是 entry-common.S）与它的作用（一句话）。
2. 为什么 `strace` 不能替代 `objdump` 作为本实验的核心证据？
3. 若 `grep` 不到 `svc`，你的第一个检查动作是什么？

## 6. 验证方法 (Verification)

1. `objdump` 输出含 `svc 0x00000000` 且上邻两条为 `mov r7,#20` / 下邻为 `bx lr`——缺任何一条即 FAIL。
2. 运行输出两行 pid 相等。
3. 能说出观察与解释的边界：反汇编 + 行为成功**支持**走了 SVC 路径，但不暴露每一步内核寄存器变迁。

## 7. 典型失败模式 (Failure modes)

* 只测了 libc `getpid` 且反汇编无 `svc`——vDSO/优化捷径绕过了被测指令，Lab 不算完成，必须用 `svc_getpid.S` 重测。
* 用 `strace` 看到 `getpid` 就宣布证明——`strace` 是 userspace 观察，不能替代指令证据。
* 把 `invoke_syscall` 引用写成 `entry-common.S`——归属是 `entry-header.S:392`，写错即概念错误。
* Thumb/ARM 混编导致 `grep svc_getpid_raw` 为空——检查是否误加 `-mthumb`，本实验固定 `.arm`。

## 8. 调试策略 (Debug strategy)

先看符号：`nm svc_getpid.elf | grep svc_getpid_raw` 确认链接进了被测对象；再看反汇编确认指令；再看运行返回值；最后才看 `strace`。顺序反了会把“调用成功”等同于“指令存在”，这是本实验要消灭的思维捷径。

## 9. 证据状态

* 目标编译/链接：**VERIFIED**（actual-host `arm-linux-gnueabihf-gcc 13.3.0` 静态 ARM EABI 构建成功）。
* 反汇编校准：**VERIFIED**（`svc_getpid_raw` 反汇编含 `mov r7,#20` → `svc 0x00000000` → `bx lr`，ARM 模式）。
* QEMU 运行（svc 行为）：**VERIFIED**（`qemu-arm` user-mode 下、以及 **canonical Linux 6.18.50 客机**下，raw `svc` 返回值与 libc `getpid` 相等：46 == 46）。
* `scripts/check_svc_artifact.py` 接受该真实产物（PASS）；对 x86 `syscall`/注释诱饵/非 `.text` 段/非 ARM ELF/死分支仍 REJECT，缺工具仍 ERROR——**VERIFIED**。
* 证据边界：运行环境是 **canonical 6.18.50 内核 + actual-host QEMU 8.2.2**；`canonical QEMU 11.1.1 runtime` 仍 **UNVERIFIED**；canonical Arm GNU Toolchain 13.3.rel1 未使用。反汇编支持“走了 SVC 路径”，但不暴露内核每一步寄存器变迁。
* `strace` 观察：**UNVERIFIED**（actual-host 无 `strace`）。完整证据见 `fixtures/calibration-evidence.md`。

## 10. 扩展挑战 (Extension, SHOULD)

把 `r7` 改成一个非法大号（如 `0xFFFF`），预测 `invoke_syscall` 的 range-check 会返回什么错误（查表失败路径，概念层），再用反汇编 + 运行验证你的预测。注意保留原 `20` 号版本的通过证据。
