# Fault F09 — Pseudo-Filesystem Unmounted (`/proc` Missing)

> Calibrated with the REAL BusyBox 1.36.1 rootfs on real Linux 6.18.50: shell reachable, `/proc` deliberately left unmounted. Real BusyBox `ps`/`mount` behavior below — not a synthetic approximation.

## 1. Symptom

The system boots to a real BusyBox shell (`~ # `). Process and telemetry commands then misbehave in the specific way real BusyBox behaves without `procfs`:

```text
~ # ps
PID   USER     TIME  COMMAND
~ # cat /proc/uptime
cat: can't open '/proc/uptime': No such file or directory
~ # mount
mount: no /proc/mounts
~ # ls /proc
(empty output)
```

Note the signature carefully: real BusyBox `ps` does **not** print an error — it prints the header row and an empty table (there is no process source to read). `mount` fails because it reads `/proc/mounts`. `/proc` exists as a directory but is empty.

Repair is immediate and confirmatory:

```text
~ # mount -t proc none /proc
~ # ps
PID   USER     TIME  COMMAND
    1 0         0:00 /bin/sh
    2 0         0:00 [kthreadd]
    ...
```

---

## 2. Full Diagnostic Discipline Walkthrough

### Step 1: Own Description
Kernel and shell booted with no panic, but every consumer of process/kernel telemetry is blind: `ps` is empty, `/proc/*` reads fail, `mount` cannot list mounts.

### Step 2: 3–5 Hypotheses
1. `/init` or `/etc/init.d/rcS` omitted the `mount -t proc none /proc` command (or it never executed — comment/`echo` text does not mount).
2. The `/proc` mount-point directory was not created in the rootfs skeleton.
3. The kernel lacks `CONFIG_PROC_FS=y` (excluded here — our kernel serves `/proc` fine once mounted, as the repair proves).
4. The mount failed from bad syntax or a wrong target (validator checks fstype↔target binding for exactly this reason).

### Step 3: Discriminating Experiment
Inside the guest, distinguish *missing directory* from *unmounted filesystem* from *missing kernel support*:
```sh
ls -ld /proc        # directory exists?
ls /proc            # empty => mounted-nothing OR unmounted
mount               # 'mount: no /proc/mounts' => procfs not mounted
mount -t proc none /proc   # repair attempt
ps                  # full table => kernel support present, mount was the gap
```

Mount-state evidence (healthy boot for comparison):
```text
~ # cat /proc/mounts
rootfs / rootfs rw,size=211184k,nr_inodes=52796 0 0
none /proc proc rw,relatime 0 0
none /sys sysfs rw,relatime 0 0
none /dev devtmpfs rw,relatime,size=211184k,nr_inodes=52796,mode=755 0 0
```

### Step 4: Observable Evidence
1. `/proc` exists but is empty; 2. `mount` reports `no /proc/mounts`; 3. manual `mount -t proc none /proc` instantly restores `ps`. The kernel side is proven healthy by the repair.

### Step 5: Narrow Scope
Kernel config, skeleton directory, and shell are all fine. The failure is strictly the missing *active* mount command in the init path.

### Step 6: Root Cause
Neither `/init` nor `/etc/init.d/rcS` executed `mount -t proc none /proc`. Takeaway:
> **The Linux kernel does NOT require `/proc` to reach userspace.** But real BusyBox `ps`, `top`, `free`, and `mount` require a mounted `procfs` to function.

### Step 7: Fix
Add ACTIVE mount commands (not comments, not `echo`) to `/init` or `/etc/init.d/rcS`:
```sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true
```

### Step 8: Regression Check
Reboot in QEMU with the real rootfs:
- `ps` lists PID 1 (`/bin/sh`), `kthreadd`, and the shell itself;
- `cat /proc/uptime` prints uptime;
- `cat /proc/mounts` shows `proc` on `/proc`, `sysfs` on `/sys`, `devtmpfs` on `/dev`.
