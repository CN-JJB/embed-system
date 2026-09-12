# P3-M08 Source Ledger — Reproducible QEMU Embedded Linux Appliance

> Checked: **2026-09-12**（authoring host，Windows + WSL Ubuntu）。
>
> 本 ledger 分离 **actually executed（实际执行）** 与 **pinned but not run
>（已钉住但未执行）**。状态词仅用 `VERIFIED` / `PARTIALLY VERIFIED` /
> `UNVERIFIED`。任何推理都不升级证据。
>
> 本机**可以**执行的部分：host 交叉编译、静态 ELF 检查、真实 initramfs 构造、
> `qemu-arm` user-mode 运行、`qemu-system-arm` 实际启动路径与失败分类。
> 本机**不能**执行的部分：canonical Linux 6.18.50 构建、Buildroot 完整构建、
> canonical QEMU 11.1.1 客机启动。两栏严格分开报告。

---

## 1. Upstream traceability（上游可追溯性，6 pins + toolchain）

| ID | Source / artifact | Organization | Type | Exact path / section | Version · tag · peeled commit | Upstream origin | Checked | Teaching purpose | Risk / constraint |
|---|---|---|---|---|---|---|---|---|---|
| M08-S01 | Linux kernel source | kernel community | Official upstream source | `arch/arm/kernel/head.S`, `init/main.c`, `Documentation/admin-guide/kernel-parameters.rst` | **6.18.50 LTS** · tag `v6.18.50`（tag object `7995d95093f421fc173190b2f7551d8e8b0ff86f`） · peeled commit `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7` | `git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 2026-09-12 | M06 pin 复用；M08 只绑定 `zImage` hash，不重钉内核 | GPL-2.0-only；**not built here** |
| M08-S02 | QEMU system emulator | QEMU project | Official upstream source | `docs/system/arm/virt.rst` | **11.1.1** · tag `v11.1.1`（tag object `5e35f26695645b20931e10d8567c7e0169e62c07`） · peeled commit `c3d48b7d1e89604920e5b81b91140c2ad39a1943` | `https://gitlab.com/qemu-project/qemu.git` | 2026-09-12 | frozen argv `virt,highmem=off,gic-version=2` + `cortex-a7` + `512M` + `smp 1` | GPL-2.0；actual-host 与 canonical 分离报告 |
| M08-S03 | BusyBox multi-call binary | BusyBox project | Official upstream source | `init/init.c`, `applets/applets.c` | **1.36.1** · tag `1_36_1` · commit `1a64f6a20aaf6ea4dbba68bbfa8cc1ab7e5c57c4` | `https://git.busybox.net/busybox/` | 2026-09-12 | manual userspace 对比路径的 pin | GPL-2.0-only；M08 主路径经 Buildroot 复用 |
| M08-S04 | Buildroot build system | Buildroot project | Official upstream source | `docs/manual/customize-rootfs.adoc`, `docs/manual/rebuilding-packages.adoc`, `package/busybox/busybox.mk` | **2026.05.2** · tag `2026.05.2`（tag object `d5774f1666c406402abc46c94aa1517775dd61af`） · peeled commit `72d9d4fa636a371ef9eb99c92a735ce9f6d829d5` | `https://gitlab.com/buildroot.org/buildroot.git` | 2026-09-12 | primary path：image reuse + overlay + stamp 规则（F12） | GPL-2.0-or-later；**not built here** |
| M08-S05 | Device Tree Compiler | DTC project | Official upstream source | `dtc/` source tree | **v1.7.0** · tag object `66dbfc5bbbbc2aade889881a2b4358eab6b4fac7` · peeled commit `039a99414e778332d8f9c04cbd3072e1dcc62798` | `https://git.kernel.org/pub/scm/utils/dtc/dtc.git` | 2026-09-12 | explicit DTB 供给时的编译器 pin | GPL-2.0-or-later / BSD-2-Clause |
| M08-S06 | Devicetree Specification | devicetree.org | Specification | release documents | **v0.4** · tag object `3bd573063e4d8c8e20879f935674516b87364243` · peeled commit `112f53cc57e5931f1503dfcaa1644caf15362c30` | devicetree spec release | 2026-09-12 | DT 语义权威（model / compatible / reg） | CC-BY-4.0 |
| M08-S07 | Cross-toolchain | Arm | Official package | toolchain tarball | **Arm GNU Toolchain 13.3.rel1** · package `arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-linux-gnueabihf.tar.xz` · **SHA256 `560267bdecf966b7a48467d0af6c81a85b906ef7b0a9b9dd91f506184b940281`** · GCC 13.3.1 / Binutils 2.42 / Glibc 2.39 · triple `arm-none-linux-gnueabihf-` | Arm developer site | 2026-09-12 | `src/appliance-diag.c` 交叉编译基线 | GPL-3.0-with-GCC-exception；alternate distro `arm-linux-gnueabihf-` 仅显式声明时可用 |

Kernel config contract（冻结）：`multi_v7_defconfig` + `CONFIG_ARCH_VIRT=y`，
`CONFIG_ARM_LPAE=n`，`CONFIG_VMSPLIT_3G=y`（`PAGE_OFFSET=0xC0000000`），
`CONFIG_SERIAL_AMBA_PL011=y`，`CONFIG_DEVTMPFS=y`（+`MOUNT`），
`CONFIG_VIRTIO_MMIO=y`，`CONFIG_VIRTIO_BLK=y`，`CONFIG_EXT4_FS=y`。

---

## 2. Pin verification actually performed（实际执行的 pin 核验）

| # | Action | Exact command（abridged） | Result | Status |
|---|---|---|---|---|
| 0 | Upstream pin resolution（全部 6 pins） | `git ls-remote <remote> 'refs/tags/<tag>*'`（kernel.org stable、gitlab qemu-project、github mirror/busybox、kernel.org utils/dtc、github devicetree-org、gitlab buildroot） | 六组 peeled commit **与 §1 声明的值逐字相符**：Linux `7cfc41f8…b79c7`；QEMU `c3d48b7d…a1943`；BusyBox `1a64f6a2…57c4`；DTC `039a9941…2798`；DT Spec `112f53cc…2c30`；Buildroot `72d9d4fa…29d5`（tag object 亦与 §1 记录一致） | **VERIFIED** |
| 1 | Manifest pins vs contract | `python3 scripts/manifest.py --validate fixtures/sample_manifest.json` | PASS（6 pins + toolchain SHA + DT dual-mode + hash form） | **VERIFIED**（tooling） |
| 2 | Run record shape | `scripts/verify_project.sh` step 2（argv + 4-token bootargs） | PASS | **VERIFIED**（tooling） |
| 3 | Sample image audit | `audit_final_image.py --image <materialised> --overlay overlay` | PASS（in-image / not-stale / no-decoy）；截断归档仍 ERROR（未放宽严格性） | **VERIFIED**（tooling, synthetic） |
| 3a | cpio 生成器自检 | `python3 scripts/materialise_sample_cpio.py --self-test` | PASS（字段布局 pin + plain/gzip 往返） | **VERIFIED**（tooling） |
| 4 | Binder negative controls | authoring regression entry point（assessment-private） | 见 §2.1 | 见 §2.1 |
| 5 | Isolation audit | assessment-private isolation audit | 见 §2.1 | 见 §2.1 |
| 7 | Real appliance QEMU boot（canonical 11.1.1） | —（QEMU 11.1.1 未安装） | not attempted | **UNVERIFIED** |
| 7a | Canonical 内核构建 | `make -C fundamentals/linux/06-kernel-build-boot real-kernel-build-check LINUX_SRC=/opt/pins/linux-6.18.50`（`CROSS_COMPILE=arm-linux-gnueabihf-`） | **Linux 6.18.50** 由 pinned commit 以冻结配置（`multi_v7_defconfig` + `phase3_delta.config`，`# CONFIG_ARM_LPAE is not set` / `CONFIG_VMSPLIT_3G=y`）构建成功；真实 `zImage` 11817472 B，sha256 `46e75c3d…f0b0`；`vmlinux` ARM，`System.map` 与 `vmlinux` 一致 | **VERIFIED** |
| 7b | **Canonical 客机 appliance boot + binder** | `bash scripts/run_appliance.sh --manifest build/canonical-appliance/appliance.manifest.json …`，随后 `python3 scripts/verify_m08_runtime.py …` | 冻结机器契约 + 冻结 4-token bootargs 启动 **canonical Linux 6.18.50** 客机；overlay `S99appliance-diag` 运行（`APPLIANCE-OVERLAY-BOOT-MARKER`）；诊断工具输出真实 `KERNEL-RELEASE=6.18.50` / `DT-MODEL=linux,dummy-virt` / `APPLIANCE-RELEASE` / `UPTIME-SEC` / `MEM-AVAILABLE-KB`；终镜像审计 5/5 PASS；runner exit **0**；binder **`=== APPLIANCE RUNTIME EVIDENCE: VERIFIED (bound to audited artifacts) ===`（rc=0）** | **VERIFIED**（actual-host QEMU 8.2.2 维度）；`canonical QEMU 11.1.1 runtime` 仍 **UNVERIFIED** |
| 7c | Runner 退出分类（真实客机） | 四类真实工况 | `0` capture-done（健康 appliance boot）✓；`2` LAUNCH-FAIL（缺输入）✓；`3` GUEST-MARKER-ABSENT（客机干净退出但 image 缺 `/usr/bin/appliance-diag`，无 `APPLIANCE-DIAG-END`）✓；`124` TIMEOUT（panic 循环）✓ | **VERIFIED**（`1` ERROR 类未在本机触发 → **UNVERIFIED**） |
| 7d | **Fault A 客机侧复现** | 直接 QEMU 调用（**对冻结 argv 的刻意偏离以制造故障**）`rdinit=/init` 指向无该路径的 image | 真实 panic：`Trying to unpack rootfs image as initramfs...` 紧随 `Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)` | **VERIFIED**（原始预测的 `No working init found` 被实测证伪，已修正文档） |
| 7e | **Fault A binder 侧** | 在真实 canonical manifest + 真实 log 上仅 skew `rdinit` | `REJECT: 2 check(s) failed: ['argv.fingerprint', 'bootargs.exact-set']`；rc=**1** | **VERIFIED**（semantic REJECT，非 ERROR） |
| 7f | **Fault B 客机侧复现 + binder** | init 不挂载 sysfs，其余不变 | 客机：`DT-MODEL=UNAVAILABLE` 而 `KERNEL-RELEASE`/`APPLIANCE-RELEASE`/`UPTIME-SEC`/`MEM-AVAILABLE-KB` 全部健康；binder：`REJECT: 1 check(s) failed: ['guest.dt-model']`；rc=**1** | **VERIFIED** |
| 7g | Fail-closed 退出分类（shim + 真实） | 4 类 shim + 真实缺失输入/QEMU 不存在/畸形 manifest | exit 0 现要求 `APPLIANCE-DIAG-END` 存在；真实路径观察到 2 / 3 / 124 | **VERIFIED** |
| 8 | Fault runtime reproduction | 见 7d–7f | 两条 fault 均在真实 canonical 客机上复现并被 binder 拒绝 | **VERIFIED**（此前为 UNVERIFIED） |
| 9 | Live GDB / physical measurement | —（out of scope） | — | **UNVERIFIED** |

Fault campaign 的完整逐字记录见 `faults/FAULT_CAMPAIGN_EVIDENCE.md`。

## 2.1 Reviewer-only regression status

Assessment-private regression entry points are described here by role rather than
by path, so that learner-facing documentation never names assessment-private
assets. The authoritative, current pass/fail state of those entry points is
recorded in the pull-request handoff report, which is the surface the Leader
reviews; it is deliberately not duplicated into learner-facing text.

Two facts belong here because they concern this ledger's own accuracy:

* The binder's negative-control regression is the only mechanism that proves the
  runtime binder rejects mismatched provenance. Until it runs green end to end,
  the binder must be reported as **PARTIALLY VERIFIED**, not VERIFIED.
* Binder consistency is not authenticity: the static binder proves manifest /
  run-record / log / artifact agreement, and **cannot** prove the log came from a
  trusted execution. Authenticity still requires a trusted replay of the exact
  argv on a trusted host. See `BUILD_RUN_DEBUG.md` §4.

### Actual-host vs canonical

| Dimension | Canonical | Actually used | Status |
|---|---|---|---|
| Linux | 6.18.50（pin） | pin verified；**not built** | pin VERIFIED, build UNVERIFIED |
| QEMU（appliance boot） | 11.1.1（`v11.1.1`） | host QEMU **8.2.2**；`canonical_claim=false` 记录在 run record | actual-host argv/launch VERIFIED；canonical runtime UNVERIFIED |
| Buildroot | 2026.05.2 | source inspected via M06；**not built** | pin VERIFIED, build UNVERIFIED |
| Toolchain | 13.3.rel1 `arm-none-linux-gnueabihf-` | Ubuntu `arm-linux-gnueabihf-gcc` 13.3.0 | actual-host compile VERIFIED；canonical toolchain UNVERIFIED |
| Host | POSIX（Linux） | Windows + WSL Ubuntu | **not the canonical build host** |

---

## 3. Committed artifacts and their provenance（提交物来源）

| Artifact | Origin | Status |
|---|---|---|
| `manifest.schema.json` / `run.schema.json` | authored for this repo（design §exact schemas） | **VERIFIED**（structure） |
| `fixtures/sample_manifest.json` / `fixtures/sample_run.json` | **SYNTHETIC** authored samples（tiny, labelled） | **VERIFIED**（tooling fixture） |
| `src/appliance-diag.c` / `src/Makefile` | original work（minimal, no network） | **VERIFIED**（structure）；target compile **VERIFIED**（actual-host） |
| `overlay/**` | original work | **VERIFIED**（structure） |
| `scripts/materialise_sample_cpio.py` | original work；确定性 newc cpio 生成器（单一 writer，带 `--self-test`） | **VERIFIED**（tooling） |
| assessment-private reference invariants + hidden fault seeds | authored for this repo | **VERIFIED**（structure；路径见 §2.1） |

No kernel / Buildroot source tree，no `output/`，no toolchain，no `*.cpio.gz`，
no `*.log` committed。所有真实运行产物（`build/appliance-diag`、
`build/initramfs.cpio.gz`、`build/*.run.json`、`build/*.provenance.json`、
`build/virt.dtb`）都在 gitignored 的 `build/` 下，**未提交**。

---

## 4. Evidence summary（证据汇总）

| Dimension | Status |
|---|---|
| Linux / QEMU / BusyBox / Buildroot / DTC / DTSpec pins | **VERIFIED**（§2 row 0：上游 `git ls-remote` peeled commit 逐字相符 + contract cross-check） |
| Toolchain package SHA | **VERIFIED**（pin string match）；canonical toolchain 未安装 |
| Host/static validators | **VERIFIED**（executed, see §2 rows 1–3a, 7g） |
| Target compile/link | **VERIFIED**（actual-host `arm-linux-gnueabihf-gcc` 13.3.0）；canonical Arm GNU 13.3.rel1 **UNVERIFIED** |
| Static ELF contract | **VERIFIED**（readelf -h/-A: EABI5, hard-float, v7, VFPv4, static） |
| Canonical 内核构建（Linux 6.18.50） | **VERIFIED**（pinned commit + 冻结配置；真实 `zImage`/`vmlinux`/`System.map`） |
| **Canonical 客机 appliance boot** | **VERIFIED**（actual-host QEMU 8.2.2 维度；冻结机器契约 + 冻结 4-token bootargs） |
| **Runtime artifact binding（真实客机）** | **VERIFIED**（binder rc=0，全部 hash/argv/bootargs/milestone/overlay/RAM/CPU/execution 检查 PASS；仍为 consistency，authenticity 需可信重放） |
| Diagnostic 真实执行（arm user-mode） | **VERIFIED**（actual-host 维度；≠ 客机，≠ canonical 11.1.1） |
| Fail-closed launch classification | **VERIFIED**（0/2/3/124 四类均在真实工况观察到；`1` ERROR 类未触发 → UNVERIFIED） |
| Final image audit | **VERIFIED**（tooling synthetic + 真实 canonical appliance 镜像 5/5 PASS） |
| **Fault campaign runtime reproduction** | **VERIFIED**（Fault A 与 Fault B 均在真实 canonical 客机上复现，binder 分别 rc=1） |
| canonical QEMU 11.1.1 runtime | **UNVERIFIED**（本机 QEMU 8.2.2） |
| Complete Buildroot build | **UNVERIFIED**（未构建） |
| Live GDB / physical board | **UNVERIFIED**（out of scope） |
