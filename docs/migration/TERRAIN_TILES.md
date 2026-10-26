# Map painting and terrain tiles

Every map scene under `game/scenes/world/<region>/` is **generated**. The map's one source is its
region's layout, `tools/maps/layouts/<region>.json`: tiles (walkable area and collision), zones,
portals, doors, stairs, spawn points and every box that blocks. The painter writes the scenes:

    python -m tools.maps.paint                  # repaint every region (changed scenes only)
    python -m tools.maps.paint snow cloud       # only these regions
    python -m tools.maps.paint --check          # write nothing; exit 1 listing scenes that differ
    python -m tools.maps.paint --out build/maps # write under build/maps/<region>/ instead

A hand edit to a scene is overwritten by the next paint, and `tools/tests/test_maps_paint.py` fails
while a committed scene differs from what its layout paints. To change a map, edit its layout and
repaint. The data format of each part is in the module docstrings: `tools/maps/paint.py` (the
layout entry and `scene`), `canvas.py`, `town.py`, `fills.py`, `cells.py` (the drawing
techniques), `standard.py` with `standard.json` (the scale standard and `interior` maps) and
`scene.py` (node builders).

## Layouts

A layout's `maps` entry names its scene `file` and has:

* `draw`: the technique that paints the tiles and makes the zones, captions and markers.
  `canvas` paints natural ground step by step (`blobs`, `lines` of road with verges, `chambers`,
  `fill` rows, `clip`, `separate`) on a rock canvas, clipped to the `zones` boxes; `town` lays
  `zones` out as open ground or walled rooms with doorways onto their neighbours, then `roads` and
  `props`, with streets and building facades sized by the standard; `interior` lays a building's
  rooms out from their exits (painted as a town drawing); `fills` paints boxes in order (and fixed
  mazes); `cells` puts rooms on a grid of square cells. A `base` filler (the bare `boundary`) is
  kept only within `skirt_tiles` of walkable ground, a backdrop of its colour behind.
* `scene`: the skeleton `style` (`map` or `flat`), root name, `map` id, `player_color`, camera
  `limits` or `zoom`, collision `shapes`, the node lists `nodes`, `zones`, `spawn_points` and
  `interactions` (each item a node block, or `{"generated": ...}` for what the drawing made),
  `stairs`, `doors` with `door_style`, and `presentation` (the voxel view and its config).

Positions and boxes are pixels on the 16 px grid; boxes are `[x0, y0, x1, y1]`. A `note` field,
and a trailing string in a row, is a comment.

**Look boxes.** A fill row may end with `{"look": {"kind": ..., ...}}`: furniture and anything
else that blocks. Its box is painted with the row's kind (`blocked` in every layout) and the painter writes a `Furnishings/FurnishingNN`
`Node2D` at the box's centre with `metadata/look` and `metadata/footprint`; the voxel view draws
the thing from those nodes only ([CONTENT_DATA_FORMAT](CONTENT_DATA_FORMAT.md#regions-maps),
AGENTS.md「Maps and art」). An interior's `props` rows (sizes in bodies) become such fill rows;
a look anywhere else is an error.

**Checks the painter runs** (a failed one stops the paint): a body reaches every zone from the
`reach_from` marker, stepping only between neighbours (room exits and zone `links` in
`game/data`), and every neighbour pair is joined; nothing walkable touches the canvas edge or lies
outside the zones; every marker, landmark, service and passage has room for a body and is within
reach; doorways and doors fit their walls; facades keep off zones and keep an alley; an interior's
floor reaches its building class and exceeds each map in `larger_than`. It prints a note where a
room's text speaks of its size against its class.

## Tiles and collision

The painter fills two `TileMapLayer`s that share one placeholder TileSet,
`game/scenes/world/common/placeholder_terrain_tileset.tres` (16 px tiles, atlas
`placeholder_terrain.png`, one flat colour per tile, custom data `terrain`): `TerrainGround` and
`TerrainStructures`, drawn under everything else. Kinds in `BLOCKING` (`tools/maps/tiles.py`) go
on `TerrainStructures`, the rest on `TerrainGround`. To swap in art, replace the atlas PNG with the
same layout, or point the layers at a new TileSet that keeps the `terrain` custom data.

The TileSet has one physics layer: blocking kinds carry a full-cell shape, so on every map the
tiles are the walls and the furniture, and the walkable area is what is painted walkable. Zones,
portals, spawns, services, doors and landmarks stay separate components. The only `StaticBody2D`
nodes are door wall holders (`DoorWalls`, and `Walls`/`GateWalls` on two maps): a door's shape and
`Polygon2D` shutter cover exactly the walkable cells of its tile opening. The standard's walls are
two tiles (32 px) thick. `game/tests/runtime/terrain_tilemap_test.gd` checks every map: no other
node collision, doors fill their openings, no walkable cell borders unpainted void, spawn markers
stand on open ground.

## Atlas layout (the `terrain` custom data)

| Row | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| 0 | town_ground | street | path | floor_wood | floor_yard | floor_shop | **shop_front** | **shutter** |
| 1 | **wall** | **wall_wood** | **boundary** | grass | forest_floor | **forest** | bridge | riverbank |
| 2 | **water** | **deep_water** | rock | **blocked** | cave_floor | shallow_water | **cliff** | **chasm** |

Bold kinds block and go on `TerrainStructures`: `shop_front`, `shutter`, `wall`, `wall_wood`,
`boundary`, `forest`, `water`, `deep_water`, `blocked`, `cliff`, `chasm`. `shallow_water` is
walkable (the waterfall pool, the cave curtain).
