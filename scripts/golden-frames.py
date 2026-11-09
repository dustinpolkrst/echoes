#!/usr/bin/env python3
"""Compare lossless --shot captures with the committed golden frames.

Usage, from the repo root:
  python3 scripts/golden-frames.py --style baseline

--style selects a directory under golden/. baseline is the no-flag look.
Cutout is accepted as a name and is not shipped: there is no golden/cutout,
and this script does not pass a style flag through to the game.

Tolerance is 0. Two captures of the same --shot on this machine were
byte-identical PNGs. The shot path seeds the random generators, steps a
fixed 1/60 simulation, and writes a lossless PNG, so a channel delta above
0 is a different pixel, not capture noise. A looser tolerance would hide a
one-pixel render change.

A red result after a content change means the references are stale. Refresh
them on purpose. See golden/README.md.
"""

import argparse
import json
import os
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

# Maximum allowed per-channel delta, on the 0..255 scale stored in the PNG.
# 0 because a repeated --shot of one frame matched on every byte. See the
# module docstring.
TOLERANCE = 0

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
LOVE = os.environ.get("LOVE", "love")

PNG_SIG = b"\x89PNG\r\n\x1a\n"


def load_png(path):
    data = Path(path).read_bytes()
    if data[:8] != PNG_SIG:
        raise SystemExit(f"{path} is not a PNG")
    pos = 8
    width = height = depth = color = interlace = None
    idat = bytearray()
    while pos + 8 <= len(data):
        length = int.from_bytes(data[pos : pos + 4], "big")
        kind = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"IDAT":
            idat += chunk
        elif kind == b"IEND":
            break
    if interlace != 0 or depth != 8 or color not in (2, 6):
        raise SystemExit(
            f"{path}: unsupported PNG {width}x{height} depth {depth} color {color} interlace {interlace}"
        )
    channels = 3 if color == 2 else 4
    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    rows = []
    index = 0
    prev = bytearray(stride)
    for _ in range(height):
        filt = raw[index]
        index += 1
        row = bytearray(raw[index : index + stride])
        index += stride
        if filt == 1:
            for x in range(stride):
                left = row[x - channels] if x >= channels else 0
                row[x] = (row[x] + left) & 255
        elif filt == 2:
            for x in range(stride):
                row[x] = (row[x] + prev[x]) & 255
        elif filt == 3:
            for x in range(stride):
                left = row[x - channels] if x >= channels else 0
                row[x] = (row[x] + ((left + prev[x]) // 2)) & 255
        elif filt == 4:
            for x in range(stride):
                a = row[x - channels] if x >= channels else 0
                b = prev[x]
                c = prev[x - channels] if x >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else b if pb <= pc else c
                row[x] = (row[x] + pred) & 255
        elif filt != 0:
            raise SystemExit(f"{path}: bad PNG filter {filt}")
        rows.append(row)
        prev = row
    return width, height, channels, rows


def max_delta(ref_path, shot_path):
    rw, rh, rc, rr = load_png(ref_path)
    sw, sh, sc, sr = load_png(shot_path)
    if (rw, rh, rc) != (sw, sh, sc):
        return None, f"size {rw}x{rh}x{rc} vs {sw}x{sh}x{sc}"
    worst = 0
    over = 0
    for y in range(rh):
        a, b = rr[y], sr[y]
        for x in range(0, rw * rc, rc):
            delta = 0
            for c in range(rc):
                delta = max(delta, abs(a[x + c] - b[x + c]))
            if delta > worst:
                worst = delta
            if delta > TOLERANCE:
                over += 1
    return over, worst


def capture(level, frame):
    xdg = tempfile.mkdtemp(prefix="golden-shot-")
    cmd = [
        "xvfb-run",
        "-a",
        "env",
        f"XDG_DATA_HOME={xdg}",
        LOVE,
        str(GAME),
        "--shot",
        str(level),
        str(frame),
    ]
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    text = proc.stdout.decode("utf-8", "replace")
    shot = None
    for line in text.splitlines():
        if line.startswith("SHOT "):
            shot = line.split(" ", 1)[1].strip()
    if proc.returncode != 0 or not shot or not Path(shot).is_file():
        err = proc.stderr.decode("utf-8", "replace")[-500:]
        raise SystemExit(
            f"capture failed for --shot {level} {frame} (exit {proc.returncode})\n{text}\n{err}"
        )
    return shot


def main():
    parser = argparse.ArgumentParser(description="Diff --shot captures against golden frames.")
    parser.add_argument(
        "--style",
        default="baseline",
        help="Reference set under golden/<style>. baseline is the no-flag look. cutout is reserved and has no references.",
    )
    args = parser.parse_args()
    style = args.style
    directory = ROOT / "golden" / style
    manifest_path = directory / "manifest.json"
    if style != "baseline":
        print(
            f"FAIL style {style} has no committed references. "
            "Cutout can be added later as golden/cutout. This script does not pass a style flag to the game."
        )
        return 1
    if not manifest_path.is_file():
        print(f"FAIL missing {manifest_path}")
        return 1
    manifest = json.loads(manifest_path.read_text())
    refs = manifest["references"]
    print(f"golden-frames style {style} tolerance {TOLERANCE}")
    print(f"capture: xvfb-run -a love {GAME.name} --shot LEVEL FRAME")
    failed = 0
    for ref in refs:
        if ref["style"] != style:
            print(f"FAIL {ref['file']} manifest style {ref['style']} does not match --style {style}")
            failed += 1
            continue
        path = directory / ref["file"]
        if not path.is_file():
            print(f"FAIL {ref['file']} missing reference")
            failed += 1
            continue
        shot = capture(ref["level"], ref["frame"])
        over, worst = max_delta(path, shot)
        if over is None:
            print(
                f"FAIL {ref['file']} level {ref['level']} frame {ref['frame']} style {style}  {worst}"
            )
            failed += 1
            continue
        status = "PASS" if over == 0 else "FAIL"
        if over:
            failed += 1
        print(
            f"{status} {ref['file']} level {ref['level']} frame {ref['frame']} style {style}  "
            f"{over} pixels over tolerance {TOLERANCE}, max channel delta {worst}"
        )
    print(f"{len(refs) - failed} passed, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
