# Module B — Compile / Link / ELF

**Time box:** 60 min  
**Score:** 10 points  
**Mode:** AI-Free; documentation allowed

The starter project is a deliberately broken multi-file C program. Its object files compile, but the final link fails for more than one reason.

## Task B1 — Repair and explain the build

From this directory:

```sh
make clean
make objects
make
```

Do not immediately rewrite headers by intuition. First collect evidence.

Required tools:

```sh
gcc
nm
readelf
objdump
```

Before repairing the link, also create at least one preprocessed file and one assembly file from a project translation unit, for example:

```sh
gcc -E -Istarter/include starter/src/metrics.c -o build/metrics.i
gcc -S -O0 -Istarter/include starter/src/metrics.c -o build/metrics.s
```

You may use equivalent commands for another translation unit.

### Required evidence and answers

1. Record the linker's errors and map each error to the object files involved.
2. Use `nm` to find:
   - a symbol that is defined globally more than once;
   - a symbol that one object needs but another object defines only with local linkage.
3. Use `readelf -s` to show at least one `LOCAL`, one `GLOBAL`, and one `UND` symbol from this project.
4. Use `readelf -r` on an object that has an unresolved call and explain what the relocation means **for this program**.
5. Use `objdump -h` or `readelf -S` to identify where this program's examples of code, initialized data, and zero-initialized data are placed before final linking.
6. Repair the project with the smallest coherent header/source changes.
7. Rebuild and run the executable.
8. Explain this concrete path using the `.i`, `.s`, `.o`, and final ELF artifacts you actually produced:

```text
source (.c/.h)
  -> preprocess
  -> compile
  -> assembly / machine code
  -> relocatable .o
  -> link
  -> ELF executable
```

Your explanation must connect `.text`, `.data`, `.bss`, symbols, and relocations to named objects/symbols from this project, not only give dictionary definitions.

## Expected successful behavior after repair

```text
baseline total=7 dropped=0
```

The exact symbol addresses and section offsets are host/toolchain dependent and are not part of the expected answer.
