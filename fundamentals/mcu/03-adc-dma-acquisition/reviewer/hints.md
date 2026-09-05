# P2-M03 Progressive Pedagogical Hints

These progressive hints may be provided during lab exploration under AI-Hint mode:

## Hint Level 1: Clock & Prescaler
- Review RM0008 Section 6.2 and DS5319 Section 5.3.18. What is the absolute maximum frequency permitted for the STM32F103 ADC clock?
- If PCLK2 is running at 72 MHz, what division factors are available in `RCC->CFGR` bits [15:14]?

## Hint Level 2: Trigger Chain
- Consult RM0008 Section 11 Table 65. What binary value in `EXTSEL[2:0]` routes TIM3 TRGO to regular ADC conversions?
- What other bit in `ADC1->CR2` must be asserted to permit external hardware trigger edges to start a conversion?

## Hint Level 3: DMA Data Transfer
- Check `DMA1_Channel1->CCR`. Are memory and peripheral data sizes configured as 16-bit (`PSIZE=01`, `MSIZE=01`)?
- What register bit in ADC1 tells the ADC to assert a DMA request line to DMA1 Channel 1 after each conversion?

## Hint Level 4: Milestone Math
- If conversions run at 10,000 samples per second into a 128-sample buffer, how many milliseconds elapse between successive Half-Transfer (HT) events?
- What is the difference between an event pulse repetition rate and a toggled square wave frequency?
