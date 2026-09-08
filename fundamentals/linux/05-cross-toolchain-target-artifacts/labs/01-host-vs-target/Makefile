CROSS_COMPILE ?= arm-none-linux-gnueabihf-
ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
  ifneq ($(shell which arm-linux-gnueabihf-gcc 2>/dev/null),)
    CROSS_COMPILE := arm-linux-gnueabihf-
  endif
endif

CC := $(CROSS_COMPILE)gcc
HOST_CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2 -g

TARGET_BIN := hello_target
HOST_BIN := hello_host

.PHONY: all clean

all: $(TARGET_BIN) $(HOST_BIN)

$(TARGET_BIN): hello_target.c
	$(CC) $(CFLAGS) $< -o $@

$(HOST_BIN): hello_target.c
	$(HOST_CC) $(CFLAGS) $< -o $@

clean:
	rm -f $(TARGET_BIN) $(HOST_BIN)
