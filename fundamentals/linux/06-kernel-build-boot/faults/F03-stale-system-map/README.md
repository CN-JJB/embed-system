# Fault F03 — Stale / Mismatched `System.map`

## Symptom
During kernel crash analysis, post-mortem oops debugging, or profiling, stack trace hex addresses do not correspond to the functions claimed by debugging scripts. For instance, an oops at `0xc0800000` is mapped to an unrelated handler, or symbols from a newly added driver are completely missing.

## Diagnostic Sequence
1. **Own Description**: The text symbol lookup table (`System.map`) has fallen out of synchronization with the compiled kernel binary (`vmlinux`).
2. **3–5 Hypotheses**:
   - `vmlinux` was rebuilt after modifying source code, but `System.map` was not regenerated.
   - `System.map` was copied from a different build, defconfig, or branch.
   - Compiler flags or link-time optimization altered function placement without updating symbol map.
   - Address space randomized (KASLR enabled without offset adjustment).
3. **Experiment**: Extract canonical symbol addresses directly from the ELF symbol table of `vmlinux` using `readelf -s vmlinux` or `nm -n vmlinux`, and compare them symbol-by-symbol against `System.map`.
4. **Evidence**:
   ```text
   Symbol Name               | vmlinux Addr     | System.map Addr  | Status    
   --------------------------+------------------+------------------+-----------
   stext                     | 0xc0008024       | 0xc0008024       | MATCH     
   start_kernel              | 0xc0800000       | 0xc0804000       | DRIFT     
   rest_init                 | 0xc0800014       | 0xc0808000       | DRIFT     
   kernel_init               | 0xc0800018       | 0xc0800018       | MATCH     
   ```
   `start_kernel` and `rest_init` addresses have drifted!
5. **Narrow Scope**: The binary itself is valid, but the plain-text mapping file is stale.
6. **Root Cause**: `System.map` belongs to an older build revision where `start_kernel` resided at `0xc0804000`.
7. **Fix**: Regenerate `System.map` from current `vmlinux`:
   ```bash
   $(CROSS_COMPILE)nm -n vmlinux | awk '{print $1, $2, $3}' > System.map
   ```
8. **Regression**: Run `./diagnose_f03.sh fixtures/vmlinux fixtures/System.map.current`, verify all symbols report `MATCH`.
