# Reviewer Postmortem — Variant B2 (Family B-FD)

## Hidden Seed Specification
* **Component:** `variants/b2/spool.c:spool_rotate`
* **Defect:** `spool_rotate` opens a new file descriptor for the rotated segment (`new_fd = open(...)`) and reassigns `mgr->current_fd = new_fd`, but fails to close the previously open file descriptor (`mgr->current_fd`).
* **Broken Contract:** File Descriptor Ownership & Lifecycle contract. Reassigning a descriptor handle without closing the previously owned descriptor leaks the underlying kernel file description, leading to descriptor exhaustion (`EMFILE`).

## Reference Repair
In `spool_rotate`:
```c
int new_fd = open(new_path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
if (new_fd < 0) {
    return -1;
}
if (mgr->current_fd >= 0) {
    close(mgr->current_fd);
}
mgr->current_fd = new_fd;
```

## Evidence & Verification
* **Reproducing:** `./repro` reports descriptor growth from baseline, logging `leaked descriptors`.
* **Fixing:** Closing the existing descriptor before reassigning the handle restores a constant descriptor count in `/proc/self/fd`.
