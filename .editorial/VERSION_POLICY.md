# Version Policy

## Rule

Version-sensitive teaching must state its baseline.

Track where applicable:

- Linux kernel;
- U-Boot;
- FreeRTOS;
- Zephyr;
- GCC;
- binutils;
- GDB;
- Buildroot;
- Yocto/OpenEmbedded;
- QEMU;
- board firmware;
- SoC documentation revisions.

## Stable vs Current

Distinguish:

- **stable concept** — e.g. virtual memory principles;
- **current implementation/API** — e.g. a specific Linux kernel helper;
- **project-specific behavior** — e.g. one SoC DMA engine.

Stable concepts may use classic books heavily. Current implementation claims must be checked against current upstream documentation/source.

## Upgrade Review

When a baseline changes:

1. identify affected chapters/labs;
2. rerun relevant build/tests;
3. update source ledgers;
4. record behavioral/API changes;
5. avoid silently rewriting historical results.

## Reproducibility

Flagship projects should eventually pin sufficient tool and source versions to be reproducible.
