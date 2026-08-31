# Corrupted Telemetry Integration — Reviewer Reasoning

The integration is successful only if the learner changes evidence source as the fault domain changes.

| Mode | Expected first evidence | What it proves |
|---|---|---|
| good | golden vector | decoder matches declared contract |
| short | length check / ASan | seeded access exceeds available bytes |
| wrong-endian | byte vector + arithmetic | semantic interpretation contradicts LE contract |
| memory-fault | ASan | later access uses invalidated allocation |
| state-change | GDB watchpoint | exact write that corrupts an already-decoded field |

Key transfer: “binary record wrong” is a symptom family, not one debugging domain.
