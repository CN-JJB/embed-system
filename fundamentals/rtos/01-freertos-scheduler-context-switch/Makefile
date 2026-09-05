CC      := arm-none-eabi-gcc
OBJCOPY := arm-none-eabi-objcopy
OBJDUMP := arm-none-eabi-objdump
SIZE    := arm-none-eabi-size

BUILD_DIR := build
TARGET    := $(BUILD_DIR)/firmware

MCU_FLAGS := -mcpu=cortex-m3 -mthumb -mfloat-abi=soft
CFLAGS    := $(MCU_FLAGS) -O2 -g3 -Wall -Wextra -Werror -ffunction-sections -fdata-sections -MMD -MP -DSTM32F103xB
INCLUDES  := -Iinclude \
             -I../vendor/freertos/include \
             -I../vendor/freertos/portable/GCC/ARM_CM3 \
             -I../../mcu/vendor/cmsis/include
ASFLAGS   := $(MCU_FLAGS) -g3

LINKER_SCRIPT := linker/stm32f103c8tx_flash.ld
LDFLAGS   := $(MCU_FLAGS) -T$(LINKER_SCRIPT) -nostartfiles -Wl,-e,Reset_Handler -Wl,--gc-sections -Wl,-Map=$(TARGET).map,--cref --specs=nano.specs --specs=nosys.specs

C_SOURCES := src/main.c \
             src/clock.c \
             src/gpio.c \
             src/system_stm32f1xx.c \
             src/runtime_glue.c \
             ../vendor/freertos/tasks.c \
             ../vendor/freertos/list.c \
             ../vendor/freertos/queue.c \
             ../vendor/freertos/portable/GCC/ARM_CM3/port.c \
             ../vendor/freertos/portable/MemMang/heap_4.c

ASM_SOURCES := src/startup_stm32f103c8.s

# Object mapping
APP_OBJS := $(addprefix $(BUILD_DIR)/, $(filter src/%.o, $(C_SOURCES:.c=.o))) \
            $(addprefix $(BUILD_DIR)/, $(ASM_SOURCES:.s=.o))
RTOS_OBJS := $(BUILD_DIR)/freertos/tasks.o \
             $(BUILD_DIR)/freertos/list.o \
             $(BUILD_DIR)/freertos/queue.o \
             $(BUILD_DIR)/freertos/port.o \
             $(BUILD_DIR)/freertos/heap_4.o

OBJS := $(APP_OBJS) $(RTOS_OBJS)
DEPS := $(OBJS:.o=.d)

.PHONY: all clean check disasm size

all: $(TARGET).elf $(TARGET).bin $(TARGET).hex $(TARGET).asm size

$(BUILD_DIR)/src:
	mkdir -p $(BUILD_DIR)/src

$(BUILD_DIR)/freertos:
	mkdir -p $(BUILD_DIR)/freertos

$(BUILD_DIR)/src/%.o: src/%.c | $(BUILD_DIR)/src
	@echo "[CC] $<"
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/src/%.o: src/%.s | $(BUILD_DIR)/src
	@echo "[AS] $<"
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD_DIR)/freertos/tasks.o: ../vendor/freertos/tasks.c | $(BUILD_DIR)/freertos
	@echo "[CC] $<"
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/freertos/list.o: ../vendor/freertos/list.c | $(BUILD_DIR)/freertos
	@echo "[CC] $<"
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/freertos/queue.o: ../vendor/freertos/queue.c | $(BUILD_DIR)/freertos
	@echo "[CC] $<"
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/freertos/port.o: ../vendor/freertos/portable/GCC/ARM_CM3/port.c | $(BUILD_DIR)/freertos
	@echo "[CC] $<"
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/freertos/heap_4.o: ../vendor/freertos/portable/MemMang/heap_4.c | $(BUILD_DIR)/freertos
	@echo "[CC] $<"
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(TARGET).elf: $(OBJS) $(LINKER_SCRIPT)
	@echo "[LD] $@"
	$(CC) $(OBJS) $(LDFLAGS) -o $@

$(TARGET).bin: $(TARGET).elf
	@echo "[OBJCOPY] $@"
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).elf
	@echo "[OBJCOPY] $@"
	$(OBJCOPY) -O ihex $< $@

$(TARGET).asm: $(TARGET).elf
	@echo "[OBJDUMP] $@"
	$(OBJDUMP) -d -S $< > $@

size: $(TARGET).elf
	@echo "=== M04 FreeRTOS Firmware Footprint ==="
	$(SIZE) $<

disasm: $(TARGET).asm

check: $(TARGET).elf
	@bash scripts/verify_m04.sh

clean:
	rm -rf $(BUILD_DIR)

-include $(DEPS)
