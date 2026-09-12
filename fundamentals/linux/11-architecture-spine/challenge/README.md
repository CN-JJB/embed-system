# P3-M07 Challenge — Short-Descriptor Attribute Fault

**AI policy: AI-Free (first scored attempt).** Official ARM architecture
documents (DDI 0406C.d, DEN 0013D), the pinned Linux 6.18.50 source, and the
module's taught fixtures are permitted. No AI assistance for the diagnosis
or the repair.

**Time:** ~25 min.

---

## 1. Situation

`challenge/fixtures/starter_descriptor.json` is a short-descriptor fixture in
the taught `entries` shape (`level` + `word` per entry, plus the frozen
`assumption_stamp`). It is well formed: every word parses as a 32-bit ARMv7
short descriptor, no tool error is involved, and the file itself is valid
JSON.

It nevertheless does **not** describe a canonical mapping: at least one encoded
field does not hold a value that is valid under the frozen `assumption_stamp`.
The instance (base, level and encoding) is unfamiliar — it is not the taught
DRAM golden, not the taught PL011 window, and not the tutorial's worked values.
How many fields are affected, and which, is for you to determine; §5 offers
bounded hints if you get stuck.

---

## 2. Your task

Produce a repaired fixture at `challenge/build/candidate.json` plus a written
diagnosis.

```bash
make provision          # stages the opaque starter fixture as your candidate
# ... your analysis and repair (edit the word, not the harness) ...
make check              # learner-safe format self-check
```

Repair it by editing the descriptor word — this is a data artifact, and the
decoder will reject anything that is not a well-formed short descriptor.
You may use:

```bash
python3 scripts/decode_short_desc.py --level 1 --word 0x<your-word>
python3 scripts/decode_short_desc.py challenge/build/candidate.json
```

to inspect your own candidate's fields. Those tools report your candidate's
semantics; they do not reveal the scored answer.

---

## 3. What you must submit

1. `challenge/build/candidate.json` — the repaired fixture (same shape,
   same `assumption_stamp`, corrected word).
2. `challenge/build/DIAGNOSIS.md` — the full chain:

```text
Symptom → Own Description → 3–5 Hypotheses → Experiment → Evidence
→ Narrow Scope → Root Cause → Fix → Regression
```

with Observation / Interpretation / Non-Proof kept separate, and at least one
explicit statement of what your evidence does **not** prove.

Your diagnosis must cite **where in ARM DDI 0406C.d** the relationship you
are relying on is defined (table/section, e.g. the AP table and the
TEX/C/B mapping under your frozen PRRR/NMRR), and why the frozen
`assumption_stamp` matters. "Because the reference file says so" is not a
justification.

---

## 4. Marking

| Weight | Criterion |
|---:|---|
| 45% | The repaired fixture decodes to the canonical memory type with valid permissions, verified semantically. |
| 25% | The diagnosis names the correct field and the mechanism it controls. |
| 20% | The evidence presented actually discriminates between the hypotheses. |
| 10% | The non-proof statement is correct and specific. |

A fixture that merely *mentions* the right field name in a comment does not
score. A diagnosis that reaches the right conclusion from a fabricated
observation does not score.

---

## 5. Bounded hints (AI-Hint level — use only if stuck)

<details>
<summary>Hint 1 — where the defect lives</summary>

The defect is in the **memory-attribute or permission encoding**, not in the
base address, not in the level/class, and not in JSON formatting. Ask which
three bits decide Normal vs Device under your frozen `assumption_stamp`, and
which three bits decide who may access the mapping.

</details>

<details>
<summary>Hint 2 — read the table, not a summary</summary>

Decode your starter word field by field (class, AP, TEX, C, B, S, XN) and
compare each against the taught goldens' decode — not against their hex
strings. One field's value has no valid meaning under the frozen contract.

</details>

<details>
<summary>Hint 3 — the consequence</summary>

A mapping that the hardware treats as cacheable Normal when it should be
Device (or that faults on access when it should be accessible) fails at
runtime in ways no "the file parses" check can detect. Name which one your
starter is.

</details>
