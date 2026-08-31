# Reviewer Solution — P1-M01 Gate

## Extent

`frame` 只有 10 bytes，payload 从 index 2 开始，因此最多 8 bytes；header 却声明 12。Root cause 是 **declared logical extent 未与 actual object remainder 验证**。修复应在构造 view 前验证 `declared <= sizeof frame - header_size`，而不是让 checksum 自己猜。

## Lifetime

`remember_temporary()` 返回的 view 指向 block-local array；离开 block 后 array lifetime 已结束。view object 被返回不延长 pointed-to object lifetime。修复可以让 storage 的 owner/lifetime 覆盖 consumer，或显式复制到拥有更长 lifetime 的 storage。

## Integer UB

`INT_MAX + 1` 是 signed overflow；`1 << 31` 在常见 32-bit `int` 上也无法得到可表示的 signed result。不能以一次 wrap output 作为 contract。修复要做 range check，或在明确需要 bit mask 时使用合适的 unsigned fixed-width type。

## Misleading but legal

`end = v.data + v.len` 在 `v` 表示合法 array extent 时可形成 one-past pointer；one-past pointer 可以比较/作为 loop sentinel，但不能解引用。危险感来自“它指到 object 后面”，真正边界是 **forming vs dereferencing**。

## Regression expectation

fixed code 应在 invalid frame 上拒绝、lifetime case 在 owner 活着时消费、UB case 不执行非法 signed operation，并让 legal one-past case继续通过。Sanitizer clean run 是有用 evidence，但不是全局正确性证明。
