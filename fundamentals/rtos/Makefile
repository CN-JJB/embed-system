.PHONY: all clean check

all:
	$(MAKE) -C 01-freertos-scheduler-context-switch all
	$(MAKE) -C 02-freertos-queue-isr-boundary all
	$(MAKE) -C 03-freertos-priority-inversion-stack-watchdog all

clean:
	$(MAKE) -C 01-freertos-scheduler-context-switch clean
	$(MAKE) -C 02-freertos-queue-isr-boundary clean
	$(MAKE) -C 03-freertos-priority-inversion-stack-watchdog clean

check:
	@echo "=== Running P2-M04 Checks ==="
	$(MAKE) -C 01-freertos-scheduler-context-switch check
	@echo "=== Running P2-M05 Checks ==="
	$(MAKE) -C 02-freertos-queue-isr-boundary check
	@echo "=== Running P2-M06 Checks ==="
	$(MAKE) -C 03-freertos-priority-inversion-stack-watchdog check
	@echo "=== ALL PHASE 2 RTOS FOUNDATION CHECKS (M04, M05, M06) PASSED ==="
