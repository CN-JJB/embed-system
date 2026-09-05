.PHONY: all clean check

all:
	$(MAKE) -C 01-freertos-scheduler-context-switch all

clean:
	$(MAKE) -C 01-freertos-scheduler-context-switch clean

check:
	@echo "=== Running P2-M04 Checks ==="
	$(MAKE) -C 01-freertos-scheduler-context-switch check
	@echo "=== ALL PHASE 2 RTOS FOUNDATION CHECKS PASSED ==="
