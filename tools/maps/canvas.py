"""Technique `canvas`: natural ground on a 16 px canvas of rock — rough ellipses (blobs), wobbly
lines (roads with verges, tunnels) and boxes, painted step by step, then clipped to the zones and
cut apart wherever two zones that are not neighbours would touch.

    "draw": {"technique": "canvas", "base": "cliff", "bounds": [x0, y0, x1, y1],
             "zones": {"<zone>": [x0, y0, x1, y1, ground], ...},
             "lines": {"<group>": [[[x, y, road half-width, verge left, verge right, wobble], ...], ...]},
             "chambers": {"<zone>": [[x, y], [rx, ry], seed], ...},
             "steps": [...], "reach_from": "<marker name>",
             "caption_near": {"<zone>": [x, y], ...},
             "markers": {"lanes": "<group>", "kinds": [...], "rooms": {"<zone>":
                         {"mouths": [[x, y], ...], "points": [["<name>", "<spawn point>"], ...]}}}}

Optional: "names": {"<zone>": "NodeName", ...} names a zone's node (NodeNameZone) and caption
(NodeNameLabel) instead of the id's parts.

Steps, in order:
    {"op": "blobs", "blobs": [[x, y, rx, ry, seed?], ...], "kind": k?, "only": [kinds]?, "amp": a,
     "seed": [sx, sy]}        a blob without its own seed gets x * sx + y * sy; no kind = zone ground
    {"op": "freeze"}          what lies behind the open ground from now on (where clipping closes up)
    {"op": "lines", "group": g, "kind": k?}   verges in each zone's ground, then the trodden
                              path (or `kind`: a stream, a chasm, a bough) over them
    {"op": "chambers"}        each chamber: a blob and two side pockets, in the zone's ground
    {"op": "fill", "fills": [fill rows]}
    {"op": "clip"}, {"op": "separate"}, {"op": "drop_pockets", "from": "<marker name>"}

A line point's verges are to the left and right of the direction of travel; a verge no wider than
the road means bare rock. A body must reach every zone from the reach marker, crossing only between
neighbours (room exits and zone `links` in game/data), and every neighbour pair must be joined; what
the player uses must be within reach (see within_reach). Generated: `zones`,
`captions` (the room name beside its open ground, never on the path or over a marker, as near the
given point as it fits) and `markers` (bodies spread out in a room, clear of the lanes from each
mouth to the chamber's centre and along the lines).
"""

from __future__ import annotations

import math
from collections import deque

from . import scene as sc
from .region import Drawn, explicit_markers, fill_row, numbers, zone_node_name
from .tiles import BLOCKING, T, Tiles

BODY = 17  # half of a 34 px body


def draw(region, entry: dict) -> Drawn:
    d, scene = entry['draw'], entry['scene']
    style = scene['style']
    named = explicit_markers(scene)
    zones = {z: tuple(v[:4]) for z, v in d['zones'].items()}
    verge = {z: v[4] for z, v in d['zones'].items()}
    lines = {g: [[tuple(numbers(p)) for p in poly] for poly in polys] for g, polys in d.get('lines', {}).items()}
    chambers = d.get('chambers', {})
    pairs = region.neighbours(zones)
    c = Canvas(zones, verge, tuple(d['bounds']), d['base'])
    for step in d['steps']:
        op = step['op']
        if op == 'blobs':
            sx, sy = step.get('seed', (0, 0))
            only = set(step['only']) if 'only' in step else None
            for row in step['blobs']:
                v = numbers(row)
                x, y, rx, ry = v[:4]
                seed = v[4] if len(v) > 4 else x * sx + y * sy
                c.blob(x, y, rx, ry, kind=step.get('kind'), seed=seed, amp=step['amp'], only=only)
        elif op == 'freeze':
            c.freeze_base()
        elif op == 'lines':
            c.lines(lines[step['group']], step.get('kind', 'path'))
        elif op == 'chambers':
            for (x, y), (rx, ry), seed in chambers.values():
                c.blob(x, y, rx, ry, seed=seed, amp=0.2)
                c.blob(x + rx * 0.45, y - ry * 0.4, rx * 0.4, ry * 0.35, seed=seed + 1, amp=0.25)   # side pockets
                c.blob(x - rx * 0.35, y + ry * 0.45, rx * 0.4, ry * 0.35, seed=seed + 2, amp=0.25)
        elif op == 'fill':
            for row in step['fills']:
                c.fill(*fill_row(row))
        elif op == 'clip':
            c.clip()
        elif op == 'separate':
            c.separate(pairs)
        elif op == 'drop_pockets':
            c.drop_pockets(named[step['from']])
        else:
            raise ValueError(f'unknown canvas step {op!r}')

    reached = c.reach(named[d['reach_from']], pairs)
    assert {c.zone_at(x * T + 8, y * T + 8) for x, y in reached} == set(zones), ('cut off', zones)
    for a, b in pairs:
        assert c.seam(a, b), ('neighbours not joined', a, b)
    within_reach(c, reached, scene, named, region.service_reach(), region.contact_landmarks(), region.owner_zones())

    markers, bodies = '', list(named.values())
    spec = d.get('markers')
    if spec:
        segments = [(a[0], a[1], b[0], b[1]) for poly in lines[spec['lanes']] for a, b in zip(poly, poly[1:])]
        for zone_id, room in spec['rooms'].items():
            hub = chambers[zone_id][0]
            lanes = [(mx, my, hub[0], hub[1]) for mx, my in room['mouths']] + segments
            spots = slots(c, zone_id, lanes, [], len(room['points']), set(spec['kinds']))
            for (name, point), pos in zip(room['points'], spots):
                markers += sc.build('marker', style, name=name, at=pos, id=point)
                bodies.append(pos)

    shorts = region.shorts()
    shapes, zone_nodes, captions = {}, '', ''
    names = d.get('names', {})
    for zone_id, (x0, y0, x1, y1) in zones.items():
        shapes[f'Rect_{x1 - x0}_{y1 - y0}'] = (x1 - x0, y1 - y0)
        name = names.get(zone_id)
        zone_nodes += sc.build('zone', style, name=name + 'Zone' if name else zone_node_name(zone_id, 'Zone'), id=zone_id,
                               at=((x0 + x1) // 2, (y0 + y1) // 2), shape=f'Rect_{x1 - x0}_{y1 - y0}')
        spot = caption_spot(c, zone_id, shorts[zone_id], d['caption_near'][zone_id], bodies)
        captions += sc.caption(name + 'Label' if name else zone_node_name(zone_id, 'Label'), spot, shorts[zone_id], 14)
    return Drawn(c.tiles(), {'zones': zone_nodes, 'captions': captions, 'markers': markers}, shapes, tuple(d['bounds']))


def within_reach(canvas, reached, scene, named, reach, contact, owners):
    """Everything the player uses stands where they can get to: each placed marker on open ground
    a body fits and can walk to, a passage (stairs too) and a landmark used by touch (`contact`)
    over ground a body can stand on (both act on the body's centre) and any other landmark within
    64 px of it,
    each service point within its reach of such ground, always ground of the zone that owns it
    (`owners`: the portal's, landmark's or service's zone in game/data); and nothing walkable at
    the canvas's edge."""
    x0, y0, x1, y1 = canvas.bounds
    edge = [c for c in canvas.kind if canvas.walkable(c) and (c[0] in (x0 // T, x1 // T - 1) or c[1] in (y0 // T, y1 // T - 1))]
    assert not edge, ('walkable at the edge of the canvas', edge[:4])
    for name, (x, y) in named.items():
        body = [(cx, cy) for cx in range(math.floor((x - BODY) / T), math.ceil((x + BODY) / T))
                for cy in range(math.floor((y - BODY) / T), math.ceil((y + BODY) / T))]
        assert all(canvas.walkable(cell) for cell in body), ('no room for a body at', name)
        assert (int(x // T), int(y // T)) in reached, ('cannot walk to', name)
    centres = [(cx * T + 8, cy * T + 8) for cx, cy in reached]

    def ground(item_id):
        return [(px, py) for px, py in centres if owners.get(item_id) in (None, canvas.zone_at(px, py))]
    sizes = scene['shapes']
    for item in scene.get('interactions', []):
        (ax, ay), (w, h) = item['at'], sizes[item['shape']]
        near = 0 if item['id'] in contact else 64
        assert any(abs(px - ax) <= w / 2 + near and abs(py - ay) <= h / 2 + near for px, py in ground(item['id'])), ('cannot stand at', item['name'])
    for item in scene.get('nodes', []) + [dict(s, node='passage') for s in scene.get('stairs', [])]:
        if item.get('node') == 'passage':
            (ax, ay), (w, h) = item['at'], sizes[item['shape']]
            assert any(abs(px - ax) <= w / 2 and abs(py - ay) <= h / 2 for px, py in ground(item['id'])), ('cannot stand in', item['name'])
        if item.get('node') == 'service':
            (ax, ay), r = item['at'], reach[item['id']]
            assert any(math.hypot(px - ax, py - ay) <= r for px, py in ground(item['id'])), ('out of reach', item['name'])


def wob(s, seed):
    """A smooth wobble in -1..1 along a line's length."""
    return 0.6 * math.sin(s / 23.0 + seed) + 0.4 * math.sin(s / 9.0 + seed * 2.1)


def nearest(poly, px, py):
    """(distance, length along, interpolated (rw, vl, vr, n), right side?) of the nearest point."""
    best = None
    s0 = 0.0
    for a, b in zip(poly, poly[1:]):
        ax, ay, bx, by = a[0], a[1], b[0], b[1]
        dx, dy = bx - ax, by - ay
        length2 = dx * dx + dy * dy
        length = math.sqrt(length2)
        t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length2))
        cx, cy = ax + t * dx, ay + t * dy
        d = math.hypot(px - cx, py - cy)
        if best is None or d < best[0] - 1e-9:
            attrs = [u + t * (v - u) for u, v in zip(a[2:], b[2:])]
            best = (d, s0 + t * length, attrs, dx * (py - ay) - dy * (px - ax) > 0)
        s0 += length
    return best


class Canvas:
    def __init__(self, zones, verge, bounds, backdrop='cliff'):
        self.zones = zones
        self.verge = verge
        self.bounds = bounds
        self.kind = {}
        x0, y0, x1, y1 = bounds
        for cy in range(y0 // T, y1 // T):
            for cx in range(x0 // T, x1 // T):
                self.kind[(cx, cy)] = backdrop
        self.backdrop = backdrop
        self.base = None

    def freeze_base(self):
        """What lies behind the open ground (cliff, wood): where it closes up again."""
        self.base = dict(self.kind)

    def rock_at(self, cell):
        return self.backdrop if self.base is None else self.base[cell]

    def zone_at(self, x, y):
        for zone_id, (x0, y0, x1, y1) in self.zones.items():
            if x0 <= x < x1 and y0 <= y < y1:
                return zone_id
        return None

    def cells(self, x0, y0, x1, y1):
        """Cells whose centres lie in the box (inside the canvas)."""
        for cy in range(math.floor((y0 - 8) / T), math.ceil((y1 - 8) / T) + 1):
            for cx in range(math.floor((x0 - 8) / T), math.ceil((x1 - 8) / T) + 1):
                if (cx, cy) in self.kind:
                    yield (cx, cy), cx * T + 8, cy * T + 8

    def fill(self, kind, x0, y0, x1, y1):
        assert all(v % T == 0 for v in (x0, y0, x1, y1)), (kind, x0, y0, x1, y1)
        for cy in range(y0 // T, y1 // T):
            for cx in range(x0 // T, x1 // T):
                self.kind[(cx, cy)] = kind

    def walkable(self, cell):
        return cell in self.kind and self.kind[cell] not in BLOCKING

    def ground_of(self, x, y):
        return self.verge.get(self.zone_at(x, y), 'rock')

    def lines(self, polys, path_kind='path'):
        """Verges first (each zone's own ground), then the trodden paths over them."""
        paths = []
        for seed, poly in enumerate(polys):
            m = max(max(p[3], p[4]) + p[5] for p in poly) + 24
            xs, ys = [p[0] for p in poly], [p[1] for p in poly]
            for cell, px, py in self.cells(min(xs) - m, min(ys) - m, max(xs) + m, max(ys) + m):
                d, s, (rw, vl, vr, n), right = nearest(poly, px, py)
                if rw > 0 and d <= rw:
                    paths.append(cell)
                elif d <= (vr if right else vl) + n * wob(s, seed * 1.7 + 0.4):
                    if self.kind[cell] in BLOCKING:
                        self.kind[cell] = self.ground_of(px, py)
        for cell in paths:
            self.kind[cell] = path_kind

    def blob(self, cx, cy, rx, ry, kind=None, seed=0.0, amp=0.16, only=None):
        """A rough ellipse: open ground (the zone's own) or, with `kind`, a prop over `only` kinds."""
        out = []
        for cell, px, py in self.cells(cx - rx * 1.5, cy - ry * 1.5, cx + rx * 1.5, cy + ry * 1.5):
            u, v = (px - cx) / rx, (py - cy) / ry
            a = math.atan2(v, u)
            r = 1 + amp * (0.6 * math.sin(3 * a + seed) + 0.4 * math.sin(5 * a + seed * 1.7))
            if u * u + v * v <= r * r:
                if only is not None and self.kind[cell] not in only:
                    continue
                self.kind[cell] = kind or self.ground_of(px, py)
                out.append(cell)
        return out

    def clip(self):
        """Nothing walkable outside a zone."""
        for (cx, cy), kind in self.kind.items():
            if kind not in BLOCKING and self.zone_at(cx * T + 8, cy * T + 8) is None:
                self.kind[(cx, cy)] = self.rock_at((cx, cy))

    def separate(self, pairs):
        """Close every walkable seam between rooms that are not neighbours."""
        changed = True
        while changed:
            changed = False
            for (cx, cy) in list(self.kind):
                if not self.walkable((cx, cy)):
                    continue
                here = self.zone_at(cx * T + 8, cy * T + 8)
                for dx, dy in ((1, 0), (0, 1)):
                    other = (cx + dx, cy + dy)
                    if not self.walkable(other):
                        continue
                    there = self.zone_at(other[0] * T + 8, other[1] * T + 8)
                    if here != there and tuple(sorted((here, there))) not in pairs:
                        self.kind[(cx, cy)] = self.rock_at((cx, cy))
                        self.kind[other] = self.rock_at(other)
                        changed = True

    def roomy(self, cell):
        """A body (34 px) can stand centred on this cell: the 3x3 block around it is open."""
        return all(self.walkable((cell[0] + dx, cell[1] + dy)) for dx in (-1, 0, 1) for dy in (-1, 0, 1))

    def reach(self, start, pairs):
        """Cells a body can reach from `start` (point), never crossing between non-neighbours."""
        first = (start[0] // T, start[1] // T)
        assert self.roomy(first), ('no room at the entry', start)
        seen = {first}
        queue = deque([first])
        while queue:
            cx, cy = queue.popleft()
            here = self.zone_at(cx * T + 8, cy * T + 8)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nxt = (cx + dx, cy + dy)
                if nxt in seen or not self.roomy(nxt):
                    continue
                there = self.zone_at(nxt[0] * T + 8, nxt[1] * T + 8)
                assert there is not None, ('walkable outside the zones', nxt)
                assert here == there or tuple(sorted((here, there))) in pairs, ('seam', here, there)
                seen.add(nxt)
                queue.append(nxt)
        return seen

    def drop_pockets(self, start):
        """Walkable cells no one can get to (cut off by the clip) turn back into rock."""
        first = (start[0] // T, start[1] // T)
        seen = {first}
        queue = deque([first])
        while queue:
            cx, cy = queue.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nxt = (cx + dx, cy + dy)
                if nxt not in seen and self.walkable(nxt):
                    seen.add(nxt)
                    queue.append(nxt)
        for cell in list(self.kind):
            if self.walkable(cell) and cell not in seen:
                self.kind[cell] = self.rock_at(cell)

    def tiles(self):
        tiles = Tiles()
        for cell, kind in self.kind.items():
            tiles.put(cell, kind)
        return tiles

    def seam(self, a, b):
        """Every walkable cell pair across the a/b boundary: (cells in a, cells in b)."""
        out = []
        for (cx, cy) in self.kind:
            if not self.walkable((cx, cy)) or self.zone_at(cx * T + 8, cy * T + 8) != a:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                other = (cx + dx, cy + dy)
                if self.walkable(other) and self.zone_at(other[0] * T + 8, other[1] * T + 8) == b:
                    out.append(((cx, cy), other))
        return out


def slots(canvas, zone_id, lanes, taken, count, kinds, clear=44, spread=96):
    """Spots for `count` bodies in a room: on open ground of `kinds`, clear of the lanes (bodies
    block the way) and of each other, as spread out as the room allows."""
    x0, y0, x1, y1 = canvas.zones[zone_id]
    cands = []
    for cell, px, py in canvas.cells(x0 + 24, y0 + 24, x1 - 24, y1 - 24):
        if canvas.kind[cell] not in kinds or not canvas.roomy(cell) or canvas.zone_at(px, py) != zone_id:
            continue
        lane = min((seg_dist(px, py, *lane) for lane in lanes), default=999)
        if lane < clear:
            continue
        cands.append((px, py, lane))
    out = []
    for _ in range(count):
        best = None
        for px, py, lane in cands:
            near = min([math.hypot(px - q[0], py - q[1]) for q in taken + out] + [spread])
            if near < 40:
                continue
            score = min(near, spread) + 0.25 * min(lane, 80)
            if best is None or score > best[0]:
                best = (score, (px, py))
        assert best, ('no room for a body in', zone_id)
        out.append(best[1])
    return out


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    length2 = dx * dx + dy * dy
    t = 0.0 if length2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length2))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def caption_spot(canvas, zone_id, label, near, avoid=()):
    """Where a room's caption goes: beside its open ground (cliff is fine), never on the trodden
    path or over a body's name, as near `near` as it fits."""
    width = 15 * len(label) + 8
    x0, y0, x1, y1 = canvas.zones[zone_id]
    best = None
    for cell, px, py in canvas.cells(x0, y0, x1 - width, y1 - 24):
        block = [(cell[0] + dx, cell[1] + dy) for dx in range(0, width // T + 1) for dy in (0, 1)]
        if any(canvas.kind.get(c) == 'path' or canvas.zone_at(c[0] * T + 8, c[1] * T + 8) != zone_id for c in block):
            continue
        if not any(canvas.walkable(c) for c in block):
            continue
        if any(abs(px + width / 2 - ax) < width / 2 + 40 and abs(py + 8 - ay) < 60 for ax, ay in avoid):
            continue
        d = math.hypot(px - near[0], py - near[1])
        if best is None or d < best[0]:
            best = (d, (cell[0] * T + 4, cell[1] * T + 2))
    assert best, ('no room for the caption of', zone_id)
    return best[1]
