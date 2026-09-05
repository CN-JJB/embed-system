# P2-M01 Module Gate: Unfamiliar Boot Fault Diagnosis

> **Assessment Mode**: AI-Free (Strict). Official ST manuals (RM0008, PM0056) and GNU Binutils documentation are permitted.  
> **Target Mastery**: L3 Linker/Startup reasoning, L4-local boot fault debugging.  
> **Time Limit**: 45 minutes.

## Mission
You are given a seeded, non-booting firmware image in [`gate_fault_firmware/`](gate_fault_firmware/).
The firmware compiles without errors, but target execution fails to enter `main()`.

## Deliverables
1. Identify the symptom and write your own technical description.
2. Formulate 3-5 hypotheses before making edits.
3. Collect binary and ELF evidence using `readelf`, `nm`, or `objdump`.
4. State the root cause in the startup/linker/memory-initialization family.
5. Apply the minimal fix and prove regression resolution using `make check`.

## Rules
- Do not consult AI or LLM tools.
- Do not guess or modify code randomly.
- Reviewer answers are isolated under `reviewer/`.
