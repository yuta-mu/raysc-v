#!/usr/bin/env python3
"""Convert a binary image to one little-endian 32-bit word per HEX line."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


def convert(data: bytes) -> str:
    """Return $readmemh-compatible words, padding the final word with zero bytes."""
    padded = data + bytes((-len(data)) % 4)
    words = [f"{int.from_bytes(padded[i:i + 4], 'little'):08x}" for i in range(0, len(padded), 4)]
    return "\n".join(words) + ("\n" if words else "")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path, help="input binary image")
    parser.add_argument("-o", "--output", required=True, type=Path, help="output HEX file")
    args = parser.parse_args()

    if not args.binary.is_file():
        parser.error(f"input file does not exist: {args.binary}")
    try:
        data = args.binary.read_bytes()
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(convert(data), encoding="ascii")
    except OSError as exc:
        print(f"bin2hex: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
