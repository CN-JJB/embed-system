# P3-M07 Module Gate — Architecture Transfer (AI-Free)

**AI policy: AI-Free (strict).** Official ARM documents (DDI 0406C.d,
DEN 0013D), the pinned Linux 6.18.50 source and docs, and the QEMU manual are
permitted. No AI assistance for the diagnosis, the repair, or the written
reasoning.

**Time:** ~40 min.

**Prerequisite:** you have completed Labs 7.1–7.4 and the Challenge.

---

## 1. Situation

`gate/fixtures/starter_combined.json` is a combined architecture fixture. It
is well formed: every descriptor word parses, every maps line has the
`address perms offset dev inode pathname` shape, the disassembly text is
syntactically plausible, and the file is valid JSON.

It nevertheless does **not** describe a canonical appliance state: some of the
facts it asserts are wrong. The inspection surface is the whole file — the
process-map listing, the SVC disassembly listing, the short descriptors, the
user/kernel classification, and the effective-configuration binding — and the
VAs and encodings are unfamiliar rather than replays of anything you have
already practised. How many facts are wrong, and which, is for you to
determine.

```text
EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED
A static "it parses" check cannot expose these defects. You must reason from
the encoded fields, the effective frozen configuration, and the executed-path
evidence — not from a file's existence or its comments.
```

---

## 2. Your task

1. Repair the fixture and write it to `gate/build/candidate.json`.
2. Write `gate/build/DIAGNOSIS.md`.
3. Self-check without reviewer tooling:

   ```bash
   make provision          # stages the opaque starter as your candidate
   # ... your analysis and repair ...
   make check              # learner-safe format self-check
   ```

   `make check` verifies packaging and format only. Semantic conformance is
   graded by the reviewer oracle.

---

## 3. Required reasoning (this is what is actually graded)

`DIAGNOSIS.md` must contain the full chain:

```text
Symptom → Own Description → 3–5 Hypotheses → Experiment → Evidence
→ Narrow Scope → Root Cause → Fix → Regression
```

and must additionally answer, explicitly:

1. **Aspect class.** For each defect, state which aspect it corrupts —
   descriptor permission, descriptor memory type, process-map classification,
   SVC executed-path proof, or split/binding reasoning — and why. Name the
   field or line each defect would ultimately affect.
2. **Provenance of the correct value.** State where the correct value comes
   from: the ARM ARM table/section, the effective frozen config, the maps
   range match, or the objdump mnemonic line. "It matches the reference
   file" is **not** acceptable.
3. **Comment vs evidence.** Give one concrete example, from this fixture, of
   a defect where a comment or filename looks right but the effective
   encoding/proof is wrong.
4. **Non-proof.** State at least two things your evidence does **not**
   establish. At least one must concern the difference between "the fixture
   decodes" and "the live kernel used that descriptor".

---

## 4. Marking

| Weight | Criterion |
|---:|---|
| 30% | Every seeded defect is repaired correctly, verified semantically. |
| 25% | Each defect is mapped to the aspect class it corrupts. |
| 20% | Correct-value provenance is argued from the architecture/config/artifact. |
| 15% | The comment-vs-evidence example is concrete and correct. |
| 10% | Non-proof statements are correct, specific, and non-trivial. |

Pass mark: **75%**, with the semantic-repair component at **≥ 60%**.

---

## 5. Evidence boundary you must respect in your write-up

* A descriptor that parses is not a descriptor that is correct.
* A comment that names `svc` is not an executed `svc`.
* An address printed in prose is not a mapping; only a range match in a
  well-formed maps line counts.
* A split claim in a comment is not an effective configuration.
* A fixture that decodes is not proof the live kernel used it.
* A console log is not evidence about *your* artifact set unless it is bound
  to it (executed argv + artifact identity + mapping presence).
