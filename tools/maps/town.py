"""Technique `town`: zones as rectangles of their own sizes; open ones (streets, fields) are bare
ground that runs into each other, enclosed ones (shops, houses) are walled with a doorway onto
each zone a room exit joins them to.

    "draw": {"technique": "town", "base": "boundary", "bounds": [x0, y0, x1, y1],
             "ground": [fill rows painted before the zones],
             "zones": {"<zone>": [x0, y0, x1, y1, "open" | "enclosed", ground, wall | null], ...},
             "roads": [fill rows], "props": [fill rows],     painted over the zones, in that order
             "gap_at": [["<zone>", "<zone>", centre], ...],  a doorway not in the middle of the edge
             "reach_from": "<marker name>",
             "markers_in_middle": ["<zone>", ...],           open zones that are not streets
             "placed": {"<spawn point>": [x, y], ...}}       spawn points not packed into slots

Rooms that share an edge must be neighbours (room exits in game/data) and every walkable step
from the reach marker stays between neighbours; a body must reach every room and what the player
uses must be within reach (canvas.within_reach, with every marker the map places). Doors `between`
two zones sit in their doorway: across the shared edge between two buildings, in the building's
wall when one side is a street.
Generated: `zones`, `captions` (top left of open zones, bottom left inside enclosed ones) and
`markers` (game/data spawns and item spawns, packed in reading order onto open ground clear of
doorways, stairs, the lanes from each doorway to the room's middle and the middle of streets).
"""

from __future__ import annotations

from collections import deque

from . import scene as sc
from .canvas import Canvas, within_reach
from .region import Drawn, explicit_markers, fill_row, zone_node_name
from .tiles import ATLAS, T, Tiles

OPEN, ENCLOSED = 'open', 'enclosed'


def draw(region, entry: dict) -> Drawn:
    d, scene = entry['draw'], entry['scene']
    town = Town(region, d, scene)
    tiles = Tiles()
    gaps = town.paint(tiles)
    reached, bad = town.reach(tiles, explicit_markers(scene)[d['reach_from']])
    assert not bad, ('walkable between rooms that are not neighbours', bad)
    missing = set(town.zones) - reached
    assert not missing, ('cut off', missing)
    style = scene['style']
    shapes, zones = {}, ''
    for zone_id, (x0, y0, x1, y1, *_) in town.zones.items():
        shapes[f'Rect_{x1 - x0}_{y1 - y0}'] = (x1 - x0, y1 - y0)
        zones += sc.build('zone', style, name=zone_node_name(zone_id, 'Zone'), id=zone_id,
                          at=((x0 + x1) // 2, (y0 + y1) // 2), shape=f'Rect_{x1 - x0}_{y1 - y0}')
    shorts = region.shorts()
    captions = ''.join(sc.caption(zone_node_name(z, 'Label'), town.caption_spot(z), shorts[z], 14) for z in town.zones)
    fragments = {'zones': zones, 'captions': captions, 'markers': town.markers(tiles, gaps)}
    named = explicit_markers(scene)
    body = town.canvas(tiles)
    seen = body.reach(named[d['reach_from']], town.pairs)
    missing = set(town.zones) - {body.zone_at(x * T + 8, y * T + 8) for x, y in seen}
    assert not missing, ('no way for a body into', missing)
    within_reach(body, seen, scene, {**named, **town.spots}, region.service_reach(), region.contact_landmarks(),
                 region.owner_zones())
    return Drawn(tiles, fragments, shapes, tuple(d['bounds']), town.door_at,
                 [f'{len(town.zones)} rooms, {len(gaps)} doorway bands'])


class Town:
    def __init__(self, region, d: dict, scene: dict) -> None:
        self.region = region
        self.d = d
        self.zones = {z: tuple(v) for z, v in d['zones'].items()}
        self.gap_at = {(row[0], row[1]): row[2] for row in d.get('gap_at', [])}
        self.stairs = scene.get('stairs', [])
        self.style = scene['style']
        self.pairs = region.neighbours(self.zones)
        self.spots = {}
        self.check()

    def check(self) -> None:
        """Every neighbour pair shares an edge; no two zones overlap."""
        for a, b in self.pairs:
            assert self.shared_edge(a, b) is not None, ('neighbours apart', a, b)
        ids = sorted(self.zones)
        for i, a in enumerate(ids):
            for b in ids[i + 1:]:
                ax0, ay0, ax1, ay1 = self.zones[a][:4]
                bx0, by0, bx1, by1 = self.zones[b][:4]
                assert not (ax0 < bx1 and bx0 < ax1 and ay0 < by1 and by0 < ay1), ('overlap', a, b)

    def shared_edge(self, a, b):
        """(vertical?, edge coordinate, from, to) of the boundary two rects share, or None."""
        ax0, ay0, ax1, ay1 = self.zones[a][:4]
        bx0, by0, bx1, by1 = self.zones[b][:4]
        for edge in ({ax1} & {bx0}) | ({bx1} & {ax0}):
            lo, hi = max(ay0, by0), min(ay1, by1)
            if hi > lo:
                return True, edge, lo, hi
        for edge in ({ay1} & {by0}) | ({by1} & {ay0}):
            lo, hi = max(ax0, bx0), min(ax1, bx1)
            if hi > lo:
                return False, edge, lo, hi
        return None

    def gap(self, a, b):
        vertical, edge, lo, hi = self.shared_edge(a, b)
        centre = self.gap_at.get((a, b), self.gap_at.get((b, a), (lo + hi) // 2 // 16 * 16))
        assert lo <= centre - 32 and centre + 32 <= hi, (a, b, centre, lo, hi)
        return vertical, edge, centre

    def door_at(self, between):
        """A door across the doorway between two zones: (centre, shape, extent). Between two
        buildings it straddles the shared edge; from a street it fills the building's wall."""
        vertical, edge, centre = self.gap(*between)
        w, h = (32, 64) if vertical else (64, 32)
        across = edge
        open_side = [z for z in between if self.zones[z][4] == OPEN]
        if open_side:
            x0, y0, *_ = self.zones[next(z for z in between if z not in open_side)]
            across = edge + (16 if (x0 if vertical else y0) == edge else -16)
        return ((across, centre) if vertical else (centre, across)), f'Rect_{w}_{h}', (w, h)

    def canvas(self, tiles: Tiles) -> Canvas:
        """The painted town as a canvas, for the body-size checks the canvas maps get."""
        body = Canvas({z: v[:4] for z, v in self.zones.items()}, {}, tuple(self.d['bounds']), self.d['base'])
        kinds = {v: k for k, v in ATLAS.items()}
        for layer in (tiles.ground, tiles.structures):
            for cell, (_, ax, ay, _) in layer.items():
                body.kind[cell] = kinds[(ax, ay)]
        return body

    def paint(self, tiles: Tiles) -> list:
        tiles.fill(self.d['base'], *self.d['bounds'])
        for row in self.d.get('ground', []):
            tiles.fill(*fill_row(row))
        for x0, y0, x1, y1, mode, ground, wall in self.zones.values():
            if mode == OPEN:
                tiles.fill(ground, x0, y0, x1, y1)
            else:
                tiles.fill(wall, x0, y0, x1, y1)
                tiles.fill(ground, x0 + 32, y0 + 32, x1 - 32, y1 - 32)
        for row in self.d.get('roads', []) + self.d.get('props', []):
            tiles.fill(*fill_row(row))
        gaps = []
        for a, b in sorted(self.pairs):
            if self.zones[a][4] == OPEN and self.zones[b][4] == OPEN:
                continue
            vertical, edge, centre = self.gap(a, b)
            for zone_id in (a, b):
                x0, y0, x1, y1, mode, ground, _ = self.zones[zone_id]
                if mode != ENCLOSED:
                    continue
                if vertical:
                    band = (edge - 32, centre - 32, edge, centre + 32) if x1 == edge else (edge, centre - 32, edge + 32, centre + 32)
                else:
                    band = (centre - 32, edge - 32, centre + 32, edge) if y1 == edge else (centre - 32, edge, centre + 32, edge + 32)
                tiles.fill(ground, *band)
                gaps.append(band)
        return gaps

    def zone_of_point(self, x, y):
        for zone_id, (x0, y0, x1, y1, *_) in self.zones.items():
            if x0 <= x < x1 and y0 <= y < y1:
                return zone_id
        return None

    def reach(self, tiles: Tiles, start_point):
        """Walkable cells from a point, never crossing between rooms that are not neighbours."""
        cells = tiles.walkable_cells()
        start = (start_point[0] // 16, start_point[1] // 16)
        seen = {start}
        queue = deque([start])
        bad = set()
        while queue:
            cx, cy = queue.popleft()
            here = self.zone_of_point(cx * 16 + 8, cy * 16 + 8)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nxt = (cx + dx, cy + dy)
                if nxt not in cells or nxt in seen:
                    continue
                there = self.zone_of_point(nxt[0] * 16 + 8, nxt[1] * 16 + 8)
                if here and there and here != there and tuple(sorted((here, there))) not in self.pairs:
                    bad.add(tuple(sorted((here, there))))
                    continue
                if there is None and here is not None:
                    bad.add((here, 'outside'))
                    continue
                seen.add(nxt)
                queue.append(nxt)
        reached = {self.zone_of_point(x * 16 + 8, y * 16 + 8) for x, y in seen}
        return reached, bad

    def slots(self, tiles: Tiles, zone_id, avoid, doors=()):
        """Marker spots on open ground in a room, clear of doorways, stairs, the lanes from each
        doorway to the room's middle (bodies block the way), and each other."""
        x0, y0, x1, y1, mode, *_ = self.zones[zone_id]
        hub = ((x0 + x1) / 2, (y0 + y1) / 2)
        cells = tiles.walkable_cells()
        inset = 48 if mode == ENCLOSED else 32
        wide, tall = x1 - x0, y1 - y0
        out = []
        for y in range(y0 + inset, y1 - inset + 1, 8):
            for x in range(x0 + inset, x1 - inset + 1, 8):
                box = {((x + dx) // 16, (y + dy) // 16) for dx in (-20, -8, 8, 20) for dy in (-20, -8, 8, 20)}
                if not box <= cells:
                    continue
                if any(abs(x - ax) < 60 and abs(y - ay) < 60 for ax, ay in avoid):
                    continue
                if mode == ENCLOSED and any(_near_segment(x, y, dx, dy, hub[0], hub[1], 44) for dx, dy in doors):
                    continue
                if mode == OPEN and zone_id not in self.d.get('markers_in_middle', []):
                    # Keep the middle of a street free: the long sides only.
                    if wide >= tall and abs(y - (y0 + y1) / 2) < tall / 2 - 48:
                        continue
                    if tall > wide and abs(x - (x0 + x1) / 2) < wide / 2 - 48:
                        continue
                out.append((x, y))
        return out

    def markers(self, tiles: Tiles, gaps: list) -> str:
        placed = {p: tuple(at) for p, at in self.d.get('placed', {}).items()}
        avoid = [((g[0] + g[2]) // 2, (g[1] + g[3]) // 2) for g in gaps]
        avoid += [tuple(s['at']) for s in self.stairs] + [tuple(s['marker']['at']) for s in self.stairs]
        text = ''
        used = {}
        for record in self.region.spawn_records():
            if record['zone'] not in self.zones:
                continue
            for point in record['points']:
                if point in placed:
                    pos = placed[point]
                else:
                    taken = used.setdefault(record['zone'], [])
                    inside = [((g[0] + g[2]) // 2, (g[1] + g[3]) // 2) for g in gaps
                              if self.zone_of_point((g[0] + g[2]) // 2, (g[1] + g[3]) // 2) == record['zone']]
                    inside += [tuple(s['at']) for s in self.stairs if s['zone'] == record['zone']]
                    free = [p for p in self.slots(tiles, record['zone'], avoid, inside)
                            if all(abs(p[0] - q[0]) >= 38 or abs(p[1] - q[1]) >= 38 for q in taken)]
                    assert free, ('no room for', point)
                    # Packed in reading order, 38 px apart (a body is 34).
                    pos = free[0]
                    taken.append(pos)
                self.spots[self.region.marker_name(point)] = pos
                text += sc.build('marker', self.style, name=self.region.marker_name(point), at=pos, id=point)
        return text

    def caption_spot(self, zone_id):
        x0, y0, x1, y1, mode, *_ = self.zones[zone_id]
        if mode == ENCLOSED:
            return (x0 + 40, y1 - 58)
        return (x0 + 8, y0 + 4)


def _near_segment(px, py, ax, ay, bx, by, width):
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    k = 0.0 if length == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length))
    cx, cy = ax + k * dx, ay + k * dy
    return (px - cx) ** 2 + (py - cy) ** 2 < width * width
