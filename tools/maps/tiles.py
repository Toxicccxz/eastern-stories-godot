"""The placeholder terrain TileSet's kinds and the TileMapLayer `tile_map_data` codec."""

from __future__ import annotations

import re
import struct

T = 16  # one tile, in pixels

# Kind -> atlas coordinates in res://scenes/world/common/placeholder_terrain_tileset.tres.
ATLAS = {
    'town_ground': (0, 0), 'street': (1, 0), 'path': (2, 0), 'floor_wood': (3, 0), 'floor_yard': (4, 0),
    'floor_shop': (5, 0), 'shop_front': (6, 0), 'shutter': (7, 0),
    'wall': (0, 1), 'wall_wood': (1, 1), 'boundary': (2, 1), 'grass': (3, 1), 'forest_floor': (4, 1),
    'forest': (5, 1), 'bridge': (6, 1), 'riverbank': (7, 1),
    'water': (0, 2), 'deep_water': (1, 2), 'rock': (2, 2), 'blocked': (3, 2), 'cave_floor': (4, 2),
    'shallow_water': (5, 2), 'cliff': (6, 2), 'chasm': (7, 2),
}
# Kinds that go on the TerrainStructures layer (they collide); the rest are TerrainGround.
BLOCKING = {'shop_front', 'shutter', 'wall', 'wall_wood', 'boundary', 'forest', 'water', 'deep_water',
            'blocked', 'cliff', 'chasm'}
LAYER = re.compile(r'(\[node name="(Terrain\w+)"[^\n]*\n(?:[^\n]*\n)*?tile_map_data = PackedByteArray\()([^)]*)(\))')


class Tiles:
    """The two layers as cell -> (source, atlas x, atlas y, alternative)."""

    def __init__(self) -> None:
        self.ground: dict = {}
        self.structures: dict = {}

    def put(self, cell: tuple, kind: str) -> None:
        ax, ay = ATLAS[kind]
        (self.structures if kind in BLOCKING else self.ground)[cell] = (0, ax, ay, 0)

    def fill(self, kind: str, x0: int, y0: int, x1: int, y1: int) -> None:
        """Paints a box (pixels, on the 16 px grid); `void` clears it."""
        assert all(v % T == 0 for v in (x0, y0, x1, y1)), (kind, x0, y0, x1, y1)
        for ty in range(y0 // T, y1 // T):
            for tx in range(x0 // T, x1 // T):
                self.ground.pop((tx, ty), None)
                self.structures.pop((tx, ty), None)
                if kind != 'void':
                    self.put((tx, ty), kind)

    def walkable_cells(self) -> set:
        return {cell for cell in self.ground if cell not in self.structures}

    @staticmethod
    def encode(cells: dict) -> str:
        out = bytearray(b'\x00\x00')
        for (x, y) in sorted(cells, key=lambda c: (c[1], c[0])):
            src, ax, ay, alt = cells[(x, y)]
            out += struct.pack('<hhHHHH', x, y, src, ax, ay, alt)
        return ', '.join(str(b) for b in out)

    def apply(self, text: str) -> str:
        """Writes both layers into a scene's empty TerrainGround/TerrainStructures nodes."""
        layers = {'TerrainGround': self.ground, 'TerrainStructures': self.structures}
        return LAYER.sub(lambda m: m.group(1) + self.encode(layers[m.group(2)]) + m.group(4), text)
