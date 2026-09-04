# ==============================================================================
# Makefile for Module P2-M01: Reset, Startup, Linker Script, and Vector Table
# ==============================================================================
# Toolchain Baseline: Arm GNU Toolchain (arm-none-eabi-gcc 13.x / binutils 2.42)
# Runtime Contract: Preferred Policy A (-nostartfiles, Reset_Handler entry)
# ==============================================================================

CC      := arm-none-eabi-gcc
OBJCOPY := arm-none-eabi-objcopy
OBJDUMP := arm-none-eabi-objdump
SIZE    := arm-none-eabi-size
READELF := arm-none-eabi-readelf
NM      := arm-none-eabi-nm

BUILD_DIR := build
TARGET    := $(BUILD_DIR)/firmware

# Target MCU Architecture
MCU_FLAGS := -mcpu=cortex-m3 -mthumb -mfloat-abi=soft

# Compiler Warning and Feature Flags
CFLAGS := $(MCU_FLAGS) \
          -O2 -g3 \
          -Wall -Wextra -Werror \
          -ffunction-sections -fdata-sections \
          -MMD -MP \
          -DSTM32F103xB

# Include Directories
INCLUDES := -Iinclude \
            -I../vendor/cmsis/include

# Assembler Flags
ASFLAGS := $(MCU_FLAGS) -g3

# Linker Configuration
LINKER_SCRIPT := linker/stm32f103c8tx_flash.ld
LDFLAGS := $(MCU_FLAGS) \
           -T$(LINKER_SCRIPT) \
           -nostartfiles \
           -Wl,-e,Reset_Handler \
           -Wl,--gc-sections \
           -Wl,-Map=$(TARGET).map,--cref \
           --specs=nano.specs \
           --specs=nosys.specs

# Sources
C_SOURCES := src/main.c \
             src/system_stm32f1xx.c \
             src/runtime_glue.c

ASM_SOURCES := src/startup_stm32f103c8.s

# Object files
OBJS := $(addprefix $(BUILD_DIR)/, $(C_SOURCES:.c=.o)) \
        $(addprefix $(BUILD_DIR)/, $(ASM_SOURCES:.s=.o))

# Dependencies
DEPS := $(OBJS:.o=.d)

.PHONY: all clean check disasm

all: $(TARGET).elf $(TARGET).bin $(TARGET).hex $(TARGET).asm size

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)/src

$(BUILD_DIR)/src/%.o: src/%.c | $(BUILD_DIR)
	@echo "[CC] $<"
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/src/%.o: src/%.s | $(BUILD_DIR)
	@echo "[AS] $<"
	$(CC) $(ASFLAGS) -c $< -o $@

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
	@echo "=== Firmware Memory Footprint ==="
	$(SIZE) $<

disasm: $(TARGET).asm

check: $(TARGET).elf
	@bash scripts/verify_m01.sh

clean:
	rm -rf $(BUILD_DIR)

-include $(DEPS)
