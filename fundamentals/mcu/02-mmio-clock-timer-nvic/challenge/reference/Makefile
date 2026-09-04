CC      := arm-none-eabi-gcc
OBJCOPY := arm-none-eabi-objcopy
SIZE    := arm-none-eabi-size

BUILD_DIR := build
TARGET    := $(BUILD_DIR)/firmware

MCU_FLAGS := -mcpu=cortex-m3 -mthumb -mfloat-abi=soft
CFLAGS    := $(MCU_FLAGS) -O2 -g3 -Wall -Wextra -Werror -ffunction-sections -fdata-sections -MMD -MP -DSTM32F103xB
INCLUDES  := -I. -I../../include -I../../../vendor/cmsis/include
LDFLAGS   := $(MCU_FLAGS) -T../../linker/stm32f103c8tx_flash.ld -nostartfiles -Wl,-e,Reset_Handler -Wl,--gc-sections -Wl,-Map=$(TARGET).map,--cref --specs=nano.specs --specs=nosys.specs

SRCS_C := main.c pwm.c ../../src/clock.c ../../src/system_stm32f1xx.c ../../src/runtime_glue.c
SRCS_S := ../../src/startup_stm32f103c8.s

OBJS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(notdir $(SRCS_C))) \
        $(patsubst %.s,$(BUILD_DIR)/%.o,$(notdir $(SRCS_S)))

DEPS := $(OBJS:.o=.d)

.PHONY: all clean

all: $(TARGET).elf

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/main.o: main.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/pwm.o: pwm.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/clock.o: ../../src/clock.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/system_stm32f1xx.o: ../../src/system_stm32f1xx.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/runtime_glue.o: ../../src/runtime_glue.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/startup_stm32f103c8.o: ../../src/startup_stm32f103c8.s | $(BUILD_DIR)
	$(CC) $(MCU_FLAGS) -g3 -c $< -o $@

$(TARGET).elf: $(OBJS)
	$(CC) $(OBJS) $(LDFLAGS) -o $@
	$(SIZE) $@

clean:
	rm -rf $(BUILD_DIR)

-include $(DEPS)
