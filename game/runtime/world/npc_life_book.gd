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
## - work: as wander, nearer its spot, and at each stop it works (its `gesture`).
## `gesture` (any mode but post): what its hands do while it stands (GESTURES; the voxel person
## plays it, with its tool when its look carries none). `pose` (still only): how it stands
## (POSES: on a low stool, cross-legged on the ground). `night` "home" (wander and work only; D,
## DECISIONS「夜里冷清」): one of the street's idle folk who goes indoors at night and comes out at
## dawn — never one the player needs (npc_life_test holds the list to that). A person without an
## entry stays put, as before.

const PEOPLE_KEY: String = "people"

enum Mode { STILL, POST, WANDER, WORK }

const MODE_NAMES: Dictionary[String, Mode] = {
	"still": Mode.STILL, "post": Mode.POST, "wander": Mode.WANDER, "work": Mode.WORK,
}
## A work entry without its own radius stays this near its spot.
const WORK_RADIUS_PX: int = 64
## What hands do at work (VoxelPerson plays each): 锄地, 挥镐, 劈柴, 打铁, 扫地, 钓鱼, 练拳, 擦桌,
## 讲书, 拨算盘.
const GESTURES: Array[String] = ["hoe", "pick", "chop", "hammer", "sweep", "fish", "drill", "wipe", "teach", "count"]
## How one that stays put is: standing, on a low stool, cross-legged on the ground.
const POSES: Array[String] = ["stand", "sit", "sit_ground"]


class Entry:
	extends RefCounted
	var mode: Mode = Mode.STILL
	## 0: the map's home_radius_px (work: WORK_RADIUS_PX).
	var radius_px: int = 0
	## "" none, else one of GESTURES.
	var gesture: String = ""
	var pose: String = "stand"
	## Goes indoors at night (`night`: "home").
	var night_home: bool = false

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
		if not ["mode", "radius", "gesture", "pose", "night"].has(key):
			problem.append("unknown key %s" % key)
			return null
	var gesture: Variant = record.get("gesture", "")
	if not (gesture is String) or (gesture != "" and not GESTURES.has(gesture)):
		problem.append("gesture must be one of %s" % ", ".join(GESTURES))
		return null
	if gesture != "" and result.mode == Mode.POST:
		problem.append("a post makes no gesture")
		return null
	result.gesture = gesture
	var pose: Variant = record.get("pose", "stand")
	if not (pose is String) or not POSES.has(pose):
		problem.append("pose must be one of %s" % ", ".join(POSES))
		return null
	if pose != "stand" and result.mode != Mode.STILL:
		problem.append("only one that stays put sits")
		return null
	result.pose = pose
	var night: Variant = record.get("night", "")
	if night != "" and night != "home":
		problem.append("night must be \"home\"")
		return null
	if night == "home" and not result.moves():
		problem.append("only one about the streets goes home at night")
		return null
	result.night_home = night == "home"
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
