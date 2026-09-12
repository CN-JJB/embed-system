# P3-M08 — Reproducible QEMU Embedded Linux Appliance（可复现 QEMU 嵌入式 Linux 一体机）

**Time budget（时间预算）:** 3.5 h MUST（+ ≤ 1.0 h SHOULD）
**Prerequisites（前置）:** P3-M01（toolchain），P3-M03（manual rootfs / BusyBox / PID 1），
P3-M04（bootargs / console），P3-M05（device tree），P3-M06（shallow Buildroot）
**Platform（平台）:** ARMv7-A / Cortex-A7，canonical QEMU `virt` machine

---

## 1. Mission（使命）

把 Phase 3 已经打通的整条链集成到**一个可复现、证据绑定（evidence-bound）的 appliance**，
而不增加任何应用功能膨胀（no application feature creep）：

```text
pinned inputs（6 pins + toolchain）
  -> kernel（zImage） + DT（QEMU-generated 或 explicit） + rootfs（initramfs via -initrd）
  -> reproducible manifest（SHA256 binding）
  -> canonical QEMU launch（frozen argv）
  -> PID 1 / appliance-diag health evidence
  -> runtime binder（manifest + run + log 三方一致）
  -> two-fault campaign + regression
```

Primary path（主路径）是 **Buildroot image reuse（复用 M06 产物）**，
经 `-initrd rootfs.cpio.gz` 启动（Contract-A 形状）；manual rootfs 只作为
SHOULD 对比实验（comparison lab），不另起第二套启动契约。

---

## 2. Reuse statement（复用声明）

本项目**不创建第二套不兼容栈**，全部复用 P3-M01–M07 的 canonical 机制：

| 复用项 | 来源 | 本项目用法 |
|---|---|---|
| QEMU hardware contract（`virt,highmem=off,gic-version=2` + `cortex-a7` + `512M` + `smp 1` + `-nographic`） | P3-M04 / roadmap | frozen launch argv（见 §3），任何偏离即 REJECT |
| Provenance-before-execution（先记录再执行） | P3-M04 `run_candidate_manifest.sh` | `scripts/run_appliance.sh` 先写 run.json 再执行 QEMU |
| Exact-set bootargs binding（精确集合绑定） | P3-M04 binder | 4-token 精确集合，manifest / run / guest 三处一致 |
| cpio overlay audit（`in-image / not-stale / no-decoy`） | P3-M06 `audit_output_tree.py` | `scripts/audit_final_image.py`（self-contained，见文件头文档） |
| Runtime binder（argv + hash + guest 三方绑定） | P3-M06 `verify_appliance_runtime.py` | `scripts/verify_m08_runtime.py`（M08 增强版） |
| Synthetic rejection（拒绝合成教具充当真机） | P3-M03 `run_real_qemu_m03.sh` | binder 的 `no-synthetic` + 60-line floor + ordered milestones |
| Build stamp rule（`SITE_METHOD=local` + dirclean） | P3-M06 F12 | 任何 Buildroot package rebuild 处均文档化（见 §6） |
| Fail-closed runner（QEMU 失败永不 `[OK]`） | P3-M06 reviewer runner | `run_appliance.sh` 永不打印 `[OK]/[PASS]/VERIFIED` 论证 boot |

---

## 3. Frozen launch contract（冻结启动契约，勿改）

Single frozen launch argv（唯一冻结启动参数）：

```text
qemu-system-arm -machine virt,highmem=off,gic-version=2 -cpu cortex-a7
  -m 512M -smp 1 -nographic
  -kernel <zImage> [-dtb <explicit>]
  -initrd <rootfs.cpio.gz>
  -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/sbin/init panic=1"
```

* `bootargs` 是**精确 4-token 集合**（exact-set，顺序无关，不许多、不许少、不许重复）：
  `console=ttyAMA0,115200`、`earlycon=pl011,0x09000000`、`rdinit=/sbin/init`、`panic=1`。
  binder 在 run record 与 guest `Kernel command line:` 两处强制 exact-set equality。
* DT dual-mode（设备树双模）：
  * `dt.source = "qemu-generated"` → **无 `-dtb` 参数**，QEMU 按 `-machine` 自动供给 DTB；
  * `dt.source = "explicit"` → 必须 `-dtb <path>` 且 SHA256 绑定，三方（manifest / run / file）一致，
    否则按 **stale DTB** REJECT。
* 任何 `highmem=on`、缺 `gic-version=2`、CPU / `-m` / `-smp` 偏离、argv 顺序/形状偏离
  均为 **argv skew** REJECT。

---

## 4. Layout（目录结构）

```text
qemu-embedded-linux-appliance/
  README.md                  本文件
  SOURCE_LEDGER.md           6 pins + toolchain SHA + executed-vs-pinned 切分
  BUILD_RUN_DEBUG.md         build / run / debug + 证据边界
  Makefile                   standalone；SHELL:=/bin/bash；heavy 永不默认执行
  .gitignore                 anchored 忽略（/build/ /output/ *.cpio.gz *.log …）
  manifest.schema.json       m08-manifest-v1 精确 schema
  run.schema.json            m08-run-v1 精确 schema
  scripts/
    run_appliance.sh         fail-closed 启动 harness（退出分类 0/1/2/3/124）
    manifest.py              manifest write + validate + SHA256 binding
    verify_m08_runtime.py    reviewer-grade binder（0 VERIFIED-consistency / 1 REJECT / 2 ERROR）
    audit_final_image.py     final image audit（in-image / not-stale / no-decoy）
    materialise_sample_cpio.py  确定性 newc cpio 生成器 + --self-test
    verify_project.sh        learner-safe 检查（不判隐藏变体）
  src/
    appliance-diag.c         原创 target 诊断工具（minimal，无网络/daemon/参数）
    Makefile                 CROSS_COMPILE 交叉编译
  overlay/
    etc/appliance-release    appliance 身份标记
    etc/init.d/S99appliance-diag  打印 marker 后 exec diag
  fixtures/
    sample_manifest.json     tiny SYNTHETIC-labelled 样本（仅 schema 示意）
    sample_run.json          tiny SYNTHETIC-labelled 样本（仅 argv 示意）
  faults/
    fault-a-bootchain-rdinit-skew/      boot-chain fault（rdinit 配对偏离）
    fault-b-userspace-sysfs/            userspace fault（/sys 未挂载）
  reviewer (directory)                  assessment-private：invariant reference、
                                        hidden fault seeds、突变回归入口、隔离审计
```

---

## 5. Milestones M0–M4（里程碑，fit 3.5 h MUST）

* **M0 — Reproducible workspace / input manifest（可复现工作区/输入清单）**:
  `scripts/manifest.py --write` 用 SHA256 绑定 kernel / rootfs /（explicit 时）DTB，
  `manifest.schema.json` 强制 6 pins + toolchain + kernel_config + DT 双模 + rootfs。
  生成物一律在 `/build/` 下，不进 Git。
* **M1 — Kernel / DT / rootfs artifact integration（制品集成）**:
  复用 M06 Buildroot 产物（`zImage` + `rootfs.cpio.gz` + 可选 explicit DTB），
  manifest 只列文件名不够，必须绑定 content hash。
* **M2 — Diagnostic utility + init integration（诊断工具/init 集成）**:
  `src/appliance-diag.c` 经 `S99appliance-diag` 在 PID 1 后执行，
  上报 kernel-release / uptime / mem / DT-model / appliance-release。
  无网络、无 server、无 UI、无 daemon。
* **M3 — Automated launch + runtime binding（自动启动/证据绑定）**:
  `scripts/run_appliance.sh` 非交互捕获，`scripts/verify_m08_runtime.py`
  做 manifest + run + log 三方绑定（argv / fingerprint / cmdline exact-set /
  ordered milestones + 60-line floor / RAM ±16MiB / CPU==smp / triple-hash /
  overlay 三性 / no-synthetic）。
* **M4 — Two-fault campaign（双故障战役）**:
  fault-a（boot-chain: `rdinit` 配对偏离）+ fault-b（userspace: `/sys` 未挂载），
  均走 `Symptom → Own Description → 3–5 Hypotheses → Experiment → Evidence →
  Narrow Scope → Root Cause → Fix → Regression`，回归均用 binder VERIFIED 关闭。

---

## 6. F12 precedent（Buildroot 增量规则，凡提 rebuild 必文档化）

`appliance-diag` 类 local 包满足 `SITE_METHOD = local` 时：

* plain `make` 永不重进已存在 `.stamp_target_installed` 的包；
* `make <pkg>-rebuild` 只清除 `.stamp_built` / `.stamp_target_installed`，
  **不重提**外部 SITE 源码（`.stamp_extracted` 保留），重编的是
  `output/build/` 内的 stale copy；
* 正确恢复是 `make <pkg>-dirclean all`（删 build dir → 强制重提 SITE →
  重编 → 更新 `target/` → 重打 image）。

凡本项目提及 Buildroot package rebuild，均适用本条（F12 worked tutorial 为准）。

---

## 7. Acceptance（验收）

* source/config manifest（pins + hashes）齐全且 `manifest.py --validate` PASS；
* final image 经 `audit_final_image.py` PASS（in-image / not-stale / no-decoy）；
* exact QEMU argv + fingerprint 可重算；
* bound boot log 经 binder `VERIFIED-consistency`（含 authenticity disclaimer）；
* diagnostic utility 成功（BEGIN..END + release + source-rev + kernel-release + dt-model）；
* two-fault regressions 均关闭；
* `BUILD_RUN_DEBUG.md` 描述 build / run / debug 命令与证据边界。
* `<15min` 仅为 env-specific evidence（环境相关证据），永不作为 hard gate。
* actual-host QEMU 与 canonical QEMU 11.1.1 为两个独立证据维度
 （`canonical_claim` gate）；实际执行工具链与 canonical 工具链同样分离报告。

---

## 8. Non-goals（非目标，明确不做）

No network/server stacks（无 HTTP/MQTT server）；no graphical display /
framebuffer；no package managers（apt/opkg）；no systemd or complex service
supervisors；no proprietary vendor toolchains；no U-Boot porting；no Yocto；
no driver/BSP authoring；no physical-board bring-up。诊断工具永不加
network / daemon / UI 参数。

---

## 9. Verification（验证）

```bash
make manifest        # 样本 manifest schema 验证（轻量）
make check           # learner-safe 检查（schema + run 形状 + sample 镜像审计）
make audit IMAGE=<rootfs.cpio.gz>   # 终镜像审计
bash scripts/run_appliance.sh --manifest <m> --log build/appliance.log --run build/appliance.run.json
python3 scripts/verify_m08_runtime.py --manifest <m> --run <r> --log <log> --overlay overlay
```

Assessment-private authoring regression（隔离审计、突变回归、oracle）只在 reviewer
入口运行，不在 learner 路径上；其当前 pass/fail 状态记录在 PR handoff 中，不写入
learner-facing 文本。

Heavy build/boot 均为 opt-in（`make build` / `make boot` 需 `BUILDROOT_SRC` /
`OUTPUT`），永不进入默认目标与 Phase 1/2 检查。

---

## 10. Evidence boundary（证据边界）

证据词仅用 `VERIFIED` / `PARTIALLY VERIFIED` / `UNVERIFIED`。
Tooling 在合成样本上 PASS 只证明工具自洽；real build / real boot 在本机
**UNVERIFIED**（见 `SOURCE_LEDGER.md` §3 切分表）。
`EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED` 标记一切未执行输出。
Binder 的 `VERIFIED` 恒为 consistency（一致性），authenticity（真实性）
需 reviewer 在可信主机重放 argv。
