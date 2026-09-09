# Lab 1.5 — Artifact Audit Scripting

## Objective
1. Inspect arbitrary binary artifacts.
2. Automate classification using `readelf -h`, `readelf -l`, and `readelf -d`.
3. Detect architecture mismatches and missing loader requirements before deploying binaries to a target rootfs.

## Usage
```bash
chmod +x audit_artifacts.sh
./audit_artifacts.sh ../01-host-vs-target/
./audit_artifacts.sh ../03-dynamic-elf/dynamic_app
./audit_artifacts.sh ../04-static-elf/static_app
```
