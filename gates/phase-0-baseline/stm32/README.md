# Module F — STM32 Bare-metal Fundamentals

**Time box:** 65 min  
**Score:** 15 points  
**Mode:** AI-Free; official documentation is explicitly allowed and encouraged  
**Selected MCU:** STM32F103C8T6

## Documentation baseline

Use the official ST documents for the selected MCU:

- **DS5319 Rev 20** — STM32F103x8 / STM32F103xB datasheet
- **RM0008 Rev 21** — STM32F101/102/103/105/107 reference manual
- **PM0056 Rev 7** — STM32F10xxx/20xxx/21xxx/L1xxxx Cortex-M3 programming manual

Official product/document page:

https://www.st.com/en/microcontrollers-microprocessors/stm32f103c8.html

You are expected to navigate the manual. The assessment does not reward memorizing bit names from memory.

> Verification status: **UNVERIFIED — hardware execution required**.
>
> The fixtures are reasoning artifacts only. No board output, SWD trace, interrupt timing, ADC waveform, or DMA transfer has been claimed.

## F1 — Reset to main (15 min, 4 pts)

Inspect:

- `fixtures/startup_excerpt.s`
- `fixtures/linker_excerpt.ld`

Explain the concrete path:

```text
Reset
  -> vector table
  -> initial SP
  -> Reset_Handler
  -> copy .data
  -> zero .bss
  -> SystemInit
  -> main
```

Your answer must connect the startup symbols to the linker script.

Required questions:

1. Where do the first stack-pointer value and Reset_Handler address come from?
2. Why does `.data` have a load address in Flash but a run address in SRAM?
3. Which linker symbols bound the copy/zero loops?
4. What would happen if the `.data` copy were omitted?
5. What would happen if the `.bss` zeroing were omitted?
6. Which parts of this flow are Cortex-M architecture behavior, and which are C runtime/startup implementation choices?

Do not answer with only a generic startup diagram.

## F2 — 1 ms timer interrupt (15 min, 4 pts)

Assume the clock tree has already been configured as:

```text
SYSCLK = HCLK = 72 MHz
APB1 prescaler = /2
PCLK1 = 36 MHz
```

Use **TIM2** and produce one update interrupt every **1 ms**.

From RM0008, determine and explain:

- TIM2 input clock under this APB1 prescaler;
- one valid `PSC` and `ARR` pair;
- peripheral clock enable;
- update-event / update-interrupt configuration;
- counter enable;
- NVIC enable;
- what the ISR must do with the pending/update flag.

You may write register-level C or pseudocode. HAL calls are not required and a HAL-only answer receives limited credit.

Show the arithmetic. Do not merely present register values.

## F3 — MMIO / volatile / read-modify-write (10 min, 2 pts)

Inspect `fixtures/mmio_snippet.c`.

Explain:

1. which accesses represent memory-mapped I/O (MMIO);
2. where `volatile` is required and why;
3. why the current pointer type is unsafe for a peripheral register;
4. what a read-modify-write sequence does;
5. why read-modify-write can be wrong for registers with write-one-to-clear, read side effects, or concurrent hardware changes;
6. why `volatile` does **not** by itself guarantee:
   - atomicity;
   - thread/ISR safety;
   - a complete hardware memory-ordering policy.

Propose a safer register declaration/access style for the shown ordinary control register. You do not need to solve every possible STM32 register-semantic special case.

## F4 — Timer -> ADC -> DMA debugging plan (25 min, 5 pts)

Goal:

```text
TIM3 update
   -> ADC1 regular conversion
   -> DMA1
   -> uint16_t samples[32]
```

The intended design is:

- the ADC clock is already within the datasheet limit and ADC1 has completed the required power-up/calibration readiness steps;
- TIM3 TRGO drives ADC1 external regular conversion;
- ADC1 conversion result is transferred from `ADC1_DR`;
- DMA writes halfword samples into SRAM;
- memory increments; peripheral address does not;
- 32 samples are captured.

Inspect `fixtures/dma_bad_config.txt`. It contains several deliberate configuration mistakes.

Do **not** merely list every suspicious value. Build a debug plan.

Required submission:

1. Cite the RM0008 sections/tables you used for:
   - ADC external trigger selection;
   - ADC DMA enable;
   - DMA channel mapping;
   - DMA channel configuration/status.
2. Give at least three hypotheses ranked by how directly they can break the data path.
3. For each hypothesis, state which register/flag observation would support or reject it.
4. Explain how you would distinguish:
   - timer not producing trigger;
   - ADC not converting;
   - ADC converting but DMA not transferring;
   - DMA transferring with wrong width/direction/address.
5. If SWD and an oscilloscope are available, describe safe observations that would discriminate hypotheses. A GPIO toggled from a diagnostic ISR is acceptable; destructive electrical fault injection is not.

The score is primarily for **manual-backed debug planning**, not for reproducing a CubeMX configuration.

## Sources

- STMicroelectronics, DS5319 Rev 20.
- STMicroelectronics, RM0008 Rev 21.
- STMicroelectronics, PM0056 Rev 7.
