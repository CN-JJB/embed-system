# P2-M01 Reviewer Hints & Pedagogical Guidance

> **Role**: Instructor / Reviewer Reference  
> **Audience**: Instructors evaluating learners or assisting stuck learners during lab progression.

---

## 1. Socratic Questioning Prompts

When learners are stuck during P2-M01 labs, use these graduated Socratic prompts rather than providing immediate answers:

### On Vector Table Parity & Thumb Bit (Lab 01 & Fault 1)
1. "Look at the disassembly of `Reset_Handler` vs its entry in the vector table. Notice anything unusual about bit 0?"
2. "How does the Cortex-M3 processor distinguish between Arm state and Thumb state?"
3. "Can Cortex-M processors ever execute in Arm 32-bit state? What exception does the processor raise if PC bit 0 is zero?"
4. "How does the GNU assembler decide whether a symbol is a Thumb function or raw data? What directive is required?"

### On VMA vs LMA and `.data` Copy (Lab 03 & Fault 2)
1. "Where do initialized variable values physically live when the board is powered off?"
2. "Where must the CPU read and write those variables when the firmware is executing?"
3. "Inspect your `.map` file: What is the difference between `ADDR(.data)` and `LOADADDR(.data)`?"
4. "If you set `_sidata = ADDR(.data);`, what address in memory is the startup loop reading from?"

### On `SystemInit()` Ordering & Invariants (Lab 02)
1. "In your assembly `Reset_Handler`, does `bl SystemInit` occur before or after the `.data` copy loop?"
2. "What would happen if `SystemInit()` modified a global C variable like `SystemCoreClock = 72000000;`?"
3. "Where will that value be after the `.data` copy loop executes?"
4. "What types of variables and hardware are safe for `SystemInit()` to touch before `.data` and `.bss` are initialized?"

### On Constructor Tables & `__libc_init_array` (Lab 02)
1. "What function in newlib-nano invokes constructors declared with `__attribute__((constructor))`?"
2. "Why does the linker script need `KEEP(*(.init_array*))`?"
3. "What happens if you run `arm-none-eabi-gcc` with `-Wl,--gc-sections` without `KEEP`?"

---

## 2. Common Student Traps & Misconceptions

| Misconception | Reality | How to Redirect |
|---|---|---|
| "The CPU executes an instruction to set SP to `_estack`." | Hardware automatically reads vector 0 from address `0x08000000` on reset and loads MSP before fetching vector 1. | Have the student inspect GDB registers immediately at reset before stepping the first instruction. |
| "Writing `-Wl,-e,Reset_Handler` disables default startfiles." | `-Wl,-e` only informs the ELF header of the entry symbol. `-nostartfiles` is required to prevent GCC from linking `crt0.o`. | Run `arm-none-eabi-gcc -v` with and without `-nostartfiles` to show crt0 inclusion. |
| "Global variables are automatically zeroed by silicon." | SRAM powers up with indeterminate state. Hardware does not zero SRAM; software startup loops must zero `.bss`. | Have the student step through the zero loop in GDB watching memory at `_sbss`. |
| "Linker script memory length can be arbitrarily large." | Physical STM32F103C8 has exactly 64 KB Flash and 20 KB SRAM. Exceeding limits corrupts unmapped address space. | Direct student to `ASSERT` directives in the linker script. |
