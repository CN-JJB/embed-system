# Progressive Socratic Hints for P3-M01

## Hint Level 1 (Initial orientation)
- When a shell says `No such file or directory` or `not found`, does that error message always come from the shell being unable to find the `./app` executable itself?
- Think about what the Linux kernel must do before jumping to `main()` in a dynamically linked program. What intermediate file does the kernel need to open?

## Hint Level 2 (Inspection tools)
- Which tool specifically extracts the text string requesting the dynamic linker?
  Check `readelf -l <binary> | grep -A1 INTERP`.
- Why does `readelf -h` output look identical between static and dynamic binaries?
  Both are `Type: EXEC` or `DYN`. What section or segment table shows whether dynamic linking was used?

## Hint Level 3 (Root cause isolation)
- If you have an ARM binary requesting `/lib/ld-linux-armhf.so.3` and your target rootfs only has `/lib/ld-musl-armhf.so.1`, can the kernel run the binary?
- What happens if you compile with `gcc -static`? Does the resulting binary need any file in `/lib` to run?
