# M08 Challenge Solution Reasoning

Reference code: `challenge_fixed.c` demonstrates explicit LE decoding and robust read-until-exact behavior for the repaired slice. It is not meant to replace the learner's evidence report.

Expected evidence choices:

- memory: ASan first; root cause is freed allocation retained across later access;
- endian: deterministic input bytes + LE contract; sanitizer need not report anything;
- state: watch the specific sequence field and stop on the write;
- file: inspect return/errno before tracing the OS boundary.

A correct fix without the evidence-selection rationale is incomplete for M08.
