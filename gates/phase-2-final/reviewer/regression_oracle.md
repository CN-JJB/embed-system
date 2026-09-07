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
  `[FAIL] Part A LMA mismatch: _sidata (0x080004c0) does not equal LOADADDR(.data) (0x080004d0)!`
* **Reference Fixed Fixture:**
  ```bash
  cp reviewer/reference/part-a/stm32f103c8tx_flash.ld part-a/linker/stm32f103c8tx_flash.ld
  make -C part-a clean all
  make -C part-a check
  ```
  *Expected Output:* Exits with code 0:
  `[PASS] Part A Linker LMA contract verified: _sidata matches LOADADDR(.data) (0x080004d0).`
  `[PASS] .data symbol 'g_runtime_state' has non-zero initial value in image.`

---

### Part B Oracle Check
* **Seeded Broken Fixture:**
  ```bash
  make -C part-b clean all
  make -C part-b check
  ```
  *Expected Output:* Exits with code 1:
  `[FAIL] DMA1_Channel1->CCR does not enable circular mode (DMA_CCR_CIRC)!`
* **Reference Fixed Fixture:**
  ```bash
  cp reviewer/reference/part-b/dma.c part-b/src/dma.c
  make -C part-b clean all
  make -C part-b check
  ```
  *Expected Output:* Exits with code 0:
  `[PASS] DMA1_Channel1->CCR enables circular mode (CIRC: 0x5bf) and memory increment (MINC).`

---

### Part C Oracle Check
* **Seeded Broken Fixture:**
  ```bash
  make -C part-c clean all
  make -C part-c check
  ```
  *Expected Output:* Exits with code 1:
  `[FAIL] EXTI0_IRQn configured with priority byte 0x00 (logical priority 0) which is unmasked by BASEPRI 0x50!`
* **Reference Fixed Fixture:**
  ```bash
  cp reviewer/reference/part-c/interrupt_config.c part-c/src/interrupt_config.c
  make -C part-c clean all
  make -C part-c check
  ```
  *Expected Output:* Exits with code 0:
  `[PASS] EXTI0_IRQn configured with priority byte 0x50 (logical priority 5, safe for FreeRTOS).`

---

### Part D Oracle Check
* **Seeded Broken Fixture:**
  ```bash
  make -C part-d clean all
  make -C part-d check
  ```
  *Expected Output:* Exits with code 1:
  `[FAIL] Inverted lock acquisition hierarchy in task_storage! Lock ordering violation detected.`
* **Reference Fixed Fixture:**
  ```bash
  cp reviewer/reference/part-d/node_app.c part-d/src/node_app.c
  make -C part-d clean all
  make -C part-d check
  ```
  *Expected Output:* Exits with code 0:
  `[PASS] Canonical lock hierarchy verified (task_storage acquires xSensorLock before xStorageLock).`

---

## 2. Reviewer Master Verification Script

Reviewers can execute all reference checks and seeded failure tests in a single command:
```bash
bash reviewer/verify_reviewer.sh
```
The script backs up the current learner workspace, tests the seeded failures, applies the reference fixes, verifies that all four parts pass, and restores the seeded files.
