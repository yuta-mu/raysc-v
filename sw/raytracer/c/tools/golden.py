import argparse
import copy
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys


C_DIR = Path(__file__).resolve().parents[1]
GOLDEN_DIR = C_DIR / "golden"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def decode_ppm(data, width, height):
    fields = data.split()
    if fields[:4] != [b"P3", str(width).encode(), str(height).encode(), b"255"]:
        raise ValueError(f"expected a P3 {width}x{height} maxval=255 header")
    if len(fields) != 4 + width * height * 3:
        raise ValueError(f"expected {width * height} complete RGB pixels")
    return bytes(int(value) for value in fields[4:])


def source_hashes():
    sources = [C_DIR / name for name in ("Makefile", "fpm.c", "fpm.h", "qmath.h")]
    for directory in ("core", "host", "ref"):
        sources.extend((C_DIR / directory).glob("*.[ch]"))
    return {
        str(path.relative_to(C_DIR)): sha256(path.read_bytes())
        for path in sorted(sources)
    }


def render(profile, build_dir):
    width, height = profile["width"], profile["height"]
    if not (1 <= width <= 32768 and 1 <= height <= 32768):
        raise ValueError("image dimensions must be between 1 and 32768")
    command = shlex.split(os.environ.get("MAKE", "make")) + [
        "--no-print-directory", "-C", str(C_DIR),
        f"BUILD_DIR={build_dir}", "MODE=mirrors", "SCENE=baseline",
        f"WIDTH={width}", f"HEIGHT={height}", "host",
    ]
    subprocess.run(command, check=True)
    directory = build_dir / "host" / "mirrors"
    if (width, height) != (64, 36):
        directory /= f"{width}x{height}"
    result = subprocess.run(
        [str(directory / "raytracer")], check=True, stdout=subprocess.PIPE, timeout=30,
    )
    decode_ppm(result.stdout, width, height)
    return result.stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build-dir", default="build/golden")
    parser.add_argument("--candidate-dir")
    args = parser.parse_args()
    build_dir = (C_DIR / args.build_dir).resolve()
    manifest = json.loads((GOLDEN_DIR / "manifest.json").read_text())
    target = None
    if args.candidate_dir is not None:
        if not args.candidate_dir:
            raise ValueError("set OUTPUT_DIR to a new candidate directory")
        target = (C_DIR / args.candidate_dir).resolve()
        if target.exists() or target == GOLDEN_DIR or GOLDEN_DIR in target.parents:
            raise ValueError("candidate directory must be new and outside golden/")
    images = {}
    for name, profile in manifest["profiles"].items():
        filename = profile["file"]
        if Path(filename).name != filename:
            raise ValueError("golden file must be in golden/")
        if target is None:
            expected = (GOLDEN_DIR / filename).read_bytes()
            rgb = decode_ppm(expected, profile["width"], profile["height"])
            if sha256(expected) != profile["ppm_sha256"] or sha256(rgb) != profile["rgb_sha256"]:
                raise ValueError(f"stored {name} image differs from its frozen hashes")
        data = render(profile, build_dir)
        images[filename] = data
        if target is None:
            (build_dir / filename).write_bytes(data)
            if data != expected:
                position = next(
                    (i for i, (a, b) in enumerate(zip(data, expected)) if a != b),
                    min(len(data), len(expected)),
                )
                raise ValueError(
                    f"{name} differs at byte {position}:"
                    f" actual {len(data)} B, expected {len(expected)} B"
                )
            print(f"PASS: {name} {profile['width']}x{profile['height']} PPM matches byte for byte", flush=True)
    if target is not None:
        candidate = copy.deepcopy(manifest)
        candidate["status"] = "candidate"
        candidate["approval"] = {"local": "not recorded for this candidate", "team": "not recorded"}
        candidate["validation"] = "Generated only; independent reference and RV32 checks must be rerun"
        candidate["created_at"] = datetime.now(timezone.utc).isoformat()
        candidate["source_sha256"] = source_hashes()
        candidate["build_settings"] = {
            "HOST_CC": os.environ.get("HOST_CC", "gcc"),
            "CPPFLAGS": os.environ.get("CPPFLAGS", ""),
            "CFLAGS": os.environ.get("CFLAGS", "Makefile default"),
            "LDFLAGS": os.environ.get("LDFLAGS", ""),
        }
        for profile in candidate["profiles"].values():
            profile.pop("reference_checks", None)
            data = images[profile["file"]]
            profile["ppm_bytes"] = len(data)
            profile["ppm_sha256"] = sha256(data)
            profile["rgb_sha256"] = sha256(decode_ppm(data, profile["width"], profile["height"]))
        target.mkdir(parents=True, exist_ok=False)
        for filename, data in images.items():
            (target / filename).write_bytes(data)
        (target / "manifest.json").write_text(json.dumps(candidate, indent=2) + "\n")
        print(f"CANDIDATE: saved {len(images)} images in {target}; golden/ was not updated")
    else:
        print(f"PASS: {len(images)} frozen images verified (status: {manifest['status']})")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
