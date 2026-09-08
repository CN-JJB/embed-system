# Fault F02 — Missing Dynamic Loader (`No such file or directory`)

## Symptom
On the target board or inside a minimal rootfs, executing `./bin/app_dynamic` prints:
```text
sh: ./bin/app_dynamic: not found
```
or
```text
-sh: ./bin/app_dynamic: No such file or directory
```
Yet running `ls -l bin/app_dynamic` shows:
```text
-rwxr-xr-x 1 root root 8492 Sep 8 09:00 bin/app_dynamic
```
The file clearly exists and has execute permissions (`+x`)!

## Diagnostic Sequence
1. **Own Description**: The shell claims the file does not exist, even though the file is clearly present and executable.
2. **3–5 Hypotheses**:
   - The shell cannot find the path due to typo or working directory issue (disproven by `ls bin/app_dynamic`).
   - The executable has missing execute permissions (disproven by `-rwxr-xr-x`).
   - The ELF binary requests a dynamic interpreter (`PT_INTERP`) that does not exist in `/lib`.
   - The binary has a broken shebang line `#!/bad/path`.
3. **Experiment**: Run `readelf -l bin/app_dynamic | grep interpreter` to find the required program interpreter, and check if that path exists in the rootfs.
4. **Evidence**:
   ```text
   [Requesting program interpreter: /lib/ld-linux-armhf.so.3]
   ```
   Checking rootfs `/lib`: `/lib/ld-linux-armhf.so.3` is absent! Only `ld-musl-armhf.so.1` exists.
5. **Narrow Scope**: The executable file itself is intact, but the Linux kernel's `load_elf_binary()` failed when trying to open `/lib/ld-linux-armhf.so.3`. It returned `-ENOENT` (-2).
6. **Root Cause**: Glibc dynamic binary deployed to a rootfs that does not provide the glibc dynamic linker (`ld-linux-armhf.so.3`).
7. **Fix**:
   - Option A: Copy `/lib/ld-linux-armhf.so.3` and required shared libraries (`libc.so.6`) from the toolchain sysroot into the rootfs `/lib/`.
   - Option B: Recompile the binary with `-static` so it requires no dynamic interpreter.
8. **Regression**: Run `./diagnose_f02.sh`, verify interpreter is present or static binary runs without interpreter.
