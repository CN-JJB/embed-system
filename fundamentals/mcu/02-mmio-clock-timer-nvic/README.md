# P2-M02: MMIO, Clock Tree, Hardware Timers, and NVIC Mechanism

> Module ID: **P2-M02**  
> Target Silicon: **STM32F103C8T6** (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM)  
> Planned Load: **4.5 h MUST**, 1.0 h SHOULD  
> Target Mastery: **L3** NVIC & Timer handling, **L4-local** MMIO register interaction  
> Pedagogical Baseline: **Direct CMSIS register structs / RM0008 mechanism-first / Zero HAL**

---

## 1. Pedagogical Mission

In RTOS kernels and embedded Linux device drivers, timers and interrupts are fundamental primitives. Using STM32Cube HAL libraries conceals the underlying hardware state machine, turning engineering into API memorization.

In this module, you bring up the STM32F103 clock tree and Timer 2 (TIM2) periodic interrupt entirely through direct register manipulation. You will trace:
```text
clock source (HSE / HSI)
  ──► PLL multiplier
  ──► AHB bus (HCLK)
  ──► APB1 prescaler (PCLK1 <= 36 MHz)
  ──► Timer Clock Doubler (x2 if APB1 prescaler != 1)
  ──► TIM2 Peripheral Clock Enable (RCC->APB1ENR)
  ──► TIM2 Counter Prescaler (PSC) & Auto-Reload (ARR)
  ──► Update Event (UEV) & Interrupt Enable (TIM2->DIER)
  ──► NVIC Priority & IRQ Enable (NVIC_SetPriority / NVIC_EnableIRQ)
  ──► CPU Exception Stacking & Handler Mode Entry
  ──► Peripheral Flag Acknowledge (TIM2->SR) & DSB Barrier
```

---

## 2. Core Mental Models

### 2.1 The Memory-Mapped I/O (MMIO) Mental Model
In Cortex-M3, peripherals are mapped into the physical address space between `0x40000000` and `0x5FFFFFFF`. The CPU reads and writes peripheral control registers using standard `LDR` and `STR` machine instructions.

- **CMSIS Struct Pointer Mapping**:
  ```c
  #define PERIPH_BASE       ((uint32_t)0x40000000)
  #define APB1PERIPH_BASE   PERIPH_BASE
  #define TIM2_BASE         (APB1PERIPH_BASE + 0x0000)
  #define TIM2              ((TIM_TypeDef *)TIM2_BASE)
  ```
- **What `volatile` Does / Does Not Guarantee**:
  - `volatile` informs the compiler that the register can change outside the program flow (by hardware) and that writes produce observable hardware side effects.
  - `volatile` guarantees that GCC emits an explicit memory load or store on every access, preventing register caching and dead-store elimination.
  - **`volatile` DOES NOT guarantee atomicity** across multi-step read-modify-write sequences!
  - **`volatile` DOES NOT enforce CPU out-of-order write-buffer synchronization**; hardware memory barriers (`__DSB()`) are required.

### 2.2 Read-Modify-Write (RMW) Race Conditions and Atomic BSRR
When software modifies a register using bitwise operators:
```c
GPIOA->ODR |= (1 << 2);
```
GCC compiles this into three distinct machine instructions:
1. `LDR r1, [r0, #12]` (Read ODR into core register)
2. `ORR r1, r1, #4`    (Modify bit 2 in core register)
3. `STR r1, [r0, #12]` (Write updated word back to ODR)

**The Race Hazard**:
If an interrupt (e.g. `TIM2_IRQHandler`) preempts execution between step 1 and step 3 and modifies another bit in `ODR` (e.g. pin 1), that modification will be silently overwritten and erased when Thread mode resumes and executes its `STR`!

**The Atomic Hardware Resolution**:
STM32 GPIO peripherals feature dedicated **Bit Set/Reset Registers** (`BSRR` and `BRR`):
- Writing a `1` to `BSRR[15:0]` sets pin `n`.
- Writing a `1` to `BSRR[31:16]` or `BRR[15:0]` resets pin `n`.
- Writing a `0` has no effect.
This is executed as a **single atomic bus write** (`STR`). No read phase occurs, eliminating the race condition entirely without needing to disable interrupts.

### 2.3 The Clock Tree & Timer Doubling Rule
STM32F103 features two peripheral buses with different speed ceilings:
- **APB2** (High-Speed): 72 MHz maximum (GPIO, ADC1, USART1, TIM1).
- **APB1** (Low-Speed): **36 MHz maximum** (TIM2, TIM3, TIM4, USART2, I2C1, SPI2).

**Timer Input Clock Doubling Rule** (RM0008 Section 6.2):
- If the APB prescaler division factor == 1: Timer clock = APB clock.
- If the APB prescaler division factor > 1: **Timer clock = APB clock * 2**.

```text
  SYSCLK = 72 MHz (HSE 8 MHz x PLL 9)
       │
       ├─► AHB Prescaler /1 ──► HCLK = 72 MHz
       │         │
       │         ├─► APB2 Prescaler /1 ──► PCLK2 = 72 MHz
       │         │                              │
       │         │                              └─► TIM1 Clock = 72 MHz (prescaler = 1)
       │         │
       │         └─► APB1 Prescaler /2 ──► PCLK1 = 36 MHz (<= 36 MHz Limit)
       │                                        │
       │                                        └─► TIM2/3/4 Clock = 36 MHz * 2 = 72 MHz!
```

### 2.4 NVIC Priority Architecture: Logical vs. Encoded Representation
Cortex-M3 supports up to 256 priority levels (8 bits). STM32F103 silicon physically implements **4 bits** (`__NVIC_PRIO_BITS = 4`), residing in the upper nibble of each priority byte:

$$	ext{Encoded Byte in } 	ext{NVIC->IP[x]} = 	ext{Logical Priority} \ll (8 - \_\_	ext{NVIC\_PRIO\_BITS}) = 	ext{Logical Priority} \ll 4$$

- **CMSIS Logical Priority**: $0$ (highest urgency) to $15$ (lowest urgency).
- Passing logical priority `6` to `NVIC_SetPriority(TIM2_IRQn, 6)` writes `0x60` into `NVIC->IP[TIM2_IRQn]`.
- **Preemption Rule**: An exception with numerically lower logical priority preempts an active exception with numerically higher logical priority.

### 2.5 Interrupt Acknowledgment & The Interrupt Storm
When a peripheral event occurs, the peripheral asserts its interrupt line to the NVIC.
- The NVIC transitions the interrupt from **Inactive** $	o$ **Pending** $	o$ **Active**.
- Entering the ISR clears the NVIC pending bit, but **DOES NOT** clear the peripheral flag in `TIM2->SR`!
- If software exits `TIM2_IRQHandler` without writing `TIM2->SR = ~TIM_SR_UIF`:
  - The peripheral continues to hold the interrupt line asserted.
  - Upon executing `BX LR`, the NVIC immediately re-triggers the same ISR!
  - Thread mode is completely starved (**Interrupt Storm**).
- **Write-Buffer Delay Hazard**: Cortex-M3 write buffer can hold the `STR` clearing `TIM2->SR` for several cycles. Software must insert `__DSB()` immediately following the flag clear before returning.

---

## 3. Clock Profiles Supported

1. **Primary Profile (`CLOCK_PROFILE_72MHZ_HSE`)**:
   - Requires external 8 MHz HSE crystal.
   - Flash ACR: 2 wait states (`FLASH_ACR_LATENCY_2`) + Prefetch buffer enabled.
   - AHB /1 (72 MHz), APB2 /1 (72 MHz), APB1 /2 (36 MHz).
   - Timer 2 input clock: 72 MHz.
2. **Safe Fallback Profile (`CLOCK_PROFILE_64MHZ_HSI`)**:
   - Uses internal 8 MHz RC oscillator (HSI / 2 * 16 = 64 MHz).
   - Operates reliably even on boards with broken or missing crystals.
   - Flash ACR: 2 wait states.
   - AHB /1 (64 MHz), APB2 /1 (64 MHz), APB1 /2 (32 MHz).
   - Timer 2 input clock: 64 MHz.

---

## 4. Module Map & Labs

| Path | Description | Verification Status |
|---|---|---|
| [`labs/01-mmio-volatile-gdb/`](labs/01-mmio-volatile-gdb/README.md) | Dissect peripheral register addresses, CMSIS structs, and `volatile` disassembly | **VERIFIED** (host toolchain) |
| [`labs/02-clock-tree-profiles/`](labs/02-clock-tree-profiles/README.md) | Configure 72 MHz HSE PLL & 64 MHz HSI fallback; audit Flash latency wait states | **VERIFIED** (register calculation) |
| [`labs/03-tim2-1khz-interrupt/`](labs/03-tim2-1khz-interrupt/README.md) | Direct register TIM2 1 kHz periodic interrupt, PSC/ARR derivation, ISR flag clear | **VERIFIED** (compile/link verified) |
| [`labs/04-nvic-priority-modes/`](labs/04-nvic-priority-modes/README.md) | NVIC logical vs encoded priority, Handler vs Thread mode, `EXC_RETURN` unstacking | **VERIFIED** (disassembly audit) |
| [`labs/05-rmw-concurrency-hazard/`](labs/05-rmw-concurrency-hazard/README.md) | Controlled demonstration of ODR RMW race condition vs atomic BSRR resolution | **VERIFIED** (code analysis) |
| [`challenge/`](challenge/README.md) | Configure multi-channel software PWM or nested interrupt latency measurement | **AI-Free Challenge** |
| [`faults/`](faults/README.md) | 5 reproducible fault fixtures (clock gating, storm, math error, NVIC, RMW) | **VERIFIED** |
| [`gate/`](gate/README.md) | AI-Free Module Gate assessment fixture | **AI-Free Assessment** |
| [`reviewer/`](reviewer/README.md) | Diagnostic solutions, fault root-cause analysis, and regression | **Reviewer Isolated** |

---

## 5. Physical Evidence Contract

In embedded systems, physical timing evidence must strictly separate three categories:

```text
[Observation]
PA1 exhibits a periodic square wave with 1.0 ms toggle interval (500 Hz frequency).
Measured on target hardware using logic analyzer / oscilloscope.

[Interpretation]
The 1.0 ms toggle supports the mathematical calculation that TIM2 prescaler (PSC=71)
and auto-reload (ARR=999) correctly divide the 72 MHz timer clock to 1000 Hz.

[Non-Proof]
This single-run observation DOES NOT prove that all board crystals run at exactly 8.000 MHz,
nor does it establish worst-case interrupt jitter under nested preemption.
```

If no physical oscilloscope is connected during build:
- Physical observation is marked **`UNVERIFIED`**.
- Target compile/link status remains **`VERIFIED`**.
- No fabricated waveform outputs are presented.

---

## 6. Verification Commands

Run automated static checks:

```bash
make check
```

Or execute script:

```bash
bash scripts/verify_m02.sh
```
