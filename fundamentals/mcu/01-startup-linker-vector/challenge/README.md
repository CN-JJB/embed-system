# P2-M01 Challenge: Blank-Directory Startup Reconstruction

## Objective
Reconstruct a complete, working bare-metal startup assembly file and linker script from scratch in an empty directory within 25 minutes without looking at reference files.

## Acceptance Criteria
1. Original linker script declaring `FLASH (64K)` and `RAM (20K)`.
2. Stack pointer initialized to top of RAM (`0x20005000`).
3. Vector table containing initial MSP and Thumb `Reset_Handler`.
4. Assembly `Reset_Handler` implementing:
   - `SystemInit()` call
   - `.data` copy from Flash LMA to RAM VMA
   - `.bss` zeroing in RAM
   - `__libc_init_array()` call
   - `main()` branch
5. Strict compiler/linker flags (`-Wall -Wextra -Werror -nostartfiles`).
6. Memory assertions guarding against Flash/RAM overflow.
## Directory Structure
- `starter/`: Incomplete template with missing reset sequences (used for negative verification).
- `reference/`: Verified working reference implementation meeting all acceptance criteria.
- `validate.sh`: Comprehensive validator that inspects and builds an arbitrary learner submission directory.
- `verify_challenge.sh`: Verification script running `validate.sh` against reference and confirming rejection of starter.

## Verification
To validate your submission:
```bash
bash challenge/validate.sh <path-to-your-submission>
```
To run full challenge regression checks:
```bash
bash challenge/verify_challenge.sh
```
