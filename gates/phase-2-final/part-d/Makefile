# ==============================================================================
# Makefile: Part D — Concurrency, Priority Inversion & HW/SW Debugging
# Target: STM32F103C8T6 (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM)
# ==============================================================================

CC      := arm-none-eabi-gcc
SIZE    := arm-none-eabi-size
READELF := arm-none-eabi-readelf
NM      := arm-none-eabi-nm
OBJDUMP := arm-none-eabi-objdump

BUILD_DIR := build
TARGET    := $(BUILD_DIR)/firmware

ROOT_DIR     := ../../..
FREERTOS_DIR := $(ROOT_DIR)/fundamentals/rtos/vendor/freertos
CMSIS_DIR    := $(ROOT_DIR)/fundamentals/mcu/vendor/cmsis

MCU_FLAGS := -mcpu=cortex-m3 -mthumb -mfloat-abi=soft
CFLAGS    := $(MCU_FLAGS) -O2 -g3 -Wall -Wextra -Werror \
             -ffunction-sections -fdata-sections -MMD -MP \
             -DSTM32F103xB
ASFLAGS   := $(MCU_FLAGS) -g3

INCLUDES  := -Iinclude \
             -I$(FREERTOS_DIR)/include \
             -I$(FREERTOS_DIR)/portable/GCC/ARM_CM3 \
             -I$(CMSIS_DIR)/include

LINKER_SCRIPT := linker/stm32f103c8tx_flash.ld
LDFLAGS   := $(MCU_FLAGS) -T$(LINKER_SCRIPT) \
             -nostartfiles \
             -Wl,-e,Reset_Handler \
             -Wl,--gc-sections \
             -Wl,-Map=$(TARGET).map,--cref \
             --specs=nano.specs --specs=nosys.specs

C_SOURCES := src/main.c \
             src/node_app.c \
             src/system_stm32f1xx.c \
             src/runtime_glue.c

ASM_SOURCES := src/startup_stm32f103c8.s

APP_OBJS := $(addprefix $(BUILD_DIR)/, $(C_SOURCES:.c=.o)) \
            $(addprefix $(BUILD_DIR)/, $(ASM_SOURCES:.s=.o))
RTOS_OBJS := $(BUILD_DIR)/freertos/tasks.o \
             $(BUILD_DIR)/freertos/list.o \
             $(BUILD_DIR)/freertos/queue.o \
             $(BUILD_DIR)/freertos/port.o \
             $(BUILD_DIR)/freertos/heap_4.o

OBJS := $(APP_OBJS) $(RTOS_OBJS)
DEPS := $(OBJS:.o=.d)

.PHONY: all clean check size disasm

all: $(TARGET).elf $(TARGET).asm size

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

$(BUILD_DIR)/freertos/%.o: $(FREERTOS_DIR)/%.c | $(BUILD_DIR)/freertos
	@echo "[CC] $<"
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/freertos/%.o: $(FREERTOS_DIR)/portable/GCC/ARM_CM3/%.c | $(BUILD_DIR)/freertos
	@echo "[CC] $<"
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/freertos/%.o: $(FREERTOS_DIR)/portable/MemMang/%.c | $(BUILD_DIR)/freertos
	@echo "[CC] $<"
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(TARGET).elf: $(OBJS) $(LINKER_SCRIPT)
	@echo "[LD] $@"
	$(CC) $(OBJS) $(LDFLAGS) -o $@

$(TARGET).asm: $(TARGET).elf
	@echo "[OBJDUMP] $@"
	$(OBJDUMP) -d -S $< > $@

size: $(TARGET).elf
	@echo "=== Firmware Size ==="
	$(SIZE) $<

clean:
	rm -rf $(BUILD_DIR)

check: $(TARGET).elf $(TARGET).asm
	@echo "=== Verifying Part D Firmware Artifact Integrity ==="
	@python3 scripts/check_artifact.py $(TARGET).elf $(READELF) $(NM)
	@echo "=== Part D Verification Complete ==="

-include $(DEPS)
