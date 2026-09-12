# Fault-a — Boot-Chain `rdinit` Skew（启动链 init 配对偏离）

**Family（家族）:** kernel command line / init handshake ·
**Introduced（引入）:** P3-M08 · **Gate transfer:** Phase 3 Final Gate Part B
（bootargs / init 诊断）变体来源之一

> Worked **tutorial** fault（教学示范故障）。Hypotheses 故意写全；
> scored material 永不预写。

---

## 1. Mechanism（机制）

Frozen bootargs 要求 `rdinit=/sbin/init`（精确 4-token 集之一）。
若 manifest / run 误写 `rdinit=/init`，而终镜像的 PID 1 实际位于
`/sbin/init`（M08 overlay + BusyBox 布局），kernel 的
`try_to_run_init_process()` 将按错误路径寻找 init，握手失败。

这是**配对偏离（pairing skew）**：argv 声明与 image 内容各自合法，
组合起来不合法。单看 manifest 或单看 cpio listing 都看不出故障，
必须三方绑定（cmdline + init 缺席行 + cpio listing）。

---

## 2. Reproduce（复现）

先在**已绑定真实 artifact** 的 manifest + run record 上制造配对偏离（不动 image，
只改 argv/bootargs，并故意保留旧 fingerprint）：

```bash
# 前提：build/real.manifest.json 与 build/real-appliance.run.json 已由
#       scripts/manifest.py --write + scripts/run_appliance.sh 产生
python3 - build/real.manifest.json build/real-appliance.run.json build/skew.run.json <<'PY'
import json, sys
man, runp, dst = sys.argv[1:4]
run = json.load(open(runp, encoding="utf-8"))
GOOD, BAD = "rdinit=/sbin/init", "rdinit=/init"
run["argv"] = [a.replace(GOOD, BAD) if isinstance(a, str) else a for a in run["argv"]]
if isinstance(run.get("bootargs"), str):
    run["bootargs"] = run["bootargs"].replace(GOOD, BAD)
json.dump(run, open(dst, "w", encoding="utf-8"), indent=2, sort_keys=True)
print("skewed bootargs ->", run.get("bootargs"))
PY

# 绑定验证：必须 REJECT(1)，绝非 VERIFIED(0)
python3 scripts/verify_m08_runtime.py \
  --manifest build/real.manifest.json --run build/skew.run.json \
  --log build/appliance.log --overlay overlay
echo "expect: rc=1 REJECT"
```

**本机实际观察到的结果（VERIFIED，静态 binder 维度）：**

```text
skewed bootargs -> console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init panic=1
REJECT: 15 check(s) failed: ['argv.fingerprint', 'bootargs.exact-set', 'log.length', ...]
[FAIL] argv.fingerprint  -- recorded b7f7125404dd... vs recomputed f396911cf448...
[FAIL] bootargs.exact-set -- run bootargs [... 'rdinit=/init' ...] must be exactly
                             [... 'rdinit=/sbin/init']
rc=1
```

判别信号是 `bootargs.exact-set`（argv 声明的 init 路径与冻结集合不符）与
`argv.fingerprint`（手改 JSON 未重算指纹）。在真实故障运行中还会同时出现
`log.cmdline` 与 `log.cmdline-exact-set` 失败。

**证据边界（必须同时对学习者与评审说清）：** 以上是本机在**真实绑定 artifact + 真实客机运行**下得到的结果 —— 它同时证明「客机侧：kernel 找不到 init 并 panic」与「binder 侧：配对偏离必被 REJECT」。
但所用的 QEMU 是 **actual-host 8.2.2**（非 canonical 11.1.1），且复现 fault 时的 QEMU 调用是**对冻结 argv 的刻意偏离**（这本身就是制造故障的手段，不是健康启动）。
真实 Buildroot image 布局下的 panic 字符串仍为 **UNVERIFIED**。详见 `FAULT_CAMPAIGN_EVIDENCE.md` §2。

**binder 侧实测（同一份真实 log 与真实 artifact）：**

```text
BINDER_RC=1  (semantic REJECT)
REJECT: 2 check(s) failed: ['argv.fingerprint', 'bootargs.exact-set']
[FAIL] argv.fingerprint -- recorded 4cbce28f125c... vs recomputed 606f234568ea...
[FAIL] bootargs.exact-set -- run bootargs [..., 'rdinit=/init', ...] must be exactly
                             [..., 'rdinit=/sbin/init']
```

**本机实测结果（VERIFIED，真实客机运行，见 `FAULT_CAMPAIGN_EVIDENCE.md` §2）：**

```text
[    0.000000] Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init panic=1
[    4.333619] Trying to unpack rootfs image as initramfs...
[    8.922203] Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```

> **早期预测已被实测证伪（bounded correction）。** 本文档原先预测的签名是
> `Kernel panic - not syncing: No working init found`；在冻结 Linux 6.18.50 +
> 本仓 initramfs 布局下，真实观察到的 panic 是
> `VFS: Unable to mount root fs on unknown-block(0,0)`（前一行
> `Trying to unpack rootfs image as initramfs...`）。
> **结论**：panic 精确字符串依赖内核版本与 image 布局，**绝不能作为唯一判据**。
> 判别证据始终是「捕获到的 cmdline + init 握手行缺席 + image 内容」三件套 ——
> 这正是本 fault 要教的。换用真实 Buildroot image（init 布局不同）时该字符串
> 可能不同，属于 **UNVERIFIED**（见 `FAULT_CAMPAIGN_EVIDENCE.md` §4）。

---

## 3. Diagnostic chain（诊断链）

### Symptom

Guest 在 init 握手处 panic/hang，未见 `Run /sbin/init as init process`，
未见 `APPLIANCE-OVERLAY-BOOT-MARKER` 与 `APPLIANCE-DIAG-BEGIN`。

### Own description

Kernel 已起来（earlycon / cmdline / memory 行正常），userspace 第一跳失败：
PID 1 路径与 image 内容对不上。

### 3–5 hypotheses

1. `rdinit=` 指向的路径在 image 内根本不存在（配对偏离）。
2. `/sbin/init` 存在但缺可执行位（permission denied 家族，非本 fault）。
3. `rootfs.cpio.gz` 本身 stale，`target/` 已更新但 image 未重打（F12 家族）。
4. DTB stale 导致 console/内存异常，连带 init 失败（DT 家族，非本 fault）。
5. QEMU argv 被手写串改，实际执行的不是 manifest 声明的 bootargs（argv skew）。

### Experiment

```bash
# 1. Guest 到底用了哪个 rdinit？
grep -a "Kernel command line:" build/appliance.log
# 2. init 握手行是否存在？
grep -a "Run /sbin/init as init process" build/appliance.log || echo "ABSENT (fault signature)"
# 3. image 内到底有没有 /sbin/init？
python3 scripts/audit_final_image.py --image <rootfs.cpio.gz> --overlay overlay --json \
  | grep -a "sbin/init"
# 4. run record 的 bootargs 与 fingerprint 是否自洽？
python3 scripts/verify_m08_runtime.py --manifest <m> --run <r> --log <log> --overlay overlay
```

### Evidence

* `Kernel command line:` 行携带 `rdinit=/init`（与 frozen `rdinit=/sbin/init` 不符）；
* `Run /sbin/init as init process` 缺席（check-access 行证明 kernel 找错了路径）；
* cpio listing 显示 `/sbin/init` 存在于 image 内（故非缺文件，而是 argv 配对错）；
* binder 以 `bootargs.exact-set` / `log.cmdline-exact-set` REJECT（非 ERROR）。

### Narrow scope

* Hypotheses 2（权限）出局：listing 显示 mode 可执行；
* Hypotheses 3（stale image）出局：`overlay.in-image` PASS；
* Hypotheses 4（DT）出局：memory / console 握手行正常；
* Hypotheses 5（argv 手写）需同时看 fingerprint：若 fingerprint 自洽，
  则是 manifest 源头写错，而非执行期串改。

### Root cause

Run record 的 `bootargs` 与终镜像 PID 1 布局配对偏离：
`rdinit=/init` vs 实际 `/sbin/init`。

### Fix

1. `bootargs` 改回 frozen 精确 4-token 集（含 `rdinit=/sbin/init`）；
2. **Re-materialize**：重跑 `scripts/run_appliance.sh`（更新 fingerprint + hashes），
   不得只改 JSON 字符串；
3. 若镜像来自 Buildroot 且 overlay 刚更新，注意 F12 规则：
   `SITE_METHOD=local` 包用 `<pkg>-dirclean all` 重打 image 后再 rehash。

### Regression

```bash
bash scripts/run_appliance.sh --manifest <fixed-m> --log build/appliance.log --run build/appliance.run.json
python3 scripts/verify_m08_runtime.py --manifest <fixed-m> --run build/appliance.run.json \
  --log build/appliance.log --overlay overlay
# 预期：exit 0 VERIFIED-consistency（含 authenticity disclaimer）
```

---

## 4. Why the "obvious" answers are wrong（为什么直觉答案是错的）

* **“只改 manifest 字符串就行。”** 不行：fingerprint 与 hashes 必须重算，
  手改 JSON 即 argv skew，binder 照样 REJECT。
* **“重打 image 就能修 bootargs。”** 不能：bootargs 活在 argv，不在 image；
  image 健康（`in-image` PASS）恰是本 fault 的特征。
* **“panic 行就是一切。”** 不够：必须同时出示 cmdline + 握手缺席 + listing，
  否则分不清 rdinit 错、权限错、stale image 三大家族。
