# Lab 7.3 — 内核/用户边界与受控地址 Fault (Kernel Boundary Fault)

**Time:** ~45 min MUST。**Prerequisite:** Lab 7.1（地址空间）；冻结切分结论。

---

## 1. 目标 (Objective)

用一个有界的用户态程序访问冻结内核虚地址范围 (kernel virtual range，`>= 0xC0000000`，演示用 `0xC0008000`），观察进程 fault/信号 (signal/fault) 与可用的目标内核诊断证据。学完你能用切分 + 权限讲清 fault 原因，并说出它**不证明**什么。

## 2. 前置知识 (Prerequisites)

* `VMSPLIT_3G`：`PAGE_OFFSET=0xC0000000`，`TASK_SIZE=0xBF000000`，用户教学范围 `0x00000000–0xBEFFFFFF`。
* 用户映射 vs 内核映射的权限边界：PL0 不能解引用内核半区。
* `SIGSEGV` 是用户态可观察的 fault 证据；`dmesg`（如有）是第二证据通道。

## 3. 环境与版本 (Environment)

* Canonical：Arm GNU Toolchain 13.3.rel1，Linux 6.18.50，QEMU 11.1.1（同 Lab 7.1）。
* 校准所用 actual-host 环境（非 canonical）：`arm-linux-gnueabihf-gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0`；`qemu-system-arm 8.2.2`。**内核用的是 canonical Linux 6.18.50**（由 pinned commit 本地构建，冻结配置 `CONFIG_ARM_LPAE=n` / `CONFIG_VMSPLIT_3G=y`）。
* 源码：`src/kfault.c`（受控读 `0xC0008000`，`SIGSEGV` handler 接住后按预期退出）。目标运行已 **VERIFIED**（见 §9）。
* **不要**硬编码任何 exact `dmesg` 行/fault code——具体内核日志文本未校准（UNVERIFIED）。

## 4. 步骤 (Procedure)

```bash
# 硬浮点工具链需补 -mfpu 与 -mfloat-abi=hard（见 Lab 7.1 §4 说明）.
arm-none-linux-gnueabihf-gcc -static -march=armv7-a -mfpu=vfpv4-d16 \
  -mfloat-abi=hard -marm -O0 -g -o kfault.elf src/kfault.c
./kfault.elf; echo "exit=$?"
# 如 appliance 可用，再看内核侧（文本仅作存在性检查，不匹配固定字符串）
dmesg | tail -20
cat /proc/self/maps | grep -i c000 || echo "no kernel-half line (EXPECTED)"
```

## 5. 预期可观察现象 (Expected observable)

下面是**真实捕获**（**canonical Linux 6.18.50 客机** boot 上运行；pid 每次会变）：

```text
VERIFIED — real capture
  runtime: CANONICAL Linux 6.18.50 guest (pinned commit 7cfc41f8…b79c7, built from the
           frozen Phase 3 config: CONFIG_ARM_LPAE=n, CONFIG_VMSPLIT_3G=y)
           under actual-host qemu-system-arm 8.2.2 with the frozen machine contract
pid=47 attempting controlled read of 0xc0008000 (>= PAGE_OFFSET 0xC0000000)
caught SIGSEGV: userspace fault on kernel-range access (EXPECTED)
proves: PL0 cannot dereference kernel half; does NOT prove any physical mapping
exit=42
```

`dmesg`（如能捕获）只要求“有对应时间窗的 fault 相关行”，**不**要求某一固定字符串。maps 里没有 `0xCxxxxxxx` 行是预期的：它只展示用户半区。

### 5.1 证据通道表（两个通道，效力不同）

| 通道 | 内容 | 效力 |
|---|---|---|
| 进程信号 | `SIGSEGV` + handler 路径退出 | 主证据：用户态可直接观测的 fault |
| 内核日志 | 对应时间窗的 fault 相关行（如能捕获） | 辅证据：只做存在性检查，不匹配固定字符串 |
| maps 反查 | 无 `0xCxxxxxxx` 行 | 反向证据：maps 只展示用户半区，找不到是预期的 |

### 5.2 Checkpoint（过关自查）

1. 不看讲义，写出 `PAGE_OFFSET`、`TASK_SIZE`、用户教学范围三个数字。
2. 为什么“地址看起来很大”不能作为根因？
3. fault 之后，哪两句话是禁止说的（非证明）？

## 6. 验证方法 (Verification)

1. 程序以 handler 路径退出（示例 `exit=42`），而不是沉默返回成功。
2. 能画出证据链：虚地址 `0xC0008000` → `>= PAGE_OFFSET` → 内核半区 → PL0 权限拒绝 → `SIGSEGV`。
3. 能说出两条非证明：fault 不证明该虚地址背后有/无物理页；不证明任意内核物理内存的内容。

## 7. 典型失败模式 (Failure modes)

* 用 `-O2` 把受控读优化掉——用 `-O0` 且经 `volatile` 访问（源码已处理）。
* 在 handler 里调用非异步安全函数导致二次 fault——本源码 handler 只做最小打印与 `_exit`。
* 把“地址看起来很大”当作唯一论证——必须同时引用切分值与权限边界，否则 F13 判 FAIL。
* 硬匹配某行 `dmesg` 字符串——文本未校准，匹配失败不代表实验失败。

## 8. 调试策略 (Debug strategy)

先确认二进制身份与运行方式（是否真在目标上跑）；再确认地址常量（`>= 0xC0000000`？）；再确认信号行为（handler 是否生效）；最后才看 `dmesg`。`dmesg` 为空时优先怀疑 console/log 等级配置，而不是宣布“没有 fault”。

## 9. 证据状态

* 目标编译/链接：**VERIFIED**（actual-host `arm-linux-gnueabihf-gcc 13.3.0` 静态 ARM EABI 构建成功）。
* QEMU 运行（受控 fault）：**VERIFIED**（`qemu-arm` user-mode 下、以及 **canonical Linux 6.18.50 客机**下，解引用 `0xC0008000` 均触发 `SIGSEGV`，handler 按预期 `exit=42`）。
* 内核日志捕获：**UNVERIFIED**（本校准未做 `dmesg` 文本匹配；只记录进程侧信号证据）。
* 证据边界：运行环境是 **canonical 6.18.50 内核 + actual-host QEMU 8.2.2**；`canonical QEMU 11.1.1 runtime` 仍 **UNVERIFIED**。fault 不证明该虚地址背后有/无物理页。
* GDB：**UNVERIFIED**。物理板：**UNVERIFIED**（out of scope）。完整证据见 `fixtures/calibration-evidence.md`。

## 10. 扩展挑战 (Extension, SHOULD)

分别尝试 `0xBFFFFFFF`（用户顶之外、内核之下，视配置可能 fault）与 `0xBF000000`（`TASK_SIZE` 边界），记录信号行为差异，并用切分 + module-space 概念解释。不得把本次扩展的地址值当作 scored material 的答案。
