extends RefCounted

## DECISIONS「主线卡死点」: two checks over the data, no session, run before a story package
## reaches the owner's playtest.
## 1. Every mark the data reads (a quest step's `done`, an act's or a call's condition, a rule's
##    asker_marks, a spawn's present / until …) is written somewhere in the data (a rule's
##    mark_asker, an act's `mark` step, a spawn's cleared_mark, a reward …) or by the code
##    (CODE_MARKS, CODE_PREFIXES). A mark read and never written is a way that never opens
##    (番坊 C's 站了浪人 was one: the fixtures wrote it, the game never did).
## 2. A step of the main story or of a faction line (a branch: every one of its options) does not
##    hang on one person who can be killed and is never made anew: for each mark (or `heard`, or an
##    item carried or worn) that does the step, some writer (some giver) does not need such a
##    person standing, nor a mark or an item only such a person gives (the writer rule's own
##    asker_marks, asker_carries, carries) — or the step (or a later one of its quest on its way:
##    not waiting for another option, `only_after`) `keeps` them (knocked down, never killed, until
##    it is done). One who never dies here: fight_deferred or spar_only; one made anew: a spawn a
##    room reset remakes (not staged, or an ES2 resident on the stage: NpcSpawnDefinition.resident).
##    An act's branch that asks `present` / `by` of someone hangs on the one of them in that act's
##    room. A condition the check does not know how to judge is a failure, not a pass.
## The data is read raw (res://data/**/*.json) for who writes and reads what; the catalog for the
## quests, the NPCs and the spawns.

const DATA_ROOT: String = "res://data"
## Marks the code writes (WorldBounties: the 悬赏榜's taken / done).
const CODE_MARKS: Array[String] = ["a2_bounty_taken", "a2_bounty_done"]
## Mark families the code writes (CombatInsights.WOUNDED_BY: the last school that wounded the player).
const CODE_PREFIXES: Array[String] = ["wounded_by/"]
## Marks read and on purpose written by nothing: the wrong answer of a question (village/world.json's
## 璃虹: 商玦's telling of the 铜牒; the answers' `note` says so) never holds.
const NEVER_WRITTEN: Array[String] = ["信了商玦"]
## Keys whose value names items a writer gives (an act's give / drop, a rule's gives, a landmark's
## reward and what comes with it).
const GIVE_KEYS: Array[String] = ["gives", "give", "drop", "reward", "with"]
## Records under these keys give their `item` whoever is killed: a floor spawn, what an NPC carries
## (on their corpse), a vendor's goods. So do a container's `contains` and an NPC's `die_carries`.
const STURDY_GIVE_PARENTS: Array[String] = ["item_spawns", "carry", "goods"]
const STURDY_GIVE_KEYS: Array[String] = ["contains", "die_carries"]
## Keys of a rule (an act's branch) whose value names what the one doing it must already hold: its
## marks, the item it carries (an id or an alias).
const NEED_MARK_KEYS: Array[String] = ["asker_marks"]
const NEED_ITEM_KEYS: Array[String] = ["asker_carries", "carries"]
## Conditions a step may wait on that no killing takes away (walking somewhere, the clock, growing,
## one's family, the story so far, not holding something).
const ALWAYS_DOABLE: Array[int] = [
	JournalEntryDefinition.When.ZONE, JournalEntryDefinition.When.PHASE, JournalEntryDefinition.When.EXP_AT_LEAST,
	JournalEntryDefinition.When.SKILL_AT_LEAST, JournalEntryDefinition.When.FORCE_AT_LEAST, JournalEntryDefinition.When.FAMILY,
	JournalEntryDefinition.When.MILESTONE, JournalEntryDefinition.When.QUEST, JournalEntryDefinition.When.NOT,
]
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

## Who writes a mark (gives an item): the file, the NPC whose record it is in ("" for none), the
## people an act's branch or a step's `by` needs standing first, the room of a world act, and what
## the rule asks of the one doing it (marks held, items carried).
class Source:
	extends RefCounted
	var origin: String = ""
	var npc: StringName = &""
	var gates: Array[StringName] = []
	var zone: StringName = &""
	var needs_marks: Array[String] = []
	var needs_items: Array[String] = []
	## An item's giver that is a corpse: the NPC who carries it ("" for none).
	var carrier: StringName = &""

	func _copy() -> Source:
		var source := Source.new()
		source.origin = origin
		source.npc = npc
		source.gates = gates.duplicate()
		source.zone = zone
		source.needs_marks = needs_marks.duplicate()
		source.needs_items = needs_items.duplicate()
		source.carrier = carrier
		return source

	func with_gate(npc_id: StringName) -> Source:
		var source: Source = _copy()
		if not source.gates.has(npc_id):
			source.gates.append(npc_id)
		return source

	func with_needs(marks: Array, items: Array) -> Source:
		var source: Source = _copy()
		for mark: Variant in marks:
			if mark is String and not source.needs_marks.has(mark):
				source.needs_marks.append(mark)
		for item: Variant in items:
			if item is String and not source.needs_items.has(item):
				source.needs_items.append(item)
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
## Item id → its givers (Source).
var _givers: Dictionary[String, Array] = {}
## Conditions met that the check cannot judge (reported, never passed).
var _unjudged: Array[String] = []
## What is being judged now ("mark:<m>" / "item:<i>"): a ring of rules is no way.
var _judging: Dictionary[String, bool] = {}
## The marks the earlier steps on the way of the step judged now were done by (held_for()).
var _held: Dictionary[String, bool] = {}


func run_all(_tree: SceneTree) -> Dictionary[String, Variant]:
	scan(DATA_ROOT)
	_check(_writers.size() > 250 and _readers.size() > 250,"the data read: %d marks written, %d read" % [_writers.size(), _readers.size()])
	for problem: String in unwritten():
		_check(false, problem)
	for problem: String in hanging_steps(GameContent.catalog()):
		_check(false, problem)
	_test_what_it_sees(GameContent.catalog())
	return {"assertions": _count, "failures": _failures}


## The check sees what it is meant to (each on made-up tables, in a fresh copy of the check): an
## item only a mortal gives; a writer rule's own asker_marks and carries; a later step's keeps only on
## its own way; a condition it cannot judge, even inside an `any`; an answer's, a dance step's and a
## searched landmark's mark are read.
func _test_what_it_sees(catalog: ContentCatalog) -> void:
	const MORTAL: StringName = &"native.npc.andun"  # staged, killable, not remade (as data stands)
	var none: Dictionary[StringName, bool] = {}
	var check: Object = (get_script() as Script).new()
	_check(not check._sturdy(MORTAL, &"", catalog, none), "the made-up tables' mortal can be killed for good")
	var mortal := Source.new()
	mortal.origin = "t"
	mortal.npc = MORTAL
	var anyone := Source.new()
	anyone.origin = "t"
	check._givers["t:item"] = [mortal]
	check._writers["t:mark"] = [mortal]
	_check(check._hangs(_when(JournalEntryDefinition.When.ITEM, "t:item"), catalog, none).contains(String(MORTAL)), "an item only a mortal gives hangs on them")
	check._givers["t:item"] = [mortal, anyone]
	_check(check._hangs(_when(JournalEntryDefinition.When.WEARING, "t:item"), catalog, none).is_empty(), "an item also given whoever is killed does not")
	_check(check._hangs(_when(JournalEntryDefinition.When.ITEM, "t:nobody's"), catalog, none).begins_with("nothing gives"), "an item nothing gives hangs")
	var asks := Source.new()
	asks.origin = "t"
	check._writers["t:asked"] = [asks.with_needs(["t:mark"], [])]
	_check(check._hangs(_when(JournalEntryDefinition.When.MARK, "t:asked"), catalog, none).contains("it needs a mark: 「t:mark」 only by " + String(MORTAL)), "a writer rule whose asker_marks only a mortal writes hangs on them")
	check._givers["t:item"] = [mortal]
	check._writers["t:asked"] = [asks.with_needs([], ["t:item"])]
	_check(check._hangs(_when(JournalEntryDefinition.When.MARK, "t:asked"), catalog, none).contains("it needs an item: the item t:item only from " + String(MORTAL)), "a writer rule whose carries only a mortal gives hangs on them")
	check._held["t:mark"] = true
	_check(check._hangs(_when(JournalEntryDefinition.When.MARK, "t:mark"), catalog, none).is_empty(), "a mark an earlier step on the way was done by is held")
	check._held.clear()
	# A condition it does not judge fails, inside an `any` too.
	var unknown: JournalEntryDefinition = _when(JournalEntryDefinition.When.ANY, "")
	unknown.parts.assign([_when(JournalEntryDefinition.When.ZONE, "t.zone"), _when(JournalEntryDefinition.When.TEMP, "t:temp")])
	_check(check._hangs(unknown, catalog, none, "t/step").is_empty() and check._unjudged.size() == 1 and check._unjudged[0].begins_with("t/step"), "a condition it cannot judge is reported, inside an any: %s" % [check._unjudged])
	# keeps only on the way: a later step waiting for another option keeps nobody here.
	var quest := StoryQuestDefinition.new()
	var choose := StoryQuestDefinition.Step.new()
	for option_id: StringName in [&"a", &"b"]:
		var option := StoryQuestDefinition.Option.new()
		option.option_id = option_id
		option.condition = _when(JournalEntryDefinition.When.MARK, "t:" + option_id)
		choose.options.append(option)
	var after_a := StoryQuestDefinition.Step.new()
	after_a.only_after = &"a"
	after_a.keeps.assign([&"t.npc.a"])
	var after_b := StoryQuestDefinition.Step.new()
	after_b.only_after = &"b"
	after_b.keeps.assign([&"t.npc.b"])
	var last := StoryQuestDefinition.Step.new()
	last.keeps.assign([&"t.npc.all"])
	quest.steps.assign([choose, after_a, after_b, last])
	_check(kept_for(quest, 0, [&"", &"a"]).keys() == [&"t.npc.a", &"t.npc.all"], "option a: kept by its own later step and the common one: %s" % [kept_for(quest, 0, [&"", &"a"]).keys()])
	_check(kept_for(quest, 1, [&"a"]).keys() == [&"t.npc.a", &"t.npc.all"] and kept_for(quest, 2, [&"b"]).keys() == [&"t.npc.b", &"t.npc.all"], "a step on one way is not kept by the other's")
	_check(held_for(quest, 2, [&"b"]).keys() == ["t:b"] and held_for(quest, 3, [&""]).is_empty(), "held: the option the way waits for, not the other")
	# What reads a mark.
	_check(_mark_role({"text": "x", "mark": "m"}, "mark", ["questions", "answers"], "answers") == "read", "an answer's mark is read")
	_check(_mark_role({"name": "x", "mark": "m"}, "mark", ["dance", "steps"], "steps") == "read", "a dance step's mark is read")
	_check(_mark_role({"policy": "search", "mark": "m"}, "mark", ["landmarks"], "landmarks") == "read", "a searched landmark's mark is read")
	_check(_mark_role({"mark": "m"}, "mark", ["steps"], "steps") == "write", "an act step's mark is written")
	# Walked from data: a carried thing comes off its carrier's corpse; a gift rule needs the gift and
	# the giver's mark; an act's branch needs the marks it is gated by.
	var walked: Object = (get_script() as Script).new()
	var from := Source.new()
	from.origin = "t/npcs.json"
	walked._walk({"npcs": [{
		"id": String(MORTAL), "carry": [{"item": "t:carried"}],
		"accept_object": [{"item": "t:gift", "giver_mark": "t:given", "accept": true, "mark_giver": "t:thanked"}],
		"acts": [{"mark": "t:gate", "steps": [{"mark": "t:after"}]}],
	}]}, [] as Array[String], from)
	var carried: Array = walked._givers.get("t:carried", [])
	_check(carried.size() == 1 and carried[0].carrier == MORTAL, "a carried thing's giver is its carrier's corpse")
	_check(walked._hangs(_when(JournalEntryDefinition.When.ITEM, "t:carried"), catalog, none).is_empty(), "one who can be killed gives what they carry")
	var keeping: Dictionary[StringName, bool] = {MORTAL: true}
	_check(walked._hangs(_when(JournalEntryDefinition.When.ITEM, "t:carried"), catalog, keeping).contains("not killed"), "one kept (never killed) does not")
	var thanked: Array = walked._writers.get("t:thanked", [])
	_check(thanked.size() == 1 and thanked[0].needs_items.has("t:gift") and thanked[0].needs_marks.has("t:given"), "a gift rule needs the gift and the giver's mark")
	var after: Array = walked._writers.get("t:after", [])
	_check(after.size() == 1 and after[0].needs_marks.has("t:gate"), "an act's branch needs the mark it is gated by")



static func _when(kind: int, key: String) -> JournalEntryDefinition:
	var condition := JournalEntryDefinition.new()
	condition.when = kind
	condition.key = key
	return condition


## Reads every data file under `root` into the writer and reader tables.
func scan(root: String) -> void:
	_writers.clear()
	_readers.clear()
	_givers.clear()
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
		if _writers.has(mark) or CODE_MARKS.has(mark) or NEVER_WRITTEN.has(mark) or CODE_PREFIXES.any(func(prefix: String) -> bool: return mark.begins_with(prefix)):
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
	_unjudged.clear()
	for quest: StoryQuestDefinition in catalog.story_quests():
		if quest.line != StoryQuestDefinition.LINE_MAIN and quest.line != StoryQuestDefinition.LINE_FACTION:
			continue
		for index: int in quest.steps.size():
			var step: StoryQuestDefinition.Step = quest.steps[index]
			var where: String = "%s/%s" % [quest.quest_id, step.step_id]
			_held = held_for(quest, index, [step.only_after])
			if not step.is_branch():
				var why: String = _hangs(step.condition, catalog, kept_for(quest, index, [step.only_after]), where)
				if not why.is_empty():
					problems.append("%s hangs on one who can be killed for good: %s" % [where, why])
				continue
			# A branch is stuck only when no option is left (one way closed by a killing is a choice made).
			var whys: PackedStringArray = PackedStringArray()
			for option: StoryQuestDefinition.Option in step.options:
				var why: String = _hangs(option.condition, catalog, kept_for(quest, index, [step.only_after, option.option_id]), "%s/%s" % [where, option.option_id])
				if why.is_empty():
					whys.clear()
					break
				whys.append("%s: %s" % [option.option_id, why])
			if not whys.is_empty():
				problems.append("%s hangs on one who can be killed for good: %s" % [where, "; ".join(whys)])
	_held = {}
	problems.append_array(_unjudged)
	return problems


## The marks held by the time the step at `index` of `quest` waits: those that did the earlier steps
## on its way (a plain step's marks; of a branch, the option `ways` names: the one it waits for).
static func held_for(quest: StoryQuestDefinition, index: int, ways: Array) -> Dictionary[String, bool]:
	var held: Dictionary[String, bool] = {}
	for earlier: int in range(index - 1, -1, -1):
		var step: StoryQuestDefinition.Step = quest.steps[earlier]
		if not step.only_after.is_empty() and not ways.has(step.only_after):
			continue
		if not step.is_branch():
			_held_marks(step.condition, held)
			continue
		for option: StoryQuestDefinition.Option in step.options:
			if ways.has(option.option_id):
				_held_marks(option.condition, held)
	return held


static func _held_marks(condition: JournalEntryDefinition, held: Dictionary[String, bool]) -> void:
	if condition == null:
		return
	if condition.when == JournalEntryDefinition.When.MARK:
		held[condition.key] = true
	elif condition.when == JournalEntryDefinition.When.ALL:
		for part: JournalEntryDefinition in condition.parts:
			_held_marks(part, held)


## The people kept while the step at `index` of `quest` waits: its own `keeps` and those of the
## later steps on its way — waiting for no option (`only_after` ""), or for one of `ways` (the option
## the step itself waits for; the branch's option being judged). A later step waiting for another
## option keeps nobody on this way (StoryKeeps: its keeps lapse when that option was not taken).
static func kept_for(quest: StoryQuestDefinition, index: int, ways: Array) -> Dictionary[StringName, bool]:
	var kept: Dictionary[StringName, bool] = {}
	for later: int in range(index, quest.steps.size()):
		var step: StoryQuestDefinition.Step = quest.steps[later]
		if later != index and not step.only_after.is_empty() and not ways.has(step.only_after):
			continue
		for npc_id: StringName in step.keeps:
			kept[npc_id] = true
	return kept


## Why `condition` cannot be done once someone is killed ("" when it always can). `where`: the step
## (or option) judged, named when the condition is one the check does not know.
func _hangs(condition: JournalEntryDefinition, catalog: ContentCatalog, kept: Dictionary[StringName, bool], where: String = "") -> String:
	if condition == null:
		return ""
	match condition.when:
		JournalEntryDefinition.When.ALL:
			for part: JournalEntryDefinition in condition.parts:
				var why: String = _hangs(part, catalog, kept, where)
				if not why.is_empty():
					return why
			return ""
		JournalEntryDefinition.When.ANY, JournalEntryDefinition.When.AT_LEAST:
			# ANY wants one part doable, AT_LEAST its amount. Every part is judged (an unknown one is
			# reported even when another part would do).
			var wanted: int = 1 if condition.when == JournalEntryDefinition.When.ANY else condition.amount
			var doable: int = 0
			var whys: PackedStringArray = PackedStringArray()
			for part: JournalEntryDefinition in condition.parts:
				var why: String = _hangs(part, catalog, kept, where)
				if why.is_empty():
					doable += 1
				else:
					whys.append(why)
			return "" if doable >= wanted else " / ".join(whys)
		JournalEntryDefinition.When.HEARD, JournalEntryDefinition.When.SEEN, JournalEntryDefinition.When.CHAT:
			var npc_id := StringName(condition.key)
			return "" if _sturdy(npc_id, &"", catalog, kept) else "heard %s" % npc_id
		JournalEntryDefinition.When.MARK:
			return _mark_hangs(condition.key, catalog, kept)
		JournalEntryDefinition.When.ITEM, JournalEntryDefinition.When.WEARING:
			return _item_hangs(condition.key, catalog, kept)
	if ALWAYS_DOABLE.has(condition.when):
		return ""
	var unjudged: String = "%s: a condition the check cannot judge (%s %s): teach story_reach_test it" % [where, JournalEntryDefinition.When.keys()[condition.when], condition.key]
	if not _unjudged.has(unjudged):
		_unjudged.append(unjudged)
	return "a condition the check cannot judge"


## Why the mark `mark` cannot be written once someone is killed ("" when it always can).
func _mark_hangs(mark: String, catalog: ContentCatalog, kept: Dictionary[StringName, bool]) -> String:
	if _held.has(mark):
		return ""  # an earlier step on the way was done by it
	var sources: Array = _writers.get(mark, [])
	if sources.is_empty():
		return ""  # unwritten() says so (or the code writes it)
	return _sources_hang("mark:" + mark, "「%s」 only by" % mark, sources, catalog, kept)


## Why the item `item` (an id or an alias) cannot be had once someone is killed ("" when it always can).
func _item_hangs(item: String, catalog: ContentCatalog, kept: Dictionary[StringName, bool]) -> String:
	var sources: Array = []
	for id: String in item_ids(item, catalog):
		sources.append_array(_givers.get(id, []))
	if sources.is_empty():
		return "nothing gives the item %s" % item
	return _sources_hang("item:" + item, "the item %s only from" % item, sources, catalog, kept)


## "" when one of `sources` needs nothing a killing takes away; else `label` and what each needs.
func _sources_hang(judging: String, label: String, sources: Array, catalog: ContentCatalog, kept: Dictionary[StringName, bool]) -> String:
	if _judging.has(judging):
		return "%s again (a ring)" % judging
	_judging[judging] = true
	var needs: PackedStringArray = PackedStringArray()
	for source: Source in sources:
		var fragile: String = _fragile_need(source, catalog, kept)
		if fragile.is_empty():
			needs.clear()
			break
		needs.append("%s (%s)" % [fragile, source.origin])
	_judging.erase(judging)
	return "" if needs.is_empty() else "%s %s" % [label, ", ".join(needs)]


## The item definitions `item` names: an alias or a name names every item that has it; anything else
## is an id (given under that id, or by nothing).
static func item_ids(item: String, catalog: ContentCatalog) -> Array[String]:
	var ids: Array[String] = []
	if catalog.item(StringName(item)) == null:
		for definition: ItemContentDefinition in catalog.items():
			if definition.aliases().has(item) or definition.display_name == item:
				ids.append(String(definition.item_definition_id))
	if ids.is_empty():
		ids.append(item)
	return ids


## What `source` needs that a killing can take away for good — one standing, or a mark or an item
## its rule asks for that only such a one writes or gives — or "".
func _fragile_need(source: Source, catalog: ContentCatalog, kept: Dictionary[StringName, bool]) -> String:
	if not source.carrier.is_empty():
		# Off the corpse of one who is never killed (or kept, knocked down, while the step waits): never.
		var carrier: NpcDefinition = catalog.npc(source.carrier)
		if carrier == null or kept.has(source.carrier) or carrier.dealings().is_fight_deferred() or carrier.spar_only():
			return "carried by %s, who is not killed" % source.carrier
	if not source.npc.is_empty() and not _sturdy(source.npc, &"", catalog, kept):
		return String(source.npc)
	for npc_id: StringName in source.gates:
		if npc_id != source.npc and not _sturdy(npc_id, source.zone, catalog, kept):
			return String(npc_id)
	for mark: String in source.needs_marks:
		var why: String = _mark_hangs(mark, catalog, kept)
		if not why.is_empty():
			return "it needs a mark: " + why
	for item: String in source.needs_items:
		var why: String = _item_hangs(item, catalog, kept)
		if not why.is_empty():
			return "it needs an item: " + why
	return ""


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
	# What the rule (the branch) asks of the one doing it.
	var need_marks: Array = []
	var need_items: Array = []
	for key: String in NEED_MARK_KEYS:
		need_marks.append_array(_strings(record.get(key)))
	for key: String in NEED_ITEM_KEYS:
		need_items.append_array(_strings(record.get(key)))
	# A gift rule (accept_object) wants the thing given and the giver's marks.
	if last == "accept_object":
		need_items.append_array(_strings(record.get("item")))
		need_items.append_array(_strings(record.get("giver_carries")))
		need_marks.append_array(_strings(record.get("giver_mark")))
	# An act's branch gated by marks the player holds (`mark`, `marks` beside its `steps`).
	if record.has("steps"):
		need_marks.append_array(_strings(record.get("mark")))
		need_marks.append_array(_strings(record.get("marks")))
	if not need_marks.is_empty() or not need_items.is_empty():
		here = here.with_needs(need_marks, need_items)
	var anyone := Source.new()
	anyone.origin = here.origin
	if STURDY_GIVE_PARENTS.has(last) and record.get("item") is String:
		# What an NPC carries comes off their corpse: given only by one who can be killed.
		var giver: Source = anyone
		if last == "carry" and not here.npc.is_empty():
			giver = Source.new()
			giver.origin = here.origin
			giver.carrier = here.npc
		_note(_givers, record["item"], giver)
	for key: Variant in record:
		var child: Variant = record[key]
		var name: String = str(key)
		if GIVE_KEYS.has(name):
			_note(_givers, child, here)
		elif STURDY_GIVE_KEYS.has(name):
			_note(_givers, child, anyone)
		if WRITE_KEYS.has(name):
			_note(_writers, child, here)
		elif READ_KEYS.has(name):
			_note(_readers, child, here.origin)
		elif name == "any" and last == "answers":
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
## picture's glyph). A question's answer reads its marks (ScriptedAct.Answer.is_true: the true
## answer is the one the player's marks bear out); so do a dance step (danced by one who has its
## mark) and a searched landmark (policy search: searched by one who has it).
static func _mark_role(record: Dictionary, name: String, path: Array[String], last: String) -> String:
	if not (record[name] is String or record[name] is Array):
		return ""
	if path.has("draw"):
		return ""
	if last == "answers" or path.slice(-2) == ["dance", "steps"] or record.get("policy") == "search":
		return "read"
	if name == "marks" and last == "reward":
		return "write"
	if last in ["steps", "true", "false"] and not record.has("steps"):
		return "write"
	if WRITE_PARENTS.has(last):
		return "write"
	if CONDITION_PARENTS.has(last) or record.has("steps"):
		return "read"
	return "read"


static func _strings(value: Variant) -> Array:
	if value is String:
		return [value]
	if value is Array:
		return value.filter(func(each: Variant) -> bool: return each is String)
	return []


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
