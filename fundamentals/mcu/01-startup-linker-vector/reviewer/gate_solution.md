# P2-M01 Gate Solution & Diagnostic Walkthrough

> **Assessment Mode**: AI-Free (Strict)  
> **Target Mastery**: L3 Linker/Startup reasoning, L4-local boot fault recovery  
> **Time Limit**: 45 minutes

---

## 1. Complete Diagnostic Mapping

```text
symptom
→ hypotheses
→ evidence
→ root cause
→ minimal fix
→ regression
```

### Step 1: Symptom
The Gate firmware image (`gate/gate_fault_firmware/build/firmware.elf`) compiles cleanly without warnings, but the MCU halts immediately after power-on reset. Stepping through in GDB shows that the CPU enters `HardFault_Handler` before reaching `main()`.

### Step 2: Hypotheses
1. **Reset vector misaligned / even**: The reset vector entry at `0x08000004` lacks the Thumb execution bit (bit 0 == 0).
2. **Unaligned section placement**: The `.text` section is not word-aligned (4-byte aligned), causing PC instruction fetch alignment faults on 32-bit Thumb-2 wide instructions.
3. **Data/BSS pointer corruption**: The LMA/VMA pointers for `.data` or `.bss` are pointing to invalid addresses or overlapping Flash memory.
4. **Stack pointer out of bounds**: The initial MSP word is pointing to invalid address space.

### Step 3: Evidence Collection
Run binary inspection on the compiled gate ELF:
```bash
arm-none-eabi-readelf -S build/firmware.elf
```
Inspect the section header table:
```text
Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 1] .isr_vector       PROGBITS        08000000 010000 0000ec 00   A  0   0  1
  [ 2] .text             PROGBITS        080000ee 0100ee 000184 00  AX  0   0  2
```
Key observations:
1. `readelf -h` shows entry point `0x08000221`, confirming the Thumb bit is present on `Reset_Handler`.
2. Vector 0 contains `0x20005000` (valid MSP).
3. Section `.text` begins at `0x080000ee` (which is `0xec + 2` bytes offset). This address is **NOT 4-byte aligned** (`0x080000ee % 4 == 2`)!
4. Disassembling `firmware.elf`:
   ```bash
   arm-none-eabi-objdump -d build/firmware.elf | head -n 30
   ```
   Shows instructions are misaligned relative to word boundaries, causing Cortex-M3 instruction prefetch hardware exceptions.

### Step 4: Root Cause
In `gate/gate_fault_firmware/linker_gate.ld`, the `.isr_vector` section was modified with an artificial 2-byte increment (`. = . + 2;`), and the linker script omitted `. = ALIGN(4);` before the `.text` section. Consequently, all executable machine instructions were placed at a 2-byte offset, violating 4-byte architectural alignment rules for section transitions.

### Step 5: Minimal Fix
Edit `linker_gate.ld`:
1. Remove the artificial 2-byte misalignment in `.isr_vector`.
2. Ensure `. = ALIGN(4);` is declared at the section boundaries.

```diff
--- a/gate/gate_fault_firmware/linker_gate.ld
+++ b/gate/gate_fault_firmware/linker_gate.ld
@@ -16,8 +16,9 @@ SECTIONS
     .isr_vector :
     {
+        . = ALIGN(4);
         KEEP(*(.isr_vector))
-        . = . + 2;
+        . = ALIGN(4);
     } > FLASH
```

### Step 6: Regression Verification
Recompile the gate firmware:
```bash
make -C gate/gate_fault_firmware clean all
arm-none-eabi-readelf -S gate/gate_fault_firmware/build/firmware.elf
```
Verify that:
1. `.isr_vector` size is `0xec` and `.text` starts at `0x080000ec` (4-byte aligned: `0xec % 4 == 0`).
2. Run `make check` to verify overall module consistency.
