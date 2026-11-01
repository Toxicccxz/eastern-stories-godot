"""The 地图 page's pictures (DECISIONS「总图」): python -m tools.maps.atlas.bake --godot <godot>

Shoots every place of game/data/common/atlas.json that has a voxel view (bake_atlas.gd, windowed,
a few maps a run), then writes game/assets/textures/atlas/: <map>.png, arrow.png and bake.json
with each picture's anchor and pins and the fingerprint of the maps it was shot from. Run it in
the same change as anything that alters a map; check() fails the gate when that was forgotten.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GAME = ROOT / "game"
OUT = GAME / "assets" / "textures" / "atlas"
BAKE = OUT / "bake.json"
ATLAS = GAME / "data" / "common" / "atlas.json"
SCRATCH = ROOT / "build" / "atlas"
SCRIPT = Path(__file__).with_name("bake_atlas.gd")
PX = 4.0
BATCH = 10
## The 沙盘's rim round the places, in projected units.
RIM = (120.0, 110.0, 120.0, 120.0)
COS_X = 0.7071
COS_Y = 0.4631


def _text_files(folder: Path) -> list[Path]:
    return sorted(path for path in folder.rglob("*.json") if path.is_file())


def fingerprint() -> str:
    """Of everything the pictures are shot from: the layouts, the voxel configs, the atlas."""
    files = [ATLAS, *_text_files(ROOT / "tools" / "maps" / "layouts")]
    files.extend(sorted(path for path in (GAME / "data").glob("*/voxel/*.json")))
    digest = hashlib.sha256()
    for path in files:
        digest.update(path.relative_to(ROOT).as_posix().encode("utf8"))
        digest.update(path.read_bytes().replace(b"\r\n", b"\n"))
    return digest.hexdigest()


def check() -> str | None:
    """The problem with the baked pictures, or None."""
    if not BAKE.is_file():
        return f"{BAKE.relative_to(ROOT).as_posix()} is missing: run python -m tools.maps.atlas.bake"
    baked = json.loads(BAKE.read_text(encoding="utf8")).get("fingerprint")
    if baked != fingerprint():
        return "the maps changed since the 沙盘 was baked: run python -m tools.maps.atlas.bake --godot <godot> and commit it with the change"
    return None


def _run(godot: str, arguments: list[str]) -> str:
    command = [godot, "--path", str(GAME), "--resolution", "640x360", "--script", SCRIPT.as_posix(), "--", SCRATCH.as_posix(), str(PX), *arguments]
    done = subprocess.run(command, capture_output=True, text=True, encoding="utf8", errors="replace", timeout=300, cwd=ROOT)
    return done.stdout


def _places() -> dict[str, list[int]]:
    rows = json.loads(ATLAS.read_text(encoding="utf8"))["atlas"]
    return {row["map"]: [row["x"], row["y"]] for row in rows}


def _frame(places: dict[str, list[int]]) -> list[float]:
    seen = [((x - y) * COS_X, (x + y) * COS_Y) for x, y in places.values()]
    return [min(s[0] for s in seen) - RIM[0], min(s[1] for s in seen) - RIM[1], max(s[0] for s in seen) + RIM[2], max(s[1] for s in seen) + RIM[3]]


def bake(godot: str) -> None:
    places = _places()
    wanted = list(places)
    SCRATCH.mkdir(parents=True, exist_ok=True)
    keep = (GAME / "project.godot").read_bytes()
    log: list[str] = []
    try:
        for first in range(0, len(wanted), BATCH):
            batch = wanted[first : first + BATCH]
            log.extend(_run(godot, batch).splitlines())
            print("shot", ", ".join(batch), flush=True)
        _run(godot, ["@arrow"])
    finally:
        (GAME / "project.godot").write_bytes(keep)
    cells: dict[str, dict] = {}
    viewless: list[str] = []
    for line in log:
        parts = line.split(" ")
        if line.startswith("TRIM "):
            cells[parts[1]] = {"size": [int(parts[2]), int(parts[3])], "anchor": [round(float(parts[4]), 1), round(float(parts[5]), 1)], "pins": {}}
        elif line.startswith("PIN ") and parts[1] in cells:
            cells[parts[1]]["pins"].setdefault(parts[2], [round(float(parts[3]), 1), round(float(parts[4]), 1)])
        elif line.startswith("NO VIEW "):
            viewless.append(parts[2])
    missing = [map_id for map_id in wanted if map_id not in cells and map_id not in viewless]
    if missing:
        raise SystemExit(f"not shot: {missing}")
    print("no voxel view, a plate on the 沙盘:", ", ".join(viewless))
    OUT.mkdir(parents=True, exist_ok=True)
    for name in [*cells, "arrow"]:
        shutil.copyfile(SCRATCH / f"{name}.png", OUT / f"{name}.png")
    written = {"fingerprint": fingerprint(), "px": PX, "frame": [round(value, 1) for value in _frame(places)], "cells": cells}
    BAKE.write_text(json.dumps(written, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf8", newline="\n")
    print("baked", len(cells), "places")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="the Godot editor binary; without it, only check the fingerprint")
    arguments = parser.parse_args()
    if arguments.godot:
        bake(arguments.godot)
    problem = check()
    if problem:
        print(problem, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
