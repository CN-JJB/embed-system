# P1-M07 — Struct Layout, Alignment, Endian, Serialization

> Phase 1 / M07  
> Target: **L3**, with **L4-local** byte/layout diagnosis  
> AI mode: first Challenge, Gate, and D+7 reconstruction are **AI-Free**; standards/upstream docs are allowed.  
> Planned learner time: **4.5 h MUST** (canonical roadmap). REQUIRED external reading: **~50–60 min**.

## Core boundary

本模块训练的不是“背某台机器的 struct 大小”，而是：

    C field values
    ↓
    object representation
    ↓
    implementation / ABI layout: offsets + padding + alignment
    ↓
    explicit encoder
    ↓
    declared byte order + exact offsets
    ↓
    stable external byte stream

**C object representation ≠ portable external byte format.**  
**source-level field sequence ≠ guaranteed wire/file layout.**

即使某次 `sizeof(struct)==12`，raw object bytes 也恰好与协议 12 bytes 相同，它仍然只证明当前 implementation/ABI/host 的一次观察，不自动建立 portable serialization contract。

## 1. Size, offsets, padding, alignment

For:

    struct sample {
        uint8_t type;
        uint32_t value;
        uint16_t flags;
    };

分别问：member type size、member offset、internal padding、struct alignment、tail padding、total size。用 `sizeof`, `_Alignof`, `offsetof` 测当前 implementation。N1570 约束 member address order、允许 padding，并明确 struct size 可包含 internal/trailing padding；具体 offset 仍是 implementation/ABI evidence。

Array-of-struct 的相邻元素 stride 是 `sizeof(struct)`，后续元素也必须能满足该 struct 的 alignment；这是理解 tail padding 的实用入口。Field reordering 可以改变 size，但本模块不训练“手工优化每个 struct”。

## 2. Alignment and byte-buffer casts

Alignment 是 object access contract 的一部分。不要默认这样合法：

    struct record *r = (struct record *)(buf + 1);
    use(r->value);

至少要同时问：

- address 是否满足目标 type alignment；
- byte storage 是否有可按该 type 访问的 object/effective-type contract；
- padding/layout 是否匹配 external format；
- endian 是否匹配；
- bounds 是否足够。

M07 不展开完整 strict-aliasing 课程；canonical parsing rule 是：**外部 bytes 按 bytes 显式解析，不把 byte buffer 当 struct object。**

## 3. Object representation observation

Character type 可以用于观察 object representation。Lab 02 对 `uint32_t x = 0x11223344` 使用 `unsigned char *` 逐 byte 观察。authoring x86-64 host 的观察只是 host evidence，不是 wire-format golden。

不要用 questionable pointer aliasing trick 来“聪明检测” endian。

C 的 byte 也由 `CHAR_BIT` 定义。本模块 wire format 明确采用 **8-bit octets**；codec reference 通过 `_Static_assert(CHAR_BIT == 8, ...)` 把支持范围写入 contract。

## 4. Fixed-width integers

Wire format 不应依赖 `sizeof(int)==4`。使用 `<stdint.h>` 的 exact-width types where available。N1570 §7.20.1.1 的 `intN_t/uintN_t` typedef 是可选的；存在时 exact-width representation 条件成立。

Challenge 保留 `int32_t value`。在 pinned N1570 baseline 下，若 `int32_t` 存在，它无 padding 且为 two's-complement exact-width signed type。reference code 使用 `memcpy` 在 `int32_t`/ `uint32_t` objects 之间搬运 representation，再显式编码 endian；不通过 incompatible pointer cast 取 bits。

## 5. Endianness

Endianness 是 **multi-byte value 在 byte sequence 中的 ordering**，不是 struct member order。

Canonical telemetry wire contract:

| Offset | Size | Meaning | Byte order |
|---:|---:|---|---|
| 0 | 1 | version | n/a |
| 1 | 1 | kind/type | n/a |
| 2 | 2 | flags | little-endian |
| 4 | 4 | value | little-endian |
| 8 | 4 | sequence | little-endian |

Wire size = **12 octets**.

## 6. Serialization rule

默认课程 contract 禁止把以下写法称为 stable portable serialization：

    write(fd, &some_struct, sizeof some_struct);

它最多在明确限定 same ABI/layout/endian/version 的 contract 下成立。M07 baseline 是 explicit byte encoding：`put/get_u16_le`, `put/get_u32_le`, explicit offsets, bounds, version。

`packed` attribute/pragma 只做 implementation-specific forward reference：

- packed ≠ portable protocol；
- 可能产生 misaligned members；
- cost/behavior target-specific；
- 不能解决 endian/bounds/version/effective-type contract。

Bit-fields 同样只做 warning：不要假定它们有 portable external layout。

## Codec failure contract

Challenge/reference:

- exact wire size 12；
- version 1；
- LE multi-byte fields；
- no raw struct copy；
- no byte-buffer-to-struct dereference；
- validate length/version before byte access/publication；
- decode failure leaves `*dst` **unchanged**；
- encode validates before writing output bytes；
- protocol golden bytes deterministic；host memory bytes non-golden。

## Labs

| Lab | Question | Evidence |
|---|---|---|
| [01 Layout Audit](labs/01-layout-audit/) | offsets/size/alignment? | `sizeof/_Alignof/offsetof` |
| [02 Object Bytes](labs/02-object-bytes/) | host representation bytes? | `unsigned char *` |
| [03 Field Reordering](labs/03-field-reordering/) | order changes storage layout? | size + offsets |
| [04 Explicit Codec](labs/04-explicit-codec/) | stable bytes? | golden vector |
| [05 Raw-Struct Trap](labs/05-raw-struct-trap/) | raw bytes happen to match—what does that prove? | `od` + contract audit |

## Open-source reading

Pinned future-reading: Linux **v6.18**, commit `7d0a66e4bb9081d75c82ec4957c50034cb0ea449`, `include/linux/unaligned.h`.

Teaching question: why do production low-level helpers make unaligned access and LE/BE intent explicit (for example `get_unaligned_le32` / `put_unaligned_le32`) instead of hiding them in a struct cast? This is source reading only; do not copy kernel macros into userspace curriculum.

## Fault campaign

[faults/](faults/) contains:

- F1 object layout / `sizeof(struct)` mistaken for wire contract；
- F2 host-endian write (can accidentally match LE on current host)；
- F3 unaligned typed dereference；
- F4 short input / bounds；
- F5 failure publishes partial output。

A fault need not crash to be real.

## Challenge

[Fixed Telemetry Record Codec](challenge/) is **AI-Free first pass**. Starter compiles and returns `ENOSYS`; learner implements the 12-byte codec and must pass zero, non-palindromic, signed edge, invalid-version, short-input, and failure-state tests.

## Gate

[Binary Record Boundary Audit](gate/) is **65–90 min, AI-Free**. Required stations: wire table, 3–5 hypotheses, byte evidence via `od` (or hexdump/xxd if present), host layout evidence, explicit repair, golden regression, invalid-version/short/output-state regression.

## Debug workflow

    Symptom
    ↓
    Own description
    ↓
    3–5 hypotheses
    ↓
    choose bytes / layout / bounds evidence
    ↓
    narrow scope
    ↓
    root cause in contract language
    ↓
    explicit fix
    ↓
    regression

## Spaced review

**D+1:** closed-book draw C struct vs wire format; distinguish padding/alignment/endian/encoding.  
**D+3:** predict a new struct's offsets, verify, then write a manual encoder.  
**D+7:** from empty file implement an 8–12 byte fixed record codec with encode/decode/golden/short-input test, **AI-Free**.

## Career relevance

layout awareness → ABI / later MMIO-register-structure awareness → device descriptors / firmware-kernel-user boundaries.  
explicit bytes → sensor/device protocols → binary storage / packet / DT formats later.

Do not turn a C struct into hardware/wire layout unless that specific contract says so.

## Exclusions

No MMIO/volatile/DMA/cache curriculum, network protocols/sockets, TLV/protobuf/JSON/CBOR, checksum/crypto/compression, or M09/M10 implementation.

Exact sources: [SOURCE_LEDGER.md](SOURCE_LEDGER.md).
