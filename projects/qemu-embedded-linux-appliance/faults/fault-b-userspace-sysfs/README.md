# Fault-b — Userspace `/sys` Unmounted（用户态 sysfs 未挂载）

**Family（家族）:** init script / pseudo-filesystem ·
**Introduced（引入）:** P3-M08 · **Gate transfer:** Phase 3 Final Gate Part D
（userspace 环境依赖）变体来源之一

> Worked **tutorial** fault（教学示范故障）。Hypotheses 故意写全；
> scored material 永不预写。

---

## 1. Mechanism（机制）

`appliance-diag` 的 `DT-MODEL` 来自
`/sys/firmware/devicetree/base/model`。若 init 脚本（`rcS` / `inittab`
等价物）漏挂 `sysfs`（`mount -t sysfs none /sys` 缺失），`/sys` 为空，
`fopen()` 失败，diag 打印 `DT-MODEL=UNAVAILABLE`，但其余行
（`KERNEL-RELEASE` / `UPTIME-SEC` / `MEM-AVAILABLE-KB`）完全健康。

这是**环境依赖故障**，不是内核/argv/DT 故障：kernel 已正确消费 DT
（`Memory` / console 行正常），只是 userspace 没把 sysfs 挂上，
diag 看不见它。

---

## 2. Reproduce（复现）

```bash
# 让 guest 的 init 不挂载 sysfs（其余不变），重打 image 后按冻结契约启动
# mount -t sysfs sysfs /sys    ->  (删除/注释该行)
```

**本机实测结果（VERIFIED，真实 canonical Linux 6.18.50 客机；逐字记录见
`faults/FAULT_CAMPAIGN_EVIDENCE.md` §3）：**

```text
APPLIANCE-INIT-BEGIN
APPLIANCE-OVERLAY-BOOT-MARKER
APPLIANCE-DIAG-BEGIN
SOURCE-REV=1.0
KERNEL-RELEASE=6.18.50
APPLIANCE-RELEASE=EMBED-SYSTEM P3-M08 appliance release 1.0
DT-MODEL=UNAVAILABLE          <-- 唯一降级事实
UPTIME-SEC=17
MEM-AVAILABLE-KB=470964
APPLIANCE-DIAG-END
APPLIANCE-INIT-END
```

binder 判定：

```text
BINDER_RC=1  (semantic REJECT)
REJECT: 1 check(s) failed: ['guest.dt-model']
[FAIL] guest.dt-model -- DT-MODEL 'UNAVAILABLE'
```

注意：除 `DT-MODEL` 外一切健康——这正是本 fault 的签名；binder 也只在这一个不变量上
REJECT，没有把故障误报成环境 ERROR。运行维度边界：内核为 canonical 6.18.50，QEMU 为
actual-host 8.2.2（`canonical QEMU 11.1.1 runtime: UNVERIFIED`）。

---

## 3. Diagnostic chain（诊断链）

### Symptom

Binder 报 `guest.dt-model` FAIL；其余 diag 行 PASS；boot milestones 有序且完整。

### Own description

Utility 跑完了（BEGIN..END），只有 DT-model 取数失败：问题在取数路径
（`/sys`），不在 kernel DT 消费，不在 argv。

### 3–5 hypotheses

1. `/sys` 未挂载（init 脚本漏 `mount -t sysfs`）。
2. DTB 本身缺 `model` 节点（explicit DTB 内容错）。
3. QEMU 用了 `qemu-generated` 但 argv 误带 stale `-dtb`（DT 配对错）。
4. `/etc/appliance-release` 缺失导致连带失败（release 家族，非本 fault）。
5. 终镜像 stale：`target/` 已修但 image 未重打（F12 家族）。

### Experiment

```bash
# 1. guest 视角：/sys 到底挂没挂？
grep -a "/sys" build/appliance.log | grep -a "sysfs" || echo "SYSFS ABSENT (fault signature)"
# 2. sysfs 树是否存在？
#    （交互/串口探针，或 log 中 ls /sys/firmware/devicetree/base 的回显）
grep -a "No such file or directory" build/appliance.log || true
# 3. 其余 diag 行是否健康？（区分内核/argv 故障）
grep -aE "^(KERNEL-RELEASE|UPTIME-SEC|MEM-AVAILABLE-KB)=" build/appliance.log
# 4. binder 定位
python3 scripts/verify_m08_runtime.py --manifest <m> --run <r> --log <log> --overlay overlay
```

### Evidence

* `/proc/mounts` 回显缺 `sysfs /sys` 行；
* `ls /sys/firmware/devicetree/base` 报 `No such file or directory`；
* `KERNEL-RELEASE=6.18.50` / `UPTIME-SEC` / `MEM-AVAILABLE-KB` 健康
  （kernel + procfs 正常，排除 argv/内核故障）；
* binder 仅 `guest.dt-model` FAIL（`DT-MODEL=UNAVAILABLE`），余者 PASS。

### Narrow scope

* Hypotheses 2（DTB 内容）出局：kernel memory/console 行正常，且 fault-a 式
  cmdline 检查通过；
* Hypotheses 3（DT 配对）出局：`binding.dtb-*` PASS；
* Hypotheses 4（release）出局：`APPLIANCE-RELEASE` 行健康；
* Hypotheses 5（stale）需 `audit_final_image.py` 确认 `in-image` PASS
  后方可出局。

### Root cause

Init 序列漏挂 `sysfs`：`/sys` 空 → `DT-MODEL=UNAVAILABLE`，余者健康。

### Fix

1. 恢复 init 脚本 `mount -t sysfs none /sys` 行；
2. Repack image（重打 `rootfs.cpio.gz`）；
3. Rehash manifest（`manifest.py --write` 更新 rootfs sha256）；
4. 重跑 `run_appliance.sh` + binder 回归。
5. 若包走 Buildroot 且 `SITE_METHOD=local`，重打后仍 stale 则用
   `<pkg>-dirclean all`（F12 规则），不得只重编 `target/`。

### Regression

```bash
python3 scripts/audit_final_image.py --image <fixed-rootfs> --overlay overlay
python3 scripts/verify_m08_runtime.py --manifest <fixed-m> --run <fixed-r> \
  --log build/appliance.log --overlay overlay
# 预期：audit PASS；binder exit 0 VERIFIED-consistency（含 authenticity disclaimer）
```

---

## 4. Why the "obvious" answers are wrong（为什么直觉答案是错的）

* **“DT-MODEL 不行就是 DTB 坏了。”** 错：kernel 侧 DT 消费正常，
  坏的是 userspace 的 sysfs 视图。
* **“只改 staging `target/` 就行。”** 错：boot 的是终镜像，
  `in-image` 不更新即 stale，binder 照样 REJECT。
* **“看到 UNAVAILABLE 就全盘否定启动。”** 错：BEGIN..END 完整 +
  其余三行健康，恰证明这是孤立的环境依赖故障，而非 boot-chain 故障。
