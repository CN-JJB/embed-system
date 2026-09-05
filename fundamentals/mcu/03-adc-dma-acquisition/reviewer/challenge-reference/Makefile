CC := arm-none-eabi-gcc
BUILD_DIR := build
MCU_FLAGS := -mcpu=cortex-m3 -mthumb -mfloat-abi=soft
CFLAGS := $(MCU_FLAGS) -O2 -g3 -Wall -Wextra -Werror -DSTM32F103xB -I. -I../../include -I../../../vendor/cmsis/include
LDFLAGS := $(MCU_FLAGS) -T../../linker/stm32f103c8tx_flash.ld -nostartfiles -Wl,-e,Reset_Handler --specs=nano.specs --specs=nosys.specs

all: $(BUILD_DIR)/firmware.elf

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/firmware.elf: main.c acquisition.c ../../src/runtime_glue.c ../../src/system_stm32f1xx.c ../../src/startup_stm32f103c8.s | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
