"""Technique `cells`: rooms on a grid of equal square cells, each a walled box with its floor
inset by two tiles.

    "draw": {"technique": "cells", "cell": 256, "base": "boundary", "bounds": [x0, y0, x1, y1],
             "rooms": {"<zone>": [column, row, columns wide, ground, wall], ...},
             "reserved": {"<zone>": [[slot x, slot y], ...]}}

Generated: `zones` (the cell boxes), `captions` (the zone's room name at the foot of each room)
and `markers` (game/data spawns and item spawns of these zones, on a fixed 5x5 grid of slots per
cell, skipping the band of a room with stairs and its reserved slots).
"""

from __future__ import annotations

from . import scene as sc
from .region import Drawn, zone_node_name
from .tiles import Tiles

SLOTS = [52, 90, 128, 166, 204]
BAND = (84 - 17, 172 + 17)  # the middle band, a body's half-width either side


def draw(region, entry: dict) -> Drawn:
    d, scene = entry['draw'], entry['scene']
    style = scene['style']
    cell, rooms = d['cell'], d['rooms']
    assert cell == 256, 'SLOTS, BAND and the caption offset are laid out for 256 px cells'
    bounds = tuple(d['bounds'])

    def box(zone_id):
        c, r, w = rooms[zone_id][:3]
        return c * cell, r * cell, (c + w) * cell, (r + 1) * cell

    tiles = Tiles()
    tiles.fill(d['base'], *bounds)
    for zone_id, (_, _, _, ground, wall) in rooms.items():
        x0, y0, x1, y1 = box(zone_id)
        tiles.fill(wall, x0, y0, x1, y1)
        tiles.fill(ground, x0 + 32, y0 + 32, x1 - 32, y1 - 32)

    shorts = region.shorts()
    shapes, zones, captions = {}, '', ''
    for zone_id in rooms:
        x0, y0, x1, y1 = box(zone_id)
        shapes[f'Rect_{x1 - x0}_{y1 - y0}'] = (x1 - x0, y1 - y0)
        zones += sc.build('zone', style, name=zone_node_name(zone_id, 'Zone'), id=zone_id,
                          at=((x0 + x1) // 2, (y0 + y1) // 2), shape=f'Rect_{x1 - x0}_{y1 - y0}')
        captions += sc.caption(zone_node_name(zone_id, 'Label'), (x0 + 40, y0 + 226), shorts[zone_id], 14)

    with_stairs = {s['zone'] for s in scene.get('stairs', [])}
    reserved = {z: {tuple(p) for p in slots} for z, slots in d.get('reserved', {}).items()}

    def slots(zone_id):
        x0, y0, x1, _ = box(zone_id)
        xs = SLOTS if x1 - x0 <= cell else SLOTS + [cell + x for x in SLOTS]
        out = []
        for y in SLOTS:
            for x in xs:
                if zone_id in with_stairs and BAND[0] < x % cell < BAND[1]:
                    continue
                if (x, y) in reserved.get(zone_id, ()):
                    continue
                out.append((x0 + x, y0 + y))
        return out

    markers, used = '', {}
    for record in region.spawn_records():
        if record['zone'] not in rooms:
            continue
        free = used.setdefault(record['zone'], slots(record['zone']))
        for point in record['points']:
            assert free, ('no room for', point)
            markers += sc.build('marker', style, name=region.marker_name(point), at=free.pop(0), id=point)

    return Drawn(tiles, {'zones': zones, 'captions': captions, 'markers': markers}, shapes, bounds)
