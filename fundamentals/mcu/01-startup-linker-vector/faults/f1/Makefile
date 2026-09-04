# ==============================================================================
# Makefile for Fault Fixture 1: Misaligned Reset Vector
# ==============================================================================
CC      := arm-none-eabi-gcc
OBJCOPY := arm-none-eabi-objcopy
SIZE    := arm-none-eabi-size

BUILD_DIR := build
TARGET    := $(BUILD_DIR)/firmware

MCU_FLAGS := -mcpu=cortex-m3 -mthumb -mfloat-abi=soft
CFLAGS    := $(MCU_FLAGS) -O2 -g3 -Wall -Wextra -Werror -ffunction-sections -fdata-sections -DSTM32F103xB
INCLUDES  := -I../../include -I../../../vendor/cmsis/include
LDFLAGS   := $(MCU_FLAGS) -T../../linker/stm32f103c8tx_flash.ld -nostartfiles -Wl,-e,Reset_Handler -Wl,--gc-sections -Wl,-Map=$(TARGET).map,--cref --specs=nano.specs --specs=nosys.specs

.PHONY: all clean

all: $(TARGET).elf

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/startup_faulty.o: startup_faulty.s | $(BUILD_DIR)
	$(CC) $(MCU_FLAGS) -g3 -c $< -o $@

$(BUILD_DIR)/main.o: ../../src/main.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/system.o: ../../src/system_stm32f1xx.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/runtime_glue.o: ../../src/runtime_glue.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(TARGET).elf: $(BUILD_DIR)/startup_faulty.o $(BUILD_DIR)/main.o $(BUILD_DIR)/system.o $(BUILD_DIR)/runtime_glue.o
	$(CC) $^ $(LDFLAGS) -o $@
	$(SIZE) $@

clean:
	rm -rf $(BUILD_DIR)
