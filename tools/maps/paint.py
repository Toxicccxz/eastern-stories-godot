"""Paint the generated world maps from their layout data.

These maps are generated, never edited by hand:

    oldpine: oldpine_outdoor, oldpine_cave, oldpine_gorge, oldpine_tree, oldpine_cliff, oldpine_stone,
             oldpine_caves, oldpine_cliff2
    snow:    snow_outdoor, snow_inn, snow_inn_upstairs, snow_cellar
    cloud:   cloud_outdoor, cloud_tearoom_upstairs, cloud_jiyuan_upstairs, cloud_duchang_upstairs
    goathill: goathill_mountain, goathill_caverns
    waterfog: waterfog_mountain, waterfog_pavilion, waterfog_upstairs
    green:   green_village, green_mountain, green_maze
    temple:  temple_mountain, temple_grounds, temple_library
    latemoon: latemoon_manor, latemoon_secret, latemoon_garden, latemoon_upper, latemoon_hills
    sanyen:  sunhill_mountain (泓水 and 日照山), sanyen_temple
    choyin:  choyin_town, choyin_yamen, choyin_altar, choyin_hotel_2f, choyin_hotel_3f, choyin_tree_hollow,
             choyin_lion_cave, choyin_east, choyin_furnace, choyin_guye, choyin_crown, choyin_cliff_cave,
             choyin_summit, choyin_valley
    canyon:  canyon_clifftop, canyon_pass, canyon_armory, canyon_bamboo, canyon_stoneroom
    village: village_main, village_midlake (the boat), village_icecave
    city:    city_main, city_upstairs (太白酒楼's upper floor), city_wall_top (院墙), city_cellar (地下密室)
    chuenyu: chuenyu_main (the road, 黑松山 and the castle), chuenyu_upstairs (淳于's rooms)
    death:   death_realm (阴间: 奈何桥, 鬼门关, 酆都城 and the long road)

Each region has one layout file, tools/maps/layouts/<region>.json; to change a map, edit its
layout and rerun the painter. tools/tests/test_maps_paint.py fails when a committed scene differs
from what its layout paints (a hand edit, or a layout change that was not repainted). Run from the
repository root:

    python -m tools.maps.paint                      # repaint every region in place (changed scenes only)
    python -m tools.maps.paint cloud snow           # only these regions
    python -m tools.maps.paint --check              # write nothing; exit 1 listing maps that differ
    python -m tools.maps.paint --out build/maps     # write under build/maps/<region>/ instead

A layout's `maps` entry names its scene `file` under game/scenes/world/<region>/ and has:

* `draw`: the technique that paints the tiles (fills, cells, town, canvas, interior; each module's
  docstring gives its data, standard.py the interior's) and whatever that technique makes for the
  scene (zones, captions, markers). Sizes come from the scale standard (standard.json): street
  classes, building facades and their doors on town maps, interiors laid out from their exits;
  a technique's `base` filler (the bare `boundary`; a wild map's forest or cliff is terrain) is
  kept only within a skirt of walkable ground, a backdrop of its colour behind.
* `scene`: the skeleton `style` (map or flat, see scene.py), the root node name, the `map` id,
  `player_color`, camera `limits` (default: the drawing's bounds, or where a trimmed map's tiles end) or `zoom`, the `shapes`, and the
  node lists `nodes` (after the tile layers), `zones`, `spawn_points` and `interactions`. A list
  item is a node block (`node` names the builder in scene.py; in zones, spawn_points and
  interactions it defaults to zone, marker and landmark) or {"generated": name} for what the
  drawing, the `stairs` or the `doors` made: zones, captions, markers, stairs, stair_markers,
  door_walls, shutters, doors.
* `scene.stairs`: passages drawn as steps, each with its arrival or return marker.
* `scene.doors` and `scene.door_style`: a door is placed `at` with a `shape`, or `between` two
  zones of a town (in their doorway); a door's own `color` overrides the style's.

Positions and boxes are pixels; boxes are [x0, y0, x1, y1]. A `note` field, and a trailing string
in a fill, gap_at, line point or blob row, is a comment. A fill row may end with
{"look": {"kind": ..., ...}}: what stands on its blocked box, drawn by the map's voxel view from
the scene's `Furnishings` nodes (furnishings()); a room's `life` adds lived-in corner pieces to
them (life.py); `scene.presentation` names that view and its
config, game/data/<region>/voxel/<map>.json (AGENTS.md「地图」). Captions, neighbours and auto-placed
markers read game/data/<region>/ (rooms, world, spawns, item_spawns).
"""

from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path

from . import canvas, cells, fills, life, standard, town
from . import scene as sc
from .region import Region
from .tiles import BACKDROP, T

REPOSITORY = Path(__file__).resolve().parents[2]
LAYOUTS = Path(__file__).resolve().parent / 'layouts'
DATA = REPOSITORY / 'game/data'
WORLD = REPOSITORY / 'game/scenes/world'
TECHNIQUES = {'fills': fills.draw, 'cells': cells.draw, 'town': town.draw, 'canvas': canvas.draw}
# What an entry becomes before its technique paints it: street classes and facades resolved,
# an interior laid out as the town drawing that paints it (standard.py).
PREPARE = {'town': standard.prepare_town, 'interior': standard.prepare_interior}


def regions() -> list[str]:
    return sorted(p.stem for p in LAYOUTS.glob('*.json'))


def layout(region: str) -> dict:
    return json.loads((LAYOUTS / f'{region}.json').read_text(encoding='utf-8'))


def paint_map(region: Region, entry: dict, notes: list | None = None) -> str:
    """The scene text of one layout entry."""
    entry = PREPARE.get(entry['draw']['technique'], lambda _region, e: copy.deepcopy(e))(region, entry)
    scene = entry['scene']
    style = scene['style']
    drawn = TECHNIQUES[entry['draw']['technique']](region, entry)
    # Rooms with a life get their corner pieces, placed on the drawing, then drawn again with
    # them (life.py): every check the technique makes covers them too.
    if pieces := life.dress(entry, drawn):
        entry['draw']['fills' if 'fills' in entry['draw'] else 'props'] += pieces
        drawn = TECHNIQUES[entry['draw']['technique']](region, entry)
    backdrop = None
    if entry['draw'].get('base') in standard.STANDARD['trimmed_bases'] and scene['style'] == 'map':
        zones = [v[:4] for v in entry['draw'].get('zones', {}).values() if isinstance(v, list)]
        standard.trim_filler(drawn.tiles, entry['draw']['base'], zones)
        backdrop = BACKDROP[entry['draw']['base']]
    # The camera stops where the tiles end (WorldMapController.frame_camera() does the same
    # from the used cells); the backdrop still covers the drawing's bounds.
    limits = drawn.bounds
    cells = list(drawn.tiles.ground) + list(drawn.tiles.structures)
    if backdrop and cells:
        xs, ys = [c[0] for c in cells], [c[1] for c in cells]
        limits = (min(xs) * T, min(ys) * T, (max(xs) + 1) * T, (max(ys) + 1) * T)
    interior = entry['draw'].get('interior')
    if interior:
        for other in interior['larger_than']:
            other_region, key = other.split('/')
            other_entry = layout(other_region)['maps'][key]
            if other_entry['draw']['technique'] == 'interior':
                floor = standard.prepare_interior(Region(other_region, DATA), other_entry)['draw']['interior']['floor']
            else:
                floor = standard.floor_of(other_entry)
            assert interior['floor'] > floor, ('not larger than', other, scene['map'], round(interior['floor']), round(floor))
    if notes is not None:
        notes.extend(drawn.notes)
        if interior:
            notes.extend(interior['notes'])
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
        look = dict(scene['door_style'], **({'color': door['color']} if 'color' in door else {}))
        parts = sc.door_parts(door['name'], door['id'], at, extent, shape, look)
        walls, shutters, doors = walls + parts[0], shutters + parts[1], doors + parts[2]
    fragments.update(stairs=stairs, stair_markers=arrivals, door_walls=walls, shutters=shutters, doors=doors)

    nodes = sc.render(scene.get('nodes', []), '', style, fragments)
    zones = sc.render(scene.get('zones', []), 'zone', style, fragments)
    points = sc.render(scene.get('spawn_points', []), 'marker', style, fragments)
    has_doors = bool(scene.get('doors'))
    if style == 'map':
        interactions = sc.render(scene.get('interactions', []), 'landmark', style, fragments)
        has_services = any(n.get('node') == 'service' for n in scene.get('nodes', []))
        text = sc.map_scene(scene['root'], scene['map'], sizes, nodes, zones, points, interactions,
                            scene.get('limits', limits), scene['player_color'], has_doors, has_services,
                            (backdrop, _grown(drawn.bounds, BACKDROP_MARGIN)) if backdrop else None)
    else:
        text = sc.flat_scene(scene['root'], scene['map'], sizes, nodes, zones, points,
                             scene['player_color'], scene['zoom'], has_doors)
    if presentation := scene.get('presentation'):
        resource = ('[ext_resource type="Script" path="' + presentation['script'] + '" id="map_view"]\n\n')
        text = text.replace('[ext_resource', resource + '[ext_resource', 1)
        text += ('\n[node name="MapView" type="Node" parent="."]\n'
                 'script = ExtResource("map_view")\n'
                 'layout_path = "' + presentation['layout'] + '"\n')
    text += furnishings(entry['draw'])
    text += life.scene_node(life.rooms_of(entry))
    return drawn.tiles.apply(text)


def furnishings(draw: dict) -> str:
    """The `Furnishings` nodes: every fill row ending in {"look": {...}} says what stands on its
    (blocked) box. The box, its centre and size, is the one fact for collision and model; the
    look gives the kind and how it is drawn. WorldVoxelView reads these nodes."""
    lists = [value for value in draw.values() if isinstance(value, list)]
    # A canvas map's fills are inside its steps ({"op": "fill", "fills": [...]}).
    lists += [step['fills'] for step in draw.get('steps', []) if isinstance(step, dict) and step.get('op') == 'fill']
    rows = [row for value in lists for row in value
            if isinstance(row, list) and row and isinstance(row[-1], dict) and 'look' in row[-1]]
    # A look anywhere else (a nested or non-box row) would be dropped without a model.
    assert json.dumps(draw).count('"look"') == len(rows), 'a "look" outside a top-level fill row'
    assert all(len(row) >= 6 and all(isinstance(v, int) for v in row[1:5]) for row in rows), 'a "look" on a row that is not a box'
    if not rows:
        return ''
    text = '\n[node name="Furnishings" type="Node2D" parent="."]\n'
    for index, row in enumerate(rows, 1):
        x0, y0, x1, y1 = row[1:5]
        look = json.dumps(row[-1]['look'], ensure_ascii=False)
        text += (f'\n[node name="Furnishing{index:02d}" type="Node2D" parent="Furnishings"]\n'
                 f'position = Vector2({(x0 + x1) / 2:g}, {(y0 + y1) / 2:g})\n'
                 f'metadata/look = {look}\n'
                 f'metadata/footprint = Vector2({x1 - x0}, {y1 - y0})\n')
    return text


# The backdrop reaches this far past a map's drawing: a room smaller than the screen sits on
# it (the camera centres it), not on the window's clear colour.
BACKDROP_MARGIN = 2048


def _grown(box, margin: int) -> tuple:
    x0, y0, x1, y1 = box
    return (x0 - margin, y0 - margin, x1 + margin, y1 + margin)


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
