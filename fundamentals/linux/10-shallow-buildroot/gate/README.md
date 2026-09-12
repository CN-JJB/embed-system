# P3-M06 Module Gate — Buildroot Configuration and Provenance Diagnosis (AI-Free)

**AI policy: AI-Free (strict).** Official Buildroot documentation and source,
the Linux kernel documentation and source, and the QEMU documentation are
permitted. No AI assistance for the diagnosis, the repair, or the written
reasoning.

**Time:** ~40 min.

**Prerequisite:** you have completed Labs 6.1–6.5 and the Challenge.

---

## 1. Situation

`gate/fixtures/starter.conf` is a Buildroot configuration fragment. It is well
formed: every symbol exists in the real 2026.05.2 source tree, nothing is defined
twice, and no value contains shell content.

It nevertheless does **not** describe the canonical Phase 3 appliance. **More
than one fact in it is wrong**, and the defects are of different kinds.

```text
EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED
A build from this fragment is expected to succeed.  Some of the defects are
invisible to any check that only asks "did the build finish?" or "does an image
file exist?".  You must therefore reason from the configuration's *semantics*
and from the artifact classes it produces, not from a build exit status.
```

---

## 2. Your task

1. Repair the fragment and write it to `gate/build/candidate.conf`.
2. Write `gate/build/DIAGNOSIS.md`.
3. If you have a Buildroot source tree available, build from your repaired
   fragment and audit the result:

   ```bash
   make audit OUTPUT=/path/to/br-output
   ```

   and, where the environment permits, boot the appliance and bind the capture:

   ```bash
   bash scripts/run_buildroot_appliance.sh OUTPUT_DIR LOG PROVENANCE
   python3 scripts/verify_appliance_runtime.py OUTPUT_DIR/images/rootfs.cpio.gz \
       PROVENANCE LOG --overlay fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay
   ```

---

## 3. Required reasoning (this is what is actually graded)

`DIAGNOSIS.md` must contain the full chain:

```text
Symptom → Own Description → 3–5 Hypotheses → Experiment → Evidence
→ Narrow Scope → Root Cause → Fix → Regression
```

and must additionally answer, explicitly:

1. **Artifact class.** For each defect, state which artifact class it corrupts —
   the toolchain, the kernel, the staging tree, the packaged image, or the
   launch contract — and why. Name the file each defect would ultimately affect.
2. **Provenance of the correct value.** State where the correct value comes
   from: the Buildroot source tree (file and, where practical, line), the
   documented manual, or an artifact you inspected. "It matches the reference
   file" is **not** acceptable.
3. **Build success vs deployable success.** Give one concrete example, from this
   configuration, of a defect that a successful `make` cannot detect.
4. **Non-proof.** State at least two things your evidence does **not** establish.
   At least one must concern the difference between "the image contains the
   customization" and "the customization executed on the target".

---

## 4. Marking

| Weight | Criterion |
|---:|---|
| 30% | Every seeded defect is repaired correctly, verified semantically. |
| 25% | Each defect is mapped to the artifact class it corrupts. |
| 20% | Correct-value provenance is argued from the source tree or manual. |
| 15% | The build-success-vs-deployable-success example is concrete and correct. |
| 10% | Non-proof statements are correct, specific, and non-trivial. |

Pass mark: **75%**, with the semantic-repair component at **≥ 60%**.

---

## 5. Evidence boundary you must respect in your write-up

* A configuration that parses is not a configuration that is correct.
* A successful build is not a boot.
* A boot is not a verified appliance.
* `output/target/` is a staging view; it is not the image you deploy.
* A file present in the image is not proof that anything executed it.
* A console log is not evidence about *your* image unless it is bound to it
  (executed argv + image identity + overlay presence).
