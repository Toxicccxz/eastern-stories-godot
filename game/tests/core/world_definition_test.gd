extends RefCounted

const WorldCounts := preload("res://tests/support/world_counts.gd")
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
	_test_services_and_doors()
	_test_loader_rejects_broken_services_and_doors()
	_test_landmarks_water_and_pacing()
	_test_loader_rejects_broken_landmarks_and_pacing()
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
	_assert_eq(ids, WorldCounts.ids("maps"), "maps with a scene (world_counts.json)")
	_assert_eq(catalog.region(OldPineWorld.REGION_ID).display_name, "老松岭", "Old Pine region name")
	_assert_eq(catalog.region(SnowWorld.REGION_ID).display_name, "雪亭镇", "Snow region name")


func _test_zones_and_rooms() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_assert_eq(catalog.zones_for_map(SnowWorld.INN_MAP_ID).size(), 1, "Inn main floor")
	_assert_eq(catalog.zones_for_map(SnowWorld.OUTDOOR_MAP_ID).size(), 31, "Snow outdoor zones")
	_assert_eq([catalog.zones_for_map(&"snow.inn_upstairs").size(), catalog.zones_for_map(&"snow.cellar").size()], [4, 1], "Inn upstairs: corridor and three rooms; the secret storage")
	_assert_eq(catalog.zones_for_map(OldPineWorld.OUTDOOR_MAP_ID).size(), 11, "Old Pine forest zones and the keep's three")
	_assert_eq(catalog.zones_for_map(OldPineWorld.GORGE_MAP_ID).size(), 3, "Old Pine gorge: waterfall, river, lake")
	_assert_eq([catalog.zones_for_map(OldPineWorld.TREE_MAP_ID).size(), catalog.zones_for_map(OldPineWorld.CLIFF_MAP_ID).size()], [1, 1], "tree top and cliff niche")
	_assert_eq(catalog.zones_for_map(OldPineWorld.CAVE_MAP_ID).size(), 3, "Passage Cave: passage, secrectpath1, path3")
	var rooms: Dictionary[StringName, bool] = {}
	for zone: ZoneDefinition in catalog.zones():
		_assert_true(zone.is_valid(), "%s is coherent" % zone.zone_id)
		_assert_eq(zone.combat_location_id, zone.zone_id, "%s fights per zone" % zone.zone_id)
		for room_id: StringName in zone.room_ids():
			_assert_false(rooms.has(room_id), "%s is in one zone" % room_id)
			rooms[room_id] = true
			_assert_true(catalog.room(room_id) != null, "%s resolves" % room_id)
	_assert_eq(rooms.size(), WorldCounts.number("rooms"), "the playable rooms (world_counts.json)")
	_assert_eq(
		catalog.zone(OldPineWorld.SLOPE_ZONE_ID).room_ids(),
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
	_assert_eq(catalog.portals_for_map(SnowWorld.OUTDOOR_MAP_ID).size(), WorldCounts.ids("snow_outdoor_portals").size(), "Snow outdoor: Inn door, Old Pine road, 野羊山 north, 卧龙岗 south, 水烟阁 west, 茅山's steps and the weapon storage's hidden way down")
	_assert_eq(catalog.portals_for_map(OldPineWorld.OUTDOOR_MAP_ID).size(), 5, "Old Pine forest: Snow road, pine, two vine branches, cliffdown")
	# One map per height level (DECISIONS 3B5): every Old Pine move that is not a walk changes map.
	for map: MapDefinition in catalog.maps():
		if map.region_id == OldPineWorld.REGION_ID:
			for portal: PortalDefinition in catalog.portals_for_map(map.map_id):
				_assert_true(portal.destination_map_id != portal.source_map_id, "%s changes map" % portal.portal_id)


## The zone-change guard Snow used to hard-code, now read from room exits.
func _test_snow_adjacency_follows_room_exits() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var expected: Array[String] = [
		"square|sroad1", "sroad1|eroad1", "eroad1|eroad2", "eroad2|eroad3",
		"square|mstreet1", "square|temple", "eroad1|temple",
		"mstreet1|bank", "mstreet1|school1", "school1|school2", "school2|schoolhall",
		"mstreet1|mstreet2", "mstreet2|workplace", "mstreet2|mstreet3",
		"mstreet3|hockshop", "mstreet3|mstreet4", "mstreet4|crossroad",
		"sroad1|sroad2", "sroad2|sroad3", "sroad3|sroad4", "sroad4|sroad5", "sroad2|school",
		"mstreet2|smithy", "mstreet3|herbshop", "mstreet4|postoffice", "hockshop|hockshop2",
		"school2|weapon_storage", "schoolhall|inneryard", "inneryard|innerhall", "inneryard|guestroom", "inneryard|nyard",
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
			{"id": "x.map", "region": "x", "scene": "res://x.tscn", "entry": "x.start"},
			{"id": "x.lost", "region": "nowhere", "scene": "res://y.tscn", "entry": "x.start"},
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


func _test_services_and_doors() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var ids: Array[StringName] = []
	for service: ServiceDefinition in catalog.services_for_map(SnowWorld.OUTDOOR_MAP_ID):
		ids.append(service.service_id)
		_assert_eq(catalog.zone(service.zone_id).map_id, service.map_id, "%s map follows its zone" % service.service_id)
	_assert_eq(ids, [&"snow.workplace.mill", &"snow.bank.counter", &"snow.hockshop.counter"], "Snow outdoor services: the rooms' own commands")
	# The shopkeepers sell from their bodies (4E): the vendor record is on the NPC.
	for row: Array in [[&"snow.npc.herbalist", &"snow.vendor.herbalist"], [&"snow.npc.smith", &"snow.vendor.smith"], [&"snow.npc.waiter", &"snow.vendor.waiter"]]:
		_assert_eq(catalog.npc(row[0]).dealings().vendor_id, row[1], "%s sells %s" % row)
	_assert_true(catalog.services_for_map(SnowWorld.INN_MAP_ID).is_empty(), "the Inn has no room service")
	var gate: DoorDefinition = catalog.door(&"snow.school.gate")
	_assert_eq([gate.display_name, gate.zone_ids(), gate.closable], ["红漆大门", [&"snow.school1", &"snow.school2"], true], "school1.c create_door")
	var hockshop: DoorDefinition = catalog.door(&"snow.hockshop.door")
	_assert_eq([hockshop.map_id, hockshop.closable], [SnowWorld.OUTDOOR_MAP_ID, false], "pawn shop door is open-only")
	for map: MapDefinition in catalog.maps():
		_assert_false(map.entry_spawn_id.is_empty(), "%s has an entry spawn" % map.map_id)


func _test_landmarks_water_and_pacing() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_assert_eq(catalog.pacing().combat_round_seconds, 1.0, "one combat round per second, the pre-B2 implicit cadence")
	var counts: Array[int] = []
	for map_id: StringName in [OldPineWorld.OUTDOOR_MAP_ID, OldPineWorld.TREE_MAP_ID, OldPineWorld.GORGE_MAP_ID, OldPineWorld.CLIFF_MAP_ID]:
		counts.append(catalog.landmarks_for_map(map_id).size())
		for landmark: WorldLandmarkDefinition in catalog.landmarks_for_map(map_id):
			_assert_true(landmark.is_valid(), "%s is valid" % landmark.landmark_id)
			for portal_id: StringName in landmark.portal_ids():
				_assert_eq(catalog.portal(portal_id).source_zone_id, landmark.zone_id, "%s leaves from its zone" % portal_id)
	_assert_eq(counts, [7, 1, 4, 2], "pine, vine, cliffdown and the look-only sign, footprints, waterfall and cliffside; tree descent; riverbank cliff and the look-only waterfall, its cliff and riverbank2's cliff; cliff1 up and down")
	var vine: WorldLandmarkDefinition = catalog.landmark(&"oldpine.outdoor.landmark.epath2_vine")
	_assert_eq([vine.policy, vine.portal_ids()], [&"vine", [&"oldpine.outdoor.vine_to_waterfall", &"oldpine.outdoor.vine_to_passage"]], "the vine rolls between waterfall and passage")
	_assert_eq(vine.message("hold"), "你爬上石桥的护栏，伸手往不远处的一根藤蔓抓去....", "epath2.c message_vision text")
	_assert_true(catalog.landmark(&"oldpine.cliff.landmark.cliff1_up").requires_contact, "cliff landmarks need contact")
	_assert_false(catalog.landmark(&"oldpine.outdoor.landmark.ancient_pine").requires_contact, "the pine is usable anywhere in the clearing")
	var water: Array[StringName] = []
	for service: ServiceDefinition in catalog.services_for_map(OldPineWorld.GORGE_MAP_ID):
		water.append(service.service_id)
		_assert_eq(service.kind, &"water", "%s is a water source (resource/water)" % service.service_id)
	_assert_eq(water.size(), 2, "waterfall and lake are water sources")
	_assert_eq(catalog.zone(OldPineWorld.LAKE_ZONE_ID).combat_entry, &"complete_set", "Lake serpents enter as one set")
	_assert_eq(catalog.zone(OldPineWorld.SLOPE_ZONE_ID).combat_entry, &"pair", "elsewhere fights start one pair at a time")
	_assert_eq(catalog.spawn(&"oldpine.gorge.lake.serpents").presence_radius, 210, "serpent presence radius")
	_assert_eq(catalog.spawn(&"oldpine.outdoor.spath1.bandits").presence_radius, 120, "default presence radius")


func _test_loader_rejects_broken_landmarks_and_pacing() -> void:
	var builder: ContentCatalogBuilder = ContentCatalogBuilder.new()
	builder.add_document({
		"rooms": [{"id": "es2:d/x/a", "short": "A", "long": "a\n"}, {"id": "es2:d/x/b", "short": "B", "long": "b\n"}],
		"regions": [{"id": "x", "name": "X"}],
		"maps": [{"id": "x.one", "region": "x", "scene": "res://x.tscn", "entry": "x.s"}],
		"zones": [
			{"id": "x.a", "map": "x.one", "rooms": ["es2:d/x/a"], "combat_entry": "brawl"},
			{"id": "x.b", "map": "x.one", "rooms": ["es2:d/x/b"]},
		],
		"portals": [{"id": "x.up", "from_zone": "x.b", "to_zone": "x.a", "to_spawn": "x.s", "legacy_room": "es2:d/x/b", "legacy_command": "up"}],
		"landmarks": [
			{"id": "x.tree", "zone": "x.a", "name": "T", "long": "t", "action": "Climb", "portals": ["x.up"], "legacy_source": "x.c"},
			{"id": "x.rope", "zone": "x.a", "name": "R", "long": "r", "action": "Hold", "policy": "vine", "portals": ["x.up"], "messages": {"hold": "h"}, "legacy_source": "x.c"},
			{"id": "x.odd", "zone": "x.gone", "name": "O", "long": "o", "action": "Poke", "policy": "poke", "portals": [], "legacy_source": "x.c"},
		],
		"pacing": {"combat_round_ms": 0},
	}, "l.json")
	builder.add_document({"pacing": {"combat_round_ms": 1000}}, "p.json")
	_assert_true(builder.build() == null, "broken landmarks and pacing do not build")
	var errors: String = "\n".join(builder.errors())
	for expected: String in [
		"l.json.zones[0].combat_entry: unsupported combat entry 'brawl'",
		"l.json.landmarks[0].portals: 'x.up' does not leave from x.a",
		"l.json.landmarks[1].portals: policy 'vine' needs 2 portal(s)",
		"l.json.landmarks[1].messages: policy 'vine' needs exactly",
		"l.json.landmarks[2].policy: unsupported landmark policy 'poke'",
		"l.json.landmarks[2].zone: unknown zone 'x.gone'",
		"l.json.pacing.combat_round_ms: must be positive",
		"p.json.pacing: pacing is already defined",
	]:
		_assert_true(errors.contains(expected), "reports: " + expected)
	var empty: ContentCatalogBuilder = ContentCatalogBuilder.new()
	empty.add_document({}, "e.json")
	_assert_true(empty.build() == null and "\n".join(empty.errors()).contains("pacing: no document defines it"), "pacing is required")


func _test_loader_rejects_broken_services_and_doors() -> void:
	var builder: ContentCatalogBuilder = ContentCatalogBuilder.new()
	builder.add_document({
		"rooms": [{"id": "es2:d/x/a", "short": "A", "long": "a\n"}],
		"regions": [{"id": "x", "name": "X"}],
		"maps": [
			{"id": "x.one", "region": "x", "scene": "res://x.tscn", "entry": "x.s"},
			{"id": "x.two", "region": "x", "scene": "res://y.tscn", "entry": "x.s"},
		],
		"zones": [
			{"id": "x.a", "map": "x.one", "rooms": ["es2:d/x/a"]},
		],
		"services": [
			{"id": "x.shop", "kind": "vendor", "zone": "x.a", "name": "S", "reach": 90, "legacy_source": "x.c"},
			{"id": "x.odd", "kind": "juggler", "zone": "x.gone", "name": "J", "reach": 0, "legacy_source": "x.c"},
		],
		"doors": [
			{"id": "x.door", "name": "D", "zones": ["x.a"], "reach": 80, "closable": "no", "legacy_room": "es2:d/x/a"},
		],
		"npcs": [
			{"id": "x.seller", "legacy_source": "x.c", "name": "S", "aliases": ["s"], "vendor": "x.none"},
		],
	}, "t.json")
	_assert_true(builder.build() == null, "broken services and doors do not build")
	var errors: String = "\n".join(builder.errors())
	for expected: String in [
		"t.json.services[0].kind: unsupported service kind 'vendor'",
		"t.json.npcs[0].vendor: unknown vendor 'x.none'",
		"t.json.services[1].kind: unsupported service kind 'juggler'",
		"t.json.services[1].reach: must be positive",
		"t.json.services[1].zone: unknown zone 'x.gone'",
		"t.json.doors[0].closable: expected true or false",
		"t.json.doors[0].zones: a door joins exactly two zones",
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
		OldPineWorld.SLOPE_ZONE_ID,
		OldPineWorld.SLOPE_ZONE_ID,
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
