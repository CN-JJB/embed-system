CROSS_COMPILE ?= arm-none-linux-gnueabihf-

ifneq ($(MAKECMDGOALS),clean)
  ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
    $(error Cross-compiler '$(CROSS_COMPILE)gcc' not found in PATH. Pass: make CROSS_COMPILE=arm-linux-gnueabihf-)
  endif
endif

FIXTURES_DIR := fixtures

.PHONY: all clean

all:
	bash ../reviewer/scripts/generate_m02_gate_fixtures.sh $(FIXTURES_DIR) $(CROSS_COMPILE)

clean:
	rm -rf $(FIXTURES_DIR)
