CC      := arm-none-eabi-gcc
SIZE    := arm-none-eabi-size

BUILD_DIR := build
TARGET    := $(BUILD_DIR)/firmware

MCU_FLAGS := -mcpu=cortex-m3 -mthumb -mfloat-abi=soft
CFLAGS    := $(MCU_FLAGS) -O2 -g3 -Wall -Wextra -Werror -ffunction-sections -fdata-sections -DSTM32F103xB
INCLUDES  := -I../../include -I../../../vendor/cmsis/include
LDFLAGS   := $(MCU_FLAGS) -T../../linker/stm32f103c8tx_flash.ld -nostartfiles -Wl,-e,Reset_Handler -Wl,--gc-sections --specs=nano.specs --specs=nosys.specs

.PHONY: all clean

all: $(TARGET).elf

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/main_faulty.o: main_faulty.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/clock.o: ../../src/clock.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/gpio.o: ../../src/gpio.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/timer_rmw.o: timer_rmw.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/system.o: ../../src/system_stm32f1xx.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/runtime_glue.o: ../../src/runtime_glue.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/startup.o: ../../src/startup_stm32f103c8.s | $(BUILD_DIR)
	$(CC) $(MCU_FLAGS) -g3 -c $< -o $@

$(TARGET).elf: $(BUILD_DIR)/main_faulty.o $(BUILD_DIR)/clock.o $(BUILD_DIR)/gpio.o $(BUILD_DIR)/timer_rmw.o $(BUILD_DIR)/system.o $(BUILD_DIR)/runtime_glue.o $(BUILD_DIR)/startup.o
	$(CC) $^ $(LDFLAGS) -o $@
	$(SIZE) $@

clean:
	rm -rf $(BUILD_DIR)
