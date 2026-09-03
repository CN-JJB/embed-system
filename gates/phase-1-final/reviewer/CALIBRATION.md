# Reviewer Calibration Plan: Phase 1 Final Gate

## 1. Initial State: Uncalibrated Baseline

> **Status:** **UNVERIFIED — Pending First Real Learner Attempt**

The canonical 5–6 hour budget and the 75-point passing threshold represent expert analytical estimates derived from curriculum design benchmarks. No empirical learner cohort data has yet been collected for this specific Gate.

* **Timing Calibration:** `UNVERIFIED`
* **Part Difficulty Calibration:** `UNVERIFIED`
* **Score-Threshold Calibration:** `UNVERIFIED`

Under no circumstances should reviewers or authors fabricate synthetic cohort scores, fake completion times, or mock grading distributions.

---

## 2. First-Learner Calibration Protocol

The first real learner attempt will serve as the empirical baseline:
1. **Instrumented Observation:** The reviewer logs exact start and completion timestamps for each Part.
2. **Friction Analysis:** Reviewers record:
   * Did any harness issue cause artificial time loss unrelated to the core engineering competencies?
   * Were any instructions ambiguous or misleading?
   * Did toolchain variations (e.g. GCC 13 vs 14, WSL2 vs native Linux) introduce unexpected differences?
3. **Threshold Review:**
   * If the first learner demonstrates solid conceptual mastery but runs over the 6-hour window due to boilerplate, the time budget may be adjusted.
   * If any Part shows unintended failure modes, adjustments to the rubric must be proposed via explicit PRs.

---

## 3. Governance of Calibration Changes

Any future adjustments to:
* Time limits (e.g. expanding to 6–7 hours)
* Score distributions or part passing floors
* Variant pool difficulty or harness watchdog parameters

**must be executed as explicit, reviewable Git commits and PRs** with clear evidentiary rationale.
