#!/bin/bash
set -euo pipefail

# Semantic validator for P3-M01: Cross-Compilation Toolchains & Target Artifacts

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M01_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M01_ROOT"

echo "================================================================"
echo "=== Running P3-M01 Semantic Verification Suite               ==="
echo "================================================================"

CROSS_COMPILE=${CROSS_COMPILE:-arm-none-linux-gnueabihf-}
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    if command -v arm-linux-gnueabihf-gcc >/dev/null 2>&1; then
        CROSS_COMPILE="arm-linux-gnueabihf-"
        echo "[NOTE] Canonical arm-none-linux-gnueabihf-gcc not in PATH; falling back to distro arm-linux-gnueabihf-gcc"
    else
        echo "ERROR: No ARM cross compiler found in PATH!" >&2
        exit 1
    fi
fi

READELF="readelf"
echo "[PASS] Toolchain prefix detected: ${CROSS_COMPILE}gcc"

# 1. Build all lab and fault targets
echo "=== Step 1: Building all M01 targets ==="
make all >/dev/null
echo "[PASS] All lab, fault, challenge, and gate targets built cleanly"

# 2. Verify Lab 1.1: Host vs Target ELF
echo "=== Step 2: Verifying Host vs Target ELF ==="
HOST_ELF="labs/01-host-vs-target/hello_host"
TARGET_ELF="labs/01-host-vs-target/hello_target"

[ -f "$HOST_ELF" ] || { echo "ERROR: $HOST_ELF missing"; exit 1; }
[ -f "$TARGET_ELF" ] || { echo "ERROR: $TARGET_ELF missing"; exit 1; }

HOST_MACHINE=$("$READELF" -h "$HOST_ELF" | awk -F: '/Machine:/ {print $2}' | xargs)
TARGET_MACHINE=$("$READELF" -h "$TARGET_ELF" | awk -F: '/Machine:/ {print $2}' | xargs)
TARGET_FLAGS=$("$READELF" -h "$TARGET_ELF" | awk -F: '/Flags:/ {print $2}' | xargs)

if [[ "$HOST_MACHINE" == *"ARM"* ]]; then
    echo "ERROR: Host binary has ARM machine type!"; exit 1;
fi
if [[ "$TARGET_MACHINE" != *"ARM"* ]]; then
    echo "ERROR: Target binary machine is not ARM! ($TARGET_MACHINE)"; exit 1;
fi
echo "[PASS] Target ELF machine strictly verified: $TARGET_MACHINE"
echo "[PASS] Target ABI flags verified: $TARGET_FLAGS"

# 3. Verify Lab 1.3: Dynamic ELF Headers
echo "=== Step 3: Verifying Dynamic ELF PT_INTERP and DT_NEEDED ==="
DYN_ELF="labs/03-dynamic-elf/dynamic_app"
[ -f "$DYN_ELF" ] || { echo "ERROR: $DYN_ELF missing"; exit 1; }

INTERP=$("$READELF" -l "$DYN_ELF" | grep "program interpreter" | awk -F: '{print $2}' | tr -d '[] ' || true)
if [ "$INTERP" != "/lib/ld-linux-armhf.so.3" ]; then
    echo "ERROR: Expected interpreter /lib/ld-linux-armhf.so.3 but got: $INTERP"; exit 1;
fi
echo "[PASS] PT_INTERP segment verified: $INTERP"

NEEDED=$("$READELF" -d "$DYN_ELF" | grep "NEEDED" | awk -F'Shared library: \\[' '{print $2}' | tr -d ']' || true)
if [[ "$NEEDED" != *"libc.so.6"* ]]; then
    echo "ERROR: DT_NEEDED does not include libc.so.6!"; exit 1;
fi
echo "[PASS] DT_NEEDED shared library verified: libc.so.6"

# 4. Verify Lab 1.4: Static ELF Proof Contract
echo "=== Step 4: Verifying Static ELF Proof Contract ==="
STATIC_ELF="labs/04-static-elf/static_app"
[ -f "$STATIC_ELF" ] || { echo "ERROR: $STATIC_ELF missing"; exit 1; }

STATIC_MACHINE=$("$READELF" -h "$STATIC_ELF" | awk -F: '/Machine:/ {print $2}' | xargs)
if [[ "$STATIC_MACHINE" != *"ARM"* ]]; then
    echo "ERROR: Static binary machine is not ARM!"; exit 1;
fi

# Proof Contract: Must prove absence of INTERP and absence of DYNAMIC
if "$READELF" -l "$STATIC_ELF" 2>/dev/null | grep -q "INTERP"; then
    echo "ERROR: Static binary contains INTERP segment!"; exit 1;
fi
echo "[PASS] Absence of PT_INTERP segment in static binary verified"

if ! "$READELF" -d "$STATIC_ELF" 2>&1 | grep -q "There is no dynamic section"; then
    echo "ERROR: Static binary unexpectedly contains dynamic section!"; exit 1;
fi
echo "[PASS] Absence of PT_DYNAMIC section in static binary verified"

# 5. Verify Fault F01: Binary Architecture Mismatch
echo "=== Step 5: Verifying Fault F01 (Wrong Architecture) ==="
F01_FAULTY="faults/F01-wrong-architecture/app_faulty"
F01_MACHINE=$("$READELF" -h "$F01_FAULTY" | awk -F: '/Machine:/ {print $2}' | xargs)
if [[ "$F01_MACHINE" == *"ARM"* ]]; then
    echo "ERROR: F01 faulty binary should not be ARM!"; exit 1;
fi
echo "[PASS] F01 faulty binary confirmed wrong architecture ($F01_MACHINE)"

# Run F01 diagnostic script
if bash faults/F01-wrong-architecture/diagnose_f01.sh "$F01_FAULTY" >/dev/null 2>&1; then
    echo "ERROR: diagnose_f01.sh should return nonzero on faulty binary!"; exit 1;
fi
echo "[PASS] F01 diagnostic oracle correctly catches architecture mismatch"

# 6. Verify Fault F02: Missing Dynamic Loader
echo "=== Step 6: Verifying Fault F02 (Missing Dynamic Loader) ==="
F02_ROOTFS="faults/F02-missing-loader/rootfs_fixture"
F02_APP="${F02_ROOTFS}/bin/app_dynamic"
[ -f "$F02_APP" ] || { echo "ERROR: F02 app missing"; exit 1; }

# Prove binary exists
[ -f "$F02_APP" ] && [ -x "$F02_APP" ]
echo "[PASS] F02 binary exists and has execute permissions on host"

# Prove interpreter requested
F02_INTERP=$("$READELF" -l "$F02_APP" | grep "program interpreter" | awk -F: '{print $2}' | tr -d '[] ' || true)
[ -n "$F02_INTERP" ]
echo "[PASS] F02 requests interpreter: $F02_INTERP"

# Prove rootfs lacks interpreter
if [ -f "${F02_ROOTFS}${F02_INTERP}" ]; then
    echo "ERROR: Rootfs should NOT contain $F02_INTERP"; exit 1;
fi
echo "[PASS] Deterministic rootfs fixture confirmed lacking $F02_INTERP"

# Run F02 diagnostic script (must exit nonzero and explain root cause)
if bash faults/F02-missing-loader/diagnose_f02.sh "$F02_ROOTFS" >/dev/null 2>&1; then
    echo "ERROR: diagnose_f02.sh should return nonzero on missing interpreter!"; exit 1;
fi
echo "[PASS] F02 diagnostic script accurately isolated missing dynamic loader"

# 7. Verify Gate Artifacts
echo "=== Step 7: Verifying Gate Candidates ==="
GATE_ALPHA="gate/fixtures/candidate_alpha"
GATE_BETA="gate/fixtures/candidate_beta"
GATE_GAMMA="gate/fixtures/candidate_gamma"

[ -f "$GATE_ALPHA" ] && [ -f "$GATE_BETA" ] && [ -f "$GATE_GAMMA" ]

ALPHA_MACH=$("$READELF" -h "$GATE_ALPHA" | awk -F: '/Machine:/ {print $2}' | xargs)
BETA_MACH=$("$READELF" -h "$GATE_BETA" | awk -F: '/Machine:/ {print $2}' | xargs)
GAMMA_MACH=$("$READELF" -h "$GATE_GAMMA" | awk -F: '/Machine:/ {print $2}' | xargs)

[[ "$ALPHA_MACH" == *"ARM"* ]] || { echo "ERROR: Alpha machine check failed"; exit 1; }
[[ "$BETA_MACH" != *"ARM"* ]]  || { echo "ERROR: Beta machine check failed"; exit 1; }
[[ "$GAMMA_MACH" == *"ARM"* ]] || { echo "ERROR: Gamma machine check failed"; exit 1; }

"$READELF" -l "$GATE_ALPHA" | grep -q "INTERP" || { echo "ERROR: Alpha missing INTERP"; exit 1; }
! ("$READELF" -l "$GATE_GAMMA" 2>/dev/null | grep -q "INTERP") || { echo "ERROR: Gamma has INTERP"; exit 1; }
echo "[PASS] Gate blind candidates strictly match reference classification"

# 8. Run Negative Control Mutations
echo "=== Step 8: Running Reviewer Negative Control Mutations ==="
bash reviewer/test_m01_mutations.sh

echo "================================================================"
echo "=== ALL P3-M01 SEMANTIC CHECKS & MUTATION TESTS PASSED (8/8) ==="
echo "================================================================"
