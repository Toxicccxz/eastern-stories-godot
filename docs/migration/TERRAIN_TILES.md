# Terrain tiles (Packages 3B4–3B6)

Map terrain is drawn on `TileMapLayer`s that share one placeholder TileSet,
`game/scenes/world/common/placeholder_terrain_tileset.tres` (16 px tiles, atlas
`placeholder_terrain.png`, one flat colour per tile). To swap in art, replace the atlas PNG with the
same layout, or point the layers at a new TileSet that keeps the `terrain` custom data.

Each map scene has `TerrainGround` (floors, roads, grass, water) and, where it needs one,
`TerrainStructures` (walls, forest, shop fronts, blocked routes) drawn on top. Both are the first
children of the map's terrain node, so labels, door shutters, counters, landmark markers and
characters draw over them. Edit them in the Godot TileMap editor.

**Collision.** The TileSet has one physics layer: blocking kinds (below) carry a full-cell shape,
so on every map the tiles are the walls and the walkable area is what is painted walkable. Every
walkable cell must border painted cells (no walking off into the void); `terrain_tilemap_test`
checks it. Zones, portals, spawns, services, doors and landmarks stay separate components.
Switchable blockers (doors, an exit closed in one world) and objects that block (Snow's counters
and teacher) stay `StaticBody2D` nodes; a door's shape and shutter cover exactly the walkable
cells of its tile opening, which the test also checks. Snow's walls are 32 px (two tiles) thick.

## Atlas layout (the `terrain` custom data)

| Row | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| 0 | town_ground | street | path | floor_wood | floor_yard | floor_shop | **shop_front** | **shutter** |
| 1 | **wall** | **wall_wood** | **boundary** | grass | forest_floor | **forest** | bridge | riverbank |
| 2 | **water** | **deep_water** | rock | **blocked** | cave_floor | shallow_water | **cliff** | **chasm** |

Bold kinds block. `shallow_water` is walkable (the waterfall pool, the cave curtain).

`TerrainStructures` holds `wall`, `wall_wood`, `boundary`, `forest`, `blocked`, `cliff`, `chasm`,
`shop_front` and `shutter`; every other kind goes on `TerrainGround`. Door shutters that open and close
(`WorldDoor.shutter`) stay `Polygon2D` nodes.
