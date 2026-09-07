# ==============================================================================
# Makefile: Part A — Bare-Metal Startup & Linker Reasoning
# Target: STM32F103C8T6 (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM)
# ==============================================================================

CC      := arm-none-eabi-gcc
SIZE    := arm-none-eabi-size
READELF := arm-none-eabi-readelf
NM      := arm-none-eabi-nm
OBJDUMP := arm-none-eabi-objdump

BUILD_DIR := build
TARGET    := $(BUILD_DIR)/firmware

ROOT_DIR  := ../../..
CMSIS_DIR := $(ROOT_DIR)/fundamentals/mcu/vendor/cmsis

MCU_FLAGS := -mcpu=cortex-m3 -mthumb -mfloat-abi=soft
CFLAGS    := $(MCU_FLAGS) -O2 -g3 -Wall -Wextra -Werror \
             -ffunction-sections -fdata-sections -MMD -MP \
             -DSTM32F103xB -Iinclude -I$(CMSIS_DIR)/include
ASFLAGS   := $(MCU_FLAGS) -g3

LINKER_SCRIPT := linker/stm32f103c8tx_flash.ld
LDFLAGS   := $(MCU_FLAGS) -T$(LINKER_SCRIPT) \
             -nostartfiles \
             -Wl,-e,Reset_Handler \
             -Wl,--gc-sections \
             -Wl,-Map=$(TARGET).map,--cref \
             --specs=nano.specs --specs=nosys.specs

C_SOURCES := src/main.c \
             src/preinit_constructor.c \
             src/system_stm32f1xx.c \
             src/runtime_glue.c

ASM_SOURCES := src/startup_stm32f103c8.s

OBJS := $(addprefix $(BUILD_DIR)/, $(C_SOURCES:.c=.o)) \
        $(addprefix $(BUILD_DIR)/, $(ASM_SOURCES:.s=.o))
DEPS := $(OBJS:.o=.d)

.PHONY: all clean check size disasm

all: $(TARGET).elf $(TARGET).asm size

$(BUILD_DIR)/src:
	mkdir -p $(BUILD_DIR)/src

$(BUILD_DIR)/src/%.o: src/%.c | $(BUILD_DIR)/src
	@echo "[CC] $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/src/%.o: src/%.s | $(BUILD_DIR)/src
	@echo "[AS] $<"
	$(CC) $(ASFLAGS) -c $< -o $@

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

check: $(TARGET).elf
	@echo "=== Verifying Part A Firmware Linker Contract ==="
	@if [ ! -f "$(TARGET).elf" ]; then \
		echo "[FAIL] $(TARGET).elf does not exist"; exit 1; \
	fi
	@INIT_SIZE=$$($(READELF) -W -S $(TARGET).elf | grep -E '\.init_array' | awk '{print $$7}'); \
	if [ -z "$$INIT_SIZE" ] || [ "$$INIT_SIZE" = "000000" ] || [ "$$INIT_SIZE" = "00000000" ]; then \
		echo "[FAIL] .init_array section size is 0! Pre-main constructor functions were discarded by linker --gc-sections."; \
		echo "       Inspect linker/stm32f103c8tx_flash.ld and section retention directives."; \
		exit 1; \
	else \
		echo "[PASS] .init_array section size is $$INIT_SIZE bytes (constructors retained)."; \
	fi
	@if ! $(NM) $(TARGET).elf | grep -q "system_peripheral_preinit"; then \
		echo "[FAIL] Symbol 'system_peripheral_preinit' was discarded from ELF!"; \
		exit 1; \
	else \
		echo "[PASS] Constructor symbol 'system_peripheral_preinit' present in ELF."; \
	fi
	@echo "=== Part A Verification Complete ==="

-include $(DEPS)
