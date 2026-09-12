# Phase 4 — Linux Kernel Driver Model and Subsystem Drivers

> **Authoring model:** resource-first. The learner writes the drivers; the repository supplies the map, authoritative resources, source-reading targets, experiment ideas and common traps.

## Exit capability

By the end of Phase 4, the learner should be able to:

- explain the Linux device/driver/bus model;
- trace how firmware/Device Tree description becomes a bound driver instance;
- write and debug a small `platform_driver`;
- acquire MMIO/IRQ/GPIO/clock/regulator resources using current kernel idioms;
- choose between hard IRQ, threaded IRQ and deferred work at a practical level;
- use `devm_*` resource management appropriately;
- read and adapt a small I2C/SPI/GPIO-oriented upstream driver;
- understand where DMA, pinctrl, regulators and clocks enter a SoC driver;
- reason about probe ordering, deferred probe and runtime/system PM at orientation depth;
- read a DT binding schema before inventing properties;
- debug driver binding and probe failures with kernel logs/sysfs/debug facilities.

The goal is **not** to memorize every driver API.

---

# Recommended sequence

## P4-1 — Kernel module and build/debug orientation

### Learn

- in-tree vs out-of-tree modules;
- Kconfig/Makefile relationship;
- module load/unload lifecycle;
- `dmesg`, dynamic debug, module parameters only as orientation;
- kernel coding conventions and error-return style.

### Resources

- Bootlin Linux kernel and driver development training: https://bootlin.com/training/kernel/
- Linux Kernel Labs: https://linux-kernel-labs.github.io/
- kernel docs: https://docs.kernel.org/

### Suggested experiment

Build one minimal module, load/unload it, inspect symbols and logs, then stop. Do not spend a week on “hello world modules”.

---

## P4-2 — Device model: device / driver / bus / binding

### Learn

- `struct device`;
- `struct device_driver`;
- buses and match/probe;
- sysfs representation;
- firmware node / OF node relationship;
- device links and dependency ordering at orientation depth.

### Primary resources

- driver infrastructure: https://docs.kernel.org/driver-api/infrastructure.html
- platform devices/drivers: https://docs.kernel.org/driver-api/driver-model/platform.html

### Source-reading direction

Trace one simple platform driver from:

```text
of_match_table
→ platform_driver registration
→ match
→ probe
→ resource acquisition
→ subsystem registration
```

### Questions

- Who creates the device object?
- Who creates the driver object?
- What causes `probe()` to run?
- What does a successful probe mean?
- Why is “driver loaded” not the same as “device bound”? 

---

## P4-3 — Platform driver + Device Tree + resources

### Learn

- `struct platform_driver`;
- `of_device_id` / compatible matching;
- MMIO resources;
- IRQ resources;
- `devm_*` lifecycle;
- mapping registers using current kernel helpers;
- error unwinding and managed resources.

### Primary resources

- platform driver docs: https://docs.kernel.org/driver-api/driver-model/platform.html
- Devicetree schema writing: https://docs.kernel.org/devicetree/bindings/writing-schema.html
- binding design guidance: https://docs.kernel.org/devicetree/bindings/writing-bindings.html

### Suggested experiment

Write one tiny platform driver for a simple emulated or controlled device. Require:

- DT node;
- `compatible` match;
- MMIO resource acquisition;
- one observable register read/write or synthetic register region;
- clean error path;
- explicit evidence that probe occurred.

Do not add a char device merely to “show output” if the subsystem already has a better interface.

---

## P4-4 — IRQs and deferred work

### Learn

- interrupt context constraints;
- hard IRQ vs threaded IRQ;
- top half / bottom half as a historical mental model;
- workqueues;
- completion/wait/event concepts as needed;
- locking between interrupt and process contexts;
- shared state and lifetime.

### Resources

Use current kernel driver/core docs and Bootlin driver training. Read exact APIs in the kernel version used by the experiment.

### Suggested experiment

Have the device/fixture trigger an interrupt or use a safe test path. Capture:

- IRQ registration;
- handler execution;
- deferred work execution;
- race-free shutdown/removal.

Be able to explain why sleeping in hard IRQ context is wrong.

---

## P4-5 — GPIO, I2C and SPI consumer-driver patterns

### Learn

- GPIO descriptor-based consumer API;
- DT GPIO mappings;
- I2C device/driver model;
- SPI device/driver model;
- register access patterns;
- regmap orientation;
- why bus drivers and client/device drivers are different roles.

### Primary resources

- GPIO docs: https://docs.kernel.org/driver-api/gpio/
- GPIO mappings: https://docs.kernel.org/driver-api/gpio/board.html
- I2C docs: https://docs.kernel.org/i2c/
- SPI docs: https://docs.kernel.org/spi/

### Suggested project

Choose **one** simple sensor/peripheral and write/adapt a driver. Prefer a device with:

- a small register map;
- existing upstream binding examples;
- easy observable output;
- no large firmware stack.

First read two upstream drivers in the same subsystem before writing yours.

---

## P4-6 — Pinctrl, clocks, regulators and reset dependencies

### Learn

At orientation depth:

- pinmux vs GPIO;
- pinctrl states;
- device clocks;
- power regulators;
- reset controls;
- probe dependencies;
- deferred probing.

### Primary resources

- pin control: https://docs.kernel.org/driver-api/pin-control.html
- regulator: https://docs.kernel.org/power/regulator/
- current kernel docs/source for clock/reset APIs used by the target SoC.

### Suggested exercise

Take a real upstream driver that requests at least two of these resources and build a dependency diagram:

```text
device
├─ pinctrl
├─ clock
├─ regulator
├─ reset
└─ IRQ/MMIO
```

Then trace which resource is automatically handled by core code and which the driver explicitly acquires.

---

## P4-7 — DMA orientation

### Learn

- CPU virtual address vs physical/DMA address;
- coherent vs streaming mappings;
- cache coherency assumptions;
- DMA mask;
- DMAEngine client model at orientation depth;
- ownership/synchronization of buffers.

### Primary resource

- DMAEngine: https://docs.kernel.org/driver-api/dmaengine/
- current DMA mapping docs under kernel core/driver docs.

### Defer

Do not start with IOMMU internals, SMMU driver development or complex scatter-gather performance tuning unless a project requires it.

---

## P4-8 — Power management orientation

### Learn

- runtime PM vs system sleep;
- device usage count mental model;
- suspend/resume callback role;
- ordering/dependencies;
- clocks/regulators/pinctrl during PM.

### Resources

- power management docs: https://docs.kernel.org/power/
- device links: https://docs.kernel.org/driver-api/device_link.html

### Suggested exercise

Read one small upstream driver's runtime-PM path and explain what state is lost/restored and what resources are disabled/enabled.

---

# Recommended capstone

Build or adapt a small driver stack that includes:

- DT binding/node;
- platform or I2C/SPI binding;
- resource acquisition;
- IRQ or polling path;
- one subsystem-facing interface;
- clean shutdown/remove;
- one deliberate binding/resource/IRQ fault;
- short debug note with evidence.

The capstone should remain small enough that you can explain every important line.

---

# Common traps

- treating a Linux driver as bare-metal register code inside a module;
- creating custom sysfs/ioctl/char interfaces when a standard subsystem exists;
- inventing DT properties instead of reading bindings;
- confusing device creation with driver registration;
- assuming `probe()` order instead of understanding dependencies/deferred probe;
- using legacy GPIO integer APIs in new code without a reason;
- ignoring lifetime/removal paths;
- confusing CPU physical addresses with DMA addresses;
- copying vendor BSP code without checking current upstream API conventions.

---

# What to defer

Until Phase 5/6 or a project demands it:

- full PCIe driver development;
- DRM/KMS;
- networking MAC/PHY driver internals;
- complex sound subsystem drivers;
- V4L2/media pipelines;
- deep IOMMU/SMMU;
- security/TEE integration;
- large vendor BSP archaeology;
- extensive upstream submission workflow.

These are specialization tracks, not prerequisites for basic driver competence.
