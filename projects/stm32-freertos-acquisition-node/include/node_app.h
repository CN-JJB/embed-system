#ifndef NODE_APP_H
#define NODE_APP_H

#include <stdint.h>
#include <stdbool.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "telemetry.h"
#include "dma.h"

/* Canonical task priority hierarchy */
#define TASK_PROCESS_PRIORITY   3
#define TASK_COMM_PRIORITY      2
#define TASK_COMPUTE_PRIORITY   2
#define TASK_HEALTH_PRIORITY    1

/* Queue capacities */
#define ACQ_QUEUE_LENGTH        4
#define LOG_QUEUE_LENGTH        4

/* Task handles */
extern TaskHandle_t g_task_process_handle;
extern TaskHandle_t g_task_comm_handle;
extern TaskHandle_t g_task_compute_handle;
extern TaskHandle_t g_task_health_handle;

/* Application queues */
extern QueueHandle_t xAcqQueue;
extern QueueHandle_t xLogQueue;

/* Diagnostic synchronization primitives */
extern SemaphoreHandle_t g_diag_sem;
extern SemaphoreHandle_t g_diag_mutex;
extern SemaphoreHandle_t g_diag_resource;

/* Diagnostic timing results */
extern volatile uint32_t g_diag_high_wait_cycles_run_a;
extern volatile uint32_t g_diag_high_wait_cycles_run_b;
extern volatile uint32_t g_low_workload_iterations;
extern volatile uint32_t g_log_drops;
extern volatile uint8_t  g_diag_run_state;

/**
 * @brief Initialize all queues, tasks, and diagnostic objects before scheduler starts.
 */
void node_app_init(void);

/**
 * @brief Diagnostic workload execution (Low role critical workload).
 * Strictly CPU-runnable with no vTaskDelay().
 */
void inversion_execute_low_workload(void);

/**
 * @brief Medium-priority interference CPU workload.
 */
void node_app_execute_medium_workload(void);

/**
 * @brief Integer square root helper for RMS computation.
 */
uint32_t isqrt_u32(uint32_t val);

/**
 * @brief Retrieve stack high-water mark in bytes.
 */
uint32_t node_app_get_watermark_bytes(TaskHandle_t xTask);

#endif /* NODE_APP_H */
