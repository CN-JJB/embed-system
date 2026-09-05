# P2-M01 Fault Competency Fixtures

This directory contains deliberate, reproducible firmware fixtures representing recurring failure modes in the startup and linker domain.

## Fault Family Catalog

| Fixture | Observed Symptom | Primary Diagnostic Channel |
|---|---|---|
| [`f1/`](f1/) | Target halts immediately after reset; fails to reach `main()` | Binary entry inspection (`readelf -h`), vector table dump (`readelf -x .isr_vector`) |
| [`f2/`](f2/) | Firmware enters `main()`, but initialized global C variables contain invalid values | Linker map audit (`build/firmware.map`), section headers (`readelf -l`) |
| [`f3/`](f3/) | Linker aborts build; reports memory allocation boundary error | Toolchain linker output diagnostic, memory map bounds |

## Investigation Protocol

1. Navigate to the fixture directory:
   ```bash
   cd faults/f1  # or f2, f3
   ```
2. Build the fixture:
   ```bash
   make clean && make
   ```
3. Formulate 3–5 hypotheses before inspecting source code.
4. Collect binary/map evidence using GNU Binutils.
5. Identify the root cause and document the minimal fix.

> [!NOTE]
> Reviewer solutions and root-cause analyses are isolated in [`../reviewer/fault_analysis.md`](../reviewer/fault_analysis.md).
