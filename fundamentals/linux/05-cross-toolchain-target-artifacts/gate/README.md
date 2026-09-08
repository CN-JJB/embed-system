# P3-M01 Module Gate — AI-Free Artifact Evaluation Exam

> **AI Policy:** Strict AI-Free. Official man-pages and Binutils docs allowed.

## Instructions
1. Run `make all` inside `gate/` to verify that the three provisioned blind candidate binaries are in place:
   - `fixtures/candidate_alpha`
   - `fixtures/candidate_beta`
   - `fixtures/candidate_gamma`
2. You must evaluate each candidate independently using GNU Binutils:
   - Machine architecture from `readelf -h`
   - Program headers (`readelf -l`)
   - Dynamic dependencies (`readelf -d`)
3. Determine:
   - Which binary is compiled for the wrong architecture?
   - Which binary is dynamically linked and will fail if `/lib/ld-linux-armhf.so.3` is missing?
   - Which binary is statically linked and ready to run in a minimal rootfs with zero shared libraries?
4. Fill out your findings in `gate_manifest.template`.
5. Submit to reviewer for scoring.

> [!CAUTION]
> A determination without verifiable command output from `readelf` will be rejected. Remember that `readelf -h` alone does NOT prove static linkage!
