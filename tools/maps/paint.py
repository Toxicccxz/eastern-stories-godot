"""Paint the generated world maps from their layout data.

These maps are generated, never edited by hand:

    oldpine: oldpine_stone, oldpine_caves, oldpine_cliff2
    snow:    snow_inn_upstairs, snow_cellar
    cloud:   cloud_outdoor, cloud_tearoom_upstairs, cloud_jiyuan_upstairs, cloud_duchang_upstairs
    goathill: goathill_mountain, goathill_caverns
    waterfog: waterfog_mountain, waterfog_pavilion, waterfog_upstairs

Each region has one layout file, tools/maps/layouts/<region>.json; to change a map, edit its
layout and rerun the painter. tools/tests/test_maps_paint.py fails when a committed scene differs
from what its layout paints (a hand edit, or a layout change that was not repainted). Run from the
repository root:

    python -m tools.maps.paint                      # repaint every region in place (changed scenes only)
    python -m tools.maps.paint cloud snow           # only these regions
    python -m tools.maps.paint --check              # write nothing; exit 1 listing maps that differ
    python -m tools.maps.paint --out build/maps     # write under build/maps/<region>/ instead

A layout's `maps` entry names its scene `file` under game/scenes/world/<region>/ and has:

* `draw`: the technique that paints the tiles (fills, cells, town, canvas; each module's docstring
  gives its data) and whatever that technique makes for the scene (zones, captions, markers).
* `scene`: the skeleton `style` (map or flat, see scene.py), the root node name, the `map` id,
  `player_color`, camera `limits` (default: the drawing's bounds) or `zoom`, the `shapes`, and the
  node lists `nodes` (after the tile layers), `zones`, `spawn_points` and `interactions`. A list
  item is a node block (`node` names the builder in scene.py; in zones, spawn_points and
  interactions it defaults to zone, marker and landmark) or {"generated": name} for what the
  drawing, the `stairs` or the `doors` made: zones, captions, markers, stairs, stair_markers,
  door_walls, shutters, doors.
* `scene.stairs`: passages drawn as steps, each with its arrival or return marker.
* `scene.doors` and `scene.door_style`: a door is placed `at` with a `shape`, or `between` two
  zones of a town (in their doorway).

Positions and boxes are pixels; boxes are [x0, y0, x1, y1]. A `note` field, and a trailing string
in a fill, gap_at, line point or blob row, is a comment. Captions, neighbours and auto-placed
markers read game/data/<region>/ (rooms, world, spawns, item_spawns).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import canvas, cells, fills, town
from . import scene as sc
from .region import Region

REPOSITORY = Path(__file__).resolve().parents[2]
LAYOUTS = Path(__file__).resolve().parent / 'layouts'
DATA = REPOSITORY / 'game/data'
WORLD = REPOSITORY / 'game/scenes/world'
TECHNIQUES = {'fills': fills.draw, 'cells': cells.draw, 'town': town.draw, 'canvas': canvas.draw}


def regions() -> list[str]:
    return sorted(p.stem for p in LAYOUTS.glob('*.json'))


def layout(region: str) -> dict:
    return json.loads((LAYOUTS / f'{region}.json').read_text(encoding='utf-8'))


def paint_map(region: Region, entry: dict, notes: list | None = None) -> str:
    """The scene text of one layout entry."""
    scene = entry['scene']
    style = scene['style']
    drawn = TECHNIQUES[entry['draw']['technique']](region, entry)
    if notes is not None:
        notes.extend(drawn.notes)
    sizes = {k: tuple(v) for k, v in scene['shapes'].items()}
    for k, v in drawn.shapes.items():
        sizes[k] = v
    fragments = dict(drawn.fragments)
    stairs = arrivals = ''
    for s in scene.get('stairs', []):
        stairs += sc.build('stairs', style, name=s['name'], at=s['at'], id=s['id'], shape=s['shape'],
                           extent=sizes[s['shape']], color=s['color'], text=s['text'])
        arrivals += sc.build('marker', style, **s['marker'])
    walls = shutters = doors = ''
    for door in scene.get('doors', []):
        if 'between' in door:
            at, shape, extent = drawn.door_at(door['between'])
        else:
            at, shape, extent = door['at'], door['shape'], sizes[door['shape']]
        parts = sc.door_parts(door['name'], door['id'], at, extent, shape, scene['door_style'])
        walls, shutters, doors = walls + parts[0], shutters + parts[1], doors + parts[2]
    fragments.update(stairs=stairs, stair_markers=arrivals, door_walls=walls, shutters=shutters, doors=doors)

    nodes = sc.render(scene.get('nodes', []), '', style, fragments)
    zones = sc.render(scene.get('zones', []), 'zone', style, fragments)
    points = sc.render(scene.get('spawn_points', []), 'marker', style, fragments)
    has_doors = bool(scene.get('doors'))
    if style == 'map':
        interactions = sc.render(scene.get('interactions', []), 'landmark', style, fragments)
        text = sc.map_scene(scene['root'], scene['map'], sizes, nodes, zones, points, interactions,
                            scene.get('limits', drawn.bounds), scene['player_color'], has_doors)
    else:
        text = sc.flat_scene(scene['root'], scene['map'], sizes, nodes, zones, points,
                             scene['player_color'], scene['zoom'], has_doors)
    return drawn.tiles.apply(text)


def generate(region: str, data: Path = DATA, notes: list | None = None) -> dict[str, str]:
    """Scene file name -> text, for every map of a region's layout."""
    reader = Region(region, data)
    return {entry['file']: paint_map(reader, entry, notes) for entry in layout(region)['maps'].values()}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n', 1)[0])
    parser.add_argument('regions', nargs='*', help='regions to paint (default: every layout)')
    parser.add_argument('--check', action='store_true', help='write nothing; exit 1 if a scene differs')
    parser.add_argument('--out', type=Path, help='write under this directory instead of game/scenes/world')
    args = parser.parse_args(argv)
    unknown = sorted(set(args.regions) - set(regions()))
    if unknown:
        parser.error(f'no layout for {", ".join(unknown)}')
    differ = []
    for region in args.regions or regions():
        notes: list = []
        for file, text in generate(region, notes=notes).items():
            target = WORLD / region / file
            same = target.is_file() and target.read_bytes() == text.encode('utf-8')
            if args.check:
                if not same:
                    differ.append(f'{region}/{file}')
                continue
            if args.out is not None:
                target = args.out / region / file
            elif same:
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding='utf-8', newline='\n')
            print(f'wrote {target}')
        for note in notes:
            print(f'{region}: {note}')
    for name in differ:
        print(f'differs: game/scenes/world/{name}')
    return 1 if differ else 0


if __name__ == '__main__':
    sys.exit(main())
