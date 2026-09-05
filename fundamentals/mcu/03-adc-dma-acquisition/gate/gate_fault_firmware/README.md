# Gate Fault Firmware Fixture

This directory contains the seeded target firmware for the P2-M03 Module Gate.

## Build
```bash
make clean all
```

## Running the Diagnostic
Inspect the generated ELF file (`build/firmware.elf`) and disassembly (`build/firmware.asm`) to discover the configuration defect preventing autonomous acquisition.
