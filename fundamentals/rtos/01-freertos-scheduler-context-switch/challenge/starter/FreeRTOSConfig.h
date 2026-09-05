#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

#include <stdint.h>

/* =============================================================================
 * Core Architecture & Clock Settings
 * =============================================================================
 */
#define configUSE_PREEMPTION                    1
#define configUSE_TIME_SLICING                  1
#define configUSE_PORT_OPTIMISED_TASK_SELECTION 0

/*
 * Dynamic Core Clock Coherence:
 * SystemCoreClock is updated by course clock_init() to reflect either
 * 72 MHz HSE primary profile or 64 MHz HSI fallback profile.
 *
 * TODO: Configure configCPU_CLOCK_HZ to dynamically evaluate SystemCoreClock
 * to prevent clock drift across fallback transitions.
 */
extern uint32_t SystemCoreClock;
#define configCPU_CLOCK_HZ                      72000000UL /* TODO: Use dynamic (SystemCoreClock) */
#define configTICK_RATE_HZ                      ((TickType_t)1000)
#define configMAX_PRIORITIES                    (5)
#define configMINIMAL_STACK_SIZE                ((uint16_t)128)
#define configMAX_TASK_NAME_LEN                 (16)
#define configUSE_16_BIT_TICKS                  0
#define configIDLE_SHOULD_YIELD                 1
#define configUSE_TASK_NOTIFICATIONS            1

/* =============================================================================
 * Memory Allocation & Heap Settings (heap_4 Exclusivity)
 * =============================================================================
 */
#define configSUPPORT_STATIC_ALLOCATION         0
#define configSUPPORT_DYNAMIC_ALLOCATION        1
#define configAPPLICATION_ALLOCATED_HEAP        0

/*
 * TODO: Configure configTOTAL_HEAP_SIZE for FreeRTOS heap_4.
 * Must fit safely within 20 KB SRAM while accommodating dual tasks and idle task.
 */
#define configTOTAL_HEAP_SIZE                   ((size_t)(10 * 1024))

/* =============================================================================
 * Hook Functions & Diagnostics
 * =============================================================================
 */
#define configUSE_IDLE_HOOK                     0
#define configUSE_TICK_HOOK                     0
#define configCHECK_FOR_STACK_OVERFLOW          0
#define configUSE_MALLOC_FAILED_HOOK            1

/* Course deterministic assertion handler */
void vAssertCalled(const char *pcFile, unsigned long ulLine);
#define configASSERT(x)                         do { if ((x) == 0) { vAssertCalled(__FILE__, __LINE__); } } while (0)

/* =============================================================================
 * Synchronization Primitives (Reserved for P2-M05 / M06)
 * =============================================================================
 */
#define configUSE_MUTEXES                       0
#define configUSE_RECURSIVE_MUTEXES             0
#define configUSE_COUNTING_SEMAPHORES           0
#define configQUEUE_REGISTRY_SIZE               0

/* =============================================================================
 * Cortex-M3 Interrupt Priority Configuration (STM32F103)
 * =============================================================================
 */
#ifdef __NVIC_PRIO_BITS
    #define configPRIO_BITS                     __NVIC_PRIO_BITS
#else
    #define configPRIO_BITS                     4
#endif

/* Lowest interrupt priority (15 for 4-bit priority) */
#define configLIBRARY_LOWEST_INTERRUPT_PRIORITY         15

/* Maximum interrupt priority from which FreeRTOS API calls can be made */
#define configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY    5

/*
 * TODO: Configure configKERNEL_INTERRUPT_PRIORITY to the lowest implemented
 * interrupt priority (0xF0 / 255) shifted for Cortex-M3 NVIC bit alignment.
 */
#define configKERNEL_INTERRUPT_PRIORITY         0 /* TODO: Configure lowest priority (configLIBRARY_LOWEST_INTERRUPT_PRIORITY << (8 - configPRIO_BITS)) */

#define configMAX_SYSCALL_INTERRUPT_PRIORITY \
    (configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))

/* =============================================================================
 * Exception Handler Mapping to Vector Table
 * =============================================================================
 *
 * TODO: Map standard FreeRTOS Cortex-M port handlers to course startup vector symbols:
 *   vPortSVCHandler     -> SVC_Handler
 *   xPortPendSVHandler  -> PendSV_Handler
 *   xPortSysTickHandler -> SysTick_Handler
 */
#define vPortSVCHandler                         vPortSVCHandler   /* TODO: Map to SVC_Handler */
#define xPortPendSVHandler                      xPortPendSVHandler/* TODO: Map to PendSV_Handler */
#define xPortSysTickHandler                     xPortSysTickHandler/* TODO: Map to SysTick_Handler */

/* =============================================================================
 * FreeRTOS API Function Inclusions
 * =============================================================================
 */
#define INCLUDE_vTaskPrioritySet                1
#define INCLUDE_uxTaskPriorityGet               1
#define INCLUDE_vTaskDelete                     1
#define INCLUDE_vTaskCleanUpResources           0
#define INCLUDE_vTaskSuspend                    1
#define INCLUDE_vTaskDelayUntil                 1
#define INCLUDE_vTaskDelay                      1
#define INCLUDE_uxTaskGetStackHighWaterMark     1
#define INCLUDE_xTaskGetSchedulerState          1

#endif /* FREERTOS_CONFIG_H */
