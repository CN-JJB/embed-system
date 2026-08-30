# Lab Standard

Every substantial lab must define:

- objective;
- prerequisite knowledge;
- hardware/software environment;
- exact versions where relevant;
- build/run procedure;
- expected observable result;
- what to measure or inspect;
- verification method;
- likely failure modes;
- debugging strategy;
- extension challenge.

## Verification Status

Use explicit status labels:

- **VERIFIED** — executed on the stated environment and evidence recorded.
- **PARTIALLY VERIFIED** — only part of the path was executed.
- **UNVERIFIED** — design/code proposal only.

Never present unexecuted output as actual output.

## Observation-First Design

A good lab should answer:

> What concrete phenomenon proves or challenges the mental model?

Examples:

- measure interrupt latency;
- inspect ELF sections;
- trace a system call;
- trigger priority inversion;
- capture SPI timing;
- compare cached and uncached access;
- inspect kernel probe order;
- reproduce a race.

## Fault Injection

Core modules should contain deliberate failure exercises where appropriate.

Examples:

- bad linker script;
- stack overflow;
- race/deadlock;
- wrong Device Tree property;
- missing clock/reset;
- IRQ polarity mismatch;
- DMA/cache misuse;
- boot/rootfs failure.

## Postmortem

Major labs and all flagship projects require:

- symptom;
- hypotheses;
- evidence;
- experiments;
- root cause;
- fix;
- prevention;
- lessons learned.
