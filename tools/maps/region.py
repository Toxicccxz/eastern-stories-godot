"""What the painters read from game/data/<region>/ and share between techniques."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

from .tiles import Tiles


class Region:
    def __init__(self, name: str, data: Path) -> None:
        self.name = name
        self.data = data / name

    def _read(self, file: str) -> dict:
        return json.loads((self.data / file).read_text(encoding='utf-8'))

    def shorts(self) -> dict:
        """Zone id -> the short name of its first room (the caption)."""
        rooms = {r['id']: r['short'] for r in self._read('rooms.json')['rooms']}
        return {z['id']: rooms[z['rooms'][0]] for z in self._read('world.json')['zones']}

    def neighbours(self, zones) -> set:
        """Sorted pairs of the given zones that a room exit joins."""
        zone_of = {room: z['id'] for z in self._read('world.json')['zones'] for room in z['rooms']}
        pairs = set()
        for room in self._read('rooms.json')['rooms']:
            for target in room.get('exits', {}).values():
                a, b = zone_of.get(room['id']), zone_of.get(target)
                if a in zones and b in zones and a != b:
                    pairs.add(tuple(sorted((a, b))))
        return pairs

    def spawn_records(self) -> list:
        """NPC spawns, then item spawns, in file order (each has a zone and its points)."""
        return self._read('spawns.json')['spawns'] + self._read('item_spawns.json')['item_spawns']

    def marker_name(self, point: str) -> str:
        """cloud.nroad1.waiter.1 -> Nroad1Waiter1."""
        return ''.join(p.capitalize() for p in point.replace(self.name + '.', '').replace('_', '.').split('.'))


def zone_node_name(zone_id: str, suffix: str) -> str:
    """cloud.dragonhill.nroad -> DragonhillNroad + suffix."""
    return ''.join(p.capitalize() for p in zone_id.split('.')[1:]) + suffix


def numbers(row: list) -> list:
    """A layout row without its notes (strings)."""
    return [v for v in row if not isinstance(v, str)]


def fill_row(row: list) -> tuple:
    """[kind, x0, y0, x1, y1, note...] -> (kind, x0, y0, x1, y1)."""
    return (row[0], *row[1:5])


def explicit_markers(scene: dict) -> dict:
    """Marker name -> position, for the spawn points the layout places itself."""
    return {m['name']: tuple(m['at']) for m in scene.get('spawn_points', []) if 'generated' not in m}


@dataclass
class Drawn:
    """What a technique made: the tiles, node text for the layout's {"generated": ...} slots,
    extra shapes (zone rectangles), the drawing's bounds and, for doors placed `between` two
    zones, where each goes."""
    tiles: Tiles
    fragments: dict = field(default_factory=dict)
    shapes: dict = field(default_factory=dict)
    bounds: tuple | None = None
    door_at: Callable | None = None
    notes: list = field(default_factory=list)
