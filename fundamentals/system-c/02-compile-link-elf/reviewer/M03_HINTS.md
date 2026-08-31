# M03 Reviewer Hints

> Reviewer-only. Learner Gate 前不得打开。

## Challenge hint ladder

1. `make objects` 后先 `nm build/*.o`，不要先猜 link order。
2. `main.o` 的 `registry_limit` 与 `registry.o` 的同名 symbol binding 是否真的 compatible？
3. default link object list 是否含 `format.o`？加入后是否暴露第二个问题？
4. `report_width` 应该有几处 external definition？
5. incremental correctness 不能用 clean build 证明。

## Gate grading anchors

- Must show `sampler.o` local `sampler_scale` vs consumer `U sampler_scale` evidence。
- Must show `main.o` relocation tied to named call；exact x86-64 enum不评分。
- Must show initialized vs zero-initialized data with final ELF evidence。
- Must demonstrate header dependency changed-context regression。
- A passing executable without these artifacts fails Gate evidence requirement。
