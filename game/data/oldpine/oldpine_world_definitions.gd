class_name OldPineWorldDefinitions
extends RefCounted

## IDs the Old Pine runtime refers to by name. The maps, zones, rooms and
## portals themselves are data (oldpine/world.json, oldpine/rooms.json).

const REGION_ID: StringName = &"oldpine"
const OUTDOOR_MAP_ID: StringName = &"oldpine.outdoor"
const CAVE_MAP_ID: StringName = &"oldpine.cave"
const GORGE_MAP_ID: StringName = &"oldpine.gorge"
const TREE_MAP_ID: StringName = &"oldpine.tree"
const CLIFF_MAP_ID: StringName = &"oldpine.cliff"

const NORTH_APPROACH_ZONE_ID: StringName = &"oldpine.outdoor.north_approach"
const CENTRAL_CLEARING_ZONE_ID: StringName = &"oldpine.outdoor.central_clearing"
const SLOPE_ZONE_ID: StringName = &"oldpine.outdoor.slope"
const EAST_BRIDGE_ZONE_ID: StringName = &"oldpine.outdoor.east_bridge"
const PINE_ENTRANCE_ZONE_ID: StringName = &"oldpine.outdoor.pine_entrance"
const PINE_DEEP_ZONE_ID: StringName = &"oldpine.outdoor.pine_deep"
const PINE_CLIFF_EDGE_ZONE_ID: StringName = &"oldpine.outdoor.pine_cliff_edge"
const CLIFFSIDE_ZONE_ID: StringName = &"oldpine.outdoor.cliffside"
const WATERFALL_BASIN_ZONE_ID: StringName = &"oldpine.gorge.waterfall"
const RIVER_GORGE_ZONE_ID: StringName = &"oldpine.gorge.river"
const LAKE_ZONE_ID: StringName = &"oldpine.gorge.lake"
const TREE_CANOPY_ZONE_ID: StringName = &"oldpine.tree.canopy"
const CLIFF_HOLE_ZONE_ID: StringName = &"oldpine.cliff.hole"
const WATERFALL_PASSAGE_ZONE_ID: StringName = &"oldpine.cave.waterfall_passage"

const CLIMB_PINE_PORTAL_ID: StringName = &"oldpine.outdoor.climb_pine"
const DESCEND_TREE1_PORTAL_ID: StringName = &"oldpine.tree.descend_tree1"
const VINE_WATERFALL_PORTAL_ID: StringName = &"oldpine.outdoor.vine_to_waterfall"
const VINE_PASSAGE_PORTAL_ID: StringName = &"oldpine.outdoor.vine_to_passage"
const PASSAGE_SOUTH_PORTAL_ID: StringName = &"oldpine.cave.passage_to_waterfall"
const RIVERBANK1_CLIFF_PORTAL_ID: StringName = &"oldpine.gorge.riverbank1_climb_cliff"
const CLIFF1_DOWN_PORTAL_ID: StringName = &"oldpine.cliff.climb_down"
const CLIFF1_UP_PORTAL_ID: StringName = &"oldpine.cliff.climb_up"
const TREE1_LANDING_SPAWN_POINT_ID: StringName = &"oldpine.tree.canopy.tree1_landing"
const CLEARING_PINE_LANDING_SPAWN_POINT_ID: StringName = (
	&"oldpine.outdoor.central_clearing.pine_landing"
)
const WATERFALL_LANDING_SPAWN_POINT_ID: StringName = &"oldpine.gorge.waterfall.landing"
const CAVE_VINE_LANDING_SPAWN_POINT_ID: StringName = (
	&"oldpine.cave.waterfall_passage.vine_landing"
)
const RIVERBANK1_CLIFF_LANDING_SPAWN_POINT_ID: StringName = (
	&"oldpine.gorge.river.riverbank1_cliff_landing"
)
const CLIFF1_LANDING_SPAWN_POINT_ID: StringName = &"oldpine.cliff.hole.cliff1_landing"
const CLIFFSIDE_LANDING_SPAWN_POINT_ID: StringName = &"oldpine.outdoor.cliffside.landing"
