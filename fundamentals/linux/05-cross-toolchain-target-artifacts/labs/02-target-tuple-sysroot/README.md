# Lab 1.2 — Target Tuple & Sysroot Discovery

## Objective
1. Understand the anatomy of the target tuple: `arm-none-linux-gnueabihf-` (canonical) vs `arm-linux-gnueabihf-` (distro).
2. Query the cross-compiler for its sysroot directory using `-print-sysroot`.
3. Locate target library files (`libc.so.6`) and dynamic linker (`ld-linux-armhf.so.3`) on the host filesystem using `-print-file-name`.

## Commands to Run
```bash
bash inspect_sysroot.sh
```

## Key Observations
- The sysroot contains header files (`/usr/include`) matching target glibc, distinct from host glibc headers.
- The dynamic loader `ld-linux-armhf.so.3` resides in the toolchain library directory. When creating a rootfs, this exact file must be copied to the target's `/lib/`.
