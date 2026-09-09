# Fault F06 — Calibrated Low-Memory Failure & Early OOM Deadlock

## 1. Symptom

During boot, the kernel crashes with an Out-of-Memory panic or hangs during early memory setup:

**Variant A (Kernel OOM Deadlock Panic — `mem=32M`):**
```text
[    0.226995] [  pid  ]   uid  tgid total_vm      rss rss_anon rss_file rss_shmem pgtables_bytes swapents oom_score_adj name
[    0.227050] Out of memory and no killable processes...
[    0.227194] Kernel panic - not syncing: System is deadlocked on memory
[    0.239620] CPU: 0 UID: 0 PID: 1 Comm: swapper/0 Not tainted 6.18.50 #1 NONE 
[    0.239898] Hardware name: Generic DT based system
---[ end Kernel panic - not syncing: System is deadlocked on memory ]---
```

**Variant B (Early CMA / Bootmem Reservation Hang — `mem=8M`):**
```text
[    0.000000] INITRD: 0x48000000+0x0003c000 is not a memory region - disabling initrd
[    0.000000] cma: Failed to reserve 64 MiB
(kernel hangs in early arch setup)
```

**Variant C (QEMU Hardware Refusal — `-m 8M`):**
```text
qemu-system-arm: kernel 'zImage' is too large to fit in RAM (kernel size 11817472, RAM size 8388608)
```

---

## 2. Full Diagnostic Discipline Walkthrough

### Step 1: Own Description
The kernel begins initialization, but memory allocations cannot be satisfied. Either the early Contiguous Memory Allocator (`CMA`) fails to reserve required memory blocks, or the page allocator runs completely out of memory during slab/driver initialization, triggering an OOM deadlock panic.

### Step 2: 3–5 Hypotheses
1. An artificial `mem=` parameter on the kernel command line restricts visible RAM below the operational threshold.
2. The virtual machine was provisioned with inadequate RAM via the QEMU `-m` flag.
3. The kernel configuration has an oversized Contiguous Memory Allocator reservation (`CONFIG_CMA_SIZE_MBYTES`) exceeding available physical RAM.
4. The initramfs image was loaded outside visible RAM boundaries.

### Step 3: Discriminating Experiment
1. Check the effective kernel command line for memory overrides:
   ```bash
   grep "Kernel command line:" /tmp/boot.log
   ```
2. Inspect early memory detection and CMA log messages:
   ```bash
   grep -E "Memory:|cma:|INITRD:" /tmp/boot.log
   ```

### Step 4: Observable Evidence
The kernel log confirms:
```text
Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init mem=32M
cma: Failed to reserve 64 MiB
Out of memory and no killable processes...
Kernel panic - not syncing: System is deadlocked on memory
```
Observation: The kernel was restricted to 32 MB (`mem=32M`), while default subsystem initialization and CMA require more memory than available.

### Step 5: Narrow Scope
The memory controllers and kernel image are intact. The fault is strictly caused by the restrictive memory parameter restricting usable RAM.

### Step 6: Root Cause
Passing `mem=32M` restricts the kernel address space below the minimum working set required by our Phase 3 kernel configuration.

### Step 7: Fix
Remove the artificial `mem=32M` boot argument, restoring the canonical platform memory contract (`-m 512M`).

### Step 8: Regression Check
Run the memory calibration script:
```bash
bash scripts/calibrate_f06_ram.sh
```
Confirm all 3 boundaries reproduce deterministically, and standard boot with 512 MB passes cleanly.
