# P2-M02 Fault Competency Fixtures

This directory houses reproducible, evidence-driven firmware fixtures covering the primary hardware/software fault families in the MMIO, clock, timer, and NVIC domains.

| Fixture | Observed Symptom | Primary Diagnostic Channel |
|---|---|---|
| [`f1/`](f1/) | Timer counter never advances; peripheral configuration appears ineffective | Bus clock gating status, peripheral control registers |
| [`f2/`](f2/) | Main thread execution completely halts; processor permanently trapped in handler | Interrupt status register inspection, handler exit state |
| [`f3/`](f3/) | Timer update event rate deviates significantly from intended calculation | Clock tree distribution audit, prescaler configuration |
| [`f4/`](f4/) | Interrupt priority byte readback differs from intended logical assignment | NVIC priority register bit layout and encoding |
| [`f5/`](f5/) | Intermittent pulse loss or output edge corruption on shared I/O lines | Instruction disassembly audit, atomic register access |

## Investigation Protocol

1. Navigate to the fixture directory:
   ```bash
   cd faults/f1  # or f2, f3, f4, f5
   ```
2. Build the fixture:
   ```bash
   make clean && make
   ```
3. Formulate 3–5 hypotheses before inspecting source code.
4. Collect register, map, or disassembly evidence.
5. Identify the root cause and document the minimal fix.

> [!NOTE]
> Reviewer solutions and root-cause analyses are isolated in [`../reviewer/fault_analysis.md`](../reviewer/fault_analysis.md).
