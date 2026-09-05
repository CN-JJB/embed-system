# Lab 05: `heap_4` Memory Management, SRAM Budgeting, and Memory Protection

## Objective
Analyze FreeRTOS `heap_4.c` memory allocation, examine the 20 KB STM32F103 SRAM budget, understand block coalescing and alignment, and evaluate why standard C library `malloc` is strictly prohibited in hard real-time systems.

## Prerequisites
- P2-M01: Linker script sections (`.data`, `.bss`, `.heap`, `.stack`) and memory map.
- Lab 01: FreeRTOS configuration and dynamic allocation settings.

## Environment
- Target: STM32F103C8T6 (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM).
- Toolchain: Arm GNU Toolchain 13.3.rel1 / Ubuntu GCC 13.2.1 cross-compiler.

## Estimated Time
- 60 minutes (MUST load).

## AI Mode
- **AI-Hint**: Socratic guidance permitted on memory layout, fragmentation metrics, and pointer arithmetic. Direct code generation prohibited.

## Architectural Principles

### 1. STM32F103 SRAM Memory Budget (20 KB = 20,480 Bytes)
The physical SRAM spans `0x20000000` to `0x20005000`. In our course architecture, SRAM is budgeted deterministically:

```text
0x20005000 +---------------------------------------------------+ <-- RAM End (_estack)
           | Main Stack Pointer (MSP) Stack Frame               | (Default 1 KB for ISRs)
           | (Grows downward)                                   |
0x20004C00 +---------------------------------------------------+
           | Free / Unallocated Space                           | (~8.9 KB safety margin)
0x20002878 +---------------------------------------------------+
           | FreeRTOS heap_4 Array (ucHeap: 10 KB = 10,240 B)   | <-- .bss (FreeRTOS Heap)
           | - Task 1 TCB (~84 B) + Stack (512 B)               |
           | - Task 2 TCB (~84 B) + Stack (512 B)               |
           | - Idle Task TCB + Stack (512 B)                    |
           | - Remaining unallocated heap blocks (~8.5 KB)      |
0x20000078 +---------------------------------------------------+
           | System .bss (Variables initialized to zero)        |
0x20000008 +---------------------------------------------------+
           | System .data (Variables initialized from Flash)    |
0x20000000 +---------------------------------------------------+ <-- RAM Start
```

Under this layout:
- Flash footprint: $\approx 5.2\text{ KB} \ll 64\text{ KB}$ ($8.1\%$ utilized).
- RAM footprint: $\approx 11.5\text{ KB} \ll 20\text{ KB}$ ($56.5\%$ utilized, including entire 10 KB OS heap and global state).

### 2. `heap_4.c` First-Fit with Block Coalescing
`heap_4.c` maintains a singly linked list of free blocks ordered by increasing memory address. Each block begins with an internal header:
```c
typedef struct A_BLOCK_LINK
{
    struct A_BLOCK_LINK *pxNextFreeBlock; /* Pointer to next free block */
    size_t xBlockSize;                    /* Size of block including header */
} BlockLink_t;
```

#### Key Mechanics:
1. **8-Byte Alignment**:
   All allocations are aligned to 8-byte boundaries (`portBYTE_ALIGNMENT = 8`), required by Cortex-M3 stack frames and 64-bit data access.
2. **Allocation Splitting**:
   When `pvPortMalloc(size)` is called, the allocator searches the list for the first free block large enough (`First-Fit`). If the block exceeds the requested size by more than `xHeapStructSize * 2`, it splits the block into two: one allocated, one returned to the free list.
3. **Contiguous Coalescing on `vPortFree()`**:
   When a block is freed, `heap_4` does NOT simply prepend it to a free list (like `heap_2`). Instead, it traverses the ordered list and checks whether the freed block is physically adjacent to either its predecessor or successor block. If adjacent, it **coalesces** them into a single larger block. This eliminates memory fragmentation caused by repeated allocation and deallocation of varying-sized buffers.
4. **Allocation Bit Tracking**:
   The most significant bit of `xBlockSize` (`A_BLOCK_ALLOCATED_BIT_MASK = 0x80000000`) is set to 1 when a block is allocated and cleared to 0 when free, preventing double-free corruption.

### 3. Why Standard Libc `malloc` is Strictly Prohibited in Embedded Real-Time Firmware
Standard C library `malloc()` (from newlib or glibc) has catastrophic disadvantages on resource-constrained microcontrollers:
1. **Non-Deterministic Execution Time**:
   Complex bucket search algorithms exhibit unbounded worst-case execution times, violating hard real-time deadlines.
2. **Memory Leaks and Irreversible Fragmentation**:
   Standard allocators often lack coalescing tailored to single-bank embedded SRAM, causing sudden allocation failures even when total free memory is large.
3. **Code Bloat**:
   Linking libc `malloc` forces the inclusion of `_sbrk_r`, reentrancy structures (`_reent`), thread safety locks, and stdio hooks, bloating flash by 4 to 8 KB.
4. **Stack Collision Risk**:
   Standard `_sbrk()` expands the heap upward toward the downward-growing MSP stack. With no hardware memory management unit (MMU) or protection boundary, a heap-stack collision silently overwrites active data frames, resulting in hard-to-trace crashes.

## Step-by-Step Procedure

1. **Verify Static Symbol Sizes in ELF**:
   ```bash
   arm-none-eabi-nm -S build/firmware.elf | grep -w "ucHeap"
   # Output: 20000078 00002800 b ucHeap
   # 0x2800 == 10,240 bytes (10 KB)
   ```
2. **Verify Absence of Libc Allocators**:
   ```bash
   arm-none-eabi-nm build/firmware.elf | grep -E "\b(malloc|_malloc_r|free|_free_r)\b"
   # Must return 0 lines (exit code 1)
   ```
3. **Examine `vApplicationMallocFailedHook()` in `runtime_glue.c`**:
   Verify that `runtime_glue.c` traps allocation failures with deterministic software breakpoint / assert logging:
   ```c
   void vApplicationMallocFailedHook(void)
   {
       taskDISABLE_INTERRUPTS();
       for (;;) {
           __asm volatile ("bkpt #0");
       }
   }
   ```

## Expected Observations & Verification
- `ucHeap` statically allocated at 10,240 bytes in `.bss`.
- Standard libc `malloc` completely absent from final binary.
- FreeRTOS tasks dynamically allocated from internal heap pool with deterministic alignment.

## Actual Verification Status
- **Static Heap and Symbol Size Verification**: **VERIFIED** on host cross-compiler.
- **Physical SRAM High-Water Mark Dynamic Profiling**: **UNVERIFIED** (Headless build environment; no physical probe attached).
