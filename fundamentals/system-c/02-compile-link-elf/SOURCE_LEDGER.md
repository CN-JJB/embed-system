# P1-M03 Source Ledger

> Checked: **2026-08-30**. Tutorial execution baseline is **GCC 14.2.0 / GNU binutils 2.44 / GNU Make 4.4.1 / Linux x86_64** because that is the actually verified host. Moving online documentation is explicitly separated from this pinned tutorial baseline.

| ID | Source | Organization / Author | Type | Exact section/path | Version / tag / commit | URL | Checked | Teaching use | Version risk |
|---|---|---|---|---|---|---|---|---|---|
| M03-S01 | GCC Manual | GNU / GCC | official docs | `Options Controlling the Kind of Output`; `-E`, `-S`, `-c`, `-o`, `-v`; preprocessor dependency options | **GCC 14.2.0** pinned tutorial baseline | https://gcc.gnu.org/onlinedocs/gcc-14.2.0/gcc/ | 2026-08-30 | translation stages; `-MMD/-MP` explanation | Medium; current upstream latest is **GCC 16.2 (2026-08-07)**. Pin retained for verified evidence. |
| M03-S02 | GNU Binary Utilities | GNU / Sourceware | official docs | `nm`; `readelf -S/-s/-r`; `objdump -d/-r`; `size` | **binutils 2.44** | https://sourceware.org/binutils/docs-2.44/ | 2026-08-30 | binary evidence for symbols/sections/relocations/disassembly | Low–Medium; current upstream latest is **binutils 2.47 (2026-07-26)**; output/details vary by target/version |
| M03-S03 | GNU `ld` manual | GNU / Sourceware | official docs | selected relocation/link concepts only | **binutils 2.44** | https://sourceware.org/binutils/docs-2.44/ld.html | 2026-08-30 | linker role; relocation terminology | Medium; backend/target details vary |
| M03-S04 | GNU make Manual | GNU / FSF | official docs | rule anatomy; prerequisites/recipes; variables; `.PHONY`; pattern rules; include/dependency basics | **GNU Make 4.4.1** | https://www.gnu.org/software/make/manual/make.html | 2026-08-30 | minimal engineering Make scope | Low; tutorial baseline equals verified host |
| M03-S05 | System V ABI, Generic ABI / ELF | System V ABI maintainers / Xinuos-hosted gABI | primary ABI specification | Object files; Sections; Symbol Table; Relocation | **ELF gABI concepts; online 4.3 DRAFT is moving** | https://gabi.xinuos.com/ | 2026-08-30 | normative object-format mental model | Medium; online draft moves, so claims stay at stable generic concepts |
| M03-S06 | System V ABI Edition 4.1 reference | SCO / System V ABI historical publication | primary ABI reference | ELF object-file selected material | **Edition 4.1** | https://refspecs.linuxfoundation.org/elf/ | 2026-08-30 | stable cross-check for ELF terms | Low for historical baseline; not “latest” |
| M03-S07 | AMD64 System V ABI | x86-64 psABI project | host psABI | relocation names only when interpreting authoring-host evidence | published **1.0 (2018-01-28)**; moving upstream exists | https://gitlab.com/x86-psABIs/x86-64-ABI | 2026-08-30 | explain that `R_X86_64_*` names are target-specific | High if treated as universal; therefore SHOULD/reference only |
| M03-S08 | Computer Systems: A Programmer's Perspective, 3e | Randal E. Bryant / David R. O'Hallaron | classic book | Ch. 7 §§7.1–7.7 REQUIRED; selected later overview SHOULD; shared-library depth skipped | 3rd ed. | https://csapp.cs.cmu.edu/3e/home.html | 2026-08-30 | stable linking mental model | Low concept risk; copyrighted—do not copy prose/figures |
| M03-S09 | Phase 1 Foundations Curriculum Design | this repository | Leader-approved design input | P1-M03 | branch baseline `curriculum/phase-1-foundations` @ `43d73631522ccfa7adeb7c7b0a7b91e3fe9a5af0` | ../../../research/phase-1/2026-08-31-foundations-curriculum-design.md | 2026-08-30 | preserve approved scope/depth/budget | Repository-controlled |

## Pinned baseline vs current upstream

- **Tutorial baseline:** GCC 14.2.0, binutils 2.44, Make 4.4.1, because those are the tools actually executed for this implementation.
- **Current upstream at check date:** GCC **16.2** (2026-08-07), binutils **2.47** (2026-07-26), GNU Make **4.4.1**. The tutorial does **not** silently reinterpret captured GCC 14.2/binutils 2.44 evidence as coming from newer versions.
- Generic ELF concepts are cross-checked against gABI; host-specific x86-64 relocation names are evidence only and are not memorization requirements.

## Reading budget

REQUIRED target: **65–75 min** total.

- GCC/binutils/make selected docs: ~20–25 min guided lookup, not cover-to-cover.
- ELF selected sections: ~10 min with Lab 03/04 open beside them.
- CS:APP Ch. 7 §§7.1–7.7: ~40 min selective reading for the specific chapter questions.

## Copyright / license note

No third-party diagram or book text is copied. Mermaid diagrams and labs are original. GNU manuals / ABI documents are linked and paraphrased. CS:APP is used as a selective reading assignment only.
