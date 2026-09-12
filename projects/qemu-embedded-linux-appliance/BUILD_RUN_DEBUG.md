# BUILD_RUN_DEBUG — P3-M08 Appliance（构建/运行/调试手册）

> 本文件只描述**实际可执行的命令**与**证据边界**。
> 一切未在本机执行的输出一律标记 `EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED`，
> 不得作为证据引用。

---

## 1. Build（构建）

### 1.1 轻量默认路径（无 heavy，总能跑）

```bash
make manifest        # 样本 manifest schema 验证
make check           # learner-safe 检查：schema + run 形状 + sample 镜像审计 + 工作区
make audit IMAGE=build/sample-rootfs.cpio.gz   # 需先有 IMAGE，否则 fail-closed
```

### 1.2 Opt-in Buildroot image reuse（主路径，需 POSIX + BUILDROOT_SRC）

```bash
# 1. 用 M06 外部树配置并构建（canonical 2026.05.2）
#    注意路径深度：本目录是 <repo>/projects/qemu-embedded-linux-appliance，
#    因此仓库根下的 fundamentals/ 需要 ../../fundamentals/...（../ 会指向 projects/）。
make -C /path/to/buildroot-2026.05.2 O=$PWD/build/br-output \
  BR2_EXTERNAL=$PWD/../../fundamentals/linux/10-shallow-buildroot/fixtures/br2-external \
  qemu_virt_a7_defconfig
make -C /path/to/buildroot-2026.05.2 O=$PWD/build/br-output \
  BR2_EXTERNAL=$PWD/../../fundamentals/linux/10-shallow-buildroot/fixtures/br2-external -j$(nproc)

# 2. 用实物 hash 写 M08 manifest（DT 双模二选一）
python3 scripts/manifest.py --write \
  --kernel build/br-output/images/zImage \
  --rootfs build/br-output/images/rootfs.cpio.gz \
  --overlay overlay --qemu-generated-dt --out build/appliance.manifest.json
# explicit DTB 时：--dtb build/br-output/images/qemu-virt.dtb（代替 --qemu-generated-dt）

# 3. 审计终镜像
python3 scripts/audit_final_image.py \
  --image build/br-output/images/rootfs.cpio.gz --overlay overlay
```

### 1.3 `SITE_METHOD=local` + dirclean vs rebuild（F12 规则，凡 rebuild 必读）

`appliance-diag` 类包使用 `APPLIANCE_DIAG_SITE_METHOD = local` 时：

* plain `make` 跳过已存在 `.stamp_target_installed` 的包；
* `make <pkg>-rebuild` 不重提外部 SITE（`.stamp_extracted` 保留），
  重编的是 `output/build/` 内 stale copy；
* 正确恢复：`make <pkg>-dirclean all`（删 build dir → 重提 SITE → 重编 →
  更新 `target/` → 重打 image），再用 `audit_final_image.py` + binder 回归。

```bash
make -C "$BR_SRC" O="$OUTPUT" BR2_EXTERNAL="$BR2_EXT" appliance-diag-dirclean all
```

### 1.4 诊断工具交叉编译（SHOULD 对比路径）

```bash
make -C src CROSS_COMPILE=arm-none-linux-gnueabihf-   # 产物 appliance-diag（不提交）
```

---

## 2. Run（运行，非交互捕获）

```bash
bash scripts/run_appliance.sh \
  --manifest build/appliance.manifest.json \
  --log build/appliance.log \
  --run build/appliance.run.json
# opt-in Buildroot 输出树：追加 --output build/br-output（自动取 images/）

# 绑定验证（reviewer-grade binder，可 opt-in 单独用）
python3 scripts/verify_m08_runtime.py \
  --manifest build/appliance.manifest.json \
  --run build/appliance.run.json \
  --log build/appliance.log --overlay overlay
```

Runner 退出码（fail-closed 分类）：`0` capture-done（**要求 console log 中出现
`APPLIANCE-DIAG-END`**）/ `1` ERROR / `2` LAUNCH 或 RUNTIME FAIL（缺输入，或 QEMU
非零退出）/ `3` GUEST-MARKER-ABSENT（QEMU 退出 0 但缺 `APPLIANCE-DIAG-END`）/
`124` TIMEOUT。QEMU 非零退出绝不映射为成功。
Runner **永不**打印 `[OK]` / `[PASS]` / `VERIFIED` 论证 boot；
只报告 `qemu exit code` + `console log` + `run record` 指针。
Boot 结论只由 binder 给出，且恒带 authenticity disclaimer。

**本机四类退出码均已用真实客机观察（不只是 shim）**，逐字记录见
`faults/FAULT_CAMPAIGN_EVIDENCE.md` §1：`0`（健康 appliance boot）、
`2`（缺输入）、`3`（客机干净退出、overlay 已跑、但 image 内缺
`/usr/bin/appliance-diag`，故无 `APPLIANCE-DIAG-END`）、`124`（panic 循环无
`-no-reboot` 时到点被杀）。`1` ERROR 类未在本机触发，仍 **UNVERIFIED**。

冻结 argv 与 4-token bootargs 见 `README.md` §3；`--help` 外的任何改形即偏离契约。

---

## 3. Debug（调试：两故障速查）

### Fault-a — boot-chain `rdinit` skew（`rdinit=/init` vs `/sbin/init`）

* Symptom：`Kernel panic - not syncing: No working init found` 或等价 init 握手失败。
* Discriminating evidence（三件套，缺一不可）：
  1. guest `Kernel command line:` 行（确认实际 `rdinit=` 值）；
  2. `Run /sbin/init as init process` 缺席 vs `try_to_run_init_process` 相关行；
  3. `audit_final_image.py` 的 cpio listing（确认 `/sbin/init` 是否真实在 image 内）。
* Fix：`bootargs` 改回 `rdinit=/sbin/init`（精确 4-token 集）+ **re-materialize**
  run record（重跑 `run_appliance.sh`，更新 fingerprint + hashes），再 binder 回归。
* 详见 `faults/fault-a-bootchain-rdinit-skew/README.md`。

### Fault-b — userspace `/sys` 未挂载（`DT-MODEL=UNAVAILABLE` 但余者健康）

* Symptom：diag 完整跑完（BEGIN..END），唯 `DT-MODEL=UNAVAILABLE`。
* Probes：
  1. guest `/proc/mounts`（确认缺 `sysfs /sys` 行）；
  2. `ls /sys/firmware/devicetree/base`（`No such file or directory`）；
  3. 其余 diag 行（`KERNEL-RELEASE` / `UPTIME-SEC` / `MEM-AVAILABLE-KB`）健康，
     证明非内核/argv 故障。
* Fix：恢复 init 脚本 `mount -t sysfs` 行 → repack image → rehash manifest →
  重跑 binder。
* 详见 `faults/fault-b-userspace-sysfs/README.md`。

---

## 4. Boundaries（边界：什么能证、什么不能）

| 产物 | 能证明 | 不能证明 |
|---|---|---|
| `manifest.py --validate` PASS | pins + schema + hash 形式正确 | 镜像真实存在/可启动 |
| `audit_final_image.py` PASS | overlay 真实在终镜像内且非 stale/decoy | guest 真的执行了它 |
| `run_appliance.sh` exit 0 | capture 完成 + provenance 先于执行 + 客机出现 `APPLIANCE-DIAG-END` | boot 成功（永不声称）；exit 3 表示客机干净退出但缺 marker |
| `verify_m08_runtime.py` exit 0 | manifest + run + log 三方一致 + `qemu.execution` 通过（QEMU 退出 0、未超时） | 真实执行（authenticity 需重放 argv） |
| `<15min` 构建时间 | 环境相关证据（env-specific） | 通用正确性（never hard gate） |
| actual-host QEMU 输出 | actual-host 维度证据 | canonical 11.1.1 维度（`canonical_claim` gate 分离） |

**本机已完成的真实运行（逐字证据见 `faults/FAULT_CAMPAIGN_EVIDENCE.md`）：**

```bash
# canonical Linux 6.18.50 构建（冻结配置）
make -C fundamentals/linux/06-kernel-build-boot real-kernel-build-check \
     LINUX_SRC=/opt/pins/linux-6.18.50 CROSS_COMPILE=arm-linux-gnueabihf-
# -> zImage 11817472 B, sha256 46e75c3d23ef46091e2d6ea86b4a0e1c96d7ae343b9898d538beb20ecf57f0b0

# 真实 appliance 启动 + 绑定
bash scripts/run_appliance.sh --manifest build/canonical-appliance/appliance.manifest.json \
     --log build/canonical-appliance/appliance.log \
     --run build/canonical-appliance/appliance.run.json
# -> RUNNER_RC=0（guest success marker present）
python3 scripts/verify_m08_runtime.py --manifest build/canonical-appliance/appliance.manifest.json \
     --run build/canonical-appliance/appliance.run.json \
     --log build/canonical-appliance/appliance.log --overlay overlay
# -> === APPLIANCE RUNTIME EVIDENCE: VERIFIED (bound to audited artifacts) ===  rc=0
```

QEMU 维度仍为 **actual-host 8.2.2**（`canonical_claim=false` 已写入 run record）；
`canonical QEMU 11.1.1 runtime` 仍 **UNVERIFIED**。Buildroot 完整构建仍 **UNVERIFIED**。

**runner 与 binder 的真实逐字输出（本机已执行，非示意）：**

```text
[RUNNER] provenance recorded before execution: .../appliance.run.json
[RUNNER] qemu: QEMU emulator version 8.2.2 (Debian 1:8.2.2+ds-0ubuntu1.18)
[RUNNER] qemu exit code: 0
[RUNNER] console log: .../appliance.log
[RUNNER] run record: .../appliance.run.json
[RUNNER] capture-done: guest success marker present (APPLIANCE-DIAG-END).

... (binder) ...
[PASS] log.length -- 236 line(s); handwritten log rejected below 60 lines
[PASS] log.ordered-milestones -- 13 checkpoints in kernel order
[PASS] log.cmdline-exact-set -- logged [4 tokens] must equal frozen set (no extras)
[PASS] guest.ram -- guest RAM matches -m 512M (delta 0B within 16MiB)
[PASS] guest.cpu -- SMP total 1 vs -smp 1
[PASS] log.overlay-marker -- overlay boot marker proves S99appliance-diag ran
[PASS] log.diag-complete -- diagnostic utility ran BEGIN..END in order
[PASS] guest.kernel-release -- KERNEL-RELEASE '6.18.50' carries 6.18.50
[PASS] qemu.execution -- qemu exited 0 and did not time out
[PASS] qemu.canonical-claim -- actual-host QEMU 8.2.2 kept separate from canonical 11.1.1
------------------------------------------------------------------
NOTE: VERIFIED here means internal consistency + artifact identity.
      It does not prove real execution; authenticity requires the
      reviewer to re-execute the recorded argv on a trusted host.
=== APPLIANCE RUNTIME EVIDENCE: VERIFIED (bound to audited artifacts) ===
```
