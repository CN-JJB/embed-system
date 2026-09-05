# Reviewer Guide: Challenge Solution Walkthrough

## Architectural Solution Overview

The challenge requires a fully integrated, deterministic priority inversion harness, stack watermark monitor, and IWDG peripheral driver.

### 1. `FreeRTOSConfig.h`
- `configUSE_MUTEXES` must be set to `1`. This enables `xSemaphoreCreateMutex()`, `xTaskPriorityInherit()`, and `xTaskPriorityDisinherit()`.
- `configCHECK_FOR_STACK_OVERFLOW` must be set to `2`. Method 2 combines Method 1's SP pointer check with inspection of the 16-byte `0xA5` canary buffer at the stack base.
- `configPRIO_BITS` is 4 for STM32F103; `configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY` is 5; shifted value is `0x50`.

### 2. `iwdg.c`
- Direct MMIO access:
  - Write `0x5555` to `IWDG->KR` to unlock `PR` and `RLR`.
  - Poll `IWDG->SR` for `IWDG_SR_PVU == 0` with a decrementing timeout counter.
  - Set `IWDG->PR` with prescaler code.
  - Poll `IWDG->SR` for `IWDG_SR_RVU == 0` with a decrementing timeout counter.
  - Set `IWDG->RLR` with reload value.
  - Write `0xAAAA` to `IWDG->KR` to reload.
  - Write `0xCCCC` to `IWDG->KR` to enable the counter.
- Reset cause:
  - Check `(RCC->CSR & RCC_CSR_IWDGRSTF) != 0`.
  - Clear flags: `RCC->CSR |= RCC_CSR_RMVF`.

### 3. `inversion_app.c`
- Run A: Creates `xSemaphoreCreateBinary()`. Low acquires lock, releases High, releases Medium. Medium preempts Low; High suffers 25 ms delay.
- Run B: Creates `xSemaphoreCreateMutex()`. Low acquires lock, releases High, releases Medium. When High blocks, Low inherits Priority 3; Medium cannot preempt Low. High suffers only 5 ms delay.
- Watermark conversion: `uxTaskGetStackHighWaterMark(xTask) * sizeof(StackType_t)`.
