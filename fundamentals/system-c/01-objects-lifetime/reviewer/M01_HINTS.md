# Reviewer Hints — M01

Do not expose this file before the learner has recorded a hypothesis.

## `span_u8`

- **Hint 1 — direction:** 把每个函数写成“先验证 contract，再做 pointer arithmetic”。
- **Hint 2 — mechanism:** bounds check 应避免先计算一个可能 overflow 的 sum。
- **Hint 3 — tool/docs:** 查 N1570 §6.5.6；对 copy overlap 再查 `memmove(3)` contract。

## Fault F2 / Gate extent

- **Hint 1:** 区分 allocation extent 与 logical protocol extent。
- **Hint 2:** sanitizer 只看到它 instrument 的 memory boundary，不知道业务 payload 长度。
- **Hint 3:** breakpoint 在消费 `len` 的函数入口，比较 `len`、真实 header/payload contract 与 memory bytes。

## Gate lifetime / UB

- **Hint 1:** pointer 数值仍可打印，不代表 pointed-to lifetime 仍有效。
- **Hint 2:** signed integer 与 shift 的合法域不是“机器会怎么 wrap”的问题。
- **Hint 3:** 对照 ASan/UBSan 的 fault class，再回到 N1570 判断 root cause。
