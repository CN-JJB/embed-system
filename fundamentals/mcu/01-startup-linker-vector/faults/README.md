# P2-M01 Fault Competency Fixtures

This directory contains deliberate, reproducible firmware fixtures representing recurring failure modes in the startup and linker domain.

## Fault Family Catalog

| Fixture | Family | Symptom | Diagnostic Tool |
|---|---|---|---|
| [`fault1_misaligned_vector/`](faults/fault1_misaligned_vector/) | Vector table / Thumb bit missing | CPU enters `HardFault` / `UsageFault` at reset; PC halts at reset vector | `arm-none-eabi-readelf -h`, `arm-none-eabi-readelf -x .isr_vector` |
| [`fault2_data_lma_mismatch/`](faults/fault2_data_lma_mismatch/) | Section boundary / LMA-VMA mismatch | Firmware reaches `main()`, but all initialized global variables contain garbage | Linker map inspection (`build/firmware.map`), `arm-none-eabi-readelf -l` |
| [`fault3_memory_overflow/`](faults/fault3_memory_overflow/) | Memory bounds / physical limits | Build fails at link time with memory exhaustion | GNU `ld` error diagnostic, `ASSERT` checks |

## Verification Policy

- **Learner-facing files do not reveal the answer or fix.**
- Detailed root cause analysis, hypothesis chains, and regression proofs are cataloged in [`../reviewer/fault_analysis.md`](reviewer/fault_analysis.md).
