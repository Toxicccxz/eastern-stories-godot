extends RefCounted

## TEST-ONLY (and the dev launcher's, tests/dev/chapter_start): what the game's own data reads and does, from the
## data files themselves (res://data, every JSON), for the checks that a start or a fixture leaves the world as a
## playthrough would:
## - the marks some condition reads (any key that names marks — `mark`, `marks`, `not_mark`, `asker_marks`,
##   `giver_mark`, a quest step's `done`, a landmark's `looks`, a condition's `when` … — except the keys that
##   write them: a step's `mark`, `mark_asker`, `mark_giver`, `teaches`, a reward's `marks` …), and the quoted
##   words of the game's own scripts (a script that reads a mark names it);
## - the items some condition reads or an act takes (`item`, `carries`, `asker_carries`, `wearing`, `takes` …,
##   by id or by name);
## - each list of steps that sends people away (`leave`) or calls some in (`summon`), with the marks it writes:
##   a list whose marks a start writes ran in the story the start stands for, so those it sent away are gone.
## Over-reading is safe (a check looks at more than it must); the reads are walked once per run.

## Keys whose marks a list of steps, a rule or a reward writes, not reads.
const WRITE_KEYS: Array[String] = [
	"mark_asker", "marks_asker", "mark_giver", "marks_giver", "teaches", "set_mark", "also_mark", "die_marks_killer",
	"scene_mark", "spar_won_mark", "vendetta_mark", "unmark", "unmarks", "unmark_giver", "once_mark", "mark_lapses_at",
]
## Keys that name an item read where they stand (a condition, a rule, an act that takes it).
const ITEM_KEYS: Array[String] = ["item", "items", "carries", "asker_carries", "asker_not_carries", "confirm_carries", "giver_carries", "die_carries", "wearing", "takes", "item_alias"]
## Parents under which `item` / `items` lay or sell things rather than read them.
const ITEM_LAYING: Array[String] = ["goods", "item_spawns", "props", "pieces", "landmarks", "looks"]
## Script folders whose quoted words count as read.
const SCRIPT_ROOTS: Array[String] = ["res://core", "res://runtime", "res://application", "res://presentation", "res://ui"]

static var _marks: Dictionary[String, bool] = {}
static var _items: Dictionary[String, bool] = {}
static var _lists: Array[Dictionary] = []
static var _walked: bool = false


## Whether some condition (or a script) reads `mark`.
static func mark_read(mark: String) -> bool:
	_walk()
	return _marks.has(mark)


## Whether some condition reads or some act takes the item `item_id` (by its id, its name or an alias).
static func item_read(item_id: StringName) -> bool:
	_walk()
	if _items.has(String(item_id)):
		return true
	var item: ItemContentDefinition = GameContent.catalog().item(item_id)
	if item == null:
		return false
	if _items.has(item.display_name):
		return true
	for alias: String in item.aliases():
		if _items.has(alias):
			return true
	return false


## Each list of steps that sends someone away or calls someone in: {"writes": Array[String] (the marks the list and
## its rule write), "leaves": Array[StringName] (NPC definitions, one entry a person), "summons": Array[StringName]
## (spawns), "npc": StringName (the NPC whose rule or call it is, &"" for none), "zone": StringName (the service's or
## landmark's zone, &"" for none)} — the people a list sends away stand where its scene plays: beside its NPC, or
## in its zone.
static func step_lists() -> Array[Dictionary]:
	_walk()
	return _lists


static func _walk() -> void:
	if _walked:
		return
	_walked = true
	for path: String in _files("res://data", ".json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed != null:
			_node(parsed, "", false, {})
	var quoted := RegEx.create_from_string("\"([^\"\\\\\\n]+)\"")
	for root: String in SCRIPT_ROOTS:
		for path: String in _files(root, ".gd"):
			for found: RegExMatch in quoted.search_all(FileAccess.get_file_as_string(path)):
				_marks[found.get_string(1)] = true


static func _files(root: String, suffix: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return out
	for name: String in dir.get_files():
		if name.ends_with(suffix):
			out.append(root.path_join(name))
	for sub: String in dir.get_directories():
		out.append_array(_files(root.path_join(sub), suffix))
	return out


## `parent`: the key `node` stands under; `step`: whether `node` is one element of a `steps` list; `owner`: the NPC
## ({"npc": id}) or zone ({"zone": id}) whose record `node` lies in.
static func _node(node: Variant, parent: String, step: bool, owner: Dictionary) -> void:
	if node is Array:
		for element: Variant in node:
			_node(element, parent, parent == "steps", owner)
		return
	if not node is Dictionary:
		return
	var record: Dictionary = node
	if parent == "npcs" and record.get("id") is String:
		owner = {"npc": StringName(record["id"])}
	elif parent in ["services", "landmarks"] and record.get("zone") is String:
		owner = {"zone": StringName(record["zone"])}
	if record.get("steps") is Array:
		_list(record, owner)
	for key: Variant in record:
		var name: String = str(key)
		var value: Variant = record[key]
		if name.contains("mark") and not WRITE_KEYS.has(name):
			var writes: bool = (step and name == "mark") or (parent == "reward" and name == "marks") or (parent == "lapses" and name == "mark")
			if not writes:
				_add(_marks, value)
		if ITEM_KEYS.has(name) and not (name.begins_with("item") and ITEM_LAYING.has(parent)):
			_add(_items, value)
		_node(value, name, false, owner)


static func _add(into: Dictionary[String, bool], value: Variant) -> void:
	if value is String:
		into[value] = true
	elif value is Array:
		for element: Variant in value:
			if element is String:
				into[element] = true


static func _list(record: Dictionary, owner: Dictionary) -> void:
	var writes: Array[String] = []
	var leaves: Array[StringName] = []
	var summons: Array[StringName] = []
	for key: String in ["mark_asker", "mark_giver"]:
		if record.get(key) is String:
			writes.append(record[key])
	for key: String in ["marks_asker", "marks_giver"]:
		if record.get(key) is Array:
			for mark: Variant in record[key]:
				writes.append(str(mark))
	for element: Variant in record["steps"]:
		if not element is Dictionary:
			continue
		if element.get("mark") is String:
			writes.append(element["mark"])
		if element.get("leave") is String:
			leaves.append(StringName(element["leave"]))
		if element.get("summon") is String:
			summons.append(StringName(element["summon"]))
	if not leaves.is_empty() or not summons.is_empty():
		_lists.append({"writes": writes, "leaves": leaves, "summons": summons, "npc": owner.get("npc", &""), "zone": owner.get("zone", &"")})
