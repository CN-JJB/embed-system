CC      := arm-none-eabi-gcc
SIZE    := arm-none-eabi-size

BUILD_DIR := build
TARGET    := $(BUILD_DIR)/firmware

MCU_FLAGS := -mcpu=cortex-m3 -mthumb -mfloat-abi=soft
CFLAGS    := $(MCU_FLAGS) -O2 -g3 -Wall -Wextra -Werror -ffunction-sections -fdata-sections -DSTM32F103xB
INCLUDES  := -I../../include -I../../../vendor/cmsis/include
LDFLAGS   := $(MCU_FLAGS) -Tlinker_faulty.ld -nostartfiles -Wl,-e,Reset_Handler -Wl,--gc-sections -Wl,-Map=$(TARGET).map,--cref --specs=nano.specs --specs=nosys.specs

.PHONY: all clean

all: $(TARGET).elf

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: ../../src/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/startup.o: ../../src/startup_stm32f103c8.s | $(BUILD_DIR)
	$(CC) $(MCU_FLAGS) -g3 -c $< -o $@

$(TARGET).elf: $(BUILD_DIR)/main.o $(BUILD_DIR)/system_stm32f1xx.o $(BUILD_DIR)/runtime_glue.o $(BUILD_DIR)/startup.o
	$(CC) $^ $(LDFLAGS) -o $@
	$(SIZE) $@

clean:
	rm -rf $(BUILD_DIR)
