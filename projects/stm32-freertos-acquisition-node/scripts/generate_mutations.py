import os, shutil

base_dir = "projects/stm32-freertos-acquisition-node"
mut_dir = os.path.join(base_dir, "reviewer/mutations")

def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

src_node_c = read_file(os.path.join(base_dir, "src/node_app.c"))
src_node_h = read_file(os.path.join(base_dir, "include/node_app.h"))
src_dma_c = read_file(os.path.join(base_dir, "src/dma.c"))
src_adc_c = read_file(os.path.join(base_dir, "src/adc.c"))
src_usart_c = read_file(os.path.join(base_dir, "src/usart.c"))
src_main_c = read_file(os.path.join(base_dir, "src/main.c"))
src_ledger_md = read_file(os.path.join(base_dir, "SOURCE_LEDGER.md"))

# mut17_decoy_task_priorities
m17_h = src_node_h.replace("#define TASK_PROCESS_PRIORITY   3", "#define TASK_PROCESS_PRIORITY   2")
write_file(os.path.join(mut_dir, "mut17_decoy_task_priorities/node_app.h"), m17_h)

# mut18_mutex_in_sample_loop
m18_c = src_node_c.replace(
    "if (xQueueReceive(xAcqQueue, &msg, portMAX_DELAY) == pdPASS) {",
    "if (xQueueReceive(xAcqQueue, &msg, portMAX_DELAY) == pdPASS) {\n            xSemaphoreTake(g_diag_sem, portMAX_DELAY);\n            xSemaphoreGive(g_diag_sem);"
)
write_file(os.path.join(mut_dir, "mut18_mutex_in_sample_loop/node_app.c"), m18_c)

# mut19_iwdg_bypasses_stack_heap_gate
m19_c = src_node_c.replace(
    "if (progress_ok && stack_ok && heap_ok) {",
    "if (progress_ok) {"
)
write_file(os.path.join(mut_dir, "mut19_iwdg_bypasses_stack_heap_gate/node_app.c"), m19_c)

# mut20_dma_wake_flag_set_true_before_send
m20_c = src_dma_c.replace(
    "BaseType_t xResult = xQueueSendFromISR(xAcqQueue, &msg, &xHigherPriorityTaskWoken);",
    "xHigherPriorityTaskWoken = pdTRUE;\n            BaseType_t xResult = xQueueSendFromISR(xAcqQueue, &msg, &xHigherPriorityTaskWoken);"
)
write_file(os.path.join(mut_dir, "mut20_dma_wake_flag_set_true_before_send/dma.c"), m20_c)

# mut21_acq_drops_unconditional
m21_c = src_dma_c.replace(
    "if (xResult == pdPASS) {\n                g_dma_ht_count++;",
    "if (xResult == pdPASS) {\n                g_acq_drops++;\n                g_dma_ht_count++;"
)
write_file(os.path.join(mut_dir, "mut21_acq_drops_unconditional/dma.c"), m21_c)

# mut22_dma_ht_tc_swapped
m22_c = src_dma_c.replace(
    "msg.buffer_index = 0;",
    "msg.buffer_index = 1;"
)
write_file(os.path.join(mut_dir, "mut22_dma_ht_tc_swapped/dma.c"), m22_c)

# mut23_adc_unbounded_cal
old_cal = """    ADC1->CR2 |= ADC_CR2_CAL;
    timeout = ADC_CAL_TIMEOUT;
    while ((ADC1->CR2 & ADC_CR2_CAL) != 0) {
        if (--timeout == 0) {
            return ADC_INIT_ERR_CAL_TIMEOUT;
        }
    }"""
new_cal = """    ADC1->CR2 |= ADC_CR2_CAL;
    while ((ADC1->CR2 & ADC_CR2_CAL) != 0) {
        __NOP();
    }"""
m23_c = src_adc_c.replace(old_cal, new_cal)
write_file(os.path.join(mut_dir, "mut23_adc_unbounded_cal/adc.c"), m23_c)

# mut24_dma_missing_htie
m24_c = src_dma_c.replace("DMA_CCR_HTIE |", "")
write_file(os.path.join(mut_dir, "mut24_dma_missing_htie/dma.c"), m24_c)

# mut25_usart_hardcoded_72mhz
m25_c = src_usart_c.replace(
    "USART1->BRR = (pclk2_hz + (baud / 2U)) / baud;",
    "USART1->BRR = (72000000U + (baud / 2U)) / baud;"
)
write_file(os.path.join(mut_dir, "mut25_usart_hardcoded_72mhz/usart.c"), m25_c)

# mut26_clock_no_hsi_fallback
old_clk = """    if (!clock_init(CLOCK_PROFILE_72MHZ_HSE)) {
        if (!clock_init(CLOCK_PROFILE_64MHZ_HSI)) {
            __disable_irq();
            for (;;) {
                __NOP();
            }
        }
    }"""
new_clk = """    clock_init(CLOCK_PROFILE_72MHZ_HSE);"""
m26_c = src_main_c.replace(old_clk, new_clk)
write_file(os.path.join(mut_dir, "mut26_clock_no_hsi_fallback/main.c"), m26_c)

# mut27_source_pin_mismatch
m27_md = src_ledger_md.replace("9b777ae5", "ffffffff")
write_file(os.path.join(mut_dir, "mut27_source_pin_mismatch/SOURCE_LEDGER.md"), m27_md)

# mut28_iwdg_init_unchecked
old_iwdg = """    if (!iwdg_init(IWDG_PRESCALER_32, 1250)) {
        __disable_irq();
        for (;;) {
            __NOP();
        }
    }"""
new_iwdg = """    iwdg_init(IWDG_PRESCALER_32, 1250);"""
m28_c = src_main_c.replace(old_iwdg, new_iwdg)
write_file(os.path.join(mut_dir, "mut28_iwdg_init_unchecked/main.c"), m28_c)

print("Mutations 17 through 28 generated successfully.")
