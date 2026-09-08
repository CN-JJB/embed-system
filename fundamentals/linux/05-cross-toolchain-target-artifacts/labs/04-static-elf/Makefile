CROSS_COMPILE ?= arm-none-linux-gnueabihf-
ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
  ifneq ($(shell which arm-linux-gnueabihf-gcc 2>/dev/null),)
    CROSS_COMPILE := arm-linux-gnueabihf-
  endif
endif

CC := $(CROSS_COMPILE)gcc
READELF ?= $(CROSS_COMPILE)readelf
ifeq ($(shell which $(READELF) 2>/dev/null),)
  READELF := readelf
endif

CFLAGS ?= -Wall -Wextra -O2 -g -static
TARGET_BIN := static_app

.PHONY: all clean inspect

all: $(TARGET_BIN)

$(TARGET_BIN): static_app.c
	$(CC) $(CFLAGS) $< -o $@

inspect: $(TARGET_BIN)
	@echo "=== Inspecting ELF Header (Machine check) ==="
	$(READELF) -h $(TARGET_BIN) | grep -E "Type:|Machine:|Flags:"
	@echo "=== Inspecting Program Headers (INTERP check) ==="
	$(READELF) -l $(TARGET_BIN) | grep INTERP || echo "[CONFIRMED: No INTERP segment present]"
	@echo "=== Inspecting Dynamic Section (DYNAMIC check) ==="
	$(READELF) -d $(TARGET_BIN) 2>&1 | grep "There is no dynamic section" || echo "[CONFIRMED: No dynamic section]"

clean:
	rm -f $(TARGET_BIN)
