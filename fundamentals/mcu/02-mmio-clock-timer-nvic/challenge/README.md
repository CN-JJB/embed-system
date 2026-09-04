# P2-M02 Challenge: Direct-Register Multi-Channel Software PWM

## Objective
Implement a 4-channel 100 Hz software PWM controller on GPIOA pins PA0–PA3 using a single hardware timer (TIM2) running at 10 kHz (100 us resolution) entirely via direct register access.

## Requirements
1. No HAL or CubeMX libraries permitted.
2. Direct register configuration of RCC, GPIO, TIM2, and NVIC.
3. Duty cycles configurable per channel (0% to 100% in 1% steps).
4. All GPIO manipulations must use atomic `BSRR` / `BRR`.
5. Verify timing on an oscilloscope or logic analyzer.

## Directory Structure
- `starter/`: Starter scaffold with challenge header and template source.
- `validate.sh`: Acceptance validator that compiles, links, and inspects your submission artifact.
- `verify_challenge.sh`: Local challenge test runner.

## Verification
To validate your submission:
```bash
bash challenge/validate.sh <path-to-your-submission>
```
To run full challenge regression checks:
```bash
bash challenge/verify_challenge.sh
```

