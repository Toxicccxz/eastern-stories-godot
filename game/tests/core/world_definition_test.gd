extends RefCounted

const OldPineWorld := preload("res://data/oldpine/oldpine_world_definitions.gd")

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_region_maps_zones_and_legacy_partition()
	_test_portal_definition()
	_test_location_identity()
	_test_immutable_defensive_arrays()
	_test_incoherent_definition_validation()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_region_maps_zones_and_legacy_partition() -> void:
	_assert_true(OldPineWorld.validate(), "Old Pine world references validate")
	var region: RegionDefinition = OldPineWorld.region_definition()
	_assert_eq(region.region_id, &"oldpine", "region ID")
	_assert_eq(region.display_name, "老松岭", "region display name")
	_assert_eq(region.legacy_source_roots(), ["d/oldpine"], "region source root")

	var maps: Array[MapDefinition] = OldPineWorld.map_definitions()
	_assert_eq(maps.size(), 3, "exact three native map boundaries")
	_assert_eq(maps[0].map_id, &"oldpine.outdoor", "outdoor map ID")
	_assert_eq(maps[1].map_id, &"oldpine.cave", "cave map ID")
	_assert_eq(maps[2].map_id, &"oldpine.keep", "keep map ID")
	for map: MapDefinition in maps:
		_assert_eq(map.region_id, region.region_id, "map region resolves")
		_assert_true(map.scene_path.begins_with("res://scenes/world/oldpine/"), "future scene content path only")

	var expected_outdoor: Array[StringName] = [
		OldPineWorld.NORTH_APPROACH_ZONE_ID,
		OldPineWorld.CENTRAL_CLEARING_ZONE_ID,
		OldPineWorld.SOUTH_SLOPE_ZONE_ID,
		OldPineWorld.EAST_BRIDGE_ZONE_ID,
		OldPineWorld.WATERFALL_BASIN_ZONE_ID,
		OldPineWorld.RIVER_GORGE_ZONE_ID,
		OldPineWorld.PINE_ENTRANCE_ZONE_ID,
		OldPineWorld.PINE_DEEP_ZONE_ID,
		OldPineWorld.PINE_CLIFF_EDGE_ZONE_ID,
		OldPineWorld.CLIFF_LEDGE_ZONE_ID,
		OldPineWorld.TREE_CANOPY_ZONE_ID,
	]
	_assert_eq(maps[0].zone_ids(), expected_outdoor, "current outdoor zone model")
	_assert_eq(OldPineWorld.zone_definitions().size(), 17, "three-map zone count")
	var legacy_rooms: Array[String] = []
	for zone: ZoneDefinition in OldPineWorld.zone_definitions():
		_assert_true(zone.is_valid(), "zone is coherent")
		_assert_true(OldPineWorld.map_by_id(zone.map_id) != null, "zone map resolves")
		_assert_eq(zone.combat_location_id, zone.zone_id, "first slice explicit combat location")
		legacy_rooms.append_array(zone.legacy_room_ids())
	_assert_eq(legacy_rooms.size(), 39, "39 implemented LPC rooms are metadata under 17 zones")
	var unique_rooms: Dictionary[String, bool] = {}
	for legacy_room: String in legacy_rooms:
		unique_rooms[legacy_room] = true
	_assert_eq(unique_rooms.size(), 39, "legacy room metadata has no overlap")
	_assert_eq(
		OldPineWorld.zone_by_id(OldPineWorld.SOUTH_SLOPE_ZONE_ID).legacy_room_ids(),
		[
			"d/oldpine/spath1.c", "d/oldpine/spath2.c",
			"d/oldpine/spath3.c", "d/oldpine/spath4.c",
		],
		"south slope merges authored south path rooms",
	)
	_assert_eq(
		OldPineWorld.zone_by_id(OldPineWorld.PINE_ENTRANCE_ZONE_ID).legacy_room_ids(),
		["d/oldpine/pine1.c", "d/oldpine/pine2.c"],
		"Pine Entrance traces pine1-pine2",
	)
	_assert_eq(
		OldPineWorld.zone_by_id(OldPineWorld.PINE_DEEP_ZONE_ID).legacy_room_ids(),
		[
			"d/oldpine/pine3.c", "d/oldpine/pine4.c",
			"d/oldpine/pine5.c", "d/oldpine/pine6.c",
		],
		"Pine Deep traces pine3-pine6",
	)
	_assert_eq(
		OldPineWorld.zone_by_id(OldPineWorld.PINE_CLIFF_EDGE_ZONE_ID).legacy_room_ids(),
		["d/oldpine/pine7.c", "d/oldpine/cliffdown.c"],
		"Pine Cliff Edge traces pine7 and cliffdown",
	)
	var region_variant: Variant = region
	var map_variant: Variant = maps[0]
	var zone_variant: Variant = OldPineWorld.zone_definitions()[0]
	_assert_false(region_variant is Node, "region is Node-free")
	_assert_false(map_variant is Node, "map is Node-free")
	_assert_false(zone_variant is Node, "zone is Node-free")


func _test_portal_definition() -> void:
	var portals: Array[PortalDefinition] = OldPineWorld.portal_definitions()
	_assert_eq(portals.size(), 9, "tree, Vine/Passage, and River/Cliff portals are authored")
	var portal: PortalDefinition = portals[0]
	_assert_true(portal.is_valid(), "climb portal is coherent")
	_assert_eq(portal.portal_id, &"oldpine.outdoor.climb_pine", "portal ID")
	_assert_eq(portal.source_map_id, OldPineWorld.OUTDOOR_MAP_ID, "portal source map")
	_assert_eq(portal.source_zone_id, OldPineWorld.CENTRAL_CLEARING_ZONE_ID, "portal source zone")
	_assert_eq(portal.destination_map_id, OldPineWorld.OUTDOOR_MAP_ID, "portal destination map")
	_assert_eq(portal.destination_zone_id, OldPineWorld.TREE_CANOPY_ZONE_ID, "portal destination zone")
	_assert_eq(portal.destination_spawn_point_id, OldPineWorld.TREE1_LANDING_SPAWN_POINT_ID, "tree1 landing")
	_assert_eq(portal.interaction_kind, PortalDefinition.InteractionKind.CLIMB, "typed climb kind")
	_assert_eq(portal.policy_id, &"", "climb pine requires no fake policy")
	_assert_eq(portal.legacy_source_path, "d/oldpine/clearing.c", "portal source trace")
	_assert_eq(portal.legacy_action_verb, &"climb", "legacy action verb metadata")
	_assert_eq(portal.legacy_action_argument, &"pine", "legacy action argument metadata")
	var portal_variant: Variant = portal
	_assert_false(portal_variant is Node, "portal is Node-free")
	_assert_false(portal_variant is Callable, "portal is not a callback")
	var return_portal: PortalDefinition = OldPineWorld.portal_by_id(
		OldPineWorld.DESCEND_TREE1_PORTAL_ID
	)
	_assert_true(return_portal != null and return_portal.is_valid(), "tree1 return portal is coherent")
	_assert_eq(return_portal.source_zone_id, OldPineWorld.TREE_CANOPY_ZONE_ID, "return starts at tree1 canopy")
	_assert_eq(return_portal.destination_zone_id, OldPineWorld.CENTRAL_CLEARING_ZONE_ID, "return reaches clearing")
	_assert_eq(return_portal.destination_spawn_point_id, OldPineWorld.CLEARING_PINE_LANDING_SPAWN_POINT_ID, "return has exact clearing landing")
	_assert_eq(return_portal.legacy_source_path, "d/oldpine/tree1.c", "return source trace")
	_assert_eq(return_portal.legacy_action_verb, &"down", "return preserves down metadata")
	var vine_waterfall: PortalDefinition = OldPineWorld.portal_by_id(
		OldPineWorld.VINE_WATERFALL_PORTAL_ID
	)
	var vine_passage: PortalDefinition = OldPineWorld.portal_by_id(
		OldPineWorld.VINE_PASSAGE_PORTAL_ID
	)
	var passage_south: PortalDefinition = OldPineWorld.portal_by_id(
		OldPineWorld.PASSAGE_SOUTH_PORTAL_ID
	)
	_assert_eq(vine_waterfall.source_map_id, OldPineWorld.OUTDOOR_MAP_ID, "Waterfall Vine belongs to Outdoor")
	_assert_eq(vine_waterfall.destination_zone_id, OldPineWorld.WATERFALL_BASIN_ZONE_ID, "Waterfall Vine destination exact")
	_assert_eq(vine_passage.source_map_id, OldPineWorld.OUTDOOR_MAP_ID, "Passage Vine belongs to Outdoor")
	_assert_eq(vine_passage.destination_map_id, OldPineWorld.CAVE_MAP_ID, "Passage Vine crosses to Cave")
	_assert_eq(vine_passage.destination_spawn_point_id, OldPineWorld.CAVE_VINE_LANDING_SPAWN_POINT_ID, "Passage Vine landing exact")
	_assert_eq(passage_south.source_map_id, OldPineWorld.CAVE_MAP_ID, "Passage South belongs to Cave")
	_assert_eq(passage_south.destination_zone_id, OldPineWorld.WATERFALL_BASIN_ZONE_ID, "Passage South returns to Waterfall")


func _test_location_identity() -> void:
	var central: WorldLocationState = WorldLocationState.new(
		OldPineWorld.REGION_ID,
		OldPineWorld.OUTDOOR_MAP_ID,
		OldPineWorld.CENTRAL_CLEARING_ZONE_ID,
		OldPineWorld.CENTRAL_CLEARING_ZONE_ID,
	)
	var same_combat_container: WorldLocationState = WorldLocationState.new(
		&"another-region-fact",
		&"another-map-fact",
		&"another-zone-fact",
		OldPineWorld.CENTRAL_CLEARING_ZONE_ID,
	)
	var south: WorldLocationState = WorldLocationState.new(
		OldPineWorld.REGION_ID,
		OldPineWorld.OUTDOOR_MAP_ID,
		OldPineWorld.SOUTH_SLOPE_ZONE_ID,
		OldPineWorld.SOUTH_SLOPE_ZONE_ID,
	)
	_assert_true(central.is_valid(), "world location valid")
	_assert_false(central.same_location(same_combat_container), "full location facts remain distinct")
	_assert_true(central.shares_combat_location(same_combat_container), "combat location alone projects same-location")
	_assert_false(central.shares_combat_location(south), "different combat container")
	_assert_ne(central.region_id, central.map_id, "region and map IDs not conflated")
	_assert_ne(central.map_id, central.zone_id, "map and zone IDs not conflated")
	var snapshot: WorldLocationState = central.duplicate_snapshot()
	_assert_true(central.same_location(snapshot), "location snapshot equality")
	var location_variant: Variant = central
	_assert_false(location_variant is Node, "location is Node-free")


func _test_immutable_defensive_arrays() -> void:
	var roots: Array[String] = ["legacy/root"]
	var region: RegionDefinition = RegionDefinition.new(&"region", "Region", roots)
	roots[0] = "mutated"
	_assert_eq(region.legacy_source_roots(), ["legacy/root"], "region does not retain caller array")
	var returned_roots: Array[String] = region.legacy_source_roots()
	returned_roots[0] = "returned mutation"
	_assert_eq(region.legacy_source_roots(), ["legacy/root"], "region getter defensive copy")

	var zone_ids: Array[StringName] = [&"zone"]
	var portal_ids: Array[StringName] = [&"portal"]
	var spawn_ids: Array[StringName] = [&"spawn"]
	var map: MapDefinition = MapDefinition.new(
		&"map",
		&"region",
		"res://future.tscn",
		zone_ids,
		portal_ids,
		spawn_ids,
	)
	zone_ids[0] = &"mutated"
	portal_ids[0] = &"mutated"
	spawn_ids[0] = &"mutated"
	_assert_eq(map.zone_ids(), [&"zone"], "map does not retain caller array")
	_assert_eq(map.portal_ids(), [&"portal"], "map portal input copied")
	_assert_eq(map.spawn_ids(), [&"spawn"], "map spawn input copied")
	var returned_zone_ids: Array[StringName] = map.zone_ids()
	var returned_portal_ids: Array[StringName] = map.portal_ids()
	var returned_spawn_ids: Array[StringName] = map.spawn_ids()
	returned_zone_ids[0] = &"returned_mutation"
	returned_portal_ids[0] = &"returned_mutation"
	returned_spawn_ids[0] = &"returned_mutation"
	_assert_eq(map.zone_ids(), [&"zone"], "map getter defensive copy")
	_assert_eq(map.portal_ids(), [&"portal"], "map portal getter defensive copy")
	_assert_eq(map.spawn_ids(), [&"spawn"], "map spawn getter defensive copy")

	var legacy_rooms: Array[String] = ["d/example/one.c"]
	var zone: ZoneDefinition = ZoneDefinition.new(&"zone", &"map", &"combat", "Zone", legacy_rooms)
	legacy_rooms[0] = "mutated"
	_assert_eq(zone.legacy_room_ids(), ["d/example/one.c"], "zone does not retain caller array")
	var returned_rooms: Array[String] = zone.legacy_room_ids()
	returned_rooms[0] = "returned mutation"
	_assert_eq(zone.legacy_room_ids(), ["d/example/one.c"], "zone getter defensive copy")


func _test_incoherent_definition_validation() -> void:
	_assert_false(RegionDefinition.new().is_valid(), "empty region invalid")
	_assert_false(MapDefinition.new(&"map", &"region", "", []).is_valid(), "empty scene content path invalid")
	_assert_false(ZoneDefinition.new(&"zone", &"map", &"", "Zone", ["legacy"]).is_valid(), "empty combat location invalid")
	_assert_false(PortalDefinition.new().is_valid(), "empty portal invalid")
	_assert_true(OldPineWorld.map_by_id(&"missing") == null, "unknown map lookup honest")
	_assert_true(OldPineWorld.zone_by_id(&"missing") == null, "unknown zone lookup honest")


func _assert_true(value: bool, label: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append("Expected true: %s" % label)


func _assert_false(value: bool, label: String) -> void:
	_assert_true(not value, label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _assert_ne(actual: Variant, unexpected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual == unexpected:
		_failures.append("%s: values unexpectedly equal: %s" % [label, actual])
