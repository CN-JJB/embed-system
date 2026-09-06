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
src_timer_c = read_file(os.path.join(base_dir, "src/timer.c"))
src_dma_h = read_file(os.path.join(base_dir, "include/dma.h"))

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

# mut29_timer_started_before_diag
old_m29 = """    if (!s_diag_completed) {
        prvRunDiagnosticComparison();
        s_diag_completed = true;

        /* Establish post-scheduler steady-state heap baseline */
        g_steady_free_heap = xPortGetFreeHeapSize();
        g_steady_min_ever_heap = xPortGetMinimumEverFreeHeapSize();

        /* Start TIM3 hardware trigger to begin regular acquisition */
        tim3_trgo_start();
    }"""
new_m29 = """    if (!s_diag_completed) {
        tim3_trgo_start();
        prvRunDiagnosticComparison();
        s_diag_completed = true;

        /* Establish post-scheduler steady-state heap baseline */
        g_steady_free_heap = xPortGetFreeHeapSize();
        g_steady_min_ever_heap = xPortGetMinimumEverFreeHeapSize();
    }"""
m29_c = src_node_c.replace(old_m29, new_m29)
write_file(os.path.join(mut_dir, "mut29_timer_started_before_diag/node_app.c"), m29_c)

# mut30_timer_ug_trgo_leak_before_diag
old_m30 = """    TIM3->CR2 &= ~TIM_CR2_MMS;

    /* 4. Generate an update event to pre-load PSC and ARR shadow registers */
    TIM3->EGR = TIM_EGR_UG;"""
new_m30 = """    TIM3->CR2 &= ~TIM_CR2_MMS;
    TIM3->CR2 |= TIM_CR2_MMS_1;

    /* 4. Generate an update event to pre-load PSC and ARR shadow registers */
    TIM3->EGR = TIM_EGR_UG;"""
m30_c = src_timer_c.replace(old_m30, new_m30)
write_file(os.path.join(mut_dir, "mut30_timer_ug_trgo_leak_before_diag/timer.c"), m30_c)

# mut31_mutex_after_sample_loop
old_m31 = """                /* Send record to log queue with zero timeout to avoid blocking fast path */
                if (xQueueSend(xLogQueue, &record, 0) != pdPASS) {
                    g_log_drops++;
                }
            }
        }
    }"""
new_m31 = """                /* Send record to log queue with zero timeout to avoid blocking fast path */
                if (xQueueSend(xLogQueue, &record, 0) != pdPASS) {
                    g_log_drops++;
                }
                xSemaphoreTake(g_diag_resource, portMAX_DELAY);
                xSemaphoreGive(g_diag_resource);
            }
        }
    }"""
m31_c = src_node_c.replace(old_m31, new_m31)
write_file(os.path.join(mut_dir, "mut31_mutex_after_sample_loop/node_app.c"), m31_c)

# mut32_dma_tc_drops_ignored
old_m32 = """        if (xAcqQueue != NULL) {
            BaseType_t xResult = xQueueSendFromISR(xAcqQueue, &msg, &xHigherPriorityTaskWoken);
            if (xResult == pdPASS) {
                g_dma_tc_count++;
                g_acq_transfers++;
            } else {
                g_acq_drops++;
            }
        }"""
new_m32 = """        if (xAcqQueue != NULL) {
            BaseType_t xResult = xQueueSendFromISR(xAcqQueue, &msg, &xHigherPriorityTaskWoken);
            if (xResult == pdPASS) {
                g_dma_tc_count++;
                g_acq_transfers++;
            } else {
                /* drop ignored */
            }
        }"""
assert old_m32 in src_dma_c, "mut32 target not found in src/dma.c"
m32_c = src_dma_c.replace(old_m32, new_m32)
write_file(os.path.join(mut_dir, "mut32_dma_tc_drops_ignored/dma.c"), m32_c)

# mut33_adc_smp0_all_ones
assert "ADC1->SMPR2 |= (ADC_SMPR2_SMP0_0 | ADC_SMPR2_SMP0_2);" in src_adc_c
m33_c = src_adc_c.replace(
    "ADC1->SMPR2 |= (ADC_SMPR2_SMP0_0 | ADC_SMPR2_SMP0_2);",
    "ADC1->SMPR2 |= (ADC_SMPR2_SMP0_0 | ADC_SMPR2_SMP0_1 | ADC_SMPR2_SMP0_2);"
)
write_file(os.path.join(mut_dir, "mut33_adc_smp0_all_ones/adc.c"), m33_c)

# mut34_dma_32bit_width
old_m34 = """    DMA1_Channel1->CCR = DMA_CCR_CIRC |
                         DMA_CCR_MINC |
                         DMA_CCR_PSIZE_0 |
                         DMA_CCR_MSIZE_0 |"""
new_m34 = """    DMA1_Channel1->CCR = DMA_CCR_CIRC |
                         DMA_CCR_MINC |
                         DMA_CCR_PSIZE_1 |
                         DMA_CCR_MSIZE_1 |"""
assert old_m34 in src_dma_c, "mut34 target not found in src/dma.c"
m34_c = src_dma_c.replace(old_m34, new_m34)
write_file(os.path.join(mut_dir, "mut34_dma_32bit_width/dma.c"), m34_c)

# mut35_dma_cndtr_wrong_size
old_m35 = "#define ADC_BUFFER_TOTAL_SIZE   (ADC_BUFFER_HALF_SIZE * 2U)"
new_m35 = "#define ADC_BUFFER_TOTAL_SIZE   256U"
assert old_m35 in src_dma_h, "mut35 target not found in include/dma.h"
m35_h = src_dma_h.replace(old_m35, new_m35)
write_file(os.path.join(mut_dir, "mut35_dma_cndtr_wrong_size/dma.h"), m35_h)

# mut36_adc1_init_unchecked
old_m36 = """    /* 8. Initialize ADC1 with TIM3 TRGO hardware trigger and DMA request */
    if (adc1_init(freqs.pclk2_hz) != ADC_INIT_OK) {
        __disable_irq();
        for (;;) {
            __NOP();
        }
    }"""
new_m36 = """    /* 8. Initialize ADC1 with TIM3 TRGO hardware trigger and DMA request */
    adc1_init(freqs.pclk2_hz);"""
m36_c = src_main_c.replace(old_m36, new_m36)
write_file(os.path.join(mut_dir, "mut36_adc1_init_unchecked/main.c"), m36_c)

# mut37_source_pin_prefix_only
m37_md = src_ledger_md.replace(
    "9b777ae5c5b8e9e456065a00294d1e5f5f9facf5",
    "9b777ae5ffffffffffffffffffffffffffffffff"
)
write_file(os.path.join(mut_dir, "mut37_source_pin_prefix_only/SOURCE_LEDGER.md"), m37_md)

# mut38_clock_hsi_unconditional_outside_fallback
old_m38 = """    if (!clock_init(CLOCK_PROFILE_72MHZ_HSE)) {
        if (!clock_init(CLOCK_PROFILE_64MHZ_HSI)) {
            __disable_irq();
            for (;;) {
                __NOP();
            }
        }
    }"""
new_m38 = """    if (!clock_init(CLOCK_PROFILE_72MHZ_HSE)) {
        __disable_irq();
        for (;;) {
            __NOP();
        }
    }
    clock_init(CLOCK_PROFILE_64MHZ_HSI);"""
m38_c = src_main_c.replace(old_m38, new_m38)
write_file(os.path.join(mut_dir, "mut38_clock_hsi_unconditional_outside_fallback/main.c"), m38_c)

print("Mutations 17 through 38 generated successfully.")
