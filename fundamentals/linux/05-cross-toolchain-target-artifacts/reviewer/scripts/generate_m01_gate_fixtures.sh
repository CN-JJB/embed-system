#!/bin/bash
set -euo pipefail

# Reviewer-isolated fixture generator for P3-M01 Gate
# Kept strictly under reviewer/ to prevent candidate mapping exposure.

OUT_DIR="${1:-fixtures}"
CROSS_COMPILE="${2:-arm-none-linux-gnueabihf-}"
HOST_CC="${HOST_CC:-gcc}"
CC="${CROSS_COMPILE}gcc"

mkdir -p "$OUT_DIR"

# Rotated candidate set:
echo 'int main(void){return 201;}' | "$HOST_CC" -x c - -O2 -o "$OUT_DIR/candidate_alpha"
echo 'int main(void){return 202;}' | "$CC" -x c - -static -O2 -o "$OUT_DIR/candidate_beta"
echo 'int main(void){return 203;}' | "$CC" -x c - -O2 -o "$OUT_DIR/candidate_gamma"
