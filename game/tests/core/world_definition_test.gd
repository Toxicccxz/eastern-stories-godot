extends RefCounted

const OldPineWorld := preload("res://data/oldpine/oldpine_world_definitions.gd")
const SnowWorld := preload("res://data/snow/snow_world_definitions.gd")

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_maps_have_scenes()
	_test_zones_and_rooms()
	_test_zone_text_is_the_primary_room()
	_test_portals()
	_test_snow_adjacency_follows_room_exits()
	_test_loader_rejects_broken_world_data()
	_test_location_identity()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_maps_have_scenes() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_assert_true(GameContent.load_errors().is_empty(), "content loads: %s" % [GameContent.load_errors()])
	var ids: Array[StringName] = []
	for map: MapDefinition in catalog.maps():
		ids.append(map.map_id)
		_assert_true(map.is_valid(), "%s is coherent" % map.map_id)
		_assert_true(catalog.region(map.region_id) != null, "%s region resolves" % map.map_id)
		_assert_true(ResourceLoader.exists(map.scene_path), "%s scene exists: %s" % [map.map_id, map.scene_path])
		_assert_false(catalog.zones_for_map(map.map_id).is_empty(), "%s has zones" % map.map_id)
	_assert_eq(ids, [SnowWorld.INN_MAP_ID, SnowWorld.OUTDOOR_MAP_ID, OldPineWorld.OUTDOOR_MAP_ID, OldPineWorld.CAVE_MAP_ID], "maps with a scene")
	_assert_eq(catalog.region(OldPineWorld.REGION_ID).display_name, "老松岭", "Old Pine region name")
	_assert_eq(catalog.region(SnowWorld.REGION_ID).display_name, "雪亭镇", "Snow region name")


func _test_zones_and_rooms() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_assert_eq(catalog.zones_for_map(SnowWorld.INN_MAP_ID).size(), 1, "Inn main floor")
	_assert_eq(catalog.zones_for_map(SnowWorld.OUTDOOR_MAP_ID).size(), 17, "Snow outdoor zones")
	_assert_eq(catalog.zones_for_map(OldPineWorld.OUTDOOR_MAP_ID).size(), 12, "Old Pine outdoor zones")
	_assert_eq(catalog.zones_for_map(OldPineWorld.CAVE_MAP_ID).size(), 1, "minimal Passage Cave")
	var rooms: Dictionary[StringName, bool] = {}
	for zone: ZoneDefinition in catalog.zones():
		_assert_true(zone.is_valid(), "%s is coherent" % zone.zone_id)
		_assert_eq(zone.combat_location_id, zone.zone_id, "%s fights per zone" % zone.zone_id)
		for room_id: StringName in zone.room_ids():
			_assert_false(rooms.has(room_id), "%s is in one zone" % room_id)
			rooms[room_id] = true
			_assert_true(catalog.room(room_id) != null, "%s resolves" % room_id)
	_assert_eq(rooms.size(), 49, "18 Snow and 31 Old Pine rooms are playable")
	_assert_eq(
		catalog.zone(OldPineWorld.SOUTH_SLOPE_ZONE_ID).room_ids(),
		[&"es2:d/oldpine/spath1", &"es2:d/oldpine/spath2", &"es2:d/oldpine/spath3", &"es2:d/oldpine/spath4"],
		"south slope merges the south path rooms",
	)
	_assert_eq(
		catalog.zone(OldPineWorld.PINE_DEEP_ZONE_ID).room_ids(),
		[&"es2:d/oldpine/pine3", &"es2:d/oldpine/pine4", &"es2:d/oldpine/pine5", &"es2:d/oldpine/pine6"],
		"Pine Deep traces pine3-pine6",
	)
	var exits: Dictionary[String, StringName] = catalog.room(&"es2:d/snow/square").exits()
	_assert_eq(exits.keys(), ["north", "west", "south", "east"], "square exits in authored order")
	_assert_eq(exits["east"], &"es2:d/snow/temple", "square east leads to the temple")
	var zone_variant: Variant = catalog.zone(OldPineWorld.CENTRAL_CLEARING_ZONE_ID)
	_assert_false(zone_variant is Node, "zone is Node-free")


func _test_zone_text_is_the_primary_room() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var square: ZoneDefinition = catalog.zone(&"snow.square")
	_assert_eq(square.display_name, "广场", "square short")
	_assert_eq(square.description, "这里是雪亭镇镇前广场的空地，地上整齐地铺著大石板。广场中央有\n一个木头搭的架子，经过多年的风吹日晒雨淋，看来非常破旧。四周建筑\n林立。往西你可以看到一间客栈，看来生意似乎很好。\n", "square long, line breaks kept")
	var temple: ZoneDefinition = catalog.zone(SnowWorld.TEMPLE_ZONE_ID)
	_assert_eq(temple.display_name, "城隍庙", "temple short")
	_assert_eq(temple.description.replace("\n", ""), "这是一间十分老旧的城隍庙，在你面前的神桌上供奉著一尊红脸的城隍，庙虽老旧，但是神案四周已被香火薰成乌黑的颜色，显示这里必定相当受到信徒的敬仰。", "temple long")
	var edge: ZoneDefinition = catalog.zone(OldPineWorld.PINE_CLIFF_EDGE_ZONE_ID)
	_assert_eq(edge.display_name, catalog.room(&"es2:d/oldpine/cliffdown").short, "a merged zone shows its first room")


func _test_portals() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var climb: PortalDefinition = catalog.portal(OldPineWorld.CLIMB_PINE_PORTAL_ID)
	_assert_true(climb.is_valid(), "climb portal is coherent")
	_assert_eq(climb.source_map_id, OldPineWorld.OUTDOOR_MAP_ID, "source map follows the zone")
	_assert_eq(climb.source_zone_id, OldPineWorld.CENTRAL_CLEARING_ZONE_ID, "portal source zone")
	_assert_eq(climb.destination_zone_id, OldPineWorld.TREE_CANOPY_ZONE_ID, "portal destination zone")
	_assert_eq(climb.destination_spawn_point_id, OldPineWorld.TREE1_LANDING_SPAWN_POINT_ID, "tree1 landing")
	_assert_eq(climb.legacy_room_id, &"es2:d/oldpine/clearing", "portal source trace")
	_assert_eq(climb.legacy_command, "climb pine", "portal legacy command")
	var vine_passage: PortalDefinition = catalog.portal(OldPineWorld.VINE_PASSAGE_PORTAL_ID)
	_assert_eq(vine_passage.source_map_id, OldPineWorld.OUTDOOR_MAP_ID, "Passage Vine belongs to Outdoor")
	_assert_eq(vine_passage.destination_map_id, OldPineWorld.CAVE_MAP_ID, "Passage Vine crosses to Cave")
	var south: PortalDefinition = catalog.portal(SnowOldPineConnectionDefinitions.SOUTH_PORTAL_ID)
	_assert_eq(south.source_map_id, SnowWorld.OUTDOOR_MAP_ID, "Snow south road starts in Snow")
	_assert_eq(south.destination_map_id, OldPineWorld.OUTDOOR_MAP_ID, "and ends in Old Pine")
	_assert_eq(catalog.portals_for_map(SnowWorld.OUTDOOR_MAP_ID).size(), 2, "Snow outdoor: Inn door and Old Pine road")
	_assert_eq(catalog.portals_for_map(OldPineWorld.OUTDOOR_MAP_ID).size(), 9, "Old Pine outdoor portals")


## The zone-change guard Snow used to hard-code, now read from room exits.
func _test_snow_adjacency_follows_room_exits() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var expected: Array[String] = [
		"square|sroad1", "sroad1|eroad1", "eroad1|eroad2", "eroad2|eroad3",
		"square|mstreet1", "square|temple", "eroad1|temple",
		"mstreet1|bank", "mstreet1|school1", "school1|school2", "school2|schoolhall",
		"mstreet1|mstreet2", "mstreet2|workplace", "mstreet2|mstreet3",
		"mstreet3|hockshop", "mstreet3|mstreet4", "mstreet4|crossroad",
	]
	var zones: Array[ZoneDefinition] = catalog.zones_for_map(SnowWorld.OUTDOOR_MAP_ID)
	var found: Array[String] = []
	for i: int in zones.size():
		for j: int in range(i + 1, zones.size()):
			var a: StringName = zones[i].zone_id
			var b: StringName = zones[j].zone_id
			_assert_eq(catalog.zones_adjacent(a, b), catalog.zones_adjacent(b, a), "adjacency is symmetric")
			if catalog.zones_adjacent(a, b):
				found.append("%s|%s" % [String(a).get_slice(".", 1), String(b).get_slice(".", 1)])
	for pair: String in expected:
		var reverse: String = "%s|%s" % [pair.get_slice("|", 1), pair.get_slice("|", 0)]
		_assert_true(found.has(pair) or found.has(reverse), "adjacent: " + pair)
	_assert_eq(found.size(), expected.size(), "no other adjacency: %s" % [found])
	_assert_false(catalog.zones_adjacent(&"snow.square", &"snow.square"), "a zone is not its own neighbour")


func _test_loader_rejects_broken_world_data() -> void:
	var builder: ContentCatalogBuilder = ContentCatalogBuilder.new()
	builder.add_document({
		"rooms": [
			{"id": "es2:d/x/a", "short": "A", "long": "a\n"},
			{"id": "es2:d/x/b", "short": "B", "long": "b\n", "exits": {"east": "es2:d/x/a"}},
		],
		"regions": [{"id": "x", "name": "X"}],
		"maps": [
			{"id": "x.map", "region": "x", "scene": "res://x.tscn"},
			{"id": "x.lost", "region": "nowhere", "scene": "res://y.tscn"},
		],
		"zones": [
			{"id": "x.a", "map": "x.map", "rooms": ["es2:d/x/a"]},
			{"id": "x.b", "map": "x.map", "rooms": ["es2:d/x/b", "es2:d/x/a"]},
			{"id": "x.c", "map": "x.none", "rooms": ["es2:d/x/missing"]},
		],
		"portals": [{
			"id": "x.p", "from_zone": "x.a", "to_zone": "x.gone", "to_spawn": "x.s",
			"legacy_room": "es2:d/x/a", "legacy_command": "east", "extra": 1,
		}],
	}, "test.json")
	_assert_true(builder.build() == null, "broken world data does not build")
	var errors: String = "\n".join(builder.errors())
	for expected: String in [
		"test.json.maps[1].region: unknown region 'nowhere'",
		"test.json.zones[1].rooms: 'es2:d/x/a' is already in x.a",
		"test.json.zones[2].map: unknown map 'x.none'",
		"test.json.zones[2].rooms: unknown room 'es2:d/x/missing'",
		"test.json.portals[0].to_zone: unknown zone 'x.gone'",
		"test.json.portals[0].extra: unknown field",
	]:
		_assert_true(errors.contains(expected), "reports: " + expected)


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
