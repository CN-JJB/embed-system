/**
 * =============================================================================
 * Original Pedagogical Startup Code for STM32F103C8T6 (Cortex-M3)
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M01 Reset, Startup, Linker Script, and Vector Table
 *
 * Sequence:
 *   1. Hardware automatically loads initial MSP from vector 0 (_estack)
 *   2. Hardware loads initial PC from vector 1 (Reset_Handler)
 *   3. Reset_Handler branches to SystemInit() (under pre-.data/.bss invariant)
 *   4. Copy initialized .data section from Flash (LMA) to SRAM (VMA)
 *   5. Zero uninitialized .bss section in SRAM
 *   6. Branch to __libc_init_array() to execute C runtime constructor array
 *   7. Branch to main()
 *   8. Infinite trap loop if main() returns
 * =============================================================================
 */

  .syntax unified
  .cpu cortex-m3
  .fpu softvfp
  .thumb

  .global g_pfnVectors
  .global Reset_Handler
  .global Default_Handler

/* Linker symbols marking section boundaries */
  .word _sidata
  .word _sdata
  .word _edata
  .word _sbss
  .word _ebss

/* =============================================================================
 * Reset Handler Implementation
 * =============================================================================
 */
  .section .text.Reset_Handler
  .weak Reset_Handler
  .type Reset_Handler, %function
Reset_Handler:
  /* Note: The processor hardware loads MSP from vector 0 before entering here.
   * We do not redundantly set SP in software.
   */

  /* 1. Low-level clock/bus initialization.
   * INVARIANT: SystemInit() executes before .data is copied and .bss is zeroed.
   * It must NOT access initialized writable global or static C variables!
   */
  bl  SystemInit

  /* 2. Copy initialized data from Flash (LMA) to RAM (VMA) */
  ldr r0, =_sdata
  ldr r1, =_edata
  ldr r2, =_sidata
  movs r3, #0
  b .L_check_data_loop

.L_copy_data_loop:
  ldr r3, [r2], #4
  str r3, [r0], #4

.L_check_data_loop:
  cmp r0, r1
  bcc .L_copy_data_loop

  /* 3. Zero out the uninitialized BSS section in RAM */
  ldr r0, =_sbss
  ldr r1, =_ebss
  movs r2, #0
  b .L_check_zero_bss_loop

.L_zero_bss_loop:
  str r2, [r0], #4

.L_check_zero_bss_loop:
  cmp r0, r1
  bcc .L_zero_bss_loop

  /* 4. Execute C runtime constructor tables (.init_array) */
  bl  __libc_init_array

  /* 5. Enter the C application */
  bl  main

  /* 6. Safety trap if main() ever returns */
.L_exit_loop:
  b   .L_exit_loop

  .size Reset_Handler, .-Reset_Handler

/* =============================================================================
 * Default Handler for unhandled exceptions and interrupts
 * =============================================================================
 */
  .section .text.Default_Handler,"ax",%progbits
Default_Handler:
.L_infinite_trap:
  b .L_infinite_trap
  .size Default_Handler, .-Default_Handler

/* =============================================================================
 * Vector Table (Placed in .isr_vector section at 0x08000000)
 * =============================================================================
 */
  .section .isr_vector,"a",%progbits
  .type g_pfnVectors, %object

g_pfnVectors:
  /* Cortex-M3 Core Exceptions */
  .word _estack                         /* Top of Main Stack */
  .word Reset_Handler                   /* Reset Handler (Thumb address, bit 0 = 1) */
  .word NMI_Handler                     /* NMI Handler */
  .word HardFault_Handler               /* Hard Fault Handler */
  .word MemManage_Handler               /* MPU Fault Handler */
  .word BusFault_Handler                /* Bus Fault Handler */
  .word UsageFault_Handler              /* Usage Fault Handler */
  .word 0                               /* Reserved */
  .word 0                               /* Reserved */
  .word 0                               /* Reserved */
  .word 0                               /* Reserved */
  .word SVC_Handler                     /* SVCall Handler */
  .word DebugMon_Handler                /* Debug Monitor Handler */
  .word 0                               /* Reserved */
  .word PendSV_Handler                  /* PendSV Handler */
  .word SysTick_Handler                 /* SysTick Handler */

  /* External Interrupts (STM32F103 Medium-Density Line) */
  .word WWDG_IRQHandler                 /* Window Watchdog */
  .word PVD_IRQHandler                  /* PVD through EXTI Line detect */
  .word TAMPER_IRQHandler               /* Tamper */
  .word RTC_IRQHandler                  /* RTC */
  .word FLASH_IRQHandler                /* Flash */
  .word RCC_IRQHandler                  /* RCC */
  .word EXTI0_IRQHandler                /* EXTI Line 0 */
  .word EXTI1_IRQHandler                /* EXTI Line 1 */
  .word EXTI2_IRQHandler                /* EXTI Line 2 */
  .word EXTI3_IRQHandler                /* EXTI Line 3 */
  .word EXTI4_IRQHandler                /* EXTI Line 4 */
  .word DMA1_Channel1_IRQHandler        /* DMA1 Channel 1 */
  .word DMA1_Channel2_IRQHandler        /* DMA1 Channel 2 */
  .word DMA1_Channel3_IRQHandler        /* DMA1 Channel 3 */
  .word DMA1_Channel4_IRQHandler        /* DMA1 Channel 4 */
  .word DMA1_Channel5_IRQHandler        /* DMA1 Channel 5 */
  .word DMA1_Channel6_IRQHandler        /* DMA1 Channel 6 */
  .word DMA1_Channel7_IRQHandler        /* DMA1 Channel 7 */
  .word ADC1_2_IRQHandler               /* ADC1 & ADC2 */
  .word USB_HP_CAN1_TX_IRQHandler       /* USB HP and CAN1 TX */
  .word USB_LP_CAN1_RX0_IRQHandler      /* USB LP and CAN1 RX0 */
  .word CAN1_RX1_IRQHandler             /* CAN1 RX1 */
  .word CAN1_SCE_IRQHandler             /* CAN1 SCE */
  .word EXTI9_5_IRQHandler              /* EXTI Line 9..5 */
  .word TIM1_BRK_IRQHandler             /* TIM1 Break */
  .word TIM1_UP_IRQHandler              /* TIM1 Update */
  .word TIM1_TRG_COM_IRQHandler         /* TIM1 Trigger and Commutation */
  .word TIM1_CC_IRQHandler              /* TIM1 Capture Compare */
  .word TIM2_IRQHandler                 /* TIM2 */
  .word TIM3_IRQHandler                 /* TIM3 */
  .word TIM4_IRQHandler                 /* TIM4 */
  .word I2C1_EV_IRQHandler              /* I2C1 Event */
  .word I2C1_ER_IRQHandler              /* I2C1 Error */
  .word I2C2_EV_IRQHandler              /* I2C2 Event */
  .word I2C2_ER_IRQHandler              /* I2C2 Error */
  .word SPI1_IRQHandler                 /* SPI1 */
  .word SPI2_IRQHandler                 /* SPI2 */
  .word USART1_IRQHandler               /* USART1 */
  .word USART2_IRQHandler               /* USART2 */
  .word USART3_IRQHandler               /* USART3 */
  .word EXTI15_10_IRQHandler            /* EXTI Line 15..10 */
  .word RTC_Alarm_IRQHandler            /* RTC Alarm through EXTI Line */
  .word USBWakeUp_IRQHandler            /* USB Wakeup from suspend */
  .size g_pfnVectors, .-g_pfnVectors

/* =============================================================================
 * Weak aliases routing unimplemented handlers to Default_Handler
 * =============================================================================
 */
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

  .weak WWDG_IRQHandler
  .thumb_set WWDG_IRQHandler,Default_Handler

  .weak PVD_IRQHandler
  .thumb_set PVD_IRQHandler,Default_Handler

  .weak TAMPER_IRQHandler
  .thumb_set TAMPER_IRQHandler,Default_Handler

  .weak RTC_IRQHandler
  .thumb_set RTC_IRQHandler,Default_Handler

  .weak FLASH_IRQHandler
  .thumb_set FLASH_IRQHandler,Default_Handler

  .weak RCC_IRQHandler
  .thumb_set RCC_IRQHandler,Default_Handler

  .weak EXTI0_IRQHandler
  .thumb_set EXTI0_IRQHandler,Default_Handler

  .weak EXTI1_IRQHandler
  .thumb_set EXTI1_IRQHandler,Default_Handler

  .weak EXTI2_IRQHandler
  .thumb_set EXTI2_IRQHandler,Default_Handler

  .weak EXTI3_IRQHandler
  .thumb_set EXTI3_IRQHandler,Default_Handler

  .weak EXTI4_IRQHandler
  .thumb_set EXTI4_IRQHandler,Default_Handler

  .weak DMA1_Channel1_IRQHandler
  .thumb_set DMA1_Channel1_IRQHandler,Default_Handler

  .weak DMA1_Channel2_IRQHandler
  .thumb_set DMA1_Channel2_IRQHandler,Default_Handler

  .weak DMA1_Channel3_IRQHandler
  .thumb_set DMA1_Channel3_IRQHandler,Default_Handler

  .weak DMA1_Channel4_IRQHandler
  .thumb_set DMA1_Channel4_IRQHandler,Default_Handler

  .weak DMA1_Channel5_IRQHandler
  .thumb_set DMA1_Channel5_IRQHandler,Default_Handler

  .weak DMA1_Channel6_IRQHandler
  .thumb_set DMA1_Channel6_IRQHandler,Default_Handler

  .weak DMA1_Channel7_IRQHandler
  .thumb_set DMA1_Channel7_IRQHandler,Default_Handler

  .weak ADC1_2_IRQHandler
  .thumb_set ADC1_2_IRQHandler,Default_Handler

  .weak USB_HP_CAN1_TX_IRQHandler
  .thumb_set USB_HP_CAN1_TX_IRQHandler,Default_Handler

  .weak USB_LP_CAN1_RX0_IRQHandler
  .thumb_set USB_LP_CAN1_RX0_IRQHandler,Default_Handler

  .weak CAN1_RX1_IRQHandler
  .thumb_set CAN1_RX1_IRQHandler,Default_Handler

  .weak CAN1_SCE_IRQHandler
  .thumb_set CAN1_SCE_IRQHandler,Default_Handler

  .weak EXTI9_5_IRQHandler
  .thumb_set EXTI9_5_IRQHandler,Default_Handler

  .weak TIM1_BRK_IRQHandler
  .thumb_set TIM1_BRK_IRQHandler,Default_Handler

  .weak TIM1_UP_IRQHandler
  .thumb_set TIM1_UP_IRQHandler,Default_Handler

  .weak TIM1_TRG_COM_IRQHandler
  .thumb_set TIM1_TRG_COM_IRQHandler,Default_Handler

  .weak TIM1_CC_IRQHandler
  .thumb_set TIM1_CC_IRQHandler,Default_Handler

  .weak TIM2_IRQHandler
  .thumb_set TIM2_IRQHandler,Default_Handler

  .weak TIM3_IRQHandler
  .thumb_set TIM3_IRQHandler,Default_Handler

  .weak TIM4_IRQHandler
  .thumb_set TIM4_IRQHandler,Default_Handler

  .weak I2C1_EV_IRQHandler
  .thumb_set I2C1_EV_IRQHandler,Default_Handler

  .weak I2C1_ER_IRQHandler
  .thumb_set I2C1_ER_IRQHandler,Default_Handler

  .weak I2C2_EV_IRQHandler
  .thumb_set I2C2_EV_IRQHandler,Default_Handler

  .weak I2C2_ER_IRQHandler
  .thumb_set I2C2_ER_IRQHandler,Default_Handler

  .weak SPI1_IRQHandler
  .thumb_set SPI1_IRQHandler,Default_Handler

  .weak SPI2_IRQHandler
  .thumb_set SPI2_IRQHandler,Default_Handler

  .weak USART1_IRQHandler
  .thumb_set USART1_IRQHandler,Default_Handler

  .weak USART2_IRQHandler
  .thumb_set USART2_IRQHandler,Default_Handler

  .weak USART3_IRQHandler
  .thumb_set USART3_IRQHandler,Default_Handler

  .weak EXTI15_10_IRQHandler
  .thumb_set EXTI15_10_IRQHandler,Default_Handler

  .weak RTC_Alarm_IRQHandler
  .thumb_set RTC_Alarm_IRQHandler,Default_Handler

  .weak USBWakeUp_IRQHandler
  .thumb_set USBWakeUp_IRQHandler,Default_Handler
