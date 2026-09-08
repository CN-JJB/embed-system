# Phase 2 Final Gate: Regression Oracle & Reviewer Verification

> **CONFIDENTIAL: REVIEWER REFERENCE MATERIALS — DO NOT DISTRIBUTE TO LEARNERS**

This document details the automated regression testing procedures used by the reviewer to verify that:
1. Seeded defective fixtures fail their respective checks as intended.
2. Reviewer reference fixes pass all automated verification checks.
3. Candidate learner submissions satisfy all technical requirements.

---

## 1. Automated Verification Commands per Part

### Part A Oracle Check
* **Seeded Broken Fixture:**
  ```bash
  make -C part-a clean all
  make -C part-a check
  ```
  *Expected Output:* Exits with code 1:
  `[FAIL] Part A bare-metal startup contract not satisfied; collect required evidence and diagnose.`
* **Reference Fixed Fixture:**
  ```bash
  cp reviewer/reference/part-a/stm32f103c8tx_flash.ld part-a/linker/stm32f103c8tx_flash.ld
  make -C part-a clean all
  make -C part-a check
  ```
  *Expected Output:* Exits with code 0:
  `[PASS] Part A bare-metal startup contract satisfied.`
* **Reviewer Oracle Verification (`reviewer/regression_oracle.py`):**
  - On seeded fixture:
    `[SEEDED_DEFECT_REJECT] Intended defect confirmed: _edata (0x20000000) == _sdata (0x20000000). Copy range length is 0 bytes; startup copy loop skips initialized data relocation.`
  - On reference fixture:
    `[REFERENCE_PASS] Reference fix verified: _sdata=0x20000000, _edata=0x20000004 (size=4 bytes), _sidata=LOADADDR(.data)=0x0800022c.`

---

### Part B Oracle Check
* **Seeded Broken Fixture:**
  ```bash
  make -C part-b clean all
  make -C part-b check
  ```
  *Expected Output:* Exits with code 1:
  `[FAIL] Part B peripheral acquisition contract not satisfied; collect required evidence and diagnose.`
* **Reference Fixed Fixture:**
  ```bash
  cp reviewer/reference/part-b/dma.c part-b/src/dma.c
  make -C part-b clean all
  make -C part-b check
  ```
  *Expected Output:* Exits with code 0:
  `[PASS] Part B peripheral acquisition contract satisfied.`
* **Reviewer Oracle Verification (`reviewer/regression_oracle.py`):**
  - On seeded fixture:
    `[SEEDED_DEFECT_REJECT] Intended defect confirmed: DMA1_Channel1->CCR configured with 0x52e (1326 decimal). Bit 7 (DMA_CCR_MINC = 0x80) is omitted; memory pointer does not increment.`
  - On reference fixture:
    `[REFERENCE_PASS] Reference fix verified: DMA1_Channel1->CCR configured with 0x5ae (1454 decimal). Circular mode (CIRC), memory increment (MINC), and transfer interrupts enabled.`

---

### Part C Oracle Check
* **Seeded Broken Fixture:**
  ```bash
  make -C part-c clean all
  make -C part-c check
  ```
  *Expected Output:* Exits with code 1:
  `[FAIL] Part C FreeRTOS scheduling contract not satisfied; collect required evidence and diagnose.`
* **Reference Fixed Fixture:**
  ```bash
  cp reviewer/reference/part-c/interrupt_config.c part-c/src/interrupt_config.c
  make -C part-c clean all
  make -C part-c check
  ```
  *Expected Output:* Exits with code 0:
  `[PASS] Part C FreeRTOS scheduling contract satisfied.`
* **Reviewer Oracle Verification (`reviewer/regression_oracle.py`):**
  - On seeded fixture:
    `[SEEDED_DEFECT_REJECT] Intended defect confirmed: EXTI0 configured with priority byte 0x30 (logical 3). Numerical byte 0x30 < 0x50, violating FreeRTOS configMAX_SYSCALL_INTERRUPT_PRIORITY boundary.`
  - On reference fixture:
    `[REFERENCE_PASS] Reference fix verified: EXTI0 configured with priority byte 0x60 (logical 6). Numerical byte 0x60 >= 0x50, safely within FreeRTOS syscall boundary.`

---

### Part D Oracle Check
* **Seeded Broken Fixture:**
  ```bash
  make -C part-d clean all
  make -C part-d check
  ```
  *Expected Output:* Exits with code 1:
  `[FAIL] Part D concurrency contract not satisfied; collect required evidence and diagnose.`
* **Reference Fixed Fixture:**
  ```bash
  cp reviewer/reference/part-d/node_app.c part-d/src/node_app.c
  make -C part-d clean all
  make -C part-d check
  ```
  *Expected Output:* Exits with code 0:
  `[PASS] Part D concurrency contract satisfied.`
* **Reviewer Oracle Verification (`reviewer/regression_oracle.py`):**
  - On seeded fixture:
    `[SEEDED_DEFECT_REJECT] Intended defect confirmed: task_storage acquires xSensorBusLock without calling xSemaphoreGive. Unreleased mutex causes mutual blocking and starves task_telemetry watchdog refresh.`
  - On reference fixture:
    `[REFERENCE_PASS] Reference fix verified: task_storage acquires and releases xSensorBusLock via xSemaphoreGive, preserving concurrency safety and continuous watchdog refresh.`

---

## 2. Reviewer Master Verification Script

Reviewers can execute all reference checks, seeded failure tests, and isolation scans in a single command:
```bash
bash reviewer/verify_reviewer.sh
```
The script performs the 4-stage staged verification across all parts:
1. `COMPILE PASS`: Seeded fixture builds cleanly.
2. `INTENDED REVIEWER ORACLE REJECT`: Defect is confirmed by `regression_oracle.py`.
3. `REFERENCE COMPILE PASS`: Reference fix builds cleanly.
4. `REFERENCE ORACLE PASS`: Reference fix satisfies `regression_oracle.py`.
5. `REVIEWER ISOLATION AUDIT`: Audits all learner-facing materials via `verify_isolation.py`.

Reviewers can also execute the negative controls suite:
```bash
bash reviewer/test_reviewer_negative_controls.sh
```
