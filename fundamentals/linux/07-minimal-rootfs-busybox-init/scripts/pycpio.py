#!/usr/bin/env python3
"""
Hermetic, reproducible Python CPIO (newc format) generator.
Used to package rootfs into initramfs archives without host tool dependencies.
"""

import os
import sys
import stat

def pad4(n):
    return (4 - (n % 4)) % 4

def make_header(ino, mode, uid, gid, nlink, mtime, filesize, maj, min_, rmaj, rmin, name):
    name_bytes = name.encode('utf-8') + b'\0'
    namesize = len(name_bytes)
    hdr = f"070701{ino:08x}{mode:08x}{uid:08x}{gid:08x}{nlink:08x}{mtime:08x}{filesize:08x}{maj:08x}{min_:08x}{rmaj:08x}{rmin:08x}{namesize:08x}{0:08x}"
    hdr_bytes = hdr.encode('ascii')
    hdr_pad = b'\0' * pad4(len(hdr_bytes) + namesize)
    return hdr_bytes + name_bytes + hdr_pad

def write_cpio(src_dir, out_fp):
    ino_counter = 1
    entries = []

    for root, dirs, files in os.walk(src_dir):
        dirs.sort()
        files.sort()
        rel_root = os.path.relpath(root, src_dir)
        if rel_root != ".":
            entries.append(rel_root)
        for d in dirs:
            rel_path = os.path.normpath(os.path.join(rel_root, d)) if rel_root != "." else d
            if rel_path not in entries:
                entries.append(rel_path)
        for f in files:
            rel_path = os.path.normpath(os.path.join(rel_root, f)) if rel_root != "." else f
            entries.append(rel_path)

    # Sort entries deterministically
    entries = sorted(list(set(entries)))

    for rel in entries:
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
            hdr = make_header(ino, mode, uid, gid, 1, mtime, filesize, 0, 0, 0, 0, rel)
            out_fp.write(hdr)
            out_fp.write(target + (b'\0' * pad4(filesize)))
        elif stat.S_ISDIR(mode):
            hdr = make_header(ino, mode, uid, gid, 2, mtime, 0, 0, 0, 0, 0, rel)
            out_fp.write(hdr)
        elif stat.S_ISREG(mode):
            filesize = st.st_size
            hdr = make_header(ino, mode, uid, gid, 1, mtime, filesize, 0, 0, 0, 0, rel)
            out_fp.write(hdr)
            with open(full_path, "rb") as f:
                data = f.read()
                out_fp.write(data + (b'\0' * pad4(filesize)))

    # Trailer
    trailer_hdr = make_header(ino_counter, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, "TRAILER!!!")
    out_fp.write(trailer_hdr)

    # Pad to 512 bytes block
    total = out_fp.tell()
    pad512 = (512 - (total % 512)) % 512
    out_fp.write(b'\0' * pad512)

def extract_cpio(cpio_path, dest_dir):
    os.makedirs(dest_dir, exist_ok=True)
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

            raw_name = fp.read(namesize)
            pad_name = pad4(110 + namesize)
            if pad_name > 0:
                fp.read(pad_name)

            name = raw_name.rstrip(b'\0').decode('utf-8', errors='ignore')
            if name == "TRAILER!!!":
                break

            target_path = os.path.join(dest_dir, name)
            parent_dir = os.path.dirname(target_path)
            if parent_dir:
                os.makedirs(parent_dir, exist_ok=True)

            filedata = fp.read(filesize)
            pad_file = pad4(filesize)
            if pad_file > 0:
                fp.read(pad_file)

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

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} [--extract|-x] <args>", file=sys.stderr)
        sys.exit(1)
    if sys.argv[1] in ("--extract", "-x"):
        extract_cpio(sys.argv[2], sys.argv[3])
    else:
        rootfs = sys.argv[1]
        out_cpio = sys.argv[2]
        with open(out_cpio, "wb") as fp:
            write_cpio(rootfs, fp)
