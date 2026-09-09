# Progressive Socratic Hints for P3-M02

## Hint Level 1 (Configuration & Architecture)
- When auditing `.config`, why is checking `phase3_delta.config` insufficient?
  What if an option in the fragment was overridden or silenced by Kconfig dependency rules during `olddefconfig`?
- What does LPAE stand for? If `CONFIG_ARM_LPAE` is disabled, what is the maximum physical address the processor MMU can generate with short-descriptor page tables?

## Hint Level 2 (Artifacts & Symbols)
- How does `System.map` get produced during a normal kernel build?
  Look at the command: `nm -n vmlinux | awk ... > System.map`.
- If you modify a C file in `drivers/` and run `make zImage`, does `vmlinux` get updated? What if someone copied an old `System.map` from another build directory? How can you prove they match?

## Hint Level 3 (QEMU & Boot Diagnostics)
- In QEMU, what happens if you run `-machine virt` without specifying `-cpu`? What default CPU does QEMU choose for `virt`?
- Why is a kernel panic `Unable to mount root fs` considered a successful test of Module 02? What early subsystems must work for the kernel to even reach that panic?
