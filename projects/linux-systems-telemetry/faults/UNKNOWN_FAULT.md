# AI-Free Unknown Project Fault
Seed: a reviewer may change queue close so it marks `closed` but does not broadcast `not_empty`. Do not reveal this seed to the learner before first pass.

Required submission: Symptom -> Own Description -> 3–5 Hypotheses -> First Evidence + Why -> Observation -> Narrow Scope -> Root Cause -> Fix -> Regression. A patch without evidence does not pass. Regression must include an empty consumer blocked before close, close/wakeup, join, and queue destroy.
