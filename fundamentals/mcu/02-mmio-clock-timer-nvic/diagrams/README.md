# P2-M02 Architectural Diagrams

```mermaid
graph TD
    HSE[HSE 8 MHz Crystal] -->|PLLSRC| PLL[PLL x9 Multiplier]
    PLL -->|SW=PLL| SYSCLK[SYSCLK 72 MHz]
    SYSCLK -->|HPRE=/1| AHB[HCLK 72 MHz]
    AHB -->|PPRE1=/2| APB1[PCLK1 36 MHz <= 36 MHz Limit]
    APB1 -->|Prescaler != 1: x2 Doubler| TIMCLK[TIM2 Clock 72 MHz]
    TIMCLK -->|PSC = 71: 1 MHz| CNT[TIM2 Counter]
    CNT -->|ARR = 999: 1000 Ticks| UEV[Update Event @ 1 kHz]
    UEV -->|DIER.UIE=1| NVIC[NVIC ISER[28] IRQ Enable]
    NVIC -->|Priority Logical 6 / 0x60| CPU[Cortex-M3 Handler Mode]
    CPU -->|Acknowledge| SR[TIM2->SR = ~TIM_SR_UIF]
```
