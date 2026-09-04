# P2-M01: Reset, Startup, Linker Script, and Vector Table

> Module ID: **P2-M01**  
> Target Silicon: **STM32F103C8T6** (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM)  
> Planned Load: **3.5 h MUST**, 1.0 h SHOULD  
> Target Mastery: **L3** Linker / Startup reasoning, **L4-local** boot fault debugging  
> Build Contract: **Arm GNU Toolchain 13.x / GNU Make / `-nostartfiles`**

---

## 1. Pedagogical Mission

Firmware engineers must never treat MCU boot as vendor magic. When an embedded board hangs before reaching `main()`, HAL libraries and RTOS abstraction layers offer zero visibility.

In this module, you build a complete, bootable bare-metal firmware image from first principles using:
1. An **original 64 KB pedagogical linker script** written from GNU `ld` manual and STM32 memory specifications.
2. An **original assembly startup module** implementing the physical boot sequence.
3. The **canonical `-nostartfiles` C runtime contract** with minimal explicit glue.

By the end of this module, you will be able to trace every machine word from power-on reset to `main()`, explain every ELF section, and diagnose boot failure modes using binary tools and GDB.

---

## 2. Core Mental Models

### 2.1 The Silicon Boot Sequence

Unlike desktop operating systems where a kernel loader creates process virtual memory spaces, a Cortex-M3 microcontroller executes directly from physical address `0x00000000` (aliased to Flash memory at `0x08000000` via boot pin strap configuration):

```text
+--------------------------------------------------------------------------------+
|                        CORTEX-M3 PHYSICAL BOOT SEQUENCE                        |
+--------------------------------------------------------------------------------+
  [Power-On Reset / NRST High]
             │
             ▼
  1. Hardware Fetch Word 0 (0x08000000) ────► Loads Initial MSP (_estack = 0x20005000)
             │
             ▼
  2. Hardware Fetch Word 1 (0x08000004) ────► Loads Initial PC (Reset_Handler | 0x1)
             │
             ▼
  3. CPU enters Privileged Thread Mode ─────► Begins executing Reset_Handler
             │
             ▼
  4. BL SystemInit ─────────────────────────► Low-level clock/bus reset
             │                                (Invariant: NO writable global C state)
             ▼
  5. Copy .data loop ───────────────────────► Flash LMA (_sidata) ──► SRAM VMA (_sdata.._edata)
             │
             ▼
  6. Zero .bss loop ────────────────────────► Zeroes SRAM (_sbss .. _ebss)
             │
             ▼
  7. BL __libc_init_array ──────────────────► Traverses .preinit_array & .init_array
             │                                (Invokes C constructors & _init)
             ▼
  8. BL main ───────────────────────────────► Enters application main()
             │
             ▼
  9. Infinite Loop (b .) ───────────────────► Catches abnormal exit if main() returns
+--------------------------------------------------------------------------------+
```

### 2.2 The Thumb Bit Rule (Bit 0 of Vector Addresses)

Arm Cortex-M processors execute **Thumb-2 instructions only**. The processor hardware never supports Arm 32-bit state.
- In Armv7-M architecture, the program counter (PC) can only branch to Thumb state when the destination address has **bit 0 set to `1`**.
- When the hardware fetches vector 1 from Flash, bit 0 indicates execution mode:
  - If bit 0 == `1`, hardware clears bit 0, sets the EPSR Thumb bit (`T`), and begins execution.
  - If bit 0 == `0`, hardware triggers an immediate **`UsageFault` (INVSTATE: Invalid State)** or lockup.
- In assembly: `.type Reset_Handler, %function` informs the GNU assembler and linker that the symbol is a function entry, causing the linker to automatically set bit 0 (`Reset_Handler | 1`) in the vector table.

### 2.3 Memory Layout: VMA vs. LMA

Flash memory is non-volatile (retains data across resets) but read-only during normal execution. SRAM is volatile (random state at reset) but read-write.
- **`.text` & `.rodata`**: Reside in Flash; executed/read directly from Flash (VMA == LMA == `0x08000000` range).
- **`.data`**: Initialized global/static variables.
  - Initial values must be stored in Flash (**LMA**: Load Memory Address, beginning at symbol `_sidata`).
  - At runtime, variables must be read and modified in SRAM (**VMA**: Virtual Memory Address, range `_sdata` to `_edata`).
  - Startup code must physically copy these bytes from Flash LMA to SRAM VMA!
- **`.bss`**: Uninitialized global/static variables.
  - Takes zero space in Flash storage.
  - Allocated in SRAM (**VMA**, range `_sbss` to `_ebss`).
  - Startup code must zero this memory block before C code executes.

```text
 FLASH MEMORY (64 KB: 0x08000000 - 0x08010000)
┌────────────────────────────────────────────────────────┐
│ 0x08000000: .isr_vector (Initial MSP + Vector Table)   │
├────────────────────────────────────────────────────────┤
│ 0x080000ec: .text (Code: Reset_Handler, main, libc)   │
├────────────────────────────────────────────────────────┤
│ 0x0800026c: .init_array (Constructor pointers)        │
├────────────────────────────────────────────────────────┤
│ 0x08000270: .data initial values (LMA: _sidata)       │──┐
└────────────────────────────────────────────────────────┘  │
                                                            │ (Startup Copy Loop)
 SRAM MEMORY (20 KB: 0x20000000 - 0x20005000)              │
┌────────────────────────────────────────────────────────┐  │
│ 0x20000000: .data variables (VMA: _sdata .. _edata)   │◄─┘
├────────────────────────────────────────────────────────┤
│ 0x20000004: .bss variables (VMA: _sbss .. _ebss)       │◄── (Startup Zero Loop)
├────────────────────────────────────────────────────────┤
│ 0x2000000c: Heap / Stack space                         │
│                                                        │
│                           ▲                            │
│                           │ (Stack grows downward)     │
├────────────────────────────────────────────────────────┤
│ 0x20005000: _estack (Top of 20 KB SRAM)                │
└────────────────────────────────────────────────────────┘
```

### 2.4 The `SystemInit()` Early-Startup Invariant

In standard Cortex-M firmware, `Reset_Handler` invokes `SystemInit()` immediately upon boot.
- Notice: `SystemInit()` runs **before** the `.data` copy loop and **before** the `.bss` zero loop!
- **Critical Invariant**: `SystemInit()` **MUST NOT** read or write any initialized writable global or static C variable (`.data` or `.bss`).
- If `SystemInit()` writes to a global variable (e.g. `SystemCoreClock = 72000000;`), that value will be overwritten and destroyed when the subsequent `.data` copy loop or `.bss` zero loop executes.
- `SystemInit()` must operate exclusively on:
  - Memory-mapped peripheral registers (`RCC`, `FLASH->ACR`, `SCB->VTOR`);
  - Core registers;
  - Local variables allocated on the stack (using the freshly loaded MSP).

### 2.5 Preferred Policy A: Runtime & Startfile Contract

This course standardizes on **Preferred Policy A**:
1. **`-nostartfiles`**: Suppresses default GCC/newlib CRT startup files (`crt0.o`, `crti.o`, `crtbegin.o`, `crtend.o`, `crtn.o`).
2. **`Reset_Handler` is the sole entry point**: No hidden toolchain `_start` is ever linked or executed.
3. **`-Wl,-e,Reset_Handler`**: Sets the ELF entry point symbol for debugger and ELF loader tools.
4. **Minimal Runtime Glue (`runtime_glue.c`)**:
   - `__libc_init_array()` from newlib-nano references `_init` (legacy constructor hook) and iterates over `.preinit_array` and `.init_array`.
   - Course runtime glue provides empty stubs:
     ```c
     void _init(void) {}
     void _fini(void) {}
     ```
   - This satisfies the linker without dragging in opaque vendor or toolchain runtime objects.
5. **Dynamic Memory Invariant**: `malloc`, `free`, `realloc`, and `_sbrk` are strictly excluded from mandatory coursework to prevent heap corruption and dual-heap memory hazards.

---

## 3. Linker Script Architecture

The pedagogical linker script [`linker/stm32f103c8tx_flash.ld`](linker/stm32f103c8tx_flash.ld) enforces:
- `FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 64K`
- `RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 20K`
- Explicit preservation of constructor tables using `KEEP()`:
  ```ld
  .init_array :
  {
      . = ALIGN(4);
      PROVIDE_HIDDEN (__init_array_start = .);
      KEEP (*(SORT(.init_array.*)))
      KEEP (*(.init_array*))
      PROVIDE_HIDDEN (__init_array_end = .);
      . = ALIGN(4);
  } > FLASH
  ```
- Physical memory overflow guards:
  ```ld
  ASSERT(_ebss + _min_stack_size <= ORIGIN(RAM) + LENGTH(RAM),
         "Linker Error: SRAM exhausted! BSS and stack exceed 20 KB capacity.")
  ASSERT(LOADADDR(.data) + SIZEOF(.data) <= ORIGIN(FLASH) + LENGTH(FLASH),
         "Linker Error: Flash exhausted! Firmware image exceeds 64 KB capacity.")
  ```

---

## 4. Module Map & Labs

| Path | Description | Verification Status |
|---|---|---|
| [`labs/01-elf-vector-inspect/`](labs/01-elf-vector-inspect/README.md) | Dissect ELF headers, vector table, and Thumb entry address | **VERIFIED** (host toolchain) |
| [`labs/02-reset-to-main-boot/`](labs/02-reset-to-main-boot/README.md) | Step-by-step verification of reset execution path | **PARTIALLY VERIFIED** (GDB script verified) |
| [`labs/03-data-bss-init/`](labs/03-data-bss-init/README.md) | Inspect `.data` LMA-to-VMA copy and `.bss` zeroing in memory | **VERIFIED** (disassembly & symbol checks) |
| [`labs/04-gdb-handlers-vectors/`](labs/04-gdb-handlers-vectors/README.md) | GDB memory dump of vector table and register states | **PARTIALLY VERIFIED** (script documented) |
| [`labs/05-startup-linker-faults/`](labs/05-startup-linker-faults/README.md) | Guided fault investigation across startup fault families | **VERIFIED** (static regression verified) |
| [`challenge/`](challenge/README.md) | Blank-directory linker script and startup reconstruction | **AI-Free Challenge** |
| [`faults/`](faults/README.md) | Reproducible fault fixtures (misaligned vector, LMA error, overflow) | **VERIFIED** |
| [`gate/`](gate/README.md) | AI-Free Module Gate assessment fixture | **AI-Free Assessment** |
| [`reviewer/`](reviewer/README.md) | Diagnostic solutions, fault root-cause analysis, and regression | **Reviewer Isolated** |

---

## 5. Verification Commands

Run the full automated static check suite:

```bash
make check
```

Or run the verification script directly:

```bash
bash scripts/verify_m01.sh
```
