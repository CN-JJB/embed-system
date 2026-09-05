/**
 * =============================================================================
 * P2-M01 Challenge Reference Startup File
 * =============================================================================
 */

  .syntax unified
  .cpu cortex-m3
  .fpu softvfp
  .thumb

  .global g_pfnVectors
  .global Reset_Handler
  .global Default_Handler

  .section .text.Reset_Handler
  .weak Reset_Handler
  .type Reset_Handler, %function
Reset_Handler:
  /* 1. Low-level initialization */
  bl  SystemInit

  /* 2. Copy .data from Flash to RAM */
  ldr r0, =_sdata
  ldr r1, =_edata
  ldr r2, =_sidata
  b .L_check_data_loop

.L_copy_data_loop:
  ldr r3, [r2], #4
  str r3, [r0], #4

.L_check_data_loop:
  cmp r0, r1
  bcc .L_copy_data_loop

  /* 3. Zero .bss in RAM */
  ldr r0, =_sbss
  ldr r1, =_ebss
  movs r2, #0
  b .L_check_zero_bss_loop

.L_zero_bss_loop:
  str r2, [r0], #4

.L_check_zero_bss_loop:
  cmp r0, r1
  bcc .L_zero_bss_loop

  /* 4. Constructor array */
  bl  __libc_init_array

  /* 5. Enter main application */
  bl  main

.L_exit_loop:
  b   .L_exit_loop

  .size Reset_Handler, .-Reset_Handler

  .section .text.Default_Handler,"ax",%progbits
Default_Handler:
.L_infinite_trap:
  b .L_infinite_trap
  .size Default_Handler, .-Default_Handler

  .section .isr_vector,"a",%progbits
  .type g_pfnVectors, %object
g_pfnVectors:
  .word _estack
  .word Reset_Handler
  .word NMI_Handler
  .word HardFault_Handler
  .word MemManage_Handler
  .word BusFault_Handler
  .word UsageFault_Handler
  .word 0
  .word 0
  .word 0
  .word 0
  .word SVC_Handler
  .word DebugMon_Handler
  .word 0
  .word PendSV_Handler
  .word SysTick_Handler
  .size g_pfnVectors, .-g_pfnVectors

  .weak NMI_Handler
  .thumb_set NMI_Handler,Default_Handler
  .weak HardFault_Handler
  .thumb_set HardFault_Handler,Default_Handler
  .weak MemManage_Handler
  .thumb_set MemManage_Handler,Default_Handler
  .weak BusFault_Handler
  .thumb_set BusFault_Handler,Default_Handler
  .weak UsageFault_Handler
  .thumb_set UsageFault_Handler,Default_Handler
  .weak SVC_Handler
  .thumb_set SVC_Handler,Default_Handler
  .weak DebugMon_Handler
  .thumb_set DebugMon_Handler,Default_Handler
  .weak PendSV_Handler
  .thumb_set PendSV_Handler,Default_Handler
  .weak SysTick_Handler
  .thumb_set SysTick_Handler,Default_Handler
