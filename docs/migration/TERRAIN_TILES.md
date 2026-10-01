# Terrain tiles (Package 3B4)

Map terrain is drawn on `TileMapLayer`s that share one placeholder TileSet,
`game/scenes/world/common/placeholder_terrain_tileset.tres` (16 px tiles, atlas
`placeholder_terrain.png`, one flat colour per tile). To swap in art, replace the atlas PNG with the
same layout, or point the layers at a new TileSet that keeps the `terrain` custom data.

Each map scene has `TerrainGround` (floors, roads, grass, water) and, where it needs one,
`TerrainStructures` (walls, forest, shop fronts, blocked routes) drawn on top. Both are the first
children of the map's terrain node, so labels, door shutters, counters, landmark markers and
characters draw over them. Edit them in the Godot TileMap editor.

**Visuals only.** The TileSet has no physics layer. Collision stays in the scene's `StaticBody2D`
shapes, and zones, portals, spawns, services, doors and landmarks stay separate components. The
grey-box geometry was not on a grid. Each old shape was painted onto the cells whose centres it
covered, so a painted edge can sit up to 8 px from the collision edge. Aligning collision to the
grid waits for real art.

## Atlas layout (the `terrain` custom data)

| Row | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| 0 | town_ground | street | path | floor_wood | floor_yard | floor_shop | shop_front | shutter |
| 1 | wall | wall_wood | boundary | grass | forest_floor | forest | bridge | riverbank |
| 2 | water | deep_water | rock | blocked | cave_floor | | | |

`TerrainStructures` holds `wall`, `wall_wood`, `boundary`, `forest`, `blocked`, `shop_front` and
`shutter`; every other kind goes on `TerrainGround`. Door shutters that open and close
(`WorldDoor.shutter`) stay `Polygon2D` nodes.
