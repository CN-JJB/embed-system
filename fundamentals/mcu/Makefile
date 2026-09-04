.PHONY: all clean check

all:
	$(MAKE) -C 01-startup-linker-vector all
	$(MAKE) -C 02-mmio-clock-timer-nvic all

clean:
	$(MAKE) -C 01-startup-linker-vector clean
	$(MAKE) -C 02-mmio-clock-timer-nvic clean

check:
	@echo "=== Running P2-M01 Checks ==="
	$(MAKE) -C 01-startup-linker-vector check
	@echo "=== Running P2-M02 Checks ==="
	$(MAKE) -C 02-mmio-clock-timer-nvic check
	@echo "=== ALL PHASE 2 MCU FOUNDATION CHECKS PASSED ==="
