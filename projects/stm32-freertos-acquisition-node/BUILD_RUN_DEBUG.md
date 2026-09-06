# BUILD, RUN & DEBUG GUIDE — STM32 FreeRTOS Acquisition Node

This operational runbook provides exact build commands, debugging workflows, and hardware inspection procedures for the P2-M07 STM32 FreeRTOS Acquisition Node on STM32F103C8T6.

> [!IMPORTANT]
> In strict accordance with root `AGENTS.md`, physical hardware execution, live GDB register sessions, logic analyzer captures, and watchdog reboot timing that have not been physically captured on a bench target are explicitly labeled:
> **`EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED`**
> Never fabricate terminal outputs, waveforms, or timing numbers.

---

## 1. Build and Footprint Inspection

### Clean Build
From the project directory:
```bash
make clean build
```

### Firmware Footprint Inspection
```bash
arm-none-eabi-size build/firmware.elf
```
*Actual Host Build Output (GCC 13.2.1)*:
```text
   text    data     bss     dec     hex filename
  12160       8   10880   23048    5a08 build/firmware.elf
```
*Memory Budget Breakdown*:
- **Total Flash (text + data)**: 12,168 bytes ($\approx 18.6\%$ of 64 KB capacity, $\ge 52$ KB headroom).
- **Total SRAM (data + bss)**: 10,888 bytes ($\approx 53.2\%$ of 20 KB capacity, $\ge 9.5$ KB headroom).
- **FreeRTOS Heap (`ucHeap` in `.bss`)**: 9,216 bytes (9 KB).
- **Acquisition DMA Double Pool**: 256 bytes (`2 * 64 * 2` bytes, halfword aligned).

### Map File Inspection
```bash
grep -E "(g_adc_pool|ucHeap|xAcqQueue|xLogQueue)" build/firmware.map
```

---

## 2. Target Flashing via OpenOCD

`EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED`

Connect an ST-Link V2 probe to the SWD pins (SWDIO, SWCLK, GND, 3.3V) of the STM32F103C8T6 target:
```bash
openocd -f interface/stlink.cfg -f target/stm32f1x.cfg \
        -c "program build/firmware.elf verify reset exit"
```

Expected OpenOCD terminal output upon target programming:
```text
** Programming Started **
Info : device id = 0x20036410
Info : flash size = 64kbytes
target halted due to debug-request, current mode: Thread
auto erase enabled
wrote 16384 bytes from file build/firmware.elf in 0.812345s (19.696 KiB/s)
** Programming Finished **
** Verify Started **
verified 12168 bytes in 0.234567s (50.682 KiB/s)
** Verified OK **
** Resetting Target **
```

---

## 3. Telemetry Stream Observation

`EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED`

Connect a USB-to-UART bridge:
- Target **PA9 (USART1 TX)** $\to$ Bridge RX
- Target **PA10 (USART1 RX)** $\to$ Bridge TX
- Common Ground (GND)

Open serial terminal at 115200 baud (8N1):
```bash
picocom -b 115200 /dev/ttyUSB0
```

Expected ASCII telemetry stream (produced by `Task_Comm` at priority 2 every ~64 ms):
```text
[TELEM] seq=1 min=2041 max=2056 avg=2048 rms=2048 drops=0
[TELEM] seq=2 min=2040 max=2054 avg=2048 rms=2048 drops=0
[TELEM] seq=3 min=2042 max=2057 avg=2049 rms=2049 drops=0
[TELEM] seq=4 min=2039 max=2055 avg=2048 rms=2048 drops=0
```

---

## 4. GPIO Instrumentation & Oscilloscope Probe Points

`EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED`

The firmware drives atomic hardware markers on GPIOA for logic analyzer / oscilloscope verification:

| Pin | Function / Event | Expected Electrical Behavior |
|---|---|---|
| **PA0** | ADC1 Channel 0 Input | Analog voltage ($0\text{ V}$ to $3.3\text{ V}$) |
| **PA1** | DMA ISR / Process Event | Toggle pulse on each HT (half 0) and TC (half 1) milestone (~15.6 Hz half-buffer rate) |
| **PA2** | `Task_Compute` Active | Logic HIGH while medium-priority interference workload executes (~20 ms) |
| **PA3** | `Task_Health` Active | Logic HIGH while periodic health audit executes (~500 ms period) |
| **PA4** | Diagnostic Resource Held | Logic HIGH while Low holds diagnostic resource (`g_diag_resource`) |
| **PC13** | Status Heartbeat LED | Toggles state every 500 ms healthy cycle (Active LOW on Blue Pill) |

---

## 5. Controlled Priority-Inversion Diagnostic Procedure

`EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED`

### Setup and Roles
- **High**: `Task_Process` (Priority 3)
- **Medium**: `Task_Compute` (Priority 2)
- **Low**: `Task_Health` (Priority 1)

### Execution Protocol
The diagnostic executes during the initial baseline phase under quiescent conditions:
1. **Run A (Binary Semaphore — No Priority Inheritance)**:
   - Low acquires `g_diag_sem`.
   - Low releases High via direct task notification.
   - High awakens, samples DWT cycle counter, calls `xSemaphoreTake(g_diag_sem)`, and blocks.
   - Scheduler returns to Low.
   - Low releases Medium via direct task notification.
   - Medium preempts Low (Priority 2 > 1) and executes CPU interference (~20 ms).
   - Low finishes critical workload (~5 ms).
   - Low releases `g_diag_sem`. High unblocks and records wait cycles in `g_diag_high_wait_cycles_run_a`.
   - **Design Target Wait Duration**: $\approx 25\text{ ms}$ (~1,800,000 cycles @ 72 MHz).

2. **Run B (Mutex — Priority Inheritance Active)**:
   - Low acquires `g_diag_mutex`.
   - Low releases High via direct task notification.
   - High awakens, samples DWT, calls `xSemaphoreTake(g_diag_mutex)`, and blocks.
   - Low inherits Priority 3!
   - Low releases Medium. Medium awakens, but cannot preempt inherited Priority 3 Low!
   - Low finishes critical workload promptly (~5 ms).
   - Low releases `g_diag_mutex` and disinherits to Priority 1. High unblocks and records wait cycles in `g_diag_high_wait_cycles_run_b`.
   - **Design Target Wait Duration**: $\approx 5\text{ ms}$ / $\le 6\text{ ms}$ (~360,000 cycles @ 72 MHz).

---

## 6. GDB Inspection & Register Observation

`EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED`

Launch OpenOCD in terminal 1, then attach GDB in terminal 2:
```bash
arm-none-eabi-gdb -ex "target extended-remote :3333" build/firmware.elf
```

### Inspect Diagnostic Cycle Results
```gdb
(gdb) print g_diag_high_wait_cycles_run_a
$1 = 1812450   <-- EXPECTED / ILLUSTRATIVE (~25.1 ms @ 72 MHz)
(gdb) print g_diag_high_wait_cycles_run_b
$2 = 362480    <-- EXPECTED / ILLUSTRATIVE (~5.03 ms @ 72 MHz)
```

### Inspect Stack Watermarks and Heap Health
```gdb
(gdb) print node_app_get_watermark_bytes(g_task_process_handle)
$3 = 640       <-- EXPECTED / ILLUSTRATIVE (160 words remaining)
(gdb) print xPortGetFreeHeapSize()
$4 = 4608      <-- EXPECTED / ILLUSTRATIVE (~4.5 KB free in heap_4)
(gdb) print xPortGetMinimumEverFreeHeapSize()
$5 = 4608      <-- EXPECTED / ILLUSTRATIVE (Zero steady-state churn)
```

### Inspect Watchdog Reset Cause
```gdb
(gdb) print (bool)iwdg_check_and_clear_reset_cause()
$6 = false     <-- EXPECTED / ILLUSTRATIVE (Normal power-on reset)
```

---

## 7. Verification Status Summary

| Evidence Item | Status | Basis | Does Not Prove |
|---|---|---|---|
| Target compile and link | **VERIFIED** | Clean build with GCC 13.2.1 under `-Werror` | Target physical execution |
| Memory bounds (Flash / SRAM) | **VERIFIED** | Linker map and `size` tool confirmation | Target runtime memory behavior |
| Peripheral register disassembly | **VERIFIED** | `objdump` confirmation of TIM3, ADC1, DMA1, USART1, IWDG, DWT | Physical hardware timing or conversions |
| Positive reference validation | **VERIFIED** | `scripts/verify_project.sh` passed on reference bundle | Target runtime correctness |
| Negative mutation rejection | **VERIFIED** | All 16 defective mutations rejected by validator | Completeness of future Final Gate |
| Target flash and run | **UNVERIFIED** | No bench hardware physically connected | Real electrical operation |
| GDB register inspection | **UNVERIFIED** | Illustrative commands; no live probe attached | Measured register contents |
| Telemetry serial output | **UNVERIFIED** | Illustrative protocol; no UART logic capture | Measured baud rate or jitter |
| Physical oscilloscope waveforms | **UNVERIFIED** | Illustrative timing diagrams; no oscilloscope | Hardware rise times or propagation delays |
