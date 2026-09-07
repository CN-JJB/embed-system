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
  `[FAIL] .init_array section size is 0! Pre-main constructor functions were discarded by linker --gc-sections.`
* **Reference Fixed Fixture:**
  ```bash
  cp reviewer/reference/part-a/stm32f103c8tx_flash.ld part-a/linker/stm32f103c8tx_flash.ld
  make -C part-a clean all
  make -C part-a check
  ```
  *Expected Output:* Exits with code 0:
  `[PASS] .init_array section size is 000004 bytes (constructors retained).`
  `[PASS] Constructor symbol 'system_peripheral_preinit' present in ELF.`

---

### Part B Oracle Check
* **Seeded Broken Fixture:**
  ```bash
  make -C part-b clean all
  make -C part-b check
  ```
  *Expected Output:* Exits with code 1:
  `[FAIL] DMA1_Channel1->CCR does not enable memory increment (MINC)!`
* **Reference Fixed Fixture:**
  ```bash
  cp reviewer/reference/part-b/dma.c part-b/src/dma.c
  make -C part-b clean all
  make -C part-b check
  ```
  *Expected Output:* Exits with code 0:
  `[PASS] DMA1_Channel1->CCR enables memory increment (MINC: 0x5ae) and circular mode.`

---

### Part C Oracle Check
* **Seeded Broken Fixture:**
  ```bash
  make -C part-c clean all
  make -C part-c check
  ```
  *Expected Output:* Exits with code 1:
  `[FAIL] EXTI0_IRQn configured with priority byte < 0x50 (logical priority < 5)!`
* **Reference Fixed Fixture:**
  ```bash
  cp reviewer/reference/part-c/interrupt_config.c part-c/src/interrupt_config.c
  make -C part-c clean all
  make -C part-c check
  ```
  *Expected Output:* Exits with code 0:
  `[PASS] EXTI0_IRQn priority is safe (encoded byte >= 0x50, logical priority >= 5).`

---

### Part D Oracle Check
* **Seeded Broken Fixture:**
  ```bash
  make -C part-d clean all
  make -C part-d check
  ```
  *Expected Output:* Exits with code 1:
  `[FAIL] xSharedResourceLock is NOT created with priority inheritance!`
* **Reference Fixed Fixture:**
  ```bash
  cp reviewer/reference/part-d/node_app.c part-d/src/node_app.c
  make -C part-d clean all
  make -C part-d check
  ```
  *Expected Output:* Exits with code 0:
  `[PASS] xSharedResourceLock created with xQueueCreateMutex (priority inheritance enabled).`

---

## 2. Reviewer Master Verification Script

Reviewers can execute all reference checks and seeded failure tests in a single command:
```bash
bash reviewer/verify_reviewer.sh
```
The script backs up the current learner workspace, tests the seeded failures, applies the reference fixes, verifies that all four parts pass, and restores the seeded files.
