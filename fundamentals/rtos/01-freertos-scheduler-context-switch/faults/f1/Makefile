CC := arm-none-eabi-gcc
BUILD_DIR := build
MCU_FLAGS := -mcpu=cortex-m3 -mthumb -mfloat-abi=soft
CFLAGS := $(MCU_FLAGS) -O2 -g3 -Wall -Wextra -Werror -ffunction-sections -fdata-sections -DSTM32F103xB -I. -I../../include -I../../../vendor/freertos/include -I../../../vendor/freertos/portable/GCC/ARM_CM3 -I../../../../mcu/vendor/cmsis/include
LDFLAGS := $(MCU_FLAGS) -T../../linker/stm32f103c8tx_flash.ld -nostartfiles -Wl,-e,Reset_Handler -Wl,--gc-sections --specs=nano.specs --specs=nosys.specs

SRCS := ../../src/main.c ../../src/clock.c ../../src/gpio.c ../../src/system_stm32f1xx.c ../../src/runtime_glue.c ../../src/startup_stm32f103c8.s \
        ../../../vendor/freertos/tasks.c ../../../vendor/freertos/list.c ../../../vendor/freertos/queue.c \
        ../../../vendor/freertos/portable/GCC/ARM_CM3/port.c ../../../vendor/freertos/portable/MemMang/heap_4.c

all: $(BUILD_DIR)/firmware.elf

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/firmware.elf: $(SRCS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
