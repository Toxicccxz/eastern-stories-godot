extends RefCounted

## The world's numbers that older suites pin and that every region package moves:
## the maps, the rooms, Snow's outdoor portals and passages, the NPCs and items a
## New Game makes, the NPC creation draws after Old Pine's and the spawn order; per map
## its zones and NPCs (`of("map_npcs", map)`); the technical world's maps and items; the
## two-map Snow route fixture's numbers (`of("snow_route", "draws")`). One
## fixture holds them; tests/runtime/world_counts_test.gd checks it against the live
## world and rewrites it with UPDATE_WORLD_COUNTS=1:
##
##     UPDATE_WORLD_COUNTS=1 <godot> --headless --path game --script res://tests/run_suite.gd -- res://tests/runtime/world_counts_test.gd
##
## Review the fixture's diff: it is what the package changed.
const PATH: String = "res://tests/fixtures/world_counts.json"

static var _values: Dictionary = {}


static func number(key: String) -> int:
	return int(_all().get(key, -1))


static func ids(key: String) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in _all().get(key, []):
		result.append(StringName(value))
	return result


## One entry of a keyed family: of("map_npcs", &"cloud.outdoor").
static func of(key: String, entry: String) -> int:
	var family: Variant = _all().get(key, {})
	return int((family as Dictionary).get(entry, -1)) if family is Dictionary else -1


static func _all() -> Dictionary:
	if _values.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_values = parsed if parsed is Dictionary else {}
	return _values
