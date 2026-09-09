# P3-M01 Challenge — Binary Artifact Classifier & Rootfs Dependency Audit

> **AI Policy:** AI-Free first attempt. Use `readelf`, `file`, and official Binutils documentation.

## Problem Context
During board bring-up, your deployment pipeline has generated three binary artifacts in `fixtures/`:
- `fixtures/unknown_1`
- `fixtures/unknown_2`
- `fixtures/unknown_3`

One of these binaries fails on the target with `cannot execute binary file: Exec format error`.  
Another fails with `No such file or directory` (missing interpreter).  
The third runs successfully even in a bare chroot rootfs with zero shared libraries.

## Your Task
1. Build the challenge workspace with `make all` (compiles your local `audit_tool` and verifies the provisioned fixtures are in place).
2. Inspect each binary artifact in `fixtures/` using GNU Binutils (`readelf -h`, `readelf -l`, `readelf -d`) or your compiled `audit_tool`.
3. For each file, classify its status:
   - Is it built for the target machine architecture (`ARM`) or host machine?
   - Is it dynamically linked or statically linked?
   - If dynamic, what exact interpreter pathname does it request?
   - What shared libraries does it require?
4. Document your findings with verifiable `readelf` command outputs and explain the root cause of the two failing binaries.
5. (Optional extension): Compile and test `audit_tool.c` to automate your audit across all three artifacts.

> [!NOTE]
> Do not guess based on file size or name. Ground your conclusions in exact ELF header and segment evidence.
