"""The 地图 page's pictures (DECISIONS「总图」): python -m tools.maps.atlas.bake --godot <godot>

Shoots the places of game/data/common/atlas.json that have a voxel view (bake_atlas.gd, windowed,
a few maps a run), then writes game/assets/textures/atlas/: <map>.png, arrow.png and bake.json
with each picture's anchor and pins and the fingerprint of the maps it was shot from. Only the
regions that changed are shot again (--all for every one), and the land and roads (bake_land.gd)
only when a place moved, changed shape or got another door, so a small map edit stays a small
commit. Run it in the same change as anything that alters a map; check() fails the gate when that
was forgotten.
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
ROOM_LIFE = GAME / "data" / "common" / "room_life.json"
LAYOUTS = ROOT / "tools" / "maps" / "layouts"
SCRATCH = ROOT / "build" / "atlas"
SCRIPT = Path(__file__).with_name("bake_atlas.gd")
LAND = Path(__file__).with_name("bake_land.gd")
LAND_FILES = ("land", "mist", "shade", "clouds")
PX = 4.0
BATCH = 10
## The 沙盘's rim round the places, in projected units.
RIM = (120.0, 110.0, 120.0, 120.0)
COS_X = 0.7071
COS_Y = 0.4631


def _digest(files: list[Path]) -> str:
    digest = hashlib.sha256()
    for path in files:
        digest.update(path.relative_to(ROOT).as_posix().encode("utf8"))
        digest.update(path.read_bytes().replace(b"\r\n", b"\n"))
    return digest.hexdigest()


def region_prints() -> dict[str, str]:
    """Of what each region's pictures are shot from: its layout and its voxel configs."""
    prints: dict[str, str] = {}
    regions = {path.stem for path in LAYOUTS.glob("*.json")} | {path.parent.name for path in (GAME / "data").glob("*/voxel")}
    for region in sorted(regions):
        layout = LAYOUTS / f"{region}.json"
        files = [layout] if layout.is_file() else []
        files.extend(sorted((GAME / "data" / region / "voxel").glob("*.json")))
        prints[region] = _digest(files)
    return prints


def fingerprint() -> str:
    """Of everything the pictures are shot from: the regions, the rooms' life, the atlas."""
    digest = hashlib.sha256(_digest([ATLAS, ROOM_LIFE]).encode("utf8"))
    for region, printed in region_prints().items():
        digest.update(f"{region}:{printed}".encode("utf8"))
    return digest.hexdigest()


def check() -> str | None:
    """The problem with the baked pictures, or None."""
    if not BAKE.is_file():
        return f"{BAKE.relative_to(ROOT).as_posix()} is missing: run python -m tools.maps.atlas.bake"
    baked = json.loads(BAKE.read_text(encoding="utf8")).get("fingerprint")
    if baked != fingerprint():
        return "the maps changed since the 沙盘 was baked: run python -m tools.maps.atlas.bake --godot <godot> and commit it with the change"
    return None


def _run(godot: str, script: Path, arguments: list[str]) -> str:
    command = [godot, "--path", str(GAME), "--resolution", "640x360", "--script", script.as_posix(), "--", *arguments]
    done = subprocess.run(command, capture_output=True, text=True, encoding="utf8", errors="replace", timeout=600, cwd=ROOT)
    return done.stdout


def _shoot(godot: str, arguments: list[str]) -> str:
    return _run(godot, SCRIPT, [SCRATCH.as_posix(), str(PX), *arguments])


def _places() -> dict[str, list[int]]:
    rows = json.loads(ATLAS.read_text(encoding="utf8"))["atlas"]
    return {row["map"]: [row["x"], row["y"]] for row in rows}


def _frame(places: dict[str, list[int]]) -> list[float]:
    seen = [((x - y) * COS_X, (x + y) * COS_Y) for x, y in places.values()]
    frame = [min(s[0] for s in seen) - RIM[0], min(s[1] for s in seen) - RIM[1], max(s[0] for s in seen) + RIM[2], max(s[1] for s in seen) + RIM[3]]
    return [round(value, 1) for value in frame]


def _shape(cell: dict | None) -> object:
    """What the land is laid out round: a picture's outline and its doors."""
    if cell is None:
        return None
    return cell["size"], cell["anchor"], {key: value for key, value in cell["pins"].items() if key.startswith("door:")}


def _read_shots(log: list[str], wanted: list[str]) -> dict[str, dict]:
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
    if viewless:
        print("no voxel view, a plate on the 沙盘:", ", ".join(viewless))
    return cells


def _write(cells: dict[str, dict], places: dict[str, list[int]], roads: list[dict]) -> None:
    written = {
        "fingerprint": fingerprint(),
        "regions": region_prints(),
        "common": _digest([ROOM_LIFE]),
        "places": _digest([ATLAS]),
        "px": PX,
        "frame": _frame(places),
        "cells": cells,
        "roads": roads,
    }
    BAKE.write_text(json.dumps(written, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf8", newline="\n")


def _bake_land(godot: str) -> list[dict]:
    land = SCRATCH / "land"
    shutil.rmtree(land, ignore_errors=True)
    print(_run(godot, LAND, [land.as_posix()])[-200:], flush=True)
    roads = json.loads((land / "roads.json").read_text(encoding="utf8"))
    for stale in OUT.glob("road_*.png"):
        stale.unlink()
    for name in LAND_FILES:
        shutil.copyfile(land / f"{name}.png", OUT / f"{name}.png")
    for path in land.glob("road_*.png"):
        shutil.copyfile(path, OUT / path.name)
    return roads


def bake(godot: str, whole: bool) -> None:
    places = _places()
    old = json.loads(BAKE.read_text(encoding="utf8")) if BAKE.is_file() else {}
    prints = region_prints()
    old_prints = old.get("regions", {})
    everything = whole or old.get("common") != _digest([ROOM_LIFE])
    stale = [map_id for map_id in places if everything or old_prints.get(map_id.partition(".")[0]) != prints.get(map_id.partition(".")[0])]
    SCRATCH.mkdir(parents=True, exist_ok=True)
    keep = (GAME / "project.godot").read_bytes()
    log: list[str] = []
    try:
        for first in range(0, len(stale), BATCH):
            batch = stale[first : first + BATCH]
            log.extend(_shoot(godot, batch).splitlines())
            print("shot", ", ".join(batch), flush=True)
        if everything or not (OUT / "arrow.png").is_file():
            _shoot(godot, ["@arrow"])
        shot = _read_shots(log, stale)
        OUT.mkdir(parents=True, exist_ok=True)
        cells = {map_id: cell for map_id, cell in old.get("cells", {}).items() if map_id in places and map_id not in stale}
        moved = whole or old.get("places") != _digest([ATLAS]) or any(_shape(old.get("cells", {}).get(map_id)) != _shape(shot.get(map_id)) for map_id in stale)
        cells.update(shot)
        for name in shot:
            shutil.copyfile(SCRATCH / f"{name}.png", OUT / f"{name}.png")
        if (SCRATCH / "arrow.png").is_file():
            shutil.copyfile(SCRATCH / "arrow.png", OUT / "arrow.png")
        roads = old.get("roads", [])
        _write(cells, places, roads)
        if moved or not (OUT / "land.png").is_file():
            roads = _bake_land(godot)
            _write(cells, places, roads)
    finally:
        (GAME / "project.godot").write_bytes(keep)
    print("baked", len(shot), "places of", len(cells), "with pictures,", "the land too" if moved else "the land as it was")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="the Godot editor binary; without it, only check the fingerprint")
    parser.add_argument("--all", action="store_true", help="shoot every place and the land")
    arguments = parser.parse_args()
    if arguments.godot:
        bake(arguments.godot, arguments.all)
    problem = check()
    if problem:
        print(problem, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
