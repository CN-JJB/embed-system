# M03 Challenge — Reviewer Solution Notes

Reference fixed tree: [`m03-challenge-fixed/`](m03-challenge-fixed/).

Coherent repair:

- `registry_limit` satisfies the header's external API contract;
- only `format.c` owns the external `report_width` definition; `report.c` uses the header declaration;
- final link includes `format.o`;
- generated header dependencies use `-MMD -MP` + `-include`.

Authoring regression **VERIFIED**:

```text
total=9 samples=2 width=48
```

`nm` proof after fix: consumer `main.o` still has `U registry_limit` (normal pre-link reference), provider `registry.o` has global `T registry_limit`; one global `D report_width` remains in `format.o`.
