# P3-M08 Fault Campaign — Captured Evidence

> Every result on this page was **executed on this authoring host** and is quoted
> verbatim. Nothing here is predicted.
>
> **Evidence class: actual-host.** The emulator is `qemu-system-arm` **8.2.2**;
> canonical QEMU **11.1.1** was not installed. The *kernel* is the real canonical
> one: **Linux 6.18.50** built from the pinned commit
> `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7` with this repository's frozen Phase 3
> configuration (`multi_v7_defconfig` + `06-kernel-build-boot/fixtures/configs/phase3_delta.config`).
> The toolchain is the actual-host `arm-linux-gnueabihf-gcc` 13.3.0, not the
> canonical Arm GNU Toolchain 13.3.rel1.
>
> So the correct reading is: **commanded platform and contract = canonical;
> emulator build = actual-host.** `canonical QEMU 11.1.1 runtime` stays
> **UNVERIFIED**.

---

## 0. Baseline: the healthy appliance boots and binds

Built the appliance rootfs from the committed overlay plus the cross-compiled
diagnostic utility, packed it deterministically, audited it, and launched it with
the project's own harness against the frozen machine contract:

```bash
qemu-system-arm -machine virt,highmem=off,gic-version=2 -cpu cortex-a7 \
  -m 512M -smp 1 -nographic \
  -kernel <zImage> -initrd <rootfs.cpio.gz> \
  -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/sbin/init panic=1"
```

Guest evidence (verbatim, from the captured console log):

```text
[    0.000000] Linux version 6.18.50 (root@ZHR) (... arm-linux-gnueabihf-gcc 13.3.0, GNU ld 2.42) #1 SMP ...
[    0.000000] CPU: ARMv7 Processor [410fc075] revision 5 (ARMv7), cr=10c5387d
[    0.000000] Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/sbin/init panic=1
[    0.569811] Memory: 420536K/524288K available (... 0K highmem)

[   11.903932] Run /sbin/init as init process
APPLIANCE-INIT-BEGIN
APPLIANCE-INIT-RUN=/etc/init.d/S99appliance-diag
APPLIANCE-OVERLAY-BOOT-MARKER
APPLIANCE-DIAG-BEGIN
SOURCE-REV=1.0
KERNEL-RELEASE=6.18.50
APPLIANCE-RELEASE=EMBED-SYSTEM P3-M08 appliance release 1.0
DT-MODEL=linux,dummy-virt
UPTIME-SEC=7
MEM-AVAILABLE-KB=468360
APPLIANCE-DIAG-END
APPLIANCE-INIT-END
```

Artifact audit and binder outcome:

```text
=== FINAL IMAGE AUDIT: PASS (5 checks) ===
  overlay.in-image / overlay.not-stale / overlay.no-decoy / image.entries

[PASS] log.length -- 236 line(s); handwritten log rejected below 60 lines
[PASS] log.ordered-milestones -- 13 checkpoints in kernel order
[PASS] log.cmdline-exact-set -- logged [4 tokens] must equal frozen set (no extras)
[PASS] guest.ram -- guest RAM matches -m 512M (delta 0B within 16MiB)
[PASS] guest.cpu -- SMP total 1 vs -smp 1
[PASS] log.overlay-marker -- overlay boot marker proves S99appliance-diag ran
[PASS] log.diag-complete -- diagnostic utility ran BEGIN..END in order
[PASS] guest.release-marker -- guest release == overlay appliance-release
[PASS] guest.kernel-release -- KERNEL-RELEASE '6.18.50' carries 6.18.50
[PASS] qemu.execution -- qemu exited 0 and did not time out
[PASS] qemu.canonical-claim -- actual-host 8.2.2 kept separate from canonical 11.1.1 (claim=False)
[PASS] overlay.in-image / overlay.not-stale / overlay.no-decoy
[PASS] log.no-synthetic
=== APPLIANCE RUNTIME EVIDENCE: VERIFIED (bound to audited artifacts) ===
```

**Proves:** a real Linux 6.18.50 guest booted under the frozen contract, the
committed overlay init script ran, the committed diagnostic utility ran and
reported the real kernel release / DT model / memory / uptime, and the runtime
binder accepted the capture with every artifact, argv, bootargs and milestone
check passing.

**Does not prove:** canonical QEMU 11.1.1 runtime; authenticity of the capture
independently of this host (the binder proves *consistency*; a reviewer must
re-execute the recorded argv on a trusted host); anything about Buildroot, whose
full build was not performed.

---

## 1. Runner exit taxonomy — all four classes observed on real guests

| Exit | Meaning | How it was produced here | Observed |
|---:|---|---|---|
| `0` | capture-done — `APPLIANCE-DIAG-END` present | healthy appliance boot above | **VERIFIED** |
| `2` | LAUNCH / RUNTIME FAIL | missing kernel path; nonexistent inputs | **VERIFIED** |
| `3` | GUEST-MARKER-ABSENT — QEMU exited 0, marker absent | guest booted, overlay ran, but the packaged diagnostic was absent from the image | **VERIFIED** |
| `124` | TIMEOUT | a panicking guest without `-no-reboot` reboot-loops until the deadline | **VERIFIED** |
| `1` | ERROR (usage / manifest validation) | not exercised on this host | **UNVERIFIED** |

The `exit 3` case is the one a fail-open harness would have mislabelled as
success. Verbatim:

```text
[RUNNER] qemu exit code: 0
[RUNNER] guest success marker absent (APPLIANCE-DIAG-END not found in capture) (GUEST-MARKER-ABSENT).
RUNNER_RC=3

guest tail:
[   11.903932] Run /sbin/init as init process
APPLIANCE-INIT-BEGIN
APPLIANCE-INIT-RUN=/etc/init.d/S99appliance-diag
APPLIANCE-OVERLAY-BOOT-MARKER
/etc/init.d/S99appliance-diag: line 11: /usr/bin/appliance-diag: not found
APPLIANCE-INIT-END
[   12.573516] reboot: Power down
```

Note the trap this closes: the overlay marker **was** present and the emulator
**did** exit 0, so a harness that checked only "did QEMU succeed" or only "did any
marker appear" would have called this a pass.

---

## 2. Fault A — boot-chain `rdinit` pairing skew

Two complementary pieces of evidence.

### 2a. Guest side — the kernel really cannot find init

The frozen `rdinit=/sbin/init` was pointed at an image whose init lives elsewhere.
Reproduced with a direct QEMU invocation, i.e. a **deliberate and documented
deviation from the frozen argv in order to create the fault** — this is not a
healthy launch:

```text
[    0.000000] Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init panic=1
[    4.333619] Trying to unpack rootfs image as initramfs...
[    8.922203] Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```

**Correction to the earlier prediction.** `faults/fault-a-bootchain-rdinit-skew/README.md`
previously predicted the signature `Kernel panic - not syncing: No working init found`.
On this kernel and image layout the observed panic is
`VFS: Unable to mount root fs on unknown-block(0,0)`, preceded by
`Trying to unpack rootfs image as initramfs...`. The prediction is therefore
**refuted by measurement** and the README has been corrected. The exact panic
string is kernel-layout dependent and must never be used as the sole detector —
which is precisely what the fault teaches: the discriminating evidence is the
*captured command line* plus the *absence of an init handshake* plus the *image
contents*, not one blessed panic line.

### 2b. Binder side — a skewed run record is rejected

On the **real** canonical manifest and real console log, with only `rdinit`
skewed (and the old fingerprint deliberately retained):

```text
BINDER_RC=1  (semantic REJECT)
REJECT: 2 check(s) failed: ['argv.fingerprint', 'bootargs.exact-set']
[FAIL] argv.fingerprint -- recorded 4cbce28f125c... vs recomputed 606f234568ea...
[FAIL] bootargs.exact-set -- run bootargs ['console=ttyAMA0,115200','earlycon=pl011,0x09000000','rdinit=/init','panic=1']
                             must be exactly ['console=ttyAMA0,115200','earlycon=pl011,0x09000000','panic=1','rdinit=/sbin/init']
```

**Proves:** a boot-chain pairing skew is detected both by the guest (kernel panic,
no init handshake) and by the binder (REJECT, not ERROR).

**Does not prove:** that the healthy log itself came from a trusted execution.

### 2c. Regression

The fix is to restore the frozen 4-token `bootargs` **and re-materialise** the run
record — re-running the harness recomputes the fingerprint. Editing the JSON
string alone is itself detected, because `argv.fingerprint` no longer matches.
The healthy baseline in §0 is the post-fix state: binder `VERIFIED`, `qemu.execution` passing.

---

## 3. Fault B — userspace environment fault: `/sys` not mounted

The appliance diagnostic runs to completion, but the init scripts never mount
sysfs, so the device-tree fact cannot be read while every other fact stays healthy:

```text
APPLIANCE-INIT-BEGIN
APPLIANCE-OVERLAY-BOOT-MARKER
APPLIANCE-DIAG-BEGIN
SOURCE-REV=1.0
KERNEL-RELEASE=6.18.50
APPLIANCE-RELEASE=EMBED-SYSTEM P3-M08 appliance release 1.0
DT-MODEL=UNAVAILABLE          <-- only degraded fact
UPTIME-SEC=17
MEM-AVAILABLE-KB=470964
APPLIANCE-DIAG-END
```

```text
BINDER_RC=1  (semantic REJECT)
REJECT: 1 check(s) failed: ['guest.dt-model']
[FAIL] guest.dt-model -- DT-MODEL 'UNAVAILABLE'
```

**Proves:** the fault is isolated to one userspace environment dependency; the
kernel, argv, artifacts and every other diagnostic fact are healthy, and the
binder rejects the capture on exactly the one invariant that legitimately failed.

**Does not prove:** anything about Buildroot's overlay handling — this fault was
produced by an init script that omits the sysfs mount, not by a Buildroot build.

### 3.1 Why the healthy `DT-MODEL` matters

In the healthy boot the guest reports `DT-MODEL=linux,dummy-virt`, which comes
from `/sys/firmware/devicetree/base/model`. That read is only possible because
sysfs is mounted, so `DT-MODEL` doubles as a *pseudo-filesystem health probe* —
the reason it was chosen as the fault's carrier.

---

## 4. What remains unverified, and the exact command to close it

| Item | Status | Command that closes it |
|---|---|---|
| canonical QEMU 11.1.1 runtime | **UNVERIFIED** | install/build QEMU `v11.1.1` (peeled `c3d48b7d1e89604920e5b81b91140c2ad39a1943`), then re-run `make boot OUTPUT=<br-output>` |
| canonical Arm GNU Toolchain 13.3.rel1 | **UNVERIFIED** | install 13.3.rel1, then `make -C src CROSS_COMPILE=arm-none-linux-gnueabihf-` |
| complete Buildroot build | **UNVERIFIED** | `make build BUILDROOT_SRC=<buildroot-2026.05.2>` then `make boot OUTPUT=<br-output>` |
| runner `exit 1` (ERROR) class | **UNVERIFIED** | `bash scripts/run_appliance.sh` with a malformed manifest, or with `python3` absent from `PATH` |
| exact `rdinit`-skew panic string on the canonical 6.18.50 kernel + a Buildroot image | **UNVERIFIED** | reproduce Fault A against a real Buildroot `output/images/rootfs.cpio.gz`, which has a different init layout |
