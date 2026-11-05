#!/usr/bin/env python3
"""Write a test PNG: make_png.py <width> <height> <out.png> [--alpha] [--black] [--seed N]

Stdlib only. The default image is an RGB gradient (not black, no alpha).
"""
import struct
import sys
import zlib


def chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    width, height, out = int(args[0]), int(args[1]), args[2]
    alpha = "--alpha" in argv
    black = "--black" in argv
    seed = 0
    if "--seed" in argv:
        seed = int(argv[argv.index("--seed") + 1])
        args = [a for a in args if a != str(seed)]
    channels = 4 if alpha else 3
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type: none
        if black:
            row = bytes(width * channels)
            if alpha:
                row = bytes([0, 0, 0, 255]) * width
        else:
            r = (y * 255 // max(height - 1, 1) + seed) % 256
            px = bytes([r, (255 - r) % 256, (r + 80) % 256] + ([255] if alpha else []))
            row = px * width
        raw += row
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6 if alpha else 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 1)) + chunk(b"IEND", b"")
    with open(out, "wb") as fh:
        fh.write(png)


if __name__ == "__main__":
    main(sys.argv[1:])
