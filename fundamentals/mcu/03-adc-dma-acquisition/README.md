# P2-M03: Peripheral Acquisition, ADC Sampling Contract, and DMA Data Path

> Module ID: **P2-M03**  
> Target Silicon: **STM32F103C8T6** (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM)  
> Planned Load: **4.5 h MUST**, 1.0 h SHOULD  
> Target Mastery: **L2–L3** DMA data path mastery, **L4-local** peripheral trigger debugging  
> Pedagogical Baseline: **Direct CMSIS register structs / RM0008 mechanism-first / Zero HAL**

---

## 1. Pedagogical Mission

In modern embedded systems, real-time data acquisition cannot waste CPU cycles polling ADC status flags or executing interrupt service routines for every single converted byte. Direct Memory Access (DMA) provides a dedicated hardware engine coexisting with the CPU across the AHB bus matrix, moving data autonomously from peripheral registers directly into SRAM.

In this module, you build and verify an **autonomous hardware acquisition pipeline**:
```text
TIM3 Update @ 10 kHz
  ──► TIM3 TRGO (MMS = 010)
  ──► ADC1 Regular External Trigger (EXTSEL = 100, EXTTRIG = 1)
  ──► ADC1 Conversion (PA0, SMP0 = 55.5 cycles, ADCPRE = /6)
  ──► ADC1 DMA Request
  ──► DMA1 Channel 1 (CPAR = &ADC1->DR, CMAR = g_adc_buffer, CNDTR = 128)
  ──► Circular SRAM Buffer (2 x 64 16-bit samples)
  ──► Half-Transfer (HT) ISR -> pulse PA3
  ──► Transfer-Complete (TC) ISR -> pulse PA4
```

Notice the critical architectural milestone: **the CPU executes `__WFI()` and sleeps in low power mode!** Data moves continuously into SRAM without executing a single instruction for individual samples.

---

## 2. Core Mental Models

### 2.1 The DMA Bus Master Mental Model
The DMA controller is not an RTOS task or a software subroutine; it is an independent **AHB bus master**. 
- It arbitrates with the CPU for access to SRAM and peripheral MMIO spaces.
- On each conversion completion, ADC1 asserts its internal DMA request line.
- DMA1 Channel 1 performs an AHB read from `ADC1->DR` (`CPAR`), increments its internal memory pointer, performs an AHB write to `g_adc_buffer` (`CMAR`), and decrements `CNDTR`.
- When `CNDTR` reaches 64, it asserts the Half-Transfer interrupt (`HTIF1`). When `CNDTR` reaches 0, it asserts Transfer-Complete (`TCIF1`), reloads `CNDTR` to 128 in circular mode (`CIRC=1`), and wraps to index 0.

### 2.2 The ADC Sampling & Electrical Contract
An analog-to-digital converter requires strict adherence to physical electrical limits:
1. **Clock Prescaler Limit ($f_{\text{ADC}} \le 14\text{ MHz}$)**:
   - In the canonical 72 MHz profile ($f_{\text{PCLK2}} = 72\text{ MHz}$), leaving `ADCPRE` at reset default (`/2` $\to$ 36 MHz) or `/4` (18 MHz) produces an out-of-spec clock violating comparator settling limits.
   - Software must configure:
     $$\text{RCC->CFGR[ADCPRE]} = \text{0b10 (Divide by 6)} \implies f_{\text{ADCCLK}} = \frac{72\text{ MHz}}{6} = 12\text{ MHz} \le 14\text{ MHz}$$
   - Under 64 MHz HSI fallback, divide-by-6 yields $f_{\text{ADCCLK}} \approx 10.67\text{ MHz} \le 14\text{ MHz}$.
2. **Sample Time & Conversion Math**:
   - Total conversion time per sample:
     $$T_{\text{conv}} = T_{\text{sample}} + 12.5\text{ cycles}$$
   - Selecting `SMP0 = 0b101` (55.5 cycles) on Channel 0 (PA0) yields:
     $$T_{\text{conv}} = 55.5 + 12.5 = 68\text{ cycles} \times \frac{1}{12\text{ MHz}} \approx 5.67\ \mu\text{s}$$
   - This conversion time comfortably fits within the 10 kHz sample period ($100\ \mu\text{s}$).
3. **Source Impedance ($R_{\text{AIN}}$) Compatibility**:
   - A 10 kΩ potentiometer wired as a voltage divider has a worst-case Thevenin resistance at midscale of $2.5\text{ k}\Omega$ ($5\text{ k}\Omega \parallel 5\text{ k}\Omega$), not 10 kΩ.
   - Selecting 55.5 cycles accommodates external source impedances up to $\approx 50\text{ k}\Omega$ (DS5319 Table 49), ensuring analog accuracy without external buffering op-amps.
4. **Mandatory Hardware Calibration Sequence (RM0008 Section 11.4)**:
   - Must be executed after power-up before enabling regular conversions to eliminate internal analog offset:
     ```text
     ADON = 1 -> wait t_STAB -> RSTCAL = 1 -> poll RSTCAL==0 -> CAL = 1 -> poll CAL==0
     ```
   - Bounded timeouts must be enforced.

### 2.3 Buffer Ownership & Storage Duration
- **Storage Duration**: DMA buffers **must have static storage duration** (file-scope or persistent global memory). Allocating a DMA buffer on a local task/function stack leads to fatal memory corruption once the function returns and the stack pointer moves.
- **Double-Buffering Ownership Contract**:
  - **Half 0 (Samples 0..63)**: Owned by DMA while filling; owned by CPU upon HT interrupt.
  - **Half 1 (Samples 64..127)**: Owned by DMA while filling; owned by CPU upon TC interrupt.

### 2.4 Milestone Frequency Mathematics
- Sampling rate $f_s = 10,000\text{ samples/sec}$.
- Total circular buffer capacity = 128 samples (64 per half).
- Milestone rate:
  $$f_{\text{event}} = \frac{10,000}{128} = 78.125\text{ events/sec}$$
- **Observable Timing**:
  - A short pulse per event on PA3/PA4 produces a **78.125 Hz pulse repetition rate**.
  - A pin toggle on each event produces a **39.0625 Hz square wave** ($25.6\text{ ms}$ full period).

---

## 3. Module Structure

```text
fundamentals/mcu/03-adc-dma-acquisition/
├── README.md                          # This pedagogical guide
├── SOURCE_LEDGER.md                   # Authoritative specification references
├── Makefile                           # Strict target build (-Werror, -nostartfiles)
├── include/                           # Direct CMSIS peripheral headers
│   ├── adc.h, dma.h, timer.h, gpio.h, clock.h, system_stm32f1xx.h
├── src/                               # Direct register implementations
│   ├── main.c, adc.c, dma.c, timer.c, gpio.c, clock.c, system_stm32f1xx.c,
│   ├── runtime_glue.c, startup_stm32f103c8.s
├── linker/
│   └── stm32f103c8tx_flash.ld         # Original pedagogical 64K Flash / 20K RAM linker
├── labs/                              # 6 progressive guided labs
│   ├── 01-adc-clock-sample-time/
│   ├── 02-adc-calibration-regular-sequence/
│   ├── 03-tim3-trgo-trigger/
│   ├── 04-dma1-circular-transfer/
│   ├── 05-ht-tc-interrupt-milestones/
│   └── 06-dma-fault-investigation/
├── faults/                            # 5 controlled learner fault fixtures (neutral IDs)
│   ├── README.md, f1/, f2/, f3/, f4/, f5/
├── challenge/                         # AI-Free challenge starter and automated validator
│   ├── README.md, acquisition.h, acquisition.c, validate.sh, verify_challenge.sh
├── gate/                              # AI-Free Module Gate exam fixture
│   ├── README.md, gate_fault_firmware/
├── reviewer/                          # Reviewer-side isolated solutions and regressions
│   ├── README.md, challenge_solution.md, gate_solution.md, fault_analysis.md,
│   ├── hints.md, test_harness_host.c, test_m03_validator_mutations.sh, verify_gate_regression.sh
├── diagrams/
│   └── acquisition_pipeline.mmd       # Pipeline architecture diagram
└── scripts/
    └── verify_m03.sh                  # Automated static & ELF contract suite
```

---

## 4. Automated Verification Commands

```bash
# 1. Strict Target Build & Footprint
make -C fundamentals/mcu/03-adc-dma-acquisition clean all

# 2. Automated Module Verification Suite
bash fundamentals/mcu/03-adc-dma-acquisition/scripts/verify_m03.sh

# 3. Challenge Validator & Mutation Regression
bash fundamentals/mcu/03-adc-dma-acquisition/challenge/verify_challenge.sh

# 4. Gate Fixture Binary Regression
bash fundamentals/mcu/03-adc-dma-acquisition/reviewer/verify_gate_regression.sh
```

---

## 5. Verification Integrity Statement

Per course standards, physical hardware timing measurements must strictly differentiate:

```text
[EXPECTED / TO RECORD ON TARGET]
PA3 emits a narrow pulse every 12.8 ms (78.125 Hz pulse repetition rate).
PA4 emits a narrow pulse every 12.8 ms, phase-shifted by 6.4 ms relative to PA3.
To be measured on target hardware using logic analyzer / oscilloscope.

[Interpretation]
The 78.125 Hz milestone frequency supports the configured TIM3 update-rate and DMA half-buffer contract on that run; register/memory evidence is still required to attribute the timing to the intended trigger and DMA configuration.

[Non-Proof]
This observation DOES NOT prove that all input analog signals are noise-free,
nor does it replace testing the ADC linearity across the full 0V–3.3V range.
```

If no physical probe is connected during automated test runs:
- Physical observation is marked **`UNVERIFIED`**.
- Target compile, link, and static register contracts remain **`VERIFIED`**.
- No fabricated register dumps or waveforms are presented.
