extends RefCounted

## Spawning Old Pine from spawns.json must create exactly the NPCs the
## pre-placed bodies did: same identities, random draws, loadout item IDs and
## positions, map by map in spawn order. Recorded before the map controller
## changed (B2) and re-recorded when Old Pine was split into one map per height
## (3B5: only IDs, positions and maps moved) and when Snow got its NPCs (4A, 4B, 4E, 柳绘心:
## they draw after Old Pine, so only next_npc_draw moved; 4E added the empty marks, combat specials
## the empty timed applies) and when Old Pine got its remainder (the keep's and the east path's
## NPCs draw on the forest map before the gorge, so the five serpents' drawn attributes moved; the
## forest's first five are unchanged); set UPDATE_OLDPINE_SPAWN_BASELINE=1 to rewrite it
## deliberately.
const SessionScene := preload("res://scenes/world/oldpine/oldpine_world_session.tscn")
const BASELINE_PATH: String = "res://tests/fixtures/oldpine_spawn_baseline.json"
const MAX_DEPTH: int = 6

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var actual: Dictionary = {
		"technical_new_game": await _capture(tree, false),
		"source_entry": await _capture(tree, true),
	}
	if OS.get_environment("UPDATE_OLDPINE_SPAWN_BASELINE") == "1":
		var file: FileAccess = FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify(actual, "\t", false) + "\n")
		file.close()
		print("wrote %s" % BASELINE_PATH)
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	_assert_true(expected is Dictionary, "the recorded spawn baseline is readable")
	if expected is Dictionary:
		# Round-trip so numbers compare the same way on both sides.
		var normalized: Dictionary = JSON.parse_string(JSON.stringify(actual))
		for mode: String in normalized:
			_assert_eq(JSON.stringify(normalized[mode], "", false), JSON.stringify(expected.get(mode), "", false), "%s spawns match the recorded baseline" % mode)
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _capture(tree: SceneTree, source_entry: bool) -> Dictionary:
	var session: WorldSessionController = SessionScene.instantiate() as WorldSessionController
	session.deterministic_npc_seed = true
	session.npc_seed = 7_021
	session.deterministic_combat_seed = true
	session.combat_seed = 5_232
	session.deterministic_world_interaction_seed = true
	if source_entry:
		session.configure_source_entry("凌雪", CharacterState.GENDER_FEMALE)
	tree.root.add_child(session)
	await tree.process_frame
	var scope: String = String(session.item_instance_scope())
	var npcs: Array = []
	for map: WorldMapController in session.world_maps():
		if GameContent.catalog().map(map.map_id()).region_id == OldPineWorldDefinitions.REGION_ID:
			npcs.append_array(_capture_map(map))
	# The next draw shows how many draws spawning consumed.
	var next_draw: int = session.npc_random_source().next_below(1_000_000)
	session.queue_free()
	await tree.process_frame
	# Item IDs carry the session's random scope; everything else must match.
	return JSON.parse_string(JSON.stringify({"npcs": npcs, "next_npc_draw": next_draw}).replace(scope, "<scope>"))


func _capture_map(map: WorldMapController) -> Array:
	var npcs: Array = []
	for npc: NpcRuntimeState in map.resident_npcs():
		var body: WorldCharacterBody2D = null
		for node: Node in map.find_children("*", "CharacterBody2D", true, false):
			if node is WorldCharacterBody2D and (node as WorldCharacterBody2D).character_id == npc.character_id:
				body = node
		var loadout: Array = []
		for item: ItemInstance in npc.loadout_items():
			loadout.append([String(item.item_instance_id), String(item.item_definition_id)])
		npcs.append({
			"map": String(map.map_id()),
			"character_id": String(npc.character_id),
			"definition": String(npc.definition_id),
			"spawn": String(npc.spawn_id),
			"point": String(npc.spawn_point_id),
			"zone": String(npc.world_location().zone_id),
			"position": [body.global_position.x, body.global_position.y] if body != null else null,
			"age": npc.age,
			"body_weight": npc.body_weight,
			"maximum_encumbrance": npc.maximum_encumbrance,
			"state": _dump(npc.character_state, 0),
			"armor": _dump(npc.armor, 0),
			"loadout": loadout,
		})
	return npcs


## Script variables only, recursively; stable key order.
func _dump(value: Variant, depth: int) -> Variant:
	if depth > MAX_DEPTH:
		return "<depth>"
	if value is Object:
		if value == null:
			return null
		var result: Dictionary = {}
		var names: Array[String] = []
		for property: Dictionary in (value as Object).get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				names.append(String(property["name"]))
		names.sort()
		for property_name: String in names:
			result[property_name] = _dump((value as Object).get(property_name), depth + 1)
		return result
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_dump(item, depth + 1))
		return items
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var copy: Dictionary = {}
		for key: Variant in keys:
			copy[str(key)] = _dump(value[key], depth + 1)
		return copy
	if value is StringName:
		return String(value)
	if value is float and not is_finite(value):
		return str(value)
	return value


func _assert_true(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected).left(400), str(actual).left(400)])
