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

takes = re.findall(r"xSemaphoreTake\s*\(", storage_body)
gives = re.findall(r"xSemaphoreGive\s*\(", storage_body)

if len(takes) > 0 and len(gives) >= len(takes):
    print("[PASS] Part D concurrency safety contract satisfied.")
    sys.exit(0)
else:
    print("[FAIL] Part D concurrency safety contract not satisfied; collect required evidence and diagnose.")
    sys.exit(1)
