# Fault F08 — Init Permission / Execution Failure

> Calibrated on real Linux 6.18.50 (`7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`) + real BusyBox 1.36.1 initramfs. Source: `init/main.c` (`try_to_run_init_process` reports non-`-ENOENT` exec failures).

## 1. Symptom

When `/init` exists but lacks the executable bit — and no fallback candidate can catch the boot — the kernel logs the precise errno and panics only after exhausting the fallback list:

```text
[    1.090619] Run /init as init process
[    1.090945] Failed to execute /init (error -13)
[    1.090983] Run /sbin/init as init process
[    1.091339] Run /etc/init as init process
[    1.091580] Run /bin/init as init process
[    1.091804] Run /bin/sh as init process
[    1.092117] Kernel panic - not syncing: No working init found.  Try passing init= option to kernel. See Linux Documentation/admin-guide/init.rst for guidance.
```

Error `-13` is `-EACCES`: the kernel's permission check (`MAY_EXEC`) rejected the file at `execve()` time.

## 1b. The Fallback Caveat (do not skip)

On the canonical rootfs this fault **does not panic**: after `Failed to execute /init (error -13)` the kernel continues with `Run /sbin/init as init process`, and the real BusyBox init boots to `Please press Enter to activate this console.` The panic above was reproduced with all fallback candidates (`/sbin/init`, `/etc/init`, `/bin/init`, `/bin/sh`) removed. A permission fault is deterministic only when the fixture makes every relevant fallback unavailable.

---

## 2. Full Diagnostic Discipline Walkthrough

### Step 1: Own Description
The kernel finds `/init` and attempts it (`Run /init as init process` is printed), but execution is denied; with no fallback available, the kernel panics.

### Step 2: 3–5 Hypotheses
1. `/init` exists but lacks the executable mode bit (`0644` instead of `0755`).
2. `/init` is a script whose shebang interpreter lacks executable permission.
3. The CPIO archive headers stored the wrong mode (repackaging dropped `+x`).
4. A fallback (`/sbin/init`, `/bin/sh`) is actually present and caught the boot — in which case there is no panic (see §1b).

### Step 3: Discriminating Experiment
Inspect inode modes from archive metadata (authoritative — not from an unprivileged extraction, which normalizes modes):
```bash
zcat rootfs.cpio.gz > /tmp/a.cpio
python3 ../scripts/pycpio.py --list /tmp/a.cpio | grep -E "(^|/)init"
# faulty: file 0644 ... init ; healthy: file 0755 (or 0777) ... init
```

### Step 4: Observable Evidence
`Run /init as init process` proves the kernel *located* the file; `Failed to execute /init (error -13)` proves *permission* (not absence — absence at this stage would read `error -2`, and absence before this stage reads `check access … failed`, the F04 route).

### Step 5: Narrow Scope
Path, archive, and binary content are all correct. The failure is isolated to mode bits in the CPIO headers.

### Step 6: Root Cause
`/init` lacks `MAY_EXEC`; `execve()` returns `-EACCES` (`-13`); with no fallback, `kernel_init()` panics.

### Step 7: Fix
Set executable permission in the staging directory and repackage:
```bash
chmod +x rootfs-staging/init
bash scripts/package_initramfs.sh rootfs-staging rootfs.cpio.gz
```

### Step 8: Regression Check
1. Verify mode in archive metadata (`--list` shows an executable mode).
2. Boot in QEMU: `Failed to execute /init (error -13)` is gone; `REAL-BUSYBOX-INIT-READY` and a real BusyBox shell follow.
