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

CFLAGS ?= -Wall -Wextra -O2 -g
TARGET_BIN := dynamic_app

.PHONY: all clean inspect

all: $(TARGET_BIN)

$(TARGET_BIN): dynamic_app.c
	$(CC) $(CFLAGS) $< -lm -o $@

inspect: $(TARGET_BIN)
	@echo "=== Inspecting Program Headers (INTERP) ==="
	$(READELF) -l $(TARGET_BIN) | grep -A1 INTERP
	@echo "=== Inspecting Dynamic Section (NEEDED) ==="
	$(READELF) -d $(TARGET_BIN) | grep NEEDED

clean:
	rm -f $(TARGET_BIN)
