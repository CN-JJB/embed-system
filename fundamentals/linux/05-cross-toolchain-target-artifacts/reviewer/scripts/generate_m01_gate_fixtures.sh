#!/bin/bash
set -euo pipefail

# Reviewer-isolated fixture generator for P3-M01 Gate
# Kept strictly under reviewer/ to prevent candidate mapping exposure.
# Materialized opaque fixtures are committed to the repo by the reviewer;
# learner workflows never execute this script.

OUT_DIR="${1:-fixtures}"
CROSS_COMPILE="${2:-arm-none-linux-gnueabihf-}"
HOST_CC="${HOST_CC:-gcc}"
CC="${CROSS_COMPILE}gcc"

mkdir -p "$OUT_DIR"

# Opaque candidate set (fresh variant; mapping is reviewer-only):
# -no-pie pins the dynamic candidate to ET_EXEC form across canonical and
# distro toolchains (Ubuntu gcc defaults to PIE/ET_DYN, which is not the
# assessment's intended "executable form").
printf '#include <stdio.h>\nint main(void){puts("gate-probe");return 211;}\n' | "$CC" -x c - -no-pie -O2 -o "$OUT_DIR/candidate_alpha"
echo 'int main(void){return 222;}' | "$CC" -x c - -static -O2 -o "$OUT_DIR/candidate_beta"
echo 'int main(void){return 233;}' | "$HOST_CC" -x c - -O2 -o "$OUT_DIR/candidate_gamma"
