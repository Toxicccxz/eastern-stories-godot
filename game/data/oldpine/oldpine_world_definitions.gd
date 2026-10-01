class_name OldPineWorldDefinitions
extends RefCounted

## IDs the Old Pine runtime refers to by name. The maps, zones, rooms and
## portals themselves are data (oldpine/world.json, oldpine/rooms.json).

const REGION_ID: StringName = &"oldpine"
const OUTDOOR_MAP_ID: StringName = &"oldpine.outdoor"
const CAVE_MAP_ID: StringName = &"oldpine.cave"

const NORTH_APPROACH_ZONE_ID: StringName = &"oldpine.outdoor.north_approach"
const CENTRAL_CLEARING_ZONE_ID: StringName = &"oldpine.outdoor.central_clearing"
const SOUTH_SLOPE_ZONE_ID: StringName = &"oldpine.outdoor.south_slope"
const EAST_BRIDGE_ZONE_ID: StringName = &"oldpine.outdoor.east_bridge"
const WATERFALL_BASIN_ZONE_ID: StringName = (
	&"oldpine.outdoor.waterfall_basin"
)
const LAKE_ZONE_ID: StringName = &"oldpine.outdoor.lake"
const RIVER_GORGE_ZONE_ID: StringName = &"oldpine.outdoor.river_gorge"
const PINE_ENTRANCE_ZONE_ID: StringName = &"oldpine.outdoor.pine_entrance"
const PINE_DEEP_ZONE_ID: StringName = &"oldpine.outdoor.pine_deep"
const PINE_CLIFF_EDGE_ZONE_ID: StringName = &"oldpine.outdoor.pine_cliff_edge"
const CLIFF_LEDGE_ZONE_ID: StringName = &"oldpine.outdoor.cliff_ledge"
const TREE_CANOPY_ZONE_ID: StringName = &"oldpine.outdoor.tree_canopy"
const WATERFALL_PASSAGE_ZONE_ID: StringName = &"oldpine.cave.waterfall_passage"

const CLIMB_PINE_PORTAL_ID: StringName = &"oldpine.outdoor.climb_pine"
const DESCEND_TREE1_PORTAL_ID: StringName = &"oldpine.outdoor.descend_tree1"
const VINE_WATERFALL_PORTAL_ID: StringName = (
	&"oldpine.outdoor.vine_to_waterfall"
)
const VINE_PASSAGE_PORTAL_ID: StringName = &"oldpine.outdoor.vine_to_passage"
const PASSAGE_SOUTH_PORTAL_ID: StringName = &"oldpine.cave.passage_to_waterfall"
const RIVERBANK1_CLIFF_PORTAL_ID: StringName = (
	&"oldpine.outdoor.riverbank1_climb_cliff"
)
const CLIFF1_DOWN_PORTAL_ID: StringName = &"oldpine.outdoor.cliff1_climb_down"
const CLIFF1_UP_PORTAL_ID: StringName = &"oldpine.outdoor.cliff1_climb_up"
const CLIFFSIDE_PINE1_PORTAL_ID: StringName = (
	&"oldpine.outdoor.cliffside_north_pine1"
)
const TREE1_LANDING_SPAWN_POINT_ID: StringName = (
	&"oldpine.outdoor.tree_canopy.tree1_landing"
)
const CLEARING_PINE_LANDING_SPAWN_POINT_ID: StringName = (
	&"oldpine.outdoor.central_clearing.pine_landing"
)
const WATERFALL_LANDING_SPAWN_POINT_ID: StringName = (
	&"oldpine.outdoor.waterfall_basin.landing"
)
const CAVE_VINE_LANDING_SPAWN_POINT_ID: StringName = (
	&"oldpine.cave.waterfall_passage.vine_landing"
)
const RIVERBANK1_CLIFF_LANDING_SPAWN_POINT_ID: StringName = (
	&"oldpine.outdoor.river_gorge.riverbank1_cliff_landing"
)
const CLIFF1_LANDING_SPAWN_POINT_ID: StringName = (
	&"oldpine.outdoor.cliff_ledge.cliff1_landing"
)
const CLIFFSIDE_LANDING_SPAWN_POINT_ID: StringName = (
	&"oldpine.outdoor.cliff_ledge.cliffside_landing"
)
const PINE1_CLIFFSIDE_LANDING_SPAWN_POINT_ID: StringName = (
	&"oldpine.outdoor.pine_entrance.cliffside_landing"
)
