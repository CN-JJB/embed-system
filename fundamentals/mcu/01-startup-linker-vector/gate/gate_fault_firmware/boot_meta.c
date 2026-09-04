#include <stdint.h>

const uint32_t g_boot_metadata[8] __attribute__((section(".boot_meta"), used)) = {
    0x53544D33, /* Magic signature: "STM3" */
    0x00010000, /* Format revision: 1.0 */
    0x00000000, /* Build timestamp */
    0x00000000, /* Checksum */
    0x00000000,
    0x00000000,
    0x00000000,
    0x00000000
};
