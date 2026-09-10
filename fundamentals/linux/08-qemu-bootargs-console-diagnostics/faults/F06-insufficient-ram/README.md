# Fault F06 — Calibrated Low-Memory Failure (REAL BusyBox initramfs)

> Calibrated on real Linux 6.18.50 + REAL BusyBox 1.36.1 initramfs. Every boundary below records its terminal state as one of: QEMU-REFUSAL / TIMEOUT-HANG / OOM-PANIC / USERSPACE. A bare `cma: Failed to reserve` line alone never classifies a hang — the verdict requires exit/timeout status plus the last semantic milestone.

## 1. Symptom (PRIMARY learner fault: `mem=32M` OOM deadlock panic)

```text
[    0.208099] Out of memory and no killable processes...
[    0.208243] Kernel panic - not syncing: System is deadlocked on memory
```

Terminal state: **OOM-PANIC**. The kernel restricted to 32 MB exhausts memory during slab/driver init and deadlocks. No `Run /init` line ever appears — userspace is never reached. This is the single deterministic runtime failure taught as F06.

## 2. Boundary Contrast (same kernel, same real initramfs)

| # | Constraint | Terminal state | Last semantic milestone |
|---|---|---|---|
| 1 | `-m 8M` (QEMU flag) | **QEMU-REFUSAL** (emulator exits, nonzero, before any kernel byte) | `qemu-system-arm: kernel 'zImage' is too large to fit in RAM` |
| 2 | `mem=8M` (kernel arg, `-m 512M`) | **TIMEOUT-HANG** (timeout exit 124, no panic, no userspace) | `INITRD: … is not a memory region - disabling initrd` + `cma: Failed to reserve 64 MiB`, then silence |
| 3 | `mem=32M` (kernel arg, `-m 512M`) | **OOM-PANIC** (deterministic deadlock panic) | `Out of memory and no killable processes...` → `System is deadlocked on memory` |
| — | canonical `-m 512M`, no `mem=` | **USERSPACE** (control) | `REAL-BUSYBOX-INIT-READY` → real `~ # ` shell |

Boundary 1 is a QEMU pre-boot contrast, not a kernel fault: keep it to teach the emulator/kernel boundary, never confuse it with OOM. Boundary 2's hang verdict rests on *timeout + warnings + absence of both panic and userspace*, not on the `cma:` line alone.

---

## 3. Full Diagnostic Discipline Walkthrough

### Step 1: Own Description
With `mem=32M`, the kernel starts normally, then dies in the page allocator before userspace; with `mem=8M`, it stalls in early setup with CMA/initrd warnings and never progresses.

### Step 2: 3–5 Hypotheses
1. A `mem=` argument restricts visible RAM below the working set.
2. The VM was provisioned short via `-m` (boundary 1 shape instead).
3. Oversized CMA reservation vs available RAM.
4. Initramfs loaded outside visible RAM (`INITRD: … disabling initrd`).

### Step 3: Discriminating Experiment
```bash
grep "Kernel command line:" /tmp/boot.log     # mem= override present?
grep -E "Memory:|cma:|INITRD:|Run /init|Kernel panic" /tmp/boot.log
bash scripts/calibrate_f06_ram.sh              # reproduces all four states
```

### Step 4: Observable Evidence
`Kernel command line: … mem=32M` + `Out of memory and no killable processes...` + `System is deadlocked on memory`, with no `Run /init`. For `mem=8M`: `cma: Failed to reserve 64 MiB`, no panic, no `Run /init`, process times out.

### Step 5: Narrow Scope
Image, drivers, and rootfs are intact. The fault is strictly the memory restriction.

### Step 6: Root Cause
`mem=32M` starves the allocator below the minimum working set of this kernel configuration (PRIMARY). `mem=8M` additionally breaks early reservations and initrd placement, stalling before the allocator can even panic.

### Step 7: Fix
Remove the `mem=` override, restoring `-m 512M`:
```bash
-append "earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"
```

### Step 8: Regression Check
```bash
bash scripts/calibrate_f06_ram.sh
# expect: QEMU-REFUSAL / TIMEOUT-HANG / OOM-PANIC / USERSPACE, PRIMARY mem=32M deterministic
```
