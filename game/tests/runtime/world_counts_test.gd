extends RefCounted

## tests/fixtures/world_counts.json against the live world (tests/support/world_counts.gd):
## the catalog's maps, rooms, Snow's outdoor portals and spawn order; a source New Game's
## NPCs, items, resident maps and Snow outdoor passages; and how many NPC creation draws
## the source world makes after the technical (Old Pine only) world's. With
## UPDATE_WORLD_COUNTS=1 it writes the fixture first.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const WorldCounts := preload("res://tests/support/world_counts.gd")
const FIXTURE: String = "res://tests/fixtures/world_counts.json"
const MAX_DRAWS: int = 20000

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var actual: Dictionary = await _measure(tree)
	if OS.get_environment("UPDATE_WORLD_COUNTS") == "1":
		var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
		file.store_string(JSON.stringify(actual, "\t", false) + "\n")
		file.close()
		WorldCounts._values = {}
	var recorded: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_check(recorded is Dictionary, "the fixture reads")
	if recorded is Dictionary:
		var round_trip: Dictionary = JSON.parse_string(JSON.stringify(actual))
		for key: String in round_trip:
			_check(recorded.get(key) == round_trip[key], "%s: fixture %s, world %s" % [key, recorded.get(key), round_trip[key]])
		_check(recorded.keys().size() == round_trip.keys().size(), "the fixture holds exactly %s" % [round_trip.keys()])
	return {"assertions": _count, "failures": _failures}


func _measure(tree: SceneTree) -> Dictionary:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps: Array[String] = []
	for map: MapDefinition in catalog.maps():
		maps.append(String(map.map_id))
	var rooms: int = 0
	for zone: ZoneDefinition in catalog.zones():
		rooms += zone.room_ids().size()
	var portals: Array[String] = []
	for portal: PortalDefinition in catalog.portals_for_map(&"snow.outdoor"):
		portals.append(String(portal.portal_id))
	var spawns: Array[String] = []
	for spawn: NpcSpawnDefinition in catalog.spawns():
		spawns.append(String(spawn.spawn_id))
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	var npc_state: int = session.npc_random_source().capture_random_state().state
	var counts := {
		"maps": maps,
		"rooms": rooms,
		"snow_outdoor_portals": portals,
		"spawn_order": spawns,
		"world_npcs": session.world_npcs().size(),
		"resident_maps": session.resident_map_count(),
		"new_game_items": session.inventory_state().registered_item_ids().size(),
		"snow_outdoor_passages": session.resident_map(&"snow.outdoor")._passages.size(),
	}
	session.free()
	await tree.process_frame
	var technical: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	technical.deterministic_npc_seed = true
	technical.deterministic_combat_seed = true
	technical.deterministic_world_interaction_seed = true
	tree.root.add_child(technical)
	var draws: NpcInitializationRandomSource = technical.npc_random_source()
	var count: int = 0
	while draws.capture_random_state().state != npc_state and count < MAX_DRAWS:
		draws.next_below(10)
		count += 1
	_check(count < MAX_DRAWS, "the source world's NPC draws continue the technical world's")
	counts["npc_draws_after_oldpine"] = count
	technical.free()
	await tree.process_frame
	return counts


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
