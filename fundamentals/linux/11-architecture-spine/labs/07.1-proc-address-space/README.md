# Lab 7.1 — 观察一个进程的地址空间 (Process Address Space)

**Time:** ~50 min MUST。**Prerequisite:** P3-M03（交叉编译与 target ELF）、P3-M04（QEMU appliance 启动）。

---

## 1. 目标 (Objective)

构建并运行一个小的 ARM 目标程序，打印四类地址：函数/`.text` 对象 (function/text)、全局/静态对象 (global/static)、堆分配 (heap)、栈变量 (stack)，并与 `/proc/<pid>/maps` 逐行对照。学完你能说出每类地址落在哪个映射里，以及 maps **不能证明什么**。

## 2. 前置知识 (Prerequisites)

* ELF 段概念：`.text` 可执行、`rodata` 只读、`data/bss` 可写；堆向上长、栈向下长（概念层即可）。
* 交叉编译基线：`arm-none-linux-gnueabihf-`，`file` 能区分 target/host ELF。
* 冻结切分结论：`PAGE_OFFSET=0xC0000000`，`TASK_SIZE=0xBF000000`，用户教学范围 `0x00000000–0xBEFFFFFF`。

## 3. 环境与版本 (Environment)

* Canonical：Arm GNU Toolchain 13.3.rel1，Linux 6.18.50（`v6.18.50`），QEMU 11.1.1（`virt,highmem=off,gic-version=2`，`cortex-a7`，`-m 512M`）。
* 校准所用 actual-host 环境（非 canonical）：`arm-linux-gnueabihf-gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0` + binutils 2.42；`qemu-system-arm 8.2.2`；真实内核 boot 用 **canonical Linux 6.18.50**（冻结配置 `CONFIG_ARM_LPAE=n` + `CONFIG_VMSPLIT_3G=y`，见 §9）。
* 本实验源码：`src/addrspace.c`。目标运行已在 actual-host ARM 内核上 **VERIFIED**（见 §9）。

## 4. 步骤 (Procedure)

```bash
# 注意: gnueabihf 硬浮点工具链下, 只给 -march=armv7-a 会报
#   "cc1: error: '-mfloat-abi=hard': selected architecture lacks an FPU"
# 必须补 -mfpu=vfpv4-d16 -mfloat-abi=hard (canonical arm-none-linux-gnueabihf 同理).
arm-none-linux-gnueabihf-gcc -static -march=armv7-a -mfpu=vfpv4-d16 \
  -mfloat-abi=hard -marm -O0 -g -o addrspace.elf src/addrspace.c
file addrspace.elf   # 确认 ARM 32-bit target ELF (statically linked)
# 拷入 appliance rootfs 并在 QEMU 目标上运行:
./addrspace.elf
```

主机冒烟（可选，只验证逻辑，不验证目标行为）：

```bash
gcc -O0 -g -o /tmp/addrspace.host src/addrspace.c && /tmp/addrspace.host | head -20
```

`fixtures/maps_sample.txt` 是本模块的对照样本（真实捕获，见 §5 与 §9）。

## 5. 预期可观察现象 (Expected observable)

下面是**真实捕获**（canonical Linux 6.18.50 内核 boot 上运行本实验，非预测；pid/ASLR 地址每次会变，区间归属是稳定事实）：

```text
VERIFIED — real capture (canonical Linux 6.18.50, actual-host qemu-system-arm 8.2.2)
pid            : 45
func   .text  : 0x10440
global data   : 0x62230
global bss    : 0x63014
heap  malloc  : 0x66da0
stack local   : 0xbedc4b90
---- /proc/self/maps ----
00010000-0005f000 r-xp 00000000 00:02 5   /addrspace.elf
0005f000-00062000 r--p 0004e000 00:02 5   /addrspace.elf
00062000-00063000 rw-p 00051000 00:02 5   /addrspace.elf
00063000-00066000 rw-p 00000000 00:00 0
00066000-00088000 rw-p 00000000 00:00 0   [heap]
beda4000-bedc5000 rw-p 00000000 00:00 0   [stack]
bede1000-bede2000 r-xp 00000000 00:00 0   [sigpage]
bede2000-bede6000 r--p 00000000 00:00 0   [vvar]
bede6000-bede7000 r-xp 00000000 00:00 0   [vdso]
ffff0000-ffff1000 r-xp 00000000 00:00 0   [vectors]
```

对照规则（格式 per `Documentation/filesystems/proc.rst §1.1`：`address perms offset dev inode pathname`）：

| 打印地址 | 应落入的映射 | 为什么 |
|---|---|---|
| 函数地址 | `r-xp` TEXT 段 | 代码段可执行、不可写 |
| 全局 data/bss | `rw-p` 数据段 | 可写、文件偏移对应 ELF 数据段 |
| `malloc` 返回 | `[heap]` | 程序 break 之上的匿名可写区 |
| 局部变量 | `[stack]` | 栈顶之下，`bf000000` 即 `TASK_SIZE` 边界 |

### 5.1 perms 与 offset 速读

每一行 maps 的 `perms` 都是四个字符（`r/w/x` + `p/s`），含义必须一次讲对：

| 字符位 | 取值 | 含义 |
|---|---|---|
| 1 | `r` / `-` | 可读 / 不可读 |
| 2 | `w` / `-` | 可写 / 不可写 |
| 3 | `x` / `-` | 可执行 / 不可执行 |
| 4 | `p` / `s` | 私有 (private, 写时复制) / 共享 (shared) |

`offset` 是该映射在 backing 文件中的偏移：`r-xp` TEXT 的 `offset 00000000` 对应 ELF 文件头之后的代码；`rw-p` 数据段的非零 offset（如 `0000b000`）对应 ELF 的数据段文件偏移；`[heap]`/`[stack]` 的 `00:00 0` 表示匿名映射（无文件、无设备、无 inode）。

### 5.2 四类地址的归宿（以样本值为例）

| 打印值 | 落入区间 | 判定 |
|---|---|---|
| `0x10440` | `00010000-0005f000 r-xp` | TEXT，函数/代码归宿 |
| `0x62230` / `0x63014` | `00062000-00063000 rw-p` | 数据段，全局可写对象归宿 |
| `0x66da0` | `00066000-00088000 rw-p [heap]` | 堆，`malloc` 归宿（随分配增长） |
| `0xbedc4b90` | `beda4000-bedc5000 rw-p [stack]` | 栈，局部变量归宿（`bf000000` = `TASK_SIZE`） |

`[vectors]`（`ffff0000-ffff1000 r-xp`）是 ARM high-vectors  helper 页：每个进程都能看到它，但它不是通用映射，不要把它当成“第五类用户内存”来讲。

### 5.3 Checkpoint（过关自查）

1. 四个打印地址各属于哪一行 maps？权限字母是否符合 §5 表格？
2. 为什么 `[heap]` 行的 `inode` 是 `0` 而 TEXT 行不是？
3. 用一句话说出 maps 的非证明：________________________________。

## 6. 验证方法 (Verification)

1. 四个打印地址全部 `< 0xBF000000`（`TASK_SIZE` 守卫）。
2. 每个地址都能在 maps 转储中找到包含它的 `start-end` 区间，且权限符合上表（`r-xp`/`rw-p`）。
3. 说出一条非证明 (non-proof)：maps 的任一行都不标识其背后的物理帧 (physical frame)。

## 7. 典型失败模式 (Failure modes)

* 用主机 `gcc` 直接编译出 x86-64 ELF，QEMU 里 `Exec format error`——回到 P3-M01 用交叉工具链重编。
* 开了 `-O2` 后局部变量被优化掉，栈地址打印恒定或消失——用 `-O0`。
* 期望每次运行地址完全固定——PIE/ASLR 下堆栈地址会变；要求的是**落在哪个区间**，不是绝对值相等。
* 在 maps 里找 `0xCxxxxxxx`——内核半区从不出现在该文件，找不到是预期的。

## 8. 调试策略 (Debug strategy)

地址对不上时按此顺序：先 `file` 确认 ELF 身份；再看打印地址是否越过 `TASK_SIZE`；再核对 maps 区间端点是开/闭（`start` 含、`end` 不含）；最后才怀疑 rootfs 传错了二进制。任何一步都记录命令与输出，不要跳步猜。

## 9. 证据状态

* 目标编译/链接：**VERIFIED**（actual-host `arm-linux-gnueabihf-gcc 13.3.0` 静态 ARM EABI 构建成功）。
* maps live 捕获：**VERIFIED**（actual-host `qemu-system-arm 8.2.2` + **canonical Linux 6.18.50** 真实 boot，§5 为真实捕获）。
* 证据边界：
  * 3G/1G 切分（栈在 `0xBF000000` 之下、无 `0xC0000000+` 行）：**VERIFIED**，即 `CONFIG_VMSPLIT_3G=y` 行为。
  * 短描述符（non-LPAE）翻译模型：**VERIFIED**（canonical 内核 boot log `cr=10c5387d` → `SCTLR.TRE=1,AFE=0`，与 `proc-v7-2level.S:164` 的 non-LPAE `v7_crval` 一致；且冻结配置 `CONFIG_ARM_LPAE=n`）。
  * maps 行只证明虚拟映射与用户/内核切分，**不证明** L1/L2 描述符表内容，也不证明物理帧。
  * canonical QEMU 11.1.1 appliance boot：**UNVERIFIED**（本捕获用 actual-host 8.2.2）；canonical Arm GNU 13.3.rel1 工具链构建：**UNVERIFIED**（用 actual-host 工具链）。
* `strace` 观察：**UNVERIFIED**（actual-host 无 `strace`）。
* 物理板：**UNVERIFIED**（out of scope）。完整证据见 `fixtures/calibration-evidence.md`。

## 10. 扩展挑战 (Extension, SHOULD)

在 appliance 上 `cat /proc/<pid>/maps` 对比另一个进程（如 shell）的栈/堆位置，解释为什么两个进程可以同时拥有“相同的虚地址”却互不干扰（页表隔离，概念层回答即可）。
