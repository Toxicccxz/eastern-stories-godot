# Terrain tiles (Packages 3B4, 3B5)

Map terrain is drawn on `TileMapLayer`s that share one placeholder TileSet,
`game/scenes/world/common/placeholder_terrain_tileset.tres` (16 px tiles, atlas
`placeholder_terrain.png`, one flat colour per tile). To swap in art, replace the atlas PNG with the
same layout, or point the layers at a new TileSet that keeps the `terrain` custom data.

Each map scene has `TerrainGround` (floors, roads, grass, water) and, where it needs one,
`TerrainStructures` (walls, forest, shop fronts, blocked routes) drawn on top. Both are the first
children of the map's terrain node, so labels, door shutters, counters, landmark markers and
characters draw over them. Edit them in the Godot TileMap editor.

**Collision.** The TileSet has one physics layer: blocking kinds (below) carry a full-cell shape,
so on Old Pine the tiles are the walls and the walkable area is what is painted walkable. Every
walkable cell must border painted cells (no walking off into the void); `terrain_tilemap_test`
checks it. Zones, portals, spawns, services, doors and landmarks stay separate components, and
switchable blockers (doors, an exit closed in one world) stay `StaticBody2D` nodes. Snow's layers
still have `collision_enabled = false` and keep their `StaticBody2D` walls until 3B6. Snow's tiles
were painted from off-grid shapes, so a painted edge there can sit up to 8 px from its collision.

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
