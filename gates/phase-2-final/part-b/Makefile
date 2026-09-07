# ==============================================================================
# Makefile: Part B — Peripheral Register & DMA Data-Path Diagnosis
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
             src/clock.c \
             src/gpio.c \
             src/timer.c \
             src/adc.c \
             src/dma.c \
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

check: $(TARGET).elf $(TARGET).asm
	@echo "=== Verifying Part B Peripheral & DMA Contract ==="
	@if [ ! -f "$(TARGET).elf" ]; then \
		echo "[FAIL] $(TARGET).elf does not exist"; exit 1; \
	fi
	@if ! $(NM) $(TARGET).elf | grep -q "dma1_channel1_init"; then \
		echo "[FAIL] Missing symbol 'dma1_channel1_init'"; exit 1; \
	fi
	@if ! $(NM) $(TARGET).elf | grep -q "g_adc_buffer"; then \
		echo "[FAIL] Missing symbol 'g_adc_buffer'"; exit 1; \
	fi
	@# Check that DMA1 Channel 1 CCR configuration enables circular mode (DMA_CCR_CIRC = bit 5 = 0x20)
	@# In disasm of dma1_channel1_init, CCR value without CIRC is 0x58e; with CIRC is 0x5ae.
	@if $(OBJDUMP) -d $(TARGET).elf | grep -A 35 "<dma1_channel1_init>:" | grep -Eq "#1422|0x58e"; then \
		echo "[FAIL] DMA1_Channel1->CCR does not enable circular mode (DMA_CCR_CIRC)!"; \
		echo "       Value 0x58e lacks bit 5 (0x20). Continuous acquisition halts after 128 samples."; \
		exit 1; \
	elif ! $(OBJDUMP) -d $(TARGET).elf | grep -A 35 "<dma1_channel1_init>:" | grep -Eq "#1454|0x5ae"; then \
		echo "[FAIL] DMA1_Channel1->CCR missing expected circular configuration (0x5ae / bit 5)!"; \
		exit 1; \
	else \
		echo "[PASS] DMA1_Channel1->CCR enables circular mode (CIRC: 0x5ae), MINC, and interrupts."; \
	fi
	@echo "=== Part B Verification Complete ==="

-include $(DEPS)
