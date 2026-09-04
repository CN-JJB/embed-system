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
The Gate firmware image (`gate/gate_fault_firmware/build/firmware.elf`) compiles cleanly with zero warnings, but upon flashing to target hardware or loading into a simulator, the MCU never executes `main()`. Instead, the core locks up or enters `HardFault_Handler` immediately upon reset.

### Step 2: Hypotheses
1. **Reset vector misaligned / even**: The reset vector entry lacks the required Thumb execution bit (bit 0 == 0).
2. **Vector table displacement / offset**: The `.isr_vector` section was not allocated at the physical base of boot memory (`0x08000000`), causing hardware to fetch arbitrary non-vector bytes as initial MSP and PC.
3. **Data/BSS pointer corruption**: The LMA/VMA pointers for `.data` or `.bss` are pointing to invalid addresses or unmapped memory.
4. **Stack pointer initialization error**: Initial MSP is pointing outside physical SRAM limits.

### Step 3: Evidence Collection
Inspect the section headers of the compiled Gate binary:
```bash
arm-none-eabi-readelf -S gate/gate_fault_firmware/build/firmware.elf
```
Section Header Table:
```text
Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 1] .boot_meta        PROGBITS        08000000 001000 000020 00   A  0   0  4
  [ 2] .isr_vector       PROGBITS        08000020 001020 0000ec 00   A  0   0  1
```
Key observations:
1. Section `[ 1] .boot_meta` is allocated at address `0x08000000` (length 32 bytes = `0x20`).
2. Section `[ 2] .isr_vector` is pushed to address `0x08000020`.
3. Dumping the raw memory at `0x08000000`:
   ```bash
   arm-none-eabi-objdump -s -j .boot_meta gate/gate_fault_firmware/build/firmware.elf
   ```
   Word 0 (`0x08000000`) contains `0x53544D33` (magic string "STM3").
   Word 1 (`0x08000004`) contains `0x00010000` (format revision).

Target execution interpretation (Expected / Illustrative; hardware run UNVERIFIED):
Per Armv7-M architecture, the CPU hardware on reset strictly reads 32-bit initial MSP from `0x08000000` and initial PC from `0x08000004`.
Because `.isr_vector` was pushed to `0x08000020`:
- Hardware loads MSP with `0x53544D33` (an unmapped memory address).
- Hardware loads PC with `0x00010000` (even address, bit 0 is 0!).
- The CPU immediately faults with `UsageFault` (INVSTATE) or `HardFault`.

### Step 4: Root Cause
In `gate/gate_fault_firmware/linker_gate.ld`, a custom metadata section (`.boot_meta`) was placed in `FLASH` before `.isr_vector`.
Per Armv7-M Architecture Reference Manual Section B1.5.3 and ST RM0008 Section 3.5, Cortex-M3 silicon hardware unconditionally fetches the vector table starting at base address `0x08000000` (aliased from `0x00000000`). Placing any other section at `0x08000000` displaces the vector table, causing hardware to execute non-code metadata on reset.

### Step 5: Minimal Fix
In `linker_gate.ld`, place `.isr_vector` at the origin of `FLASH` before `.boot_meta`:

```diff
--- a/gate/gate_fault_firmware/linker_gate.ld
+++ b/gate/gate_fault_firmware/linker_gate.ld
@@ -13,11 +13,11 @@ SECTIONS
 {
+    .isr_vector :
+    {
+        . = ALIGN(4);
+        KEEP(*(.isr_vector))
+        . = ALIGN(4);
+    } > FLASH
+
     .boot_meta :
     {
         . = ALIGN(4);
         KEEP(*(.boot_meta*))
         . = ALIGN(4);
     } > FLASH
-
-    .isr_vector :
-    {
-        . = ALIGN(4);
-        KEEP(*(.isr_vector))
-        . = ALIGN(4);
-    } > FLASH
```

### Step 6: Regression Verification
Recompile:
```bash
make -C gate/gate_fault_firmware clean all
arm-none-eabi-readelf -S gate/gate_fault_firmware/build/firmware.elf
```
Verify that:
1. Section `.isr_vector` starts strictly at `0x08000000`.
2. Vector 0 contains little-endian `0x20005000` (valid MSP) and Vector 1 contains `Reset_Handler | 1`.
