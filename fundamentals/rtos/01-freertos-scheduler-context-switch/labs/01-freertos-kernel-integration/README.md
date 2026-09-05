# Lab 01: FreeRTOS V11.3.0 Kernel Integration and Vector Table Binding

## Objective
Integrate the upstream FreeRTOS V11.3.0 kernel into a bare-metal CMSIS Cortex-M3 build environment without CubeMX or HAL wrappers, establish vector table exception handler bindings, and verify core interrupt priority levels.

## Prerequisites
- P2-M01: Bare-metal startup code, vector table structure, and linker script layout.
- P2-M02: CMSIS register definitions and NVIC architecture.
- Understanding of Cortex-M exception model (Reset, NMI, HardFault, SVCall, PendSV, SysTick).

## Environment
- Target: STM32F103C8T6 (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM).
- Toolchain: Arm GNU Toolchain 13.3.rel1 / Ubuntu GCC 13.2.1 cross-compiler.
- Upstream FreeRTOS: V11.3.0 pinned at commit `9b777ae5c5b8e9e456065a00294d1e5f5f9facf5`.

## Estimated Time
- 60 minutes (MUST load).

## AI Mode
- **AI-Hint**: Socratic assistance permitted for explaining exception vectors, FreeRTOSConfig macro semantics, and NVIC priority shifting. Direct code generation prohibited.

## Architectural Principles

### 1. Vector Table Exception Handler Remapping
The ARM Cortex-M3 architecture defines 16 system exceptions at the bottom of the vector table. FreeRTOS requires three core system exceptions to manage execution and real-time preemption:
- **Vector 11 (offset `0x2C`)**: `SVCall` (`SVC_Handler`) - Executed via the `svc` instruction during `vTaskStartScheduler()` to perform the initial unstacking of the first task context and switch CPU from privileged MSP to unprivileged/privileged PSP mode.
- **Vector 14 (offset `0x38`)**: `PendSV` (`PendSV_Handler`) - Triggered asynchronously or cooperatively via `SCB->ICSR |= SCB_ICSR_PENDSVSET_Msk` to execute task context switching at the lowest interrupt priority.
- **Vector 15 (offset `0x3C`)**: `SysTick` (`SysTick_Handler`) - Periodic core timer interrupt advancing the kernel tick counter (`xTickCount`) and unblocking delayed tasks.

In upstream FreeRTOS `portable/GCC/ARM_CM3/port.c`, these handlers are named `vPortSVCHandler`, `xPortPendSVHandler`, and `xPortSysTickHandler`. If the startup vector table declares `SVC_Handler`, `PendSV_Handler`, and `SysTick_Handler` as weak aliases pointing to `Default_Handler`, and no remapping is performed:
$$\text{Vector Address} \longrightarrow \text{Default\_Handler} \longrightarrow \text{Infinite Loop (\texttt{b .})}$$
When `vTaskStartScheduler()` triggers `svc 0`, the processor immediately jumps to `Default_Handler` and permanently hangs.

In `FreeRTOSConfig.h`, we map the upstream names directly to the startup vector table symbol names:
```c
#define vPortSVCHandler     SVC_Handler
#define xPortPendSVHandler  PendSV_Handler
#define xPortSysTickHandler SysTick_Handler
```
This forces the linker to resolve vector table entries 11, 14, and 15 to the implementations compiled from `port.c`.

### 2. Cortex-M3 Interrupt Priority Architecture
STM32F103 implements 4 bits of interrupt priority (`__NVIC_PRIO_BITS = 4`), supporting 16 priority levels ($0$ to $15$, where $0$ is highest priority and $15$ is lowest).

In the Cortex-M3 priority register byte (`IPR` or `SHPR`), the implemented 4 bits occupy the **upper 4 bits** (bits [7:4]), while bits [3:0] read as zero.
- `configKERNEL_INTERRUPT_PRIORITY`: Set to lowest priority $15 \ll 4 = \texttt{0xF0}$. PendSV and SysTick run at this priority so they never delay hardware peripheral interrupts.
- `configMAX_SYSCALL_INTERRUPT_PRIORITY`: Set to priority $5 \ll 4 = \texttt{0x50}$. Any interrupt running at priority 5 to 15 can safely invoke `FromISR` FreeRTOS APIs. Interrupts with priority 0 to 4 are non-maskable by FreeRTOS critical sections (`basepri`), achieving near-zero latency for mission-critical hardware tasks.

## Step-by-Step Procedure

1. **Verify FreeRTOS Source Tree Structure**:
   Check `fundamentals/rtos/vendor/freertos`:
   ```bash
   ls fundamentals/rtos/vendor/freertos
   # Output must contain: include/ list.c queue.c tasks.c portable/
   ```
2. **Review `FreeRTOSConfig.h` Core Definitions**:
   Inspect `fundamentals/rtos/01-freertos-scheduler-context-switch/include/FreeRTOSConfig.h`.
   Confirm:
   - `configUSE_PREEMPTION == 1`
   - `configTICK_RATE_HZ == 1000`
   - `configTOTAL_HEAP_SIZE == (10 * 1024)`
   - Handler mapping macros are present.
3. **Inspect Vector Table Assembly**:
   In `src/startup_stm32f103c8.s`, verify that vector entries 11, 14, and 15 declare `.word SVC_Handler`, `.word PendSV_Handler`, `.word SysTick_Handler`.
4. **Compile Firmware**:
   ```bash
   make -C fundamentals/rtos/01-freertos-scheduler-context-switch clean all
   ```
5. **Verify Symbol Resolution in ELF**:
   ```bash
   arm-none-eabi-nm build/firmware.elf | grep -E '(Default_Handler|SVC_Handler|PendSV_Handler|SysTick_Handler)'
   ```
   Ensure the addresses of `SVC_Handler`, `PendSV_Handler`, and `SysTick_Handler` are distinct from `Default_Handler`.

## Expected Observations & Verification

```text
08000560 T Default_Handler
08000e14 T PendSV_Handler
08000dd0 T SVC_Handler
08000f24 T SysTick_Handler
```
All three handlers reside in code memory (`.text`) with unique entry points matching `port.c`.

## Actual Verification Status
- **Static Compilation & Symbol Resolution**: **VERIFIED** on host Ubuntu GCC 13.2.1 cross-toolchain.
- **Physical GDB SVCall Step-In**: **UNVERIFIED** (Automated headless environment; no physical ST-Link attached).
