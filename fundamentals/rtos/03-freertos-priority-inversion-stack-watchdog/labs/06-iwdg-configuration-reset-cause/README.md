# Lab 06: STM32F103 IWDG Register Configuration & Reset Cause Diagnosis

## Objectives
- Configure the STM32F103 Independent Watchdog (IWDG) using direct CMSIS registers.
- Understand the clocking constraints and wide frequency spread of the internal LSI oscillator.
- Implement bounded polling on status register flags (`PVU`, `RVU`).
- Detect and clear watchdog reset flags in `RCC->CSR`.

## Hardware Architectural Constraints (RM0008 Section 18)

The IWDG is clocked by the Low-Speed Internal (LSI) RC oscillator.
- **Datasheet DS5319 Spec**: $f_{\text{LSI}}$ nominal is $40\text{ kHz}$, but varies across silicon lots and temperatures from **$30\text{ kHz}$ to $60\text{ kHz}$**!
- Any calculated timeout must account for this $\pm 30\%$ physical variation.

### Key Register Sequences (`IWDG->KR`)
- `0x5555`: Unlock access to `IWDG->PR` (prescaler) and `IWDG->RLR` (reload).
- `0xCCCC`: Start watchdog downcounter. Once started, hardware cannot stop it except via system reset.
- `0xAAAA`: Reload watchdog downcounter from `RLR` ("petting" the dog).

### Status Register (`IWDG->SR`) Polling Contract
The `PR` and `RLR` registers reside in the LSI clock domain. When the CPU writes to them from the APB1 clock domain, hardware synchronizes the values. While synchronization is in progress:
- `IWDG_SR_PVU` (Prescaler Value Update) is set.
- `IWDG_SR_RVU` (Reload Value Update) is set.

Writing to `PR` or `RLR` while these bits are 1 is ignored.

```c
/* BOUNDED POLLING PATTERN */
#define IWDG_SR_TIMEOUT_CYCLES  100000UL

void iwdg_init(uint8_t prescaler, uint16_t reload) {
    IWDG->KR = IWDG_KEY_ACCESS;

    uint32_t timeout = IWDG_SR_TIMEOUT_CYCLES;
    while ((IWDG->SR & (IWDG_SR_PVU | IWDG_SR_RVU)) && --timeout) {
        __NOP();
    }

    IWDG->PR = prescaler & 0x07U;
    IWDG->RLR = reload & 0x0FFFU;

    IWDG->KR = IWDG_KEY_RELOAD;
    IWDG->KR = IWDG_KEY_START;
}
```

## Reset Cause Inspection in `RCC->CSR`

When an MCU boots, firmware must determine whether the reset was caused by normal power-on, an external pin reset, or an unhandled watchdog timeout.

In `src/iwdg.c`:
```c
bool iwdg_was_reset_caused_by_watchdog(void) {
    return (RCC->CSR & RCC_CSR_IWDGRSTF) != 0U;
}

void iwdg_clear_reset_flags(void) {
    /* Setting RMVF clears all reset flags */
    RCC->CSR |= RCC_CSR_RMVF;
}
```

## Review Questions
1. Why must `RCC->CSR |= RCC_CSR_RMVF` be executed during boot?
   *(Answer: If reset flags are not cleared, subsequent resets will still see `IWDGRSTF` set, falsely diagnosing every future reset as a watchdog event).*
2. What happens if software enters an infinite loop while waiting for `IWDG->SR` without a bounded timeout?
   *(Answer: If the LSI fails to oscillate or clock the IWDG registers, the firmware hangs permanently in the boot sequence).*
