class_name NpcLifeBook
extends RefCounted

## Native (NPC 活起来; DECISIONS「街上的人会动」): how each person spends the time nothing else
## moves them, by NPC definition id, in game/data/<region>/npc_life.json
## ({"people": {id: entry}}; the region is the id's first part). An entry is a mode's name, or
## {"mode": name, "radius": px} to keep a person nearer its own spot than the map's
## home_radius_px (a smith by the forge, a trainee on the drilling ground):
## - still: stays put (a shopkeeper at the counter, one sitting or lying); turns to the player.
## - post: a guard at the gate: stands, now and then looks along the way, and back.
## - wander: walks a few steps about the room, stands a while, walks again.
## - work: as wander, nearer its spot (its work's places; the work's gestures come later).
## A person without an entry stays put, as before. Embodiment only: no rule reads it.

const PEOPLE_KEY: String = "people"

enum Mode { STILL, POST, WANDER, WORK }

const MODE_NAMES: Dictionary[String, Mode] = {
	"still": Mode.STILL, "post": Mode.POST, "wander": Mode.WANDER, "work": Mode.WORK,
}
## A work entry without its own radius stays this near its spot.
const WORK_RADIUS_PX: int = 64


class Entry:
	extends RefCounted
	var mode: Mode = Mode.STILL
	## 0: the map's home_radius_px (work: WORK_RADIUS_PX).
	var radius_px: int = 0

	func moves() -> bool:
		return mode == Mode.WANDER or mode == Mode.WORK

	## How far from its spot a stroll may end, under the map's `home_radius`.
	func reach(home_radius: int) -> int:
		if radius_px > 0:
			return mini(radius_px, home_radius) if home_radius > 0 else radius_px
		return mini(WORK_RADIUS_PX, home_radius) if mode == Mode.WORK else home_radius


static var _regions: Dictionary[String, Dictionary] = {}


## The entry of `definition_id`, or null (it stays put).
static func entry(definition_id: StringName) -> Entry:
	var id: String = String(definition_id)
	var dot: int = id.find(".")
	if dot <= 0:
		return null
	return _region(id.substr(0, dot)).get(id)


## Forgets what was read (a suite that writes its own files).
static func reset() -> void:
	_regions.clear()


## `raw` (a file's entry) as an Entry, or null with `problem[0]` saying why.
static func parse(raw: Variant, problem: Array[String] = []) -> Entry:
	var record: Dictionary = {"mode": raw} if raw is String else (raw if raw is Dictionary else {})
	var result: Entry = Entry.new()
	var name: Variant = record.get("mode")
	if not (name is String) or not MODE_NAMES.has(name):
		problem.append("mode must be one of %s" % ", ".join(MODE_NAMES.keys()))
		return null
	result.mode = MODE_NAMES[name]
	var radius: Variant = record.get("radius", 0)
	if not (radius is float or radius is int) or float(radius) < 0.0 or float(radius) != floorf(float(radius)):
		problem.append("radius must be a whole number of pixels, not negative")
		return null
	result.radius_px = int(radius)
	for key: Variant in record.keys():
		if key != "mode" and key != "radius":
			problem.append("unknown key %s" % key)
			return null
	return result


static func _region(region: String) -> Dictionary:
	if _regions.has(region):
		return _regions[region]
	var entries: Dictionary = {}
	var path: String = "res://data/%s/npc_life.json" % region
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and (parsed as Dictionary).get(PEOPLE_KEY) is Dictionary:
			var people: Dictionary = (parsed as Dictionary)[PEOPLE_KEY]
			for id: Variant in people.keys():
				var problem: Array[String] = []
				var parsed_entry: Entry = parse(people[id], problem)
				if parsed_entry == null:
					push_error("npc life: %s %s: %s" % [path, id, problem[0]])
				else:
					entries[String(id)] = parsed_entry
		else:
			push_error("npc life: %s is not {\"%s\": {...}}" % [path, PEOPLE_KEY])
	_regions[region] = entries
	return entries
