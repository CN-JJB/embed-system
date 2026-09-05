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
  bl  SystemInit

  /* Data copy loop */
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

  /* Zero .bss */
  ldr r0, =_sbss
  ldr r1, =_ebss
  movs r2, #0
  b .L_check_zero_bss_loop

.L_zero_bss_loop:
  str r2, [r0], #4

.L_check_zero_bss_loop:
  cmp r0, r1
  bcc .L_zero_bss_loop

  /* OMITTED: bl __libc_init_array */

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
  .word Default_Handler
  .word Default_Handler
  .size g_pfnVectors, .-g_pfnVectors
