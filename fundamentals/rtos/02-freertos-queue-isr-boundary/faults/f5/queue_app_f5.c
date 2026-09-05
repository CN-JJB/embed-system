#include "queue_app.h"
#include "gpio.h"
#include "core_cm3.h"

QueueHandle_t g_sample_queue = NULL;
volatile uint32_t g_consumer_received_count = 0;
volatile uint32_t g_consumer_sequence_errors = 0;

static void prvConsumerTask(void *pvParameters)
{
    (void)pvParameters;
    uint32_t rx_val = 0;
    uint32_t expected_seq = 0;
    uint8_t first_packet = 1;

    for (;;) {
        if (xQueueReceive(g_sample_queue, &rx_val, portMAX_DELAY) == pdPASS) {
            gpio_toggle_pa2();

            if (first_packet) {
                expected_seq = rx_val + 1;
                first_packet = 0;
            } else {
                if (rx_val == expected_seq) {
                    expected_seq++;
                } else {
                    g_consumer_sequence_errors++;
                    expected_seq = rx_val + 1;
                }
            }

            g_consumer_received_count++;

            if ((g_consumer_received_count % 100) == 0) {
                gpio_toggle_led();
            }
        }
    }
}

void queue_app_init(void)
{
    /* Sizing defect: Queue created with 1-byte items (sizeof(uint8_t))
     * instead of 4-byte items (sizeof(uint32_t)).
     * When xQueueSendFromISR copies 4 bytes, only 1 byte is stored,
     * truncating the sequence number and corrupting data.
     */
    g_sample_queue = xQueueCreate(QUEUE_APP_LENGTH, sizeof(uint8_t));
    configASSERT(g_sample_queue != NULL);

    BaseType_t xRet = xTaskCreate(
        prvConsumerTask,
        "Consumer",
        256,
        NULL,
        3,
        NULL
    );
    configASSERT(xRet == pdPASS);
}
