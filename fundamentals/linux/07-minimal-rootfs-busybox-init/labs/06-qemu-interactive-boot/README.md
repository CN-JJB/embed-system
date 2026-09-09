# Lab 3.6 — First Interactive Shell Boot in QEMU

## 1. Objective

Boot the compiled **Linux 6.18.50 `zImage`** combined with the manual **`rootfs.cpio.gz` initramfs** in QEMU under the canonical platform contract:
```text
-machine virt,highmem=off,gic-version=2 -cpu cortex-a7 -m 512M -smp 1 -nographic
```
Reach an interactive BusyBox shell (`/bin/sh`) and verify the live userspace environment (`PID 1`, `/proc`, `/sys`, and `/dev`).

---

## 2. Canonical Platform Launch Contract

To ensure 100% deterministic bring-up across ARMv7-A environments:

| Parameter | Value | Rationale |
|---|---|---|
| `-machine` | `virt,highmem=off,gic-version=2` | Standard virtual ARM platform; `highmem=off` restricts memory map to 32-bit address space for non-LPAE kernel; `gic-version=2` selects GICv2 at `0x08000000`. |
| `-cpu` | `cortex-a7` | Explicit 32-bit Cortex-A7 (overriding QEMU default `cortex-a15`). |
| `-m` | `512M` | Standard 512 MB physical DRAM at base `0x40000000`. |
| `-smp` | `1` | Single CPU core for deterministic scheduling and debugging. |
| `-nographic` | (flag) | Directs serial UART output to host terminal stdin/stdout. |
| `-kernel` | `zImage` | Linux 6.18.50 compressed kernel image. |
| `-initrd` | `rootfs.cpio.gz` | Manual minimal initramfs archive. |
| `-append` | `"console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init"` | Kernel boot arguments. |

---

## 3. Hands-On Execution

1. Run QEMU with your kernel and rootfs:
   ```bash
   qemu-system-arm \
       -machine virt,highmem=off,gic-version=2 \
       -cpu cortex-a7 \
       -m 512M \
       -smp 1 \
       -nographic \
       -kernel /path/to/linux-6.18.50/arch/arm/boot/zImage \
       -initrd /path/to/rootfs.cpio.gz \
       -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init"
   ```

2. Observe the serial boot chronology:
   - Early console banner: `bootconsole [pl011] enabled`
   - Kernel startup: `Linux version 6.18.50 ...`
   - Rootfs unpacking: `Unpacking initramfs...`
   - PID 1 invocation: `Run /init as init process`
   - Init script output: `Mounted /proc, /sys, and /dev successfully.`
   - Shell prompt:
     ```text
     / #
     ```

3. Inside the interactive shell, collect observable runtime evidence:
   ```sh
   # 1. Verify PID 1 identity and process table
   ps

   # 2. Inspect CPU information exposed by procfs
   cat /proc/cpuinfo

   # 3. Inspect system uptime
   cat /proc/uptime

   # 4. Verify mount points
   cat /proc/mounts

   # 5. Query Device Tree model exported through sysfs
   cat /sys/firmware/devicetree/base/model
   ```

4. Exit QEMU:
   Press `Ctrl-A` then `X`.

---

## 4. Expected Evidence

Capture the terminal transcript demonstrating:
1. `ps` showing `init` with PID 1;
2. `cat /proc/cpuinfo` reporting `model name: ARMv7 Processor rev 4 (v7l)` / `Hardware: Generic DT based system`;
3. `cat /proc/mounts` confirming `proc` mounted on `/proc`, `sysfs` mounted on `/sys`, and `devtmpfs` mounted on `/dev`.
