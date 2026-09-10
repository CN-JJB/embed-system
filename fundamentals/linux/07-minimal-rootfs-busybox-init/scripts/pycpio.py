#!/usr/bin/env python3
"""
Hermetic, reproducible Python CPIO (newc format) generator (M03).

Supports deterministic packaging of:
- directories
- symlinks
- regular files
- character / block device nodes (via manifest, no root required)

Device nodes cannot be created unprivileged on the host, so they are
described in a manifest file instead of relying on host mknod:

    <relpath> <c|b> <major> <minor> <mode-octal>

Example (devnodes.manifest):
    dev/console c 5 1 600
    dev/null c 1 3 666

Lines starting with '#' and blank lines are ignored. If <src_dir> contains
a file named 'devnodes.manifest', it is consumed automatically unless
--devnodes is given explicitly. An explicit --devnodes path overrides it.

All entries are sorted (LC_ALL=C byte order), UID/GID normalized to 0,
mtime normalized to 0, and gzip normalization is left to the caller
(gzip -n). The writer never follows symlinks.

A '--list' mode prints semantic archive metadata for validation:
    <type> <mode-octal> <major>:<minor> <size> <name>
where type is one of dir/symlink/file/char/block/fifo/socket/unknown.
"""

import os
import sys
import stat
import argparse
from signal import signal, SIGPIPE, SIG_DFL

# Downstream tools pipe '--list' into 'grep -q'/'head', which close the pipe
# early by design. Restore default SIGPIPE so the writer dies quietly instead
# of raising BrokenPipeError tracebacks.
try:
    signal(SIGPIPE, SIG_DFL)
except Exception:
    pass


def pad4(n):
    return (4 - (n % 4)) % 4


def make_header(ino, mode, uid, gid, nlink, mtime, filesize, maj, min_,
                rmaj, rmin, name):
    name_bytes = name.encode('utf-8') + b'\0'
    namesize = len(name_bytes)
    hdr = (f"070701{ino:08x}{mode:08x}{uid:08x}{gid:08x}{nlink:08x}"
           f"{mtime:08x}{filesize:08x}{maj:08x}{min_:08x}{rmaj:08x}"
           f"{rmin:08x}{namesize:08x}{0:08x}")
    hdr_bytes = hdr.encode('ascii')
    hdr_pad = b'\0' * pad4(len(hdr_bytes) + namesize)
    return hdr_bytes + name_bytes + hdr_pad


def parse_devnodes_manifest(path):
    """Parse manifest lines into [(rel, kind, major, minor, mode)]."""
    entries = []
    with open(path, 'r', encoding='utf-8') as fp:
        for lineno, raw in enumerate(fp, 1):
            line = raw.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split()
            if len(parts) != 5:
                raise ValueError(
                    f"{path}:{lineno}: expected 5 fields "
                    f"'<path> <c|b> <major> <minor> <mode>', got: {raw!r}")
            rel, kind, major_s, minor_s, mode_s = parts
            if kind not in ('c', 'b'):
                raise ValueError(
                    f"{path}:{lineno}: type must be 'c' or 'b', got {kind!r}")
            if rel.startswith('/') or '..' in rel.split('/'):
                raise ValueError(
                    f"{path}:{lineno}: path must be rootfs-relative, "
                    f"got {rel!r}")
            try:
                major = int(major_s, 0)
                minor = int(minor_s, 0)
                mode = int(mode_s, 8)
            except ValueError as exc:
                raise ValueError(
                    f"{path}:{lineno}: bad numeric field: {exc}") from exc
            if not (0 <= major <= 0xFFFF and 0 <= minor <= 0xFFFF):
                raise ValueError(
                    f"{path}:{lineno}: major/minor out of range 0..65535")
            if not (0 <= mode <= 0o7777):
                raise ValueError(
                    f"{path}:{lineno}: mode out of range 0..7777 octal")
            entries.append((rel, kind, major, minor, mode))
    # Deterministic: sort by path, dedupe (last wins is rejected: error).
    seen = set()
    for rel, _, _, _, _ in entries:
        if rel in seen:
            raise ValueError(f"{path}: duplicate entry for {rel!r}")
        seen.add(rel)
    entries.sort(key=lambda e: e[0].encode('utf-8'))
    return entries


def collect_fs_entries(src_dir):
    entries = []
    for root, dirs, files in os.walk(src_dir, followlinks=False):
        dirs.sort()
        files.sort()
        rel_root = os.path.relpath(root, src_dir)
        if rel_root != ".":
            # Skip the manifest control file itself if present.
            if os.path.basename(rel_root) != 'devnodes.manifest' or \
                    os.path.dirname(rel_root) != '.':
                entries.append(rel_root)
        for d in dirs:
            rel_path = os.path.normpath(os.path.join(rel_root, d)) \
                if rel_root != "." else d
            if rel_path not in entries:
                entries.append(rel_path)
        for f in files:
            if f == 'devnodes.manifest' and rel_root == '.':
                continue  # control file, never packaged
            rel_path = os.path.normpath(os.path.join(rel_root, f)) \
                if rel_root != "." else f
            entries.append(rel_path)
    return sorted(list(set(entries)))


def write_cpio(src_dir, out_fp, devnodes=None):
    ino_counter = 1
    fs_entries = collect_fs_entries(src_dir)
    manifest_rels = {e[0] for e in (devnodes or [])}
    # Manifest must not collide with a real on-disk path.
    overlap = manifest_rels.intersection(set(fs_entries))
    if overlap:
        raise ValueError(
            f"devnodes manifest collides with on-disk entries: "
            f"{sorted(overlap)} (remove the host file or manifest line)")

    # Parent dirs of manifest nodes are expected to exist on disk
    # (e.g. 'dev'); the writer does not synthesize missing parents.

    # Merge + deterministic sort (byte order).
    merged = [(rel, None) for rel in fs_entries] + \
        [(rel, spec) for rel, *spec in (devnodes or [])]
    merged.sort(key=lambda e: e[0].encode('utf-8'))

    for rel, spec in merged:
        if spec is not None:
            kind, major, minor, mode_bits = spec
            if kind == 'c':
                mode = stat.S_IFCHR | mode_bits
            else:
                mode = stat.S_IFBLK | mode_bits
            hdr = make_header(ino_counter, mode, 0, 0, 1, 0, 0,
                              0, 0, major, minor, rel)
            out_fp.write(hdr)
            ino_counter += 1
            continue
        full_path = os.path.join(src_dir, rel)
        st = os.lstat(full_path)
        mode = st.st_mode
        ino = ino_counter
        ino_counter += 1
        uid = 0
        gid = 0
        mtime = 0  # reproducible fixed timestamp

        if stat.S_ISLNK(mode):
            target = os.readlink(full_path).encode('utf-8')
            filesize = len(target)
            hdr = make_header(ino, mode, uid, gid, 1, mtime, filesize,
                              0, 0, 0, 0, rel)
            out_fp.write(hdr)
            out_fp.write(target + (b'\0' * pad4(filesize)))
        elif stat.S_ISDIR(mode):
            hdr = make_header(ino, mode, uid, gid, 2, mtime, 0,
                              0, 0, 0, 0, rel)
            out_fp.write(hdr)
        elif stat.S_ISREG(mode):
            filesize = st.st_size
            hdr = make_header(ino, mode, uid, gid, 1, mtime, filesize,
                              0, 0, 0, 0, rel)
            out_fp.write(hdr)
            with open(full_path, "rb") as f:
                data = f.read()
                out_fp.write(data + (b'\0' * pad4(filesize)))
        elif stat.S_ISCHR(mode) or stat.S_ISBLK(mode):
            rdev = st.st_rdev
            rmaj = os.major(rdev)
            rmin = os.minor(rdev)
            hdr = make_header(ino, mode, uid, gid, 1, mtime, 0,
                              0, 0, rmaj, rmin, rel)
            out_fp.write(hdr)
        elif stat.S_ISFIFO(mode):
            hdr = make_header(ino, mode, uid, gid, 1, mtime, 0,
                              0, 0, 0, 0, rel)
            out_fp.write(hdr)
        else:
            raise ValueError(
                f"unsupported file type for deterministic archive: {rel}")

    # Trailer
    trailer_hdr = make_header(ino_counter, 0, 0, 0, 1, 0, 0,
                              0, 0, 0, 0, "TRAILER!!!")
    out_fp.write(trailer_hdr)

    # Pad to 512 bytes block
    total = out_fp.tell()
    pad512 = (512 - (total % 512)) % 512
    out_fp.write(b'\0' * pad512)


def iter_cpio_entries(cpio_path):
    """Yield dicts with name/mode/filesize/rmaj/rmin for each entry."""
    with open(cpio_path, "rb") as fp:
        while True:
            hdr_bytes = fp.read(110)
            if len(hdr_bytes) < 110:
                break
            magic = hdr_bytes[:6].decode('ascii', errors='ignore')
            if magic not in ("070701", "070702"):
                break
            mode = int(hdr_bytes[14:22], 16)
            filesize = int(hdr_bytes[54:62], 16)
            namesize = int(hdr_bytes[94:102], 16)
            rmaj = int(hdr_bytes[78:86], 16)
            rmin = int(hdr_bytes[86:94], 16)

            raw_name = fp.read(namesize)
            pad_name = pad4(110 + namesize)
            if pad_name > 0:
                fp.read(pad_name)

            name = raw_name.rstrip(b'\0').decode('utf-8', errors='ignore')
            if name == "TRAILER!!!":
                break
            filedata = fp.read(filesize)
            pad_file = pad4(filesize)
            if pad_file > 0:
                fp.read(pad_file)
            yield {"name": name, "mode": mode, "filesize": filesize,
                   "rmaj": rmaj, "rmin": rmin, "data": filedata}


def entry_type(mode):
    if stat.S_ISDIR(mode):
        return "dir"
    if stat.S_ISLNK(mode):
        return "symlink"
    if stat.S_ISREG(mode):
        return "file"
    if stat.S_ISCHR(mode):
        return "char"
    if stat.S_ISBLK(mode):
        return "block"
    if stat.S_ISFIFO(mode):
        return "fifo"
    if stat.S_ISSOCK(mode):
        return "socket"
    return "unknown"


def cmd_list(cpio_path):
    for e in iter_cpio_entries(cpio_path):
        print(f"{entry_type(e['mode']):8s} "
              f"{e['mode'] & 0o7777:04o} "
              f"{e['rmaj']}:{e['rmin']} "
              f"{e['filesize']:8d} {e['name']}")


def extract_cpio(cpio_path, dest_dir):
    # NOTE: unprivileged extraction cannot recreate char/block nodes via
    # mknod. Device entries are recorded as '<path>.nodeinfo' sidecars
    # (type/mode/major/minor) so validators can still audit intent;
    # the authoritative check is '--list' over CPIO metadata itself.
    os.makedirs(dest_dir, exist_ok=True)
    for e in iter_cpio_entries(cpio_path):
        name = e["name"]
        mode = e["mode"]
        target_path = os.path.join(dest_dir, name)
        parent_dir = os.path.dirname(target_path)
        if parent_dir:
            os.makedirs(parent_dir, exist_ok=True)
        filedata = e["data"]
        if stat.S_ISDIR(mode):
            os.makedirs(target_path, exist_ok=True)
            os.chmod(target_path, mode & 0o7777)
        elif stat.S_ISLNK(mode):
            link_target = filedata.decode('utf-8', errors='ignore')
            if os.path.islink(target_path) or os.path.exists(target_path):
                os.unlink(target_path)
            os.symlink(link_target, target_path)
        elif stat.S_ISREG(mode):
            if os.path.exists(target_path) or os.path.islink(target_path):
                os.unlink(target_path)
            with open(target_path, "wb") as out_f:
                out_f.write(filedata)
            os.chmod(target_path, mode & 0o7777)
        elif stat.S_ISCHR(mode) or stat.S_ISBLK(mode):
            kind = 'char' if stat.S_ISCHR(mode) else 'block'
            marker = target_path + ".nodeinfo"
            with open(marker, "w", encoding="utf-8") as mf:
                mf.write(f"type={kind} mode={mode & 0o7777:04o} "
                         f"major={e['rmaj']} minor={e['rmin']} "
                         f"name={name}\n")
        elif stat.S_ISFIFO(mode):
            try:
                if os.path.exists(target_path):
                    os.unlink(target_path)
                os.mkfifo(target_path, mode & 0o7777)
            except OSError:
                pass


def main(argv):
    ap = argparse.ArgumentParser(description="Deterministic newc CPIO tool")
    ap.add_argument("--extract", "-x", action="store_true",
                    help="extract archive")
    ap.add_argument("--list", "-t", action="store_true",
                    help="list archive metadata (type/mode/major:minor)")
    ap.add_argument("--devnodes", default=None,
                    help="device-node manifest path")
    ap.add_argument("src", help="rootfs dir | cpio file")
    ap.add_argument("dst", nargs="?", default=None,
                    help="output cpio | dest dir")
    args = ap.parse_args(argv)

    if args.list:
        cmd_list(args.src)
        return 0
    if args.extract:
        if not args.dst:
            print("extract requires <cpio> <destdir>", file=sys.stderr)
            return 1
        extract_cpio(args.src, args.dst)
        return 0
    # pack mode: src=rootfs dst=cpio
    if not args.dst:
        print("pack requires <rootfs> <out.cpio>", file=sys.stderr)
        return 1
    manifest = args.devnodes
    if manifest is None:
        auto = os.path.join(args.src, "devnodes.manifest")
        if os.path.isfile(auto):
            manifest = auto
    devnodes = parse_devnodes_manifest(manifest) if manifest else None
    with open(args.dst, "wb") as fp:
        write_cpio(args.src, fp, devnodes)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
