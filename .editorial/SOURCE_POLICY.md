# Source Policy

## Evidence Hierarchy

Prefer sources in this order:

1. **Primary specification / datasheet / TRM / architecture manual / standard**
2. **Upstream source code**
3. **Official project documentation**
4. **High-quality university or professional teaching material**
5. **Vendor application notes and engineering material**
6. **High-quality community material**
7. **AI explanation**

AI is an assistant, not a factual source.

## Diversity Requirement

Core chapters should normally use at least three *different source types*, not merely many links of the same type.

Example for Linux interrupt handling:

- Linux Kernel Documentation;
- Linux kernel source;
- Arm GIC or SoC documentation;
- professional teaching material;
- measured lab evidence.

## Primary-Source Requirement

Claims about the following should be grounded in primary or upstream sources whenever practical:

- register behavior;
- ISA semantics;
- ABI behavior;
- kernel APIs;
- boot flow;
- memory ordering;
- DMA/cache behavior;
- RTOS scheduling behavior;
- protocol timing;
- toolchain/linker behavior.

## Source Ledger

Every core chapter must end with a Source Ledger containing, where applicable:

- Source ID
- Title
- Organization/Author
- Type
- Version/Revision/Tag/Commit
- Section/Page/Path
- Claim or teaching point supported
- Checked date

## Version-Sensitive Material

For APIs and projects that evolve, record the exact baseline used. Examples:

- Linux kernel tag;
- U-Boot release;
- FreeRTOS/Zephyr version;
- GCC/binutils/GDB version;
- Buildroot/Yocto release;
- SoC TRM revision.

## Community Sources

Blogs, forum posts, Stack Overflow, GitHub issues, and mailing-list discussions are valuable for:

- debugging patterns;
- historical context;
- real-world failure modes;
- implementation discussion.

They must not silently replace authoritative documentation.
