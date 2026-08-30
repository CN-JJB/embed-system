# Canonical Resources — Initial Registry

This is a living registry. Inclusion means “high-value reference for the curriculum”, not “read cover to cover”.

## Classic Books

### Systems / C / Linux

- **Computer Systems: A Programmer's Perspective (CS:APP)** — linking, machine-level programs, memory hierarchy, virtual memory, concurrency.
- **The Linux Programming Interface (TLPI)** — Linux userspace interfaces, processes, threads, signals, IPC, files.
- **Operating Systems: Three Easy Pieces (OSTEP)** — operating-system mental models and experiments.
- **Advanced Programming in the UNIX Environment (APUE)** — Unix/POSIX programming model and systems practice.

### Architecture

- **Computer Organization and Design** — architecture, datapath, memory hierarchy, I/O.
- **Computer Architecture: A Quantitative Approach** — later-stage performance and architecture reasoning.

### Embedded / Real-Time

Use books selectively and verify implementation details against current RTOS/vendor documentation. Real-time concepts should be paired with measured experiments and source reading.

## High-Value Open-Source Projects

### Operating Systems / Kernel

- **Linux kernel** — primary long-term source-reading target for kernel, drivers, memory, scheduling, DMA, device model, tracing.
- **xv6** — compact OS teaching implementation for selected mechanisms; not a substitute for Linux.
- **QEMU** — emulation/virtualization environment useful for reproducible OS and boot experiments.

### RTOS

- **FreeRTOS-Kernel** — first RTOS source-reading target for scheduler, task management, queues, synchronization, and context switching.
- **Zephyr** — later engineering-oriented RTOS ecosystem, device model, build/configuration, drivers.

### Boot / Embedded Linux

- **U-Boot** — boot flow, board support, device model, environment, boot scripting.
- **Buildroot** — first embedded-Linux build-system target because it exposes the whole image-building pipeline with comparatively low conceptual overhead.
- **Yocto Project / OpenEmbedded** — later production-oriented build and distribution engineering.
- **BusyBox** — compact userspace and useful source-reading target for embedded Unix utilities.

### C Library / Toolchain

- **musl libc** — compact libc implementation useful for selected source-reading topics.
- **glibc** — production libc reference for selected Linux behavior.
- **GCC / binutils / GDB** — compiler, linker, binary inspection, debugger.

### Hardware / SoC

- **RISC-V ISA specifications and ecosystem implementations** — connect prior RTL experience to formal ISA/system understanding.
- **LiteX** — optional later reference for composable SoC structures and FPGA-based system experiments.
- **Open-source RISC-V cores** — select only after defining the exact learning goal; compare architecture and implementation choices rather than copying a core.

## High-Quality Courses / Labs

Potential reference families include:

- MIT 6.S081 / xv6;
- Berkeley CS61C;
- high-quality systems programming courses;
- Bootlin training material for Linux kernel/drivers/embedded Linux;
- vendor and architecture-vendor official training.

Courses are used as teaching references, not blindly mirrored.

## How Resources Enter a Chapter

A typical core chapter should ask:

- Which official specification defines the behavior?
- Which upstream project shows the implementation?
- Which classic book gives the clearest stable mental model?
- Which course/lab demonstrates a proven learning sequence?
- Which original experiment lets the learner observe the phenomenon?

## Copyright and License

- Do not reproduce book chapters or large copyrighted passages.
- Do not copy diagrams merely because they are useful.
- Respect open-source licenses and attribution requirements.
- Prefer original diagrams, original experiments, and links to upstream source locations.
