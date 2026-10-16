"""The scale standard (standard.json) and what the painter sizes from it.

Every length is a multiple of a body's width, rounded up to whole tiles, so changing the standard
and repainting re-scales every map drawn from it. Three things read it:

* Town streets and building facades. A town zone may be a street of a class instead of a box:

      "<zone>": {"street": "main" | "lane" | "road", "axis": "x" | "y", "centre": c,
                 "span": [from, to], "ground": "street"}

  (axis "y" runs north-south: x = centre +- half the class's width, y = span). A town map's
  `buildings` are the outsides of the buildings that have maps of their own:

      {"name": "<what it is>", "street": "<zone>", "side": "west" | "east" | "north" | "south",
       "frontage": "small" | "shop" | "wide" | "grand", "depth": <a depth class>, "at": <along>,
       "doors": ["<portal id>", ...], "wall": "wall_wood", "roof": "shop_front"}

  A facade stands against the street's `side` edge, centred at `at` along it (pixels on the
  edge's axis), walls round a roof that is not walkable. Each door is a portal of game/data
  from the street into the building: its passage stands just inside the street, its shutter
  on the wall (a WorldDoor over the passage when world.json's doors has one between the two
  zones), and the marker of the portal back out (to_spawn) a body in front of it.
  Facades may not overlap a zone or each other, and two on one side of a street keep an
  alley between them.

* `interior` maps, a building's rooms laid out from their exits:

      "draw": {"technique": "interior", "building": "school" | "inn" | ...,
               "larger_than": ["<region>/<map key>", ...],
               "rooms": {"<zone>": {"size": "<room class>", "floor": "floor_wood", "wall": "wall_wood",
                                    "at": [column, row]}, ...},
               "props": [[kind, "<zone>", anchor, wide, deep, note?], ...],
               "placed": {"<spawn point>": ["<zone>", anchor]},
               "doors": {"<portal id>": "north" | "south" | "east" | "west"},
               "reach_from": "<marker name>"}

  The first room sits at column 0, row 0 and every other one beside the room whose exit leads
  to it, in the exit's direction (an `at` overrides; a diagonal exit needs one). A column is as wide as its widest room, a
  row as tall as its tallest; a room keeps its own size but reaches to the edges of its cell
  where a neighbour or a way out lies, so neighbours share a wall with a doorway in it. A
  portal from a room to another map is a door on that room's wall in the portal's direction, or
  the wall `doors` names (its passage, shutter and the marker of the way back in); stairs (scene.stairs with "zone"
  and an "anchor" instead of "at") stand in their room. Anchors are "c", "n", "s", "e", "w",
  "ne", "nw", "se", "sw", optionally with an offset in bodies: ["n", 2, 1]. Prop sizes are in
  bodies. The building's floor (all rooms, as drawn) must reach its class's minimum and exceed the
  floor of each map in `larger_than` (a 武馆 is bigger than the inn). The painter notes rooms
  whose description speaks of size against their class (宽敞 in a small room).

* The filler: a technique's `base` (the ground every map is painted on first), when it is one
  of `trimmed_bases` (the bare boundary; a wild map's forest or cliff is terrain), is kept only
  within `skirt_tiles` of walkable ground; further out the map is empty.
"""

from __future__ import annotations

import copy
import json
import math
from collections import deque
from pathlib import Path

from .tiles import T

STANDARD = json.loads((Path(__file__).resolve().parent / 'standard.json').read_text(encoding='utf-8'))
# Only the four sides place a room: rooms a diagonal exit joins need an `at` that puts them
# side by side (two rooms touching at a corner share no wall for a doorway).
DIRS = {'north': (0, -1), 'south': (0, 1), 'east': (1, 0), 'west': (-1, 0)}
CARDINAL = {'north': 'n', 'south': 's', 'east': 'e', 'west': 'w'}
OPPOSITE = {'north': 'south', 'south': 'north', 'east': 'west', 'west': 'east', 'northeast': 'southwest',
            'southwest': 'northeast', 'northwest': 'southeast', 'southeast': 'northwest', 'up': 'down', 'down': 'up',
            'enter': 'out', 'out': 'enter'}
DOOR_COLOR = 'Color(0.42, 0.3, 0.18, 1)'


def px(bodies: float, step: int = T) -> int:
    """Bodies to pixels, rounded up to whole `step`s."""
    return int(math.ceil(bodies * STANDARD['body'] / step - 1e-9)) * step


def door_px() -> int:
    return px(STANDARD['door'], 2 * T)


def wall_px() -> int:
    return STANDARD['wall_tiles'] * T


def room_floor(size: str) -> tuple[int, int]:
    w, h = STANDARD['room'][size]
    return px(w), px(h)


def bodies2(w: int, h: int) -> float:
    return w * h / (STANDARD['body'] ** 2)


# --- Town streets and facades ---------------------------------------------------------------

def street_rect(spec: dict) -> list:
    """[x0, y0, x1, y1] of a street zone from its class, centre line and span."""
    width = px(STANDARD['street'][spec['street']], 2 * T)
    lo, hi = sorted(spec['span'])
    c = spec['centre']
    if spec['axis'] == 'y':
        return [c - width // 2, lo, c + width // 2, hi]
    return [lo, c - width // 2, hi, c + width // 2]


def prepare_town(region, entry: dict) -> dict:
    """A town entry with its street classes resolved to boxes and its buildings' facades,
    doors and markers added to the drawing and the scene."""
    d = entry['draw']
    if not any(isinstance(v, dict) for v in d['zones'].values()) and not d.get('buildings'):
        return entry
    entry = copy.deepcopy(entry)
    d, scene = entry['draw'], entry['scene']
    for zone_id, value in list(d['zones'].items()):
        if isinstance(value, dict):
            d['zones'][zone_id] = [*street_rect(value), 'open', value.get('ground', 'street'), None]
    portals = region.portals()
    shapes = scene.setdefault('shapes', {})
    facades = []
    for index, b in enumerate(d.get('buildings', [])):
        assert 'street' in b or not b.get('doors'), ('a building with doors names its street', b['name'])
        facade = b['rect'] if 'rect' in b else facade_rect(d['zones'][b['street']], b)
        for other_name, other in facades:
            assert not _overlap(facade, other), ('facades overlap', b['name'], other_name)
        for zone_id, z in d['zones'].items():
            assert not _overlap(facade, z[:4]), ('facade over a zone', b['name'], zone_id)
        facades.append((b['name'], facade))
        x0, y0, x1, y1 = facade
        d.setdefault('ground', []).append([b.get('wall', 'wall_wood'), x0, y0, x1, y1, b['name']])
        d['ground'].append([b.get('roof', 'shop_front'), x0 + T, y0 + T, x1 - T, y1 - T])
        for i, portal_id in enumerate(b.get('doors', [])):
            portal = portals[portal_id]
            assert portal['from_zone'] == b['street'], ('a door leads in from its street', portal_id)
            at = b.get('door_at', [])[i] if i < len(b.get('door_at', [])) else _along_centre(facade, b['side'])
            _door(region, scene, shapes, portal, portals, d['zones'][b['street']], b['side'], at,
                  f"Building{index}Door{i}")
    _check_alleys(d, facades)
    return entry


def facade_rect(street: list, b: dict) -> list:
    x0, y0, x1, y1 = street[:4]
    wide = px(STANDARD['facade']['frontage'][b['frontage']], 2 * T)
    deep = px(STANDARD['facade']['depth'][b.get('depth', 'shop')])
    at = b['at']
    side = b['side']
    if side == 'west':
        return [x0 - deep, at - wide // 2, x0, at + wide // 2]
    if side == 'east':
        return [x1, at - wide // 2, x1 + deep, at + wide // 2]
    if side == 'north':
        return [at - wide // 2, y0 - deep, at + wide // 2, y0]
    return [at - wide // 2, y1, at + wide // 2, y1 + deep]


def _check_alleys(d: dict, facades: list) -> None:
    alley = px(STANDARD['facade']['alley'])
    by_side = {}
    for b, (_, rect) in zip(d.get('buildings', []), facades):
        if 'street' in b:
            by_side.setdefault((b['street'], b['side']), []).append((b['name'], rect))
    for (street, side), rows in by_side.items():
        k = 1 if side in ('west', 'east') else 0
        rows.sort(key=lambda r: r[1][k])
        for (a, ra), (b, rb) in zip(rows, rows[1:]):
            assert rb[k] - ra[k + 2] >= alley, ('no alley between', a, b, rb[k] - ra[k + 2])


def _along_centre(rect: list, side: str) -> int:
    x0, y0, x1, y1 = rect
    return (y0 + y1) // 2 // T * T if side in ('west', 'east') else (x0 + x1) // 2 // T * T


def _overlap(a: list, b: list) -> bool:
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def _node(text: str) -> str:
    """A node name for a building: its index-free ASCII part, or B + a stable hash."""
    ascii_part = ''.join(ch for ch in text.title() if ch.isascii() and ch.isalnum())
    return ascii_part or 'B%04x' % (sum(ord(c) * (i + 1) for i, c in enumerate(text)) & 0xffff)


def reverse_portal(region, portal: dict, portals: dict) -> dict | None:
    """The portal back through the same door: from the room this one's exit leads into, by the
    exit that leads back to this one's room (the LPC pair); failing that, the only portal
    between the two zones the other way."""
    exits = region.room_exits()
    there = exits.get(portal['legacy_room'], {}).get(portal['legacy_command'])
    back = [p for p in portals.values()
            if p['legacy_room'] == there and exits.get(there, {}).get(p['legacy_command']) == portal['legacy_room']]
    if len(back) > 1:
        # Several exits lead back (a front door and a side door): the opposite direction, or the
        # one that is no other door's opposite.
        opposite = [p for p in back if OPPOSITE.get(portal['legacy_command']) == p['legacy_command']]
        siblings = [q for q in portals.values() if q is not portal and q['legacy_room'] == portal['legacy_room']
                    and exits.get(portal['legacy_room'], {}).get(q['legacy_command']) == there]
        taken = {OPPOSITE.get(q['legacy_command']) for q in siblings}
        back = opposite or [p for p in back if p['legacy_command'] not in taken]
    if len(back) == 1:
        return back[0]
    others = [p for p in portals.values() if p['from_zone'] == portal['to_zone'] and p['to_zone'] == portal['from_zone']]
    return others[0] if len(others) == 1 else None


def _door(region, scene: dict, shapes: dict, portal: dict, portals: dict, zone: list, wall_side: str, at: int,
          name: str) -> int:
    """A door on `zone`'s `wall_side` edge at `at` along it: the portal's passage just inside the
    zone, the shutter on the edge and, for the portal that comes back through it, its marker a
    body inside. A wall of an enclosed zone is inside its box; an open zone's edge is its box's."""
    x0, y0, x1, y1 = zone[:4]
    inset = wall_px() if zone[4] == 'enclosed' else 0
    half = door_px() // 2
    depth = 2 * T
    if wall_side in ('east', 'west'):
        edge = x1 - inset if wall_side == 'east' else x0 + inset
        inward = -1 if wall_side == 'east' else 1
        shutter = [edge, at - half, edge + T, at + half] if inward < 0 else [edge - T, at - half, edge, at + half]
        passage = [edge + inward * (depth // 2 + T), at]
        marker = [edge + inward * (depth + 3 * STANDARD['body'] // 2 + T), at]
        shape = f'Rect_{depth}_{door_px() + 2 * T}'
        shapes[shape] = [depth, door_px() + 2 * T]
    else:
        edge = y1 - inset if wall_side == 'south' else y0 + inset
        inward = -1 if wall_side == 'south' else 1
        shutter = [at - half, edge, at + half, edge + T] if inward < 0 else [at - half, edge - T, at + half, edge]
        passage = [at, edge + inward * (depth // 2 + T)]
        marker = [at, edge + inward * (depth + 3 * STANDARD['body'] // 2 + T)]
        shape = f'Rect_{door_px() + 2 * T}_{depth}'
        shapes[shape] = [door_px() + 2 * T, depth]
    scene.setdefault('nodes', [])
    door = region.door_between(portal['from_zone'], portal['to_zone'])
    if door is None:
        scene['nodes'].append({'node': 'rect', 'name': f'{name}Shutter', 'rect': shutter, 'color': DOOR_COLOR})
    else:
        # An LPC door on this way (create_door()): the door stands over the passage, so shut
        # it keeps everyone off it; both maps place it and share whether it is open.
        _ensure_doors(scene)
        scene.setdefault('doors', []).append({'name': f'{name}Door', 'id': door['id'], 'at': passage, 'shape': shape})
    scene['nodes'].append({'node': 'passage', 'name': f'{name}Passage', 'id': portal['id'], 'at': passage, 'shape': shape})
    back = [reverse_portal(region, portal, portals)] if reverse_portal(region, portal, portals) else []
    points = scene.setdefault('spawn_points', [])
    assert all(m.get('id') != p['to_spawn'] for p in back for m in points), ('two doors for one way back', portal['id'])
    for p in back:
        points.insert(0, {'name': region.marker_name(p['to_spawn']), 'at': [int(marker[0]), int(marker[1])], 'id': p['to_spawn']})
    return edge


def _ensure_doors(scene: dict) -> None:
    """A scene that places doors has their style and node slots (as Snow's outdoor map)."""
    scene.setdefault('door_style', {'walls': 'Terrain/DoorWalls', 'wall_suffix': 'Wall', 'shutters': 'Terrain',
                                    'color': DOOR_COLOR})
    nodes = scene.setdefault('nodes', [])
    if not any(n.get('generated') == 'doors' for n in nodes):
        nodes += [{'node': 'group', 'name': 'DoorWalls', 'type': 'StaticBody2D', 'parent': 'Terrain'},
                  {'generated': 'door_walls'}, {'generated': 'shutters'}, {'generated': 'doors'}]


# --- Interiors ------------------------------------------------------------------------------

def prepare_interior(region, entry: dict) -> dict:
    """An `interior` entry as the `town` entry that paints it."""
    entry = copy.deepcopy(entry)
    d, scene = entry['draw'], entry['scene']
    rooms = d['rooms']
    links = region.exits_between(set(rooms))
    grid = _place(rooms, links)
    wall = wall_px()
    portals = region.portals()
    zones_world = region.zone_maps()
    # Ways out to other maps: (portal, wall side), the side the exit's direction names unless
    # the layout's `doors` gives it (an exit named "out" or "enter").
    sides = {'n': 'north', 's': 'south', 'e': 'east', 'w': 'west'}
    outside = {}
    for p in portals.values():
        if p['from_zone'] not in rooms or zones_world.get(p['to_zone']) == scene['map']:
            continue
        side = d.get('doors', {}).get(p['id']) or (sides[CARDINAL[p['legacy_command']]] if p['legacy_command'] in CARDINAL else None)
        assert side, ('a way out needs a wall (give it in "doors")', p['id'])
        outside.setdefault(p['from_zone'], []).append((p, side))
    floors = {z: room_floor(spec.get('size', 'room')) for z, spec in rooms.items()}
    cols, rows = {}, {}
    for z, (c, r) in grid.items():
        w, h = floors[z]
        cols[c] = max(cols.get(c, 0), w + 2 * wall)
        rows[r] = max(rows.get(r, 0), h + 2 * wall)
    xs, x = {}, 0
    for c in sorted(cols):
        xs[c], x = x, x + cols[c]
    ys, y = {}, 0
    for r in sorted(rows):
        ys[r], y = y, y + rows[r]
    ox, oy = -(x // 2) // T * T, -(y // 2) // T * T
    zones = {}
    for z, (c, r) in grid.items():
        cx0, cy0, cx1, cy1 = xs[c] + ox, ys[r] + oy, xs[c] + ox + cols[c], ys[r] + oy + rows[r]
        w, h = floors[z][0] + 2 * wall, floors[z][1] + 2 * wall
        reach = set(_neighbour_sides(z, grid, links)) | {side[0] for _, side in outside.get(z, [])}
        # Stretched to one side, a room would slide away from a neighbour across that axis
        # (the room south of it is centred): with one there it fills the cell's width instead.
        across_x, across_y = bool(reach & {'n', 's'}), bool(reach & {'w', 'e'})
        to_w, to_e = 'w' in reach, 'e' in reach
        to_n, to_s = 'n' in reach, 's' in reach
        if to_w != to_e and across_x:
            to_w = to_e = True
        if to_n != to_s and across_y:
            to_n = to_s = True
        rx0, rx1 = _stretch(cx0, cx1, w, to_w, to_e)
        ry0, ry1 = _stretch(cy0, cy1, h, to_n, to_s)
        spec = rooms[z]
        zones[z] = [rx0, ry0, rx1, ry1, 'enclosed', spec.get('floor', 'floor_wood'), spec.get('wall', 'wall_wood')]
    margin = 3 * T
    d['bounds'] = [ox - margin, oy - margin, ox + x + margin, oy + y + margin]
    d['base'] = d.get('base', 'boundary')
    shapes = scene.setdefault('shapes', {})
    props = []
    assert wall == 2 * T, 'town.py draws two-tile walls and doorways: keep wall_tiles at 2'
    for z, ps in outside.items():
        on_side = {}
        for i, (p, side) in enumerate(ps):
            zx0, zy0, zx1, zy1 = zones[z][:4]
            at = (zy0 + zy1) // 2 // T * T if side in ('east', 'west') else (zx0 + zx1) // 2 // T * T
            k = on_side[side] = on_side.get(side, -1) + 1
            at += (k + 1) // 2 * (door_px() + 2 * T) * (1 if k % 2 else -1)
            lo, hi = (zy0, zy1) if side in ('east', 'west') else (zx0, zx1)
            assert lo + wall <= at - door_px() // 2 and at + door_px() // 2 <= hi - wall, ('no room on the wall for the door', p['id'])
            edge = _door(region, scene, shapes, p, portals, zones[z], side, at, f'{_node(z.split(".")[-1])}Door{i}')
            props.append(_doorway(zones[z], side, at, edge))
    for row in d.get('props', []):
        kind, z, anchor, wide, deep, *note = row
        props.append([kind, *_anchored(zones[z], anchor, px(wide), px(deep)), *note])
    for s in scene.get('stairs', []):
        if 'anchor' in s:
            w, h = scene['shapes'][s['shape']]
            box = _anchored(zones[s['zone']], s.pop('anchor'), w, h)
            s['at'] = [(box[0] + box[2]) // 2, (box[1] + box[3]) // 2]
            if 'marker' in s and 'at' not in s['marker']:
                cx, cy = s['at']
                zc = ((zones[s['zone']][0] + zones[s['zone']][2]) // 2, (zones[s['zone']][1] + zones[s['zone']][3]) // 2)
                step = max(w, h) // 2 + STANDARD['body'] + T
                s['marker']['at'] = [cx + int(math.copysign(step, zc[0] - cx)) if abs(zc[0] - cx) > abs(zc[1] - cy) else cx,
                                     cy + int(math.copysign(step, zc[1] - cy)) if abs(zc[1] - cy) >= abs(zc[0] - cx) else cy]
    placed = {}
    for point, (z, anchor) in d.get('placed', {}).items():
        box = _anchored(zones[z], anchor, STANDARD['body'] + 4, STANDARD['body'] + 4, snap=False)
        placed[point] = [(box[0] + box[2]) // 2, (box[1] + box[3]) // 2]
    floor_area = sum(bodies2(v[2] - v[0] - 2 * wall, v[3] - v[1] - 2 * wall) for v in zones.values())
    minimum = STANDARD['building'][d['building']]
    assert floor_area >= minimum, ('building smaller than its class', scene['map'], round(floor_area), minimum)
    entry['draw'] = {
        'technique': 'town', 'base': d['base'], 'bounds': d['bounds'], 'ground': d.get('ground', []), 'zones': zones,
        'roads': [], 'props': props, 'reach_from': d['reach_from'], 'markers_in_middle': d.get('markers_in_middle', []),
        'placed': placed, 'gap_at': d.get('gap_at', []),
        'interior': {'floor': floor_area, 'larger_than': d.get('larger_than', []), 'notes': size_notes(region, rooms)},
    }
    return entry


def floor_of(entry: dict) -> float:
    """A town map's floor in square bodies: its enclosed rooms' insides (an interior's is
    prepare_interior()'s `floor`, as drawn)."""
    wall = wall_px()
    total = 0.0
    for v in entry['draw'].get('zones', {}).values():
        if isinstance(v, list) and v[4] == 'enclosed':
            total += bodies2(v[2] - v[0] - 2 * wall, v[3] - v[1] - 2 * wall)
    return total


def size_notes(region, rooms: dict) -> list:
    """Rooms whose description speaks of their size against their class."""
    longs = region.zone_longs()
    small, large = STANDARD['words']['small'], STANDARD['words']['large']
    notes = []
    for z, spec in rooms.items():
        size = spec.get('size', 'room')
        text = longs.get(z, '')
        big = [w for w in large if w in text]
        tiny = [w for w in small if w in text]
        if big and size in ('closet', 'small', 'room'):
            notes.append(f'{z} is "{size}" but its description says {"/".join(big)}')
        if tiny and size in ('large', 'hall', 'yard', 'grand'):
            notes.append(f'{z} is "{size}" but its description says {"/".join(tiny)}')
    return notes


def _place(rooms: dict, links: dict) -> dict:
    grid = {z: tuple(spec['at']) for z, spec in rooms.items() if 'at' in spec}
    first = next(iter(rooms))
    grid.setdefault(first, (0, 0))
    queue = deque(grid)
    while queue:
        z = queue.popleft()
        for command, other in links.get(z, []):
            if other in rooms and other not in grid and command in DIRS:
                dx, dy = DIRS[command]
                grid[other] = (grid[z][0] + dx, grid[z][1] + dy)
                queue.append(other)
    missing = set(rooms) - set(grid)
    assert not missing, ('rooms no exit places (give them "at")', sorted(missing))
    cells = {}
    for z, cell in grid.items():
        assert cell not in cells, ('two rooms on one cell (give one an "at")', cells.get(cell), z, cell)
        cells[cell] = z
    return grid


def _neighbour_sides(z: str, grid: dict, links: dict):
    c, r = grid[z]
    for _, other in links.get(z, []):
        if other not in grid:
            continue
        oc, orow = grid[other]
        if oc > c:
            yield 'e'
        if oc < c:
            yield 'w'
        if orow > r:
            yield 's'
        if orow < r:
            yield 'n'


def _stretch(lo: int, hi: int, size: int, to_lo: bool, to_hi: bool) -> tuple[int, int]:
    """A room's extent in its cell: its own size, reaching each edge a neighbour or a way out
    lies beyond."""
    if to_lo and to_hi:
        return lo, hi
    if to_lo:
        return lo, lo + size
    if to_hi:
        return hi - size, hi
    start = lo + (hi - lo - size) // 2 // T * T
    return start, start + size


def _doorway(zone: list, side: str, at: int, edge: int) -> list:
    """The floor cut through the room's wall where its door is."""
    x0, y0, x1, y1 = zone[:4]
    half = door_px() // 2
    ground = zone[5]
    if side == 'east':
        return [ground, x1 - wall_px(), at - half, x1, at + half, 'the doorway out']
    if side == 'west':
        return [ground, x0, at - half, x0 + wall_px(), at + half, 'the doorway out']
    if side == 'north':
        return [ground, at - half, y0, at + half, y0 + wall_px(), 'the doorway out']
    return [ground, at - half, y1 - wall_px(), at + half, y1, 'the doorway out']


def _anchored(zone: list, anchor, w: int, h: int, snap: bool = True) -> list:
    """A w x h box in a room's floor at an anchor ("n", ["ne", 1, 2], ...): against that wall or
    corner, offset by whole bodies towards the middle."""
    if isinstance(anchor, str):
        anchor = [anchor, 0, 0]
    where, ox, oy = anchor[0], anchor[1] if len(anchor) > 1 else 0, anchor[2] if len(anchor) > 2 else 0
    wall = wall_px()
    fx0, fy0, fx1, fy1 = zone[0] + wall, zone[1] + wall, zone[2] - wall, zone[3] - wall
    body = STANDARD['body']
    if 'w' in where:
        x = fx0 + ox * body
    elif 'e' in where:
        x = fx1 - w - ox * body
    else:
        x = (fx0 + fx1 - w) / 2 + ox * body
    if 'n' in where:
        y = fy0 + oy * body
    elif 's' in where:
        y = fy1 - h - oy * body
    else:
        y = (fy0 + fy1 - h) / 2 + oy * body
    if snap:
        x, y = int(x // T * T), int(y // T * T)
    return [int(x), int(y), int(x) + w, int(y) + h]


# --- Filler -------------------------------------------------------------------------------------

def trim_filler(tiles, base: str, zones=()) -> None:
    """Drops the base filler further than the skirt from any walkable cell and outside every
    zone (inside one an empty cell would let a spot behind a thick wall pass for free ground)."""
    from .tiles import ATLAS
    skirt = STANDARD['skirt_tiles']
    kind = ATLAS[base]
    walkable = tiles.walkable_cells()
    near = {(x + dx, y + dy) for x, y in walkable for dx in range(-skirt, skirt + 1) for dy in range(-skirt, skirt + 1)}
    for layer in (tiles.ground, tiles.structures):
        for cell in [c for c, v in layer.items() if (v[1], v[2]) == kind and c not in near]:
            x, y = cell[0] * T + T // 2, cell[1] * T + T // 2
            if not any(z[0] <= x < z[2] and z[1] <= y < z[3] for z in zones):
                del layer[cell]
