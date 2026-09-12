# Phase 4 — Linux Kernel Driver Model and Subsystem Drivers

> **Authoring model:** resource-first. The learner writes the drivers; the repository supplies the map, authoritative resources, source-reading targets, experiment ideas and common traps.

## How to navigate this phase

The unit IDs in this file are the same IDs used by:

- [`../START_HERE.md`](../START_HERE.md) — learning order;
- [`../resources/TOPIC_RESOURCE_INDEX.md`](../resources/TOPIC_RESOURCE_INDEX.md) — exact documents/source targets/actions.

Use this file for **scope and dependency context**. Use the resource index for the exact reading slice.

```text
P4.1 module/build/debug loop
→ P4.2 device/driver/bus/bind/probe
→ P4.3 platform_driver + DT + resources
→ P4.4 IRQ + deferred work + locking
→ P4.5 GPIO descriptor consumer API
→ P4.6 I2C client drivers + regmap orientation
→ P4.7 SPI device/driver pattern
→ P4.8 pinctrl + clock + regulator + reset
→ P4.9 DMA mapping + DMAEngine
→ P4.10 runtime/system PM
→ P4.11 small driver capstone
```

## Exit capability

By the end of Phase 4, the learner should be able to:

- explain the Linux device/driver/bus model;
- trace how firmware/Device Tree description becomes a bound driver instance;
- write and debug a small `platform_driver`;
- acquire MMIO/IRQ/GPIO/clock/regulator resources using current kernel idioms;
- choose between hard IRQ, threaded IRQ and deferred work at practical depth;
- use `devm_*` resource management appropriately;
- read and adapt small I2C/SPI/GPIO-oriented upstream drivers;
- understand where DMA, pinctrl, regulators and clocks enter a SoC driver;
- reason about probe ordering, deferred probe and runtime/system PM;
- read a DT binding schema before inventing properties;
- debug driver binding and probe failures using logs/sysfs/tracing evidence.

The goal is **not** to memorize every driver API.

---

## P4.1 — Kernel module, Kbuild and first debug loop

### Learn

- in-tree vs external modules;
- Kbuild/Makefile relationship;
- module load/unload lifecycle;
- symbols and module metadata;
- `dmesg` / dynamic debug orientation;
- kernel coding/error-return conventions.

### Exact resource entry

Use **P4.1** in [`../resources/TOPIC_RESOURCE_INDEX.md`](../resources/TOPIC_RESOURCE_INDEX.md): kernel **Building External Modules**, coding style, dynamic-debug HOWTO, Bootlin kernel training and Linux Kernel Labs.

### Suggested experiment

Build one minimal external module, inspect it with `modinfo`/symbol tools, load/unload it and capture logs. Do not spend a week on hello-world modules.

---

## P4.2 — Device model: device / driver / bus / binding

### Learn

- `struct device`;
- `struct device_driver`;
- bus match and bind;
- `probe()` meaning;
- sysfs representation;
- firmware-node / OF-node relationship;
- dependency ordering at orientation depth.

### Exact resource entry

Use **P4.2**: kernel **Device Model Overview**, driver infrastructure, platform driver model, plus `drivers/base/` / `drivers/base/platform.c` source-reading direction.

### Questions you must be able to answer

- Who created the device object?
- Who registered the driver?
- What matched them?
- What causes `probe()` to run?
- Why is “module loaded” not the same as “device bound”? 

---

## P4.3 — `platform_driver` + Device Tree + MMIO/IRQ resources

### Learn

- `struct platform_driver`;
- `of_device_id` / `compatible` matching;
- MMIO and IRQ resources;
- `devm_*` / devres lifetime;
- managed register mapping;
- error paths and resource lookup.

### Exact resource entry

Use **P4.3**: platform-driver docs, devres docs, DT binding guidance, and current upstream examples using `devm_platform_ioremap_resource()` / `platform_get_irq()`.

### Suggested experiment

Create one tiny platform device/driver or controlled QEMU/DT fixture with compatible matching and at least one managed resource. Prove bind/probe through sysfs/log evidence.

---

## P4.4 — IRQs, threaded IRQs, workqueues and locking

### Learn

- hard interrupt context constraints;
- `request_irq()` / `request_threaded_irq()`;
- threaded handlers;
- workqueues;
- sleeping rules;
- synchronization/lifetime across process and interrupt contexts.

### Exact resource entry

Use **P4.4**: Linux generic IRQ docs, workqueue docs, locking guide, and Bootlin's interrupt/locking/deferred-work material.

### Suggested experiment

Trace registration → interrupt → handler → deferred work and demonstrate race-free removal/shutdown.

---

## P4.5 — GPIO descriptor consumer API

### Learn

- descriptor-based GPIO consumer API;
- firmware/DT GPIO mapping;
- direction/value semantics;
- why legacy global integer GPIO numbering should not be the default mental model.

### Exact resource entry

Use **P4.5**: kernel GPIO **consumer** and **board/firmware mapping** documentation plus one small upstream `devm_gpiod_get()` consumer.

### Suggested experiment

Use a DT-described GPIO from a driver and prove the descriptor came from the intended firmware mapping.

---

## P4.6 — I2C client-driver pattern + regmap orientation

### Learn

- I2C adapter/controller vs client/device-driver roles;
- client instantiation/matching;
- register I/O;
- subsystem registration;
- regmap orientation where it reduces repeated register-access boilerplate.

### Exact resource entry

Use **P4.6**: kernel **Writing I2C Clients**, **Instantiating I2C Devices**, and selected upstream examples such as `drivers/hwmon/lm75.c` and `drivers/misc/eeprom/at24.c`.

### Suggested experiment

Read two upstream drivers before adapting/writing one small sensor/peripheral driver.

---

## P4.7 — SPI device/driver pattern

### Learn

- SPI controller vs SPI device vs device protocol;
- `spi_driver` matching/probe;
- messages/transfers;
- what the SPI core handles versus what stays device-specific.

### Exact resource entry

Use **P4.7**: current kernel SPI docs and one small upstream SPI peripheral driver from the subsystem relevant to your project.

### Suggested experiment

Compare a simple register-oriented peripheral concept over I2C and SPI. Write down what changed at the bus layer and what did not.

---

## P4.8 — Pinctrl, clocks, regulators and reset dependencies

### Learn

- pinmux vs GPIO;
- pinctrl states;
- device clocks;
- regulators/power supplies;
- reset controls;
- provider/consumer dependencies;
- deferred probe.

### Exact resource entry

Use **P4.8**: kernel pinctrl, Common Clock Framework, regulator and reset-controller documentation; then read one real driver that acquires at least two of these resources.

### Suggested exercise

Draw the selected device dependency graph:

```text
power/regulator
→ reset
→ clock
→ pinctrl
→ MMIO/IRQ
→ subsystem registration
```

Compare it with actual probe/runtime-PM code.

---

## P4.9 — DMA mapping and DMAEngine orientation

### Learn

- CPU virtual address vs physical address vs DMA address;
- coherent vs streaming DMA mappings;
- cache/coherency assumptions;
- DMA masks;
- ownership/synchronization;
- DMAEngine client flow at orientation depth.

### Exact resource entry

Use **P4.9**: kernel **DMA API HOWTO** and **DMAEngine Client** documentation.

### Defer

IOMMU/SMMU internals and complex scatter-gather tuning unless a project requires them.

---

## P4.10 — Runtime PM and system sleep

### Learn

- runtime PM vs system-wide sleep;
- usage-count/state mental model;
- suspend/resume callback role;
- dependency/order interactions;
- clocks/regulators/pinctrl across PM transitions.

### Exact resource entry

Use **P4.10**: **Runtime Power Management Framework for I/O Devices**, power-management index and device-links documentation.

### Suggested exercise

Read one small driver's runtime-PM path and state what is disabled, what state is lost, what gets restored and what makes concurrent accesses safe.

---

## P4.11 — Small driver capstone

Build or adapt one small driver stack containing:

- DT binding/node;
- platform, I2C or SPI binding;
- managed resources;
- IRQ or polling path;
- one subsystem-facing interface;
- clean remove/shutdown and basic PM reasoning;
- one deliberate binding/resource/IRQ fault;
- short evidence-backed debug note.

Use **P4.11** in the topic resource index for the Bootlin/lab cross-check and exit criterion.

The capstone should remain small enough that you can explain every important line.

---

# Common traps

- treating a Linux driver as bare-metal register code placed inside a module;
- creating custom sysfs/ioctl/char interfaces when a standard subsystem exists;
- inventing DT properties instead of reading bindings;
- confusing device creation with driver registration;
- assuming `probe()` order instead of understanding dependencies/deferred probe;
- using legacy GPIO integer APIs in new code without a reason;
- ignoring lifetime/removal paths;
- confusing CPU physical addresses with DMA addresses;
- copying vendor BSP code without checking current upstream conventions.

# What to defer

Until Phase 5/6 or a real project demands it:

- full PCIe driver development;
- DRM/KMS;
- networking MAC/PHY internals;
- complex sound/media pipelines;
- deep IOMMU/SMMU;
- TEE/security integration;
- large vendor BSP archaeology.

These are specialization tracks, not prerequisites for basic driver competence.
