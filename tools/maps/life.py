"""Lived-in corner pieces for rooms: sacks, iron goods, jars, chests stood against the walls.

A room says what it is used for in its layout entry, and the painter places the pieces of that
use (game/data/common/room_life.json) on free floor along its walls, as blocked boxes with their
looks, so the voxel view draws them from the scene's Furnishings like any authored furniture:

    interior: "rooms": {"<zone>": {..., "life": {"use": "smithy", "wealth": "plain", "seed": 1}}}
    town, fills: "draw": {..., "life": {"<zone>": {"use": ..., "wealth": ..., "seed": ...}}}

`tidy` (the room's text calls it clean) and `wealth` scale the count; `count` overrides it; a
piece that leans on its wall (`lean`) goes only against the north wall, which no view cuts low;
`keep_clear`: [[x0, y0, x1, y1], ...] boxes left alone. A piece never stands on a doorway, a
door, stairs, a passage, a marker or near a counter's front, and each one must leave every
marker, passage and doorway reachable by a body as before; pieces go to the corners first.
The same seed places the same pieces. The scene also gets a `RoomLife` node whose `rooms`
metadata gives each room's life to the voxel view (worn floors, old walls, things on walls).
"""

from __future__ import annotations

import json
import random
import re
from collections import deque
from pathlib import Path

from .canvas import BODY
from .region import explicit_markers
from .tiles import ATLAS, T

PRESETS = Path(__file__).resolve().parents[2] / 'game/data/common/room_life.json'
COUNTERS = {'counter', 'shop_counter'}
# Clear round what the player walks to or through (px beyond its box).
CLEAR = 40


def presets() -> dict:
    return json.loads(PRESETS.read_text(encoding='utf-8'))


def rooms_of(entry: dict) -> dict:
    """Zone -> life spec of the rooms a layout entry dresses."""
    d = entry['draw']
    if 'life' in d:
        return d['life']
    return {z: spec['life'] for z, spec in d.get('rooms', {}).items() if 'life' in spec}


def scene_node(rooms: dict) -> str:
    if not rooms:
        return ''
    return ('\n[node name="RoomLife" type="Node" parent="."]\n'
            f'metadata/rooms = {json.dumps(rooms, ensure_ascii=False, sort_keys=True)}\n')


def _zone_rects(entry: dict) -> dict:
    d, scene = entry['draw'], entry['scene']
    if isinstance(d.get('zones'), dict):
        return {z: tuple(v[:4]) for z, v in d['zones'].items() if isinstance(v, list)}
    shapes = scene.get('shapes', {})
    out = {}
    for zone in scene.get('zones', []):
        if 'id' in zone and 'shape' in zone:
            (x, y), (w, h) = zone['at'], shapes[zone['shape']]
            out[zone['id']] = (x - w // 2, y - h // 2, x + w // 2, y + h // 2)
    return out


def _box_cells(box) -> set:
    x0, y0, x1, y1 = box
    return {(x, y) for x in range(x0 // T, -(-x1 // T)) for y in range(y0 // T, -(-y1 // T))}


def _grown(box, by: int) -> tuple:
    return (box[0] - by, box[1] - by, box[2] + by, box[3] + by)


def _marker_points(entry: dict, drawn) -> list:
    points = list(explicit_markers(entry['scene']).values())
    for match in re.finditer(r'position = Vector2\(([-\d.]+), ([-\d.]+)\)', drawn.fragments.get('markers', '')):
        points.append((float(match.group(1)), float(match.group(2))))
    return points


def _keep(entry: dict, drawn, walk: set) -> tuple[set, list]:
    """Cells no piece may cover, and the points a body must still reach."""
    scene, d = entry['scene'], entry['draw']
    shapes = {k: tuple(v) for k, v in scene.get('shapes', {}).items()}
    shapes.update(drawn.shapes)
    keep, points = set(), []

    def around(x, y, w, h, by=CLEAR):
        keep.update(_box_cells(_grown((int(x - w / 2), int(y - h / 2), int(x + w / 2), int(y + h / 2)), by)))
        points.append((x, y))
    for x, y in _marker_points(entry, drawn):
        around(x, y, 2 * BODY, 2 * BODY)
    for item in scene.get('stairs', []) + scene.get('doors', []) + scene.get('interactions', []) + scene.get('nodes', []):
        if 'at' in item and item.get('shape') in shapes and item.get('node', 'passage') in ('passage', 'landmark', 'service'):
            around(*item['at'], *shapes[item['shape']])
        elif 'at' in item and item.get('node') == 'service':
            around(*item['at'], 2 * BODY, 2 * BODY)
    # A doorway: floor in a gap of a wall, a run of at most 8 cells between wall on both ends
    # (furniture does not count as wall).
    blocked = ATLAS['blocked']
    open_ = walk | {c for c, (_, ax, ay, _) in drawn.tiles.structures.items() if (ax, ay) == blocked}
    for x, y in walk:
        for dx, dy in ((1, 0), (0, 1)):
            run = 1
            for sign in (1, -1):
                k = 1
                while (x + sign * k * dx, y + sign * k * dy) in open_ and k <= 8:
                    k += 1
                run += k - 1
            if run <= 8:
                keep.update(_box_cells(_grown((x * T, y * T, x * T + T, y * T + T), 3 * T)))
                points.append((x * T + 8, y * T + 8))
                break
    # Not hard against other furniture (nor hidden behind it), and well clear of a counter's front.
    rows = d.get('props', []) + d.get('fills', [])
    for row in rows:
        if isinstance(row, list) and row and isinstance(row[-1], dict) and 'look' in row[-1]:
            keep.update(_box_cells(_grown(tuple(row[1:5]), 3 * T if row[-1]['look'].get('kind') in COUNTERS else T)))
    return keep, points


def _fits(walk: set) -> set:
    """Cells a body's centre can stand on (the body's square all walkable)."""
    reach = -(-BODY // T)
    return {(x, y) for x, y in walk
            if all((x + dx, y + dy) in walk for dx in range(-reach + 1, reach) for dy in range(-reach + 1, reach))}


def _reached(walk: set, points: list) -> frozenset:
    """Which points a body can walk between (each stood near, a standing cell within 24 px):
    the points grouped by connected ground, and those with nowhere to stand alone."""
    fits = _fits(walk)
    group = {}
    for cell in fits:
        if cell in group:
            continue
        group[cell] = cell
        queue = deque([cell])
        while queue:
            cx, cy = queue.popleft()
            for n in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                if n in fits and n not in group:
                    group[n] = cell
                    queue.append(n)
    joined: dict = {}
    for i, (x, y) in enumerate(points):
        near = {group[(cx, cy)] for cx in range(int(x - 24) // T, int(x + 24) // T + 1)
                for cy in range(int(y - 24) // T, int(y + 24) // T + 1) if (cx, cy) in group}
        for g in near or {('alone', i)}:
            joined.setdefault(g, set()).add(i)
    # Points sharing any ground are together: merge the sets that overlap.
    sets: list[set] = []
    for members in joined.values():
        overlapping = [s for s in sets if s & members]
        for s in overlapping:
            sets.remove(s)
            members = members | s
        sets.append(set(members))
    return frozenset(frozenset(s) for s in sets)


def _slots(rect, walk: set, w: int, h: int):
    """Boxes w x h flush against the room's walls, (box, wall side), corners first."""
    x0, y0, x1, y1 = rect
    floor = {c for c in walk if x0 // T <= c[0] < x1 // T and y0 // T <= c[1] < y1 // T}
    if not floor:
        return []
    fx0, fx1 = min(c[0] for c in floor) * T, (max(c[0] for c in floor) + 1) * T
    fy0, fy1 = min(c[1] for c in floor) * T, (max(c[1] for c in floor) + 1) * T
    out = []
    for side in ('n', 's', 'w', 'e'):
        bw, bh = (w, h) if side in 'ns' else (h, w)
        if side in 'ns':
            y = fy0 if side == 'n' else fy1 - bh
            line = [(x, y) for x in range(fx0, fx1 - bw + 1, T)]
        else:
            x = fx0 if side == 'w' else fx1 - bw
            line = [(x, y) for y in range(fy0, fy1 - bh + 1, T)]
        for i, (x, y) in enumerate(line):
            corner = i == 0 or i == len(line) - 1
            out.append((0 if corner else 1, (x, y, x + bw, y + bh), side))
    return out


ROTATION = {'n': 0, 's': 180, 'w': 90, 'e': -90}


def dress(entry: dict, drawn, table: dict | None = None) -> list:
    """The fill rows of the pieces for every room with a life, in the room's own seed order."""
    rooms = rooms_of(entry)
    if not rooms:
        return []
    table = table or presets()
    rects = _zone_rects(entry)
    walk = drawn.tiles.walkable_cells()
    keep, points = _keep(entry, drawn, walk)
    before = _reached(walk, points)
    rows = []
    for zone in sorted(rooms):
        spec = rooms[zone]
        use = table['uses'][spec['use']]
        scale = table['wealth'][spec.get('wealth', 'plain')]['pieces'] * (table['tidy']['pieces'] if spec.get('tidy') else 1.0)
        rect = rects[zone]
        area = len({c for c in walk if rect[0] // T <= c[0] < rect[2] // T and rect[1] // T <= c[1] < rect[3] // T})
        # A preset's count is for a room of ~450 floor cells (a 14 x 10 body room inside its
        # furniture); a hall gets more, a closet fewer, but a room with pieces gets one at least.
        wanted = use.get('count', 0) * scale * min(1.6, max(0.6, area / 450))
        count = spec.get('count', max(1, round(wanted)) if wanted else 0)
        rng = random.Random(f'{zone}:{spec.get("seed", 0)}')
        clear = set(keep)
        for box in spec.get('keep_clear', []):
            clear |= _box_cells(tuple(box))
        pieces = use.get('pieces', [])
        for n in range(count if pieces else 0):
            piece = pieces[n % len(pieces)]
            w, h = piece['size']
            # A piece leant on its wall (`lean`: poles, tools) stands at the north wall, the one the
            # camera never cuts low; the others go round every wall.
            slots = [slot for slot in _slots(rect, walk, w, h) if slot[2] == 'n' or not piece.get('lean')]
            rng.shuffle(slots)
            slots.sort(key=lambda s: s[0])
            for _, box, side in slots:
                cells = _box_cells(box)
                if not cells <= walk or cells & clear:
                    continue
                if _reached(walk - cells, points) != before:
                    continue
                walk -= cells
                # A piece keeps a tile's gap from the next one, so they read as separate heaps.
                clear |= _box_cells(_grown(box, T))
                look = {k: v for k, v in piece.items() if k not in ('size', 'lean')}
                look['rotation'] = ROTATION[side]
                look['seed'] = rng.randrange(1000)
                rows.append(['blocked', *box, f'{zone}: {spec["use"]} {piece["kind"]}', {'look': look}])
                break
    return rows
