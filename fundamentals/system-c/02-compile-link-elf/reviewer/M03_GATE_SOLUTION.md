# M03 Gate — Reviewer Solution Notes

Reviewer fixed source tree lives in [`m03-gate-fixed/`](m03-gate-fixed/).

Expected coherent repair:

1. `sampler_scale` satisfies external declaration instead of being file-local `static`.
2. `report.o` is included in final link.
3. Make uses generated header dependencies (`-MMD -MP` + `-include`) or an equivalent correct explicit graph.
4. No unrelated scope expansion.

Verified reviewer regression on authoring host:

```text
gate total=12 dropped=1
```

Evidence anchors:

- fixed `nm build/sampler.o`: `T sampler_scale` on authoring host;
- `readelf -r build/main.o`: relocation references `sampler_record` (and `report_emit`);
- final `readelf -S gate_app`: `.text`, `.rodata`, `.data`, `.bss` present;
- no-change second Make is a no-op; generated `.d` files carry header edges.

Do not grade exact addresses or `R_X86_64_*` spelling.
