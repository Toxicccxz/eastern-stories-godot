class_name OldPineWorldDefinitions
extends RefCounted

const REGION_ID: StringName = &"oldpine"
const OUTDOOR_MAP_ID: StringName = &"oldpine.outdoor"
const CAVE_MAP_ID: StringName = &"oldpine.cave"
const KEEP_MAP_ID: StringName = &"oldpine.keep"

const NORTH_APPROACH_ZONE_ID: StringName = &"oldpine.outdoor.north_approach"
const CENTRAL_CLEARING_ZONE_ID: StringName = &"oldpine.outdoor.central_clearing"
const SOUTH_SLOPE_ZONE_ID: StringName = &"oldpine.outdoor.south_slope"
const EAST_BRIDGE_ZONE_ID: StringName = &"oldpine.outdoor.east_bridge"
const RIVER_GORGE_ZONE_ID: StringName = &"oldpine.outdoor.river_gorge"
const PINE_MAZE_ZONE_ID: StringName = &"oldpine.outdoor.pine_maze"
const CLIFF_LEDGE_ZONE_ID: StringName = &"oldpine.outdoor.cliff_ledge"
const TREE_CANOPY_ZONE_ID: StringName = &"oldpine.outdoor.tree_canopy"
const WATERFALL_PASSAGE_ZONE_ID: StringName = &"oldpine.cave.waterfall_passage"
const SECRET_PASSAGE_ZONE_ID: StringName = &"oldpine.cave.secret_passage"
const CAVE_MAZE_ZONE_ID: StringName = &"oldpine.cave.maze"
const KEEP_ENTRANCE_ZONE_ID: StringName = &"oldpine.keep.entrance"
const KEEP_COURTYARD_ZONE_ID: StringName = &"oldpine.keep.courtyard"
const KEEP_HALL_ZONE_ID: StringName = &"oldpine.keep.hall"

const CLIMB_PINE_PORTAL_ID: StringName = &"oldpine.outdoor.climb_pine"
const TREE1_LANDING_SPAWN_POINT_ID: StringName = (
	&"oldpine.outdoor.tree_canopy.tree1_landing"
)
const SPATH1_BANDIT_SPAWN_ID: StringName = &"oldpine.outdoor.spath1.bandits"


static func region_definition() -> RegionDefinition:
	return RegionDefinition.new(REGION_ID, "老松岭", ["d/oldpine"])


static func map_definitions() -> Array[MapDefinition]:
	return [
		MapDefinition.new(
			OUTDOOR_MAP_ID,
			REGION_ID,
			"res://scenes/world/oldpine/oldpine_outdoor.tscn",
			[
				NORTH_APPROACH_ZONE_ID,
				CENTRAL_CLEARING_ZONE_ID,
				SOUTH_SLOPE_ZONE_ID,
				EAST_BRIDGE_ZONE_ID,
				RIVER_GORGE_ZONE_ID,
				PINE_MAZE_ZONE_ID,
				CLIFF_LEDGE_ZONE_ID,
				TREE_CANOPY_ZONE_ID,
			],
			[CLIMB_PINE_PORTAL_ID],
			[SPATH1_BANDIT_SPAWN_ID],
		),
		MapDefinition.new(
			CAVE_MAP_ID,
			REGION_ID,
			"res://scenes/world/oldpine/oldpine_cave.tscn",
			[
				WATERFALL_PASSAGE_ZONE_ID,
				SECRET_PASSAGE_ZONE_ID,
				CAVE_MAZE_ZONE_ID,
			],
		),
		MapDefinition.new(
			KEEP_MAP_ID,
			REGION_ID,
			"res://scenes/world/oldpine/oldpine_keep.tscn",
			[
				KEEP_ENTRANCE_ZONE_ID,
				KEEP_COURTYARD_ZONE_ID,
				KEEP_HALL_ZONE_ID,
			],
		),
	]


static func zone_definitions() -> Array[ZoneDefinition]:
	return [
		_zone(NORTH_APPROACH_ZONE_ID, OUTDOOR_MAP_ID, "北部山道", [
			"d/oldpine/npath1.c", "d/oldpine/npath2.c", "d/oldpine/npath3.c",
		]),
		_zone(CENTRAL_CLEARING_ZONE_ID, OUTDOOR_MAP_ID, "林间空地", [
			"d/oldpine/clearing.c",
		]),
		_zone(SOUTH_SLOPE_ZONE_ID, OUTDOOR_MAP_ID, "南坡林道", [
			"d/oldpine/spath1.c", "d/oldpine/spath2.c",
			"d/oldpine/spath3.c", "d/oldpine/spath4.c",
		]),
		_zone(EAST_BRIDGE_ZONE_ID, OUTDOOR_MAP_ID, "东侧桥道", [
			"d/oldpine/epath1.c", "d/oldpine/epath2.c", "d/oldpine/epath3.c",
		]),
		_zone(RIVER_GORGE_ZONE_ID, OUTDOOR_MAP_ID, "河谷水域", [
			"d/oldpine/riverbank1.c", "d/oldpine/riverbank2.c",
			"d/oldpine/lake.c", "d/oldpine/waterfall.c",
		]),
		_zone(PINE_MAZE_ZONE_ID, OUTDOOR_MAP_ID, "松林迷径", [
			"d/oldpine/pine1.c", "d/oldpine/pine2.c", "d/oldpine/pine3.c",
			"d/oldpine/pine4.c", "d/oldpine/pine5.c", "d/oldpine/pine6.c",
			"d/oldpine/pine7.c", "d/oldpine/cliffdown.c",
		]),
		_zone(CLIFF_LEDGE_ZONE_ID, OUTDOOR_MAP_ID, "山壁落脚处", [
			"d/oldpine/cliffside.c", "d/oldpine/cliff1.c", "d/oldpine/cliff2.c",
		]),
		_zone(TREE_CANOPY_ZONE_ID, OUTDOOR_MAP_ID, "大松树冠", [
			"d/oldpine/tree1.c", "d/oldpine/tree2.c", "d/oldpine/tree3.c",
		]),
		_zone(WATERFALL_PASSAGE_ZONE_ID, CAVE_MAP_ID, "瀑布秘道", [
			"d/oldpine/passage.c", "d/oldpine/path3.c", "d/oldpine/stone.c",
		]),
		_zone(SECRET_PASSAGE_ZONE_ID, CAVE_MAP_ID, "隐秘通道", [
			"d/oldpine/secrectpath1.c",
		]),
		_zone(CAVE_MAZE_ZONE_ID, CAVE_MAP_ID, "洞穴迷宫", [
			"d/oldpine/cave1.c", "d/oldpine/cave2.c", "d/oldpine/cave3.c",
			"d/oldpine/cave4.c", "d/oldpine/cave5.c",
		]),
		_zone(KEEP_ENTRANCE_ZONE_ID, KEEP_MAP_ID, "山寨入口", [
			"d/oldpine/keep1.c",
		]),
		_zone(KEEP_COURTYARD_ZONE_ID, KEEP_MAP_ID, "山寨院落", [
			"d/oldpine/keep2.c",
		]),
		_zone(KEEP_HALL_ZONE_ID, KEEP_MAP_ID, "山寨大厅", [
			"d/oldpine/keep3.c",
		]),
	]


static func portal_definitions() -> Array[PortalDefinition]:
	return [
		PortalDefinition.new(
			CLIMB_PINE_PORTAL_ID,
			OUTDOOR_MAP_ID,
			CENTRAL_CLEARING_ZONE_ID,
			OUTDOOR_MAP_ID,
			TREE_CANOPY_ZONE_ID,
			TREE1_LANDING_SPAWN_POINT_ID,
			PortalDefinition.InteractionKind.CLIMB,
			&"",
			"d/oldpine/clearing.c",
			&"climb",
			&"pine",
		),
	]


static func map_by_id(map_id: StringName) -> MapDefinition:
	for definition: MapDefinition in map_definitions():
		if definition.map_id == map_id:
			return definition
	return null


static func zone_by_id(zone_id: StringName) -> ZoneDefinition:
	for definition: ZoneDefinition in zone_definitions():
		if definition.zone_id == zone_id:
			return definition
	return null


static func portal_by_id(portal_id: StringName) -> PortalDefinition:
	for definition: PortalDefinition in portal_definitions():
		if definition.portal_id == portal_id:
			return definition
	return null


static func validate() -> bool:
	var region: RegionDefinition = region_definition()
	if not region.is_valid():
		return false
	var maps: Array[MapDefinition] = map_definitions()
	var zones: Array[ZoneDefinition] = zone_definitions()
	var portals: Array[PortalDefinition] = portal_definitions()
	var native_ids: Dictionary[StringName, bool] = {}
	if not _register_unique_id(native_ids, region.region_id):
		return false
	for map: MapDefinition in maps:
		if not _register_unique_id(native_ids, map.map_id):
			return false
	for zone: ZoneDefinition in zones:
		if not _register_unique_id(native_ids, zone.zone_id):
			return false
	for portal: PortalDefinition in portals:
		if not _register_unique_id(native_ids, portal.portal_id):
			return false

	var zone_membership_count: Dictionary[StringName, int] = {}
	var portal_membership_count: Dictionary[StringName, int] = {}
	for map: MapDefinition in maps:
		if not map.is_valid() or map.region_id != region.region_id:
			return false
		for zone_id: StringName in map.zone_ids():
			var zone: ZoneDefinition = zone_by_id(zone_id)
			if zone == null or not zone.is_valid() or zone.map_id != map.map_id:
				return false
			zone_membership_count[zone_id] = zone_membership_count.get(zone_id, 0) + 1
		for portal_id: StringName in map.portal_ids():
			var portal: PortalDefinition = portal_by_id(portal_id)
			if portal == null or portal.source_map_id != map.map_id:
				return false
			portal_membership_count[portal_id] = (
				portal_membership_count.get(portal_id, 0) + 1
			)
	for zone: ZoneDefinition in zones:
		if (
			not zone.is_valid()
			or map_by_id(zone.map_id) == null
			or zone_membership_count.get(zone.zone_id, 0) != 1
		):
			return false
	for portal: PortalDefinition in portals:
		if not portal.is_valid():
			return false
		var source_zone: ZoneDefinition = zone_by_id(portal.source_zone_id)
		var destination_zone: ZoneDefinition = zone_by_id(portal.destination_zone_id)
		if (
			source_zone == null
			or source_zone.map_id != portal.source_map_id
			or destination_zone == null
			or destination_zone.map_id != portal.destination_map_id
			or map_by_id(portal.source_map_id) == null
			or map_by_id(portal.destination_map_id) == null
			or portal_membership_count.get(portal.portal_id, 0) != 1
		):
			return false
	return true


static func _register_unique_id(
	seen: Dictionary[StringName, bool],
	id: StringName,
) -> bool:
	if id.is_empty() or seen.has(id):
		return false
	seen[id] = true
	return true


static func _zone(
	zone_id: StringName,
	map_id: StringName,
	display_name: String,
	legacy_room_ids: Array[String],
) -> ZoneDefinition:
	return ZoneDefinition.new(
		zone_id,
		map_id,
		zone_id,
		display_name,
		legacy_room_ids,
	)
