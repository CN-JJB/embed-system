#!/usr/bin/env python3
import sys
import re

if len(sys.argv) < 2:
    print("Usage: check_concurrency.py <path-to-node_app.c>")
    sys.exit(1)

src_path = sys.argv[1]

try:
    with open(src_path, "r", encoding="utf-8", errors="replace") as f:
        src = f.read()
except Exception as e:
    print(f"[FAIL] Could not open {src_path}: {e}")
    sys.exit(1)

# Extract task_storage function body
storage_match = re.search(r"void\s+task_storage\s*\([^)]*\)\s*\{(.*?)\n\}", src, re.DOTALL)
if not storage_match:
    print("[FAIL] Function task_storage not found in src/node_app.c")
    sys.exit(1)

storage_body = storage_match.group(1)

# Find sequence of xSemaphoreTake calls in task_storage
takes = re.findall(r"xSemaphoreTake\s*\(\s*([a-zA-Z0-9_]+)", storage_body)

if len(takes) < 2:
    print(f"[FAIL] Expected at least 2 xSemaphoreTake calls in task_storage, found {len(takes)}")
    sys.exit(1)

first_lock, second_lock = takes[0], takes[1]

# In canonical total ordering, xSensorBusLock must be acquired before xTelemetryBufferLock
if first_lock == "xTelemetryBufferLock" and second_lock == "xSensorBusLock":
    print("[FAIL] Part D Concurrency Hazard: Inverted lock acquisition hierarchy in task_storage!")
    print("       task_telemetry acquires xSensorBusLock -> xTelemetryBufferLock.")
    print("       task_storage acquires xTelemetryBufferLock -> xSensorBusLock.")
    print("       Circular wait condition creates AB-BA deadlock under concurrent execution.")
    print("       iwdg_refresh is starved, causing hardware watchdog reset.")
    sys.exit(1)
elif first_lock == "xSensorBusLock" and second_lock == "xTelemetryBufferLock":
    print("[PASS] Canonical lock hierarchy verified: all tasks acquire xSensorBusLock before xTelemetryBufferLock.")
    sys.exit(0)
else:
    print(f"[FAIL] Unexpected lock ordering in task_storage: {first_lock} -> {second_lock}")
    sys.exit(1)
