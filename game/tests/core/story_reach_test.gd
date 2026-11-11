extends RefCounted

## DECISIONS「主线卡死点」: two checks over the data, no session, run before a story package
## reaches the owner's playtest.
## 1. Every mark the data reads (a quest step's `done`, an act's or a call's condition, a rule's
##    asker_marks, a spawn's present / until …) is written somewhere in the data (a rule's
##    mark_asker, an act's `mark` step, a spawn's cleared_mark, a reward …) or by the code
##    (CODE_MARKS, CODE_PREFIXES). A mark read and never written is a way that never opens
##    (番坊 C's 站了浪人 was one: the fixtures wrote it, the game never did).
## 2. A step of the main story or of a faction line (a branch: every one of its options) does not
##    hang on one person who can be killed and is never made anew: for each mark (or `heard`) that
##    does the step, some writer does not
##    need such a person standing — or the step (or a later one of its quest) `keeps` them
##    (knocked down, never killed, until it is done). One who never dies here: fight_deferred or
##    spar_only; one made anew: a spawn a room reset remakes (not staged, or an ES2 resident on
##    the stage: NpcSpawnDefinition.resident). An act's branch that asks `present` / `by` of
##    someone hangs on the one of them in that act's room.
## The data is read raw (res://data/**/*.json) for who writes and reads what; the catalog for the
## quests, the NPCs and the spawns.

const DATA_ROOT: String = "res://data"
## Marks the code writes (WorldBounties: the 悬赏榜's taken / done).
const CODE_MARKS: Array[String] = ["a2_bounty_taken", "a2_bounty_done"]
## Mark families the code writes (CombatInsights.WOUNDED_BY: the last school that wounded the player).
const CODE_PREFIXES: Array[String] = ["wounded_by/"]
## Keys whose value names marks a writer sets.
const WRITE_KEYS: Array[String] = [
	"teaches", "mark_asker", "marks_asker", "mark_giver", "cleared_mark", "scene_mark", "set_mark",
	"die_marks_killer", "spar_won_mark", "again_mark", "accept_marks", "refuse_marks", "mark_on_give",
]
## Keys whose value names marks a condition reads.
const READ_KEYS: Array[String] = [
	"asker_marks", "asker_lacks", "giver_mark", "unless_giver_mark", "not_mark", "confirm_marks",
	"confirm_lacks", "listed_marks", "forbids_marks", "unless_marks", "unless_mark",
	"attack_unless_marks", "attack_unless_mark",
]
## Under these keys a `mark` / `marks` is a condition (a journal `when`, an act's branch, a rule).
const CONDITION_PARENTS: Array[String] = [
	"any", "all", "not", "of", "when", "done", "present", "until", "if", "starts", "final", "ignores_when",
	"at_least", "unless", "exit_rules", "requires", "looks", "accept_fight", "rules", "calls", "acts",
	"shown_if", "checklist", "lapses_when",
]
## Under these keys a `mark` / `marks` is what happens (a trial passed, one spared, a way taken).
const WRITE_PARENTS: Array[String] = ["trials", "caught", "spared", "routes", "lapses", "landmarks"]

## Who writes a mark: the file, the NPC whose record it is in ("" for none), the people an act's
## branch or a step's `by` needs standing first, and the room of a world act.
class Source:
	extends RefCounted
	var origin: String = ""
	var npc: StringName = &""
	var gates: Array[StringName] = []
	var zone: StringName = &""

	func with_gate(npc_id: StringName) -> Source:
		var source := Source.new()
		source.origin = origin
		source.npc = npc
		source.gates = gates.duplicate()
		source.zone = zone
		if not source.gates.has(npc_id):
			source.gates.append(npc_id)
		return source

	func with_npc(npc_id: StringName, p_origin: String) -> Source:
		var source := Source.new()
		source.origin = p_origin
		source.npc = npc_id
		source.zone = zone
		return source

	func with_zone(zone_id: StringName, p_origin: String) -> Source:
		var source := Source.new()
		source.origin = p_origin
		source.npc = npc
		source.zone = zone_id
		return source

var _count: int = 0
var _failures: Array[String] = []
var _writers: Dictionary[String, Array] = {}
var _readers: Dictionary[String, Array] = {}


func run_all(_tree: SceneTree) -> Dictionary[String, Variant]:
	scan(DATA_ROOT)
	_check(_writers.size() > 250 and _readers.size() > 250,"the data read: %d marks written, %d read" % [_writers.size(), _readers.size()])
	for problem: String in unwritten():
		_check(false, problem)
	for problem: String in hanging_steps(GameContent.catalog()):
		_check(false, problem)
	return {"assertions": _count, "failures": _failures}


## Reads every data file under `root` into the writer and reader tables.
func scan(root: String) -> void:
	_writers.clear()
	_readers.clear()
	for path: String in _json_files(root):
		var text: String = FileAccess.get_file_as_string(path)
		var data: Variant = JSON.parse_string(text)
		if data == null:
			_failures.append("story reach: %s does not parse" % path)
			continue
		var source := Source.new()
		source.origin = path.trim_prefix(root + "/")
		_walk(data, [], source)


## "<mark> is read (<where>) and nothing writes it" for each such mark, sorted.
func unwritten() -> Array[String]:
	var problems: Array[String] = []
	var marks: Array = _readers.keys()
	marks.sort()
	for mark: String in marks:
		if _writers.has(mark) or CODE_MARKS.has(mark) or CODE_PREFIXES.any(func(prefix: String) -> bool: return mark.begins_with(prefix)):
			continue
		var where: PackedStringArray = PackedStringArray()
		for origin: String in _readers[mark].slice(0, 3):
			where.append(origin)
		problems.append("「%s」 is read (%s) and nothing writes it" % [mark, ", ".join(where)])
	return problems


## "<quest>/<step>[/<option>]: …" for each main-story or faction step whose doing hangs on one
## who can be killed for good.
func hanging_steps(catalog: ContentCatalog) -> Array[String]:
	var problems: Array[String] = []
	for quest: StoryQuestDefinition in catalog.story_quests():
		if quest.line != StoryQuestDefinition.LINE_MAIN and quest.line != StoryQuestDefinition.LINE_FACTION:
			continue
		for index: int in quest.steps.size():
			var step: StoryQuestDefinition.Step = quest.steps[index]
			var kept: Dictionary[StringName, bool] = {}
			for later: StoryQuestDefinition.Step in quest.steps.slice(index):
				for npc_id: StringName in later.keeps:
					kept[npc_id] = true
			if not step.is_branch():
				var why: String = _hangs(step.condition, catalog, kept)
				if not why.is_empty():
					problems.append("%s/%s hangs on one who can be killed for good: %s" % [quest.quest_id, step.step_id, why])
				continue
			# A branch is stuck only when no option is left (one way closed by a killing is a choice made).
			var whys: PackedStringArray = PackedStringArray()
			for option: StoryQuestDefinition.Option in step.options:
				var why: String = _hangs(option.condition, catalog, kept)
				if why.is_empty():
					whys.clear()
					break
				whys.append("%s: %s" % [option.option_id, why])
			if not whys.is_empty():
				problems.append("%s/%s hangs on one who can be killed for good: %s" % [quest.quest_id, step.step_id, "; ".join(whys)])
	return problems


## Why `condition` cannot be done once someone is killed ("" when it always can).
func _hangs(condition: JournalEntryDefinition, catalog: ContentCatalog, kept: Dictionary[StringName, bool]) -> String:
	if condition == null:
		return ""
	match condition.when:
		JournalEntryDefinition.When.ALL:
			for part: JournalEntryDefinition in condition.parts:
				var why: String = _hangs(part, catalog, kept)
				if not why.is_empty():
					return why
			return ""
		JournalEntryDefinition.When.ANY:
			var whys: PackedStringArray = PackedStringArray()
			for part: JournalEntryDefinition in condition.parts:
				var why: String = _hangs(part, catalog, kept)
				if why.is_empty():
					return ""
				whys.append(why)
			return " / ".join(whys)
		JournalEntryDefinition.When.HEARD:
			var npc_id := StringName(condition.key)
			return "" if _sturdy(npc_id, &"", catalog, kept) else "heard %s" % npc_id
		JournalEntryDefinition.When.MARK:
			var sources: Array = _writers.get(condition.key, [])
			if sources.is_empty():
				return ""  # unwritten() says so
			var needs: PackedStringArray = PackedStringArray()
			for source: Source in sources:
				var fragile: StringName = _fragile_need(source, catalog, kept)
				if fragile.is_empty():
					return ""
				needs.append("%s (%s)" % [fragile, source.origin])
			return "「%s」 only by %s" % [condition.key, ", ".join(needs)]
	return ""


## The first one `source` needs standing who can be killed for good, or "".
func _fragile_need(source: Source, catalog: ContentCatalog, kept: Dictionary[StringName, bool]) -> StringName:
	if not source.npc.is_empty() and not _sturdy(source.npc, &"", catalog, kept):
		return source.npc
	for npc_id: StringName in source.gates:
		if npc_id != source.npc and not _sturdy(npc_id, source.zone, catalog, kept):
			return npc_id
	return &""


## Whether the NPC `npc_id` (the one of them in `zone_id`, unless "") is always there when wanted:
## never killed (fight_deferred, spar_only, kept by the step) or made anew by a room reset.
static func _sturdy(npc_id: StringName, zone_id: StringName, catalog: ContentCatalog, kept: Dictionary[StringName, bool]) -> bool:
	var npc: NpcDefinition = catalog.npc(npc_id)
	if npc == null:
		return false
	if kept.has(npc_id) or npc.dealings().is_fight_deferred() or npc.spar_only():
		return true
	for spawn: NpcSpawnDefinition in catalog.spawns():
		if spawn.npc_definition_id != npc_id or (not zone_id.is_empty() and spawn.zone_id != zone_id):
			continue
		if spawn.remade_by_reset():
			return true
	return false


func _walk(value: Variant, path: Array[String], source: Source) -> void:
	if value is Array:
		var steps: bool = not path.is_empty() and path[-1] in ["steps", "true", "false"]
		var running: Source = source
		for element: Variant in value:
			if steps and element is Dictionary and element.get("by") is String:
				running = running.with_gate(StringName(element["by"]))
			_walk(element, path, running)
		return
	if not value is Dictionary:
		return
	var record: Dictionary = value
	var here: Source = source
	var last: String = "" if path.is_empty() else path[-1]
	# An NPC's record: what it says and does is its own.
	if path == ["npcs"] and record.get("id") is String and source.origin.ends_with("npcs.json"):
		here = source.with_npc(StringName(record["id"]), "%s:%s" % [source.origin.get_slice(":", 0), record["id"]])
	# A world service (an act, a landmark …) in a room.
	elif path.size() == 1 and record.get("id") is String and record.get("zone") is String:
		here = source.with_zone(StringName(record["zone"]), "%s:%s" % [source.origin.get_slice(":", 0), record["id"]])
	# An act's branch for one standing there.
	if record.get("present") is String:
		here = here.with_gate(StringName(record["present"]))
	for key: Variant in record:
		var child: Variant = record[key]
		var name: String = str(key)
		if WRITE_KEYS.has(name):
			_note(_writers, child, here)
		elif READ_KEYS.has(name):
			_note(_readers, child, here.origin)
		elif name == "mark" or name == "marks":
			match _mark_role(record, name, path, last):
				"write":
					_note(_writers, child, here)
				"read":
					_note(_readers, child, here.origin)
		if child is Dictionary or child is Array:
			var deeper: Array[String] = path.duplicate()
			deeper.append(name)
			_walk(child, deeper, here)


## Whether a `mark` / `marks` in `record` writes ("write"), reads ("read") or labels ("": a
## question's answer, a picture's glyph).
static func _mark_role(record: Dictionary, name: String, path: Array[String], last: String) -> String:
	if not (record[name] is String or record[name] is Array):
		return ""
	if last == "answers" or path.has("draw"):
		return ""
	if name == "marks" and last == "reward":
		return "write"
	if last in ["steps", "true", "false"] and not record.has("steps") and path.slice(-2) != ["dance", "steps"]:
		return "write"
	if WRITE_PARENTS.has(last) or path.slice(-2) == ["dance", "steps"]:
		return "write"
	if CONDITION_PARENTS.has(last) or record.has("steps"):
		return "read"
	return "read"


func _note(table: Dictionary[String, Array], value: Variant, what: Variant) -> void:
	var marks: Array = []
	if value is String:
		marks = [value]
	elif value is Array:
		marks = value.filter(func(each: Variant) -> bool: return each is String)
	for mark: String in marks:
		if not table.has(mark):
			table[mark] = []
		table[mark].append(what)


static func _json_files(root: String) -> Array[String]:
	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return files
	for name: String in dir.get_directories():
		if name == "voxel":
			continue
		files.append_array(_json_files(root.path_join(name)))
	for name: String in dir.get_files():
		if name.ends_with(".json") and name != "item_looks.json":
			files.append(root.path_join(name))
	return files


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("story reach: " + label)
