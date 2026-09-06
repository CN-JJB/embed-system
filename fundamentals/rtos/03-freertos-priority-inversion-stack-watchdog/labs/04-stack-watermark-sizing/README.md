# Lab 04: Stack Watermark Measurement & Task Sizing

## Objectives
- Master `uxTaskGetStackHighWaterMark()` to evaluate task stack usage.
- Understand the 0xA5 memory fill pattern and scanning algorithm.
- Rigorously apply the 4x word-to-byte conversion factor on 32-bit Cortex-M3.

## Memory Architecture of FreeRTOS Task Stacks

When `xTaskCreate()` allocates a task stack of depth `configMINIMAL_STACK_SIZE` (128 words):
- Total allocated memory: $128 \times 4\text{ bytes} = 512\text{ bytes}$.
- At task creation, FreeRTOS writes `0xA5` into every single byte.
- On Cortex-M3, the stack grows from high memory (`pxEndOfStack`) downwards towards low memory (`pxStack`).

```text
[High Address: pxEndOfStack]
  | Initial context frame (r0-r3, r12, lr, pc, xpsr, r4-r11)
  | Nested function activation frames
  | Local variables & buffers
  V (Stack grows downward)
[Current SP: pxTopOfStack]
  ............................ (Unused Headroom filled with 0xA5)
[Low Address: pxStack]
```

## The High Watermark Algorithm (`tasks.c`)

```c
UBaseType_t uxTaskGetStackHighWaterMark( TaskHandle_t xTask )
{
    TCB_t *pxTCB;
    uint8_t *pucEndOfStack;
    UBaseType_t uxCount = 0;

    pxTCB = prvGetTCBFromHandle( xTask );
    pucEndOfStack = ( uint8_t * ) pxTCB->pxStack;

    while( *pucEndOfStack == ( uint8_t ) tskSTACK_FILL_BYTE )
    {
        pucEndOfStack++;
        uxCount++;
    }

    uxCount /= sizeof( StackType_t ); /* Divides by 4 on 32-bit Cortex-M3! */

    return uxCount;
}
```

## The Fatal Unit Confusion Hazard

Notice the last step in `uxTaskGetStackHighWaterMark()`:
```c
uxCount /= sizeof( StackType_t );
```
The function returns the number of **WORDS** remaining!

If a developer writes:
```c
/* BUG: UNIT CONFUSION */
UBaseType_t remaining = uxTaskGetStackHighWaterMark(xTask);
if (remaining < 64) {
    /* Developer thinks: "If less than 64 bytes remaining, raise alarm" */
}
```
In reality:
- `remaining = 64` words $= 64 \times 4 = 256$ bytes!
- If the true stack headroom drops to 60 bytes ($15$ words), `remaining` returns `15`.
- The developer's check triggers prematurely or misinterprets safe margins by a factor of 4!

### Correct Usage:
```c
UBaseType_t remaining_words = uxTaskGetStackHighWaterMark(xTask);
uint32_t remaining_bytes = remaining_words * sizeof(StackType_t); /* * 4 */

/* Require at least 64 bytes of headroom */
if (remaining_bytes < 64) {
    /* Stack exhaustion warning */
}
```

## Review Questions
1. If a task allocated 256 words has a high watermark of 32 words, how many bytes of stack did the task actually consume at peak?
   *(Answer: $(256 - 32) \times 4 = 224 \times 4 = 896$ bytes consumed out of 1024 bytes allocated).*
2. Can `uxTaskGetStackHighWaterMark` detect an overflow that occurred in the past?
   *(Answer: It will report `0` words remaining if the 0xA5 pattern at `pxStack` was overwritten).*
