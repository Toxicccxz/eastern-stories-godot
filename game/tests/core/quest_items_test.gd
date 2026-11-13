extends RefCounted

## DECISIONS「任务物品不丢」: what the story asks the player to carry stays with them, or is
## written again. Read over the data (res://data/**/*.json, raw) and the catalog, no session.
## 1. Everything a rule or an act asks the player to carry or wear (`asker_carries`,
##    `asker_not_carries`, `carries`, `wears`, `giver_carries`, `wearing`, `unless_wearing`), every
##    item a condition names at any depth (a step's `done`, an act's `when`, an NPC's
##    `ignores_when`...), every item a story file names, a door's `key` and every native quest item
##    an NPC takes as a gift: a native item there is no_drop (it cannot be dropped, given to the
##    wrong one, put away or sold), or it is in REGAINED, which says how the player gets another.
##    ES2's own things (es2:) keep ES2's rules. An item named there that the catalog lacks fails.
## 2. What a thief or a 化尸 can still take (DECISIONS「Old Pine remainder B」, the owner's to
##    weigh) is written again by whoever wrote it: the rule that gives it once the asker carries it
##    no longer, while the step that needs it is not done.
## 3. An alias those rules ask for answers to one item only, but ES2's own (AMBIGUOUS).
## 4. The rules read the carried things by their real aliases: 终章's 璃虹 knows her feather.

const DATA_ROOT: String = "res://data"
const StoryReach := preload("res://tests/core/story_reach_test.gd")
## Keys whose value is an alias the player is asked to carry or wear (or not).
const ALIAS_KEYS: Array[String] = ["asker_carries", "asker_not_carries", "carries", "wears"]
## Keys whose value is an item id the player is asked to carry or wear, wherever they stand.
const ID_KEYS: Array[String] = ["giver_carries", "wearing", "unless_wearing"]
## The keys a condition stands under (JournalEntryDefinition.read_when): an `item` there is one
## the player is asked to carry.
const CONDITION_KEYS: Array[String] = ["when", "done", "starts", "lapses", "if", "final", "ignores_when",
	"unless", "dim_when", "present", "until", "any", "all", "not", "of"]
## Native things the story asks for that may still be lost, and how the player gets another: each
## is carried by someone a room reset brings back (checked below).
const REGAINED: Dictionary[StringName, String] = {
	&"native:niling/black_crown": "逆灵宫's people wear one (17 kinds of them); any one of them, killed, gives another, and a reset brings them back",
}
## ES2's own aliases that answer to more than one item: kept as ES2 has them.
const AMBIGUOUS: Dictionary[String, String] = {
	"token": "d/city/feiyuan.c present(\"token\"), d/city/npc/guard.c id(\"token\"): 出城令牌 and 晚月庄's 杀手令牌, as in ES2",
}
const FEATHER: StringName = &"native:village/lihong_feather"

## The things written again: who writes them, on which topic, the marks the asker has by then,
## and the mark after which nobody needs them any more.
class Rewritten:
	extends RefCounted
	var item: StringName
	var npc: StringName
	var topic: String
	var marks: Array[String]
	var done_mark: String

	func _init(p_item: StringName, p_npc: StringName, p_topic: String, p_marks: Array[String], p_done_mark: String) -> void:
		item = p_item
		npc = p_npc
		topic = p_topic
		marks = p_marks
		done_mark = p_done_mark


var _count: int = 0
var _failures: Array[String] = []
var _aliases: Array[String] = []
var _ids: Dictionary[StringName, String] = {}


func run_all(_tree: SceneTree) -> Dictionary[String, Variant]:
	var catalog: ContentCatalog = GameContent.catalog()
	for path: String in StoryReach._json_files(DATA_ROOT):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(data != null, "%s parses" % path)
		_walk(data, path, path.contains("/story/"), "")
	_check(_aliases.size() >= 20 and _ids.size() >= 15, "the data read: %d aliases, %d items asked for" % [_aliases.size(), _ids.size()])
	_test_protected(catalog)
	_test_one_answer(catalog)
	_test_rewritten(catalog)
	_test_feather(catalog)
	_test_letter_pointers(catalog)
	return {"assertions": _count, "failures": _failures}


func _walk(value: Variant, path: String, story: bool, parent: String) -> void:
	if value is Dictionary:
		for key: Variant in value:
			var child: Variant = value[key]
			if child is String:
				if ALIAS_KEYS.has(key):
					if not _aliases.has(child):
						_aliases.append(child)
				elif key == "item" and parent == "accept_object" and not story:
					# A gift counts only for a quest item; asked for anywhere else, it counts.
					if not _ids.has(StringName(child)):
						_ids[StringName(child)] = "%s (gift)" % path
				elif ID_KEYS.has(key) or (key == "key" and parent == "doors") or (key == "item" and (story or CONDITION_KEYS.has(parent))):
					_ids[StringName(child)] = "%s (%s)" % [path, key]
			elif child is Array and ID_KEYS.has(key):
				for id: Variant in child:
					if id is String:
						_ids[StringName(id)] = "%s (%s)" % [path, key]
			_walk(child, path, story, String(key))
	elif value is Array:
		for child: Variant in value:
			_walk(child, path, story, parent)


func _answering(catalog: ContentCatalog, alias: String) -> Array[ItemContentDefinition]:
	var found: Array[ItemContentDefinition] = []
	for item: ItemContentDefinition in catalog.items():
		# An item's master form (set("master_id")) is the same thing, held by the one who got it.
		if item.aliases().has(alias) and not String(item.item_definition_id).ends_with(ItemContentDefinition.MASTER_SUFFIX):
			found.append(item)
	return found


func _test_protected(catalog: ContentCatalog) -> void:
	var asked: Dictionary[StringName, String] = {}
	for alias: String in _aliases:
		for item: ItemContentDefinition in _answering(catalog, alias):
			asked[item.item_definition_id] = "carries '%s'" % alias
	for id: StringName in _ids:
		var item: ItemContentDefinition = catalog.item(id)
		_check(item != null, "%s, named in %s, is an item" % [id, _ids[id]])
		# A gift an NPC takes is a quest item's only when it is one (not 银子, not a dumpling).
		if item != null and (item.quest_item or not _ids[id].ends_with("(gift)")):
			asked[id] = "named in %s" % _ids[id]
	var native: int = 0
	for id: StringName in asked:
		if not String(id).begins_with("native:"):
			continue
		native += 1
		var item: ItemContentDefinition = catalog.item(id)
		if REGAINED.has(id):
			_check(item != null and not item.no_drop and _regained(catalog, id), "%s (%s): %s" % [id, asked[id], REGAINED[id]])
		else:
			_check(item != null and item.no_drop, "%s (%s) is no_drop" % [id, asked[id]])
	for id: StringName in REGAINED:
		_check(asked.has(id), "%s in REGAINED is still asked for" % id)
	# Found only by the wider reading: a step's `wearing`, a door's `key`, an act's `item` condition.
	for id: StringName in [&"native:niling/black_crown", &"native:niling/cell_key", &"native:niling/tribute_ledger"]:
		_check(asked.has(id), "%s is read as asked for" % id)
	_check(native >= 25, "the story's things checked: %d" % native)


## Someone a room reset brings back carries `id`.
func _regained(catalog: ContentCatalog, id: StringName) -> bool:
	for spawn: NpcSpawnDefinition in catalog.spawns():
		var npc: NpcDefinition = catalog.npc(spawn.npc_definition_id)
		if npc != null and spawn.remade_by_reset() and npc.loadout_entries().any(func(entry: NpcLoadoutEntry) -> bool: return entry.item_definition_id == id):
			return true
	return false


func _test_one_answer(catalog: ContentCatalog) -> void:
	for alias: String in _aliases:
		var found: Array[ItemContentDefinition] = _answering(catalog, alias)
		_check(not found.is_empty(), "some item answers to '%s'" % alias)
		if found.size() > 1:
			var names: Array[String] = []
			for item: ItemContentDefinition in found:
				names.append(String(item.item_definition_id))
			_check(AMBIGUOUS.has(alias), "'%s' answers to one item only, not %s" % [alias, names])


func _test_rewritten(catalog: ContentCatalog) -> void:
	var table: Array[Rewritten] = [
		Rewritten.new(&"native:snow/letter_to_pan", &"common.npc.swordsman.master", "水烟阁", ["查明伪墓", "柳淳风的引荐信"], "潘军禅说了鱼饵"),
		Rewritten.new(&"native:cloud/escort_note", &"cloud.npc.b_header", "失镖", ["柳淳风的引荐信", "看过镖单"], "南危水承认了"),
		Rewritten.new(&"native:choyin/magistrate_letter", &"choyin.npc.judgeman", "兵部文书", ["堂审过", "陈显祖进了大堂", "程不平给了信", "陈显祖作了证", "程不平写了信"], "信递到了"),
		Rewritten.new(&"native:choyin/magistrate_letter", &"choyin.npc.judgeman", "供词", ["堂审过", "陈显祖进了大堂", "程不平给了信", "陈显祖作了证", "程不平写了信"], "信递到了"),
		Rewritten.new(&"native:choyin/magistrate_letter", &"choyin.npc.judgeman", "供词", ["堂审过", "放走了陈显祖", "程不平给了信", "只留了文书", "程不平写了信"], "信递到了"),
		Rewritten.new(&"native:snow/letter_to_chen", &"snow.npc.post_officer", "送信", ["雪亭驿的信"], "信送到了"),
	]
	for entry: Rewritten in table:
		var npc: NpcDefinition = catalog.npc(entry.npc)
		var item: ItemContentDefinition = catalog.item(entry.item)
		_check(npc != null and item != null and item.no_drop, "%s: %s, no_drop" % [entry.npc, entry.item])
		if npc == null or item == null:
			continue
		var rules: Array[NpcInquiryRule] = npc.talk().inquiry_rules(entry.topic)
		var marks: Dictionary[String, int] = {}
		for mark: String in entry.marks:
			marks[mark] = 1
		var none: Array[String] = []
		var lost: NpcInquiryRule = NpcInquiryRule.decide(rules, marks, null, &"", &"", 0, {}, none)
		_check(lost != null and lost.gives == entry.item and lost.mark_asker.is_empty() and lost.marks_asker.is_empty(), "%s on %s, %s lost: written again, nothing marked" % [entry.npc, entry.topic, entry.item])
		var held: NpcInquiryRule = NpcInquiryRule.decide(rules, marks, null, &"", &"", 0, {}, item.aliases())
		_check(held != null and held.gives != entry.item, "%s on %s, %s in hand: not written twice" % [entry.npc, entry.topic, entry.item])
		marks[entry.done_mark] = 1
		var after: NpcInquiryRule = NpcInquiryRule.decide(rules, marks, null, &"", &"", 0, {}, none)
		_check(after == null or after.gives != entry.item, "%s on %s after %s: not written again" % [entry.npc, entry.topic, entry.done_mark])


func _test_feather(catalog: ContentCatalog) -> void:
	var feather: ItemContentDefinition = catalog.item(FEATHER)
	var lihong: NpcDefinition = catalog.npc(&"native.npc.lihong")
	_check(feather != null and feather.no_drop and lihong != null, "the feather and 璃虹")
	if feather == null or lihong == null:
		return
	var rules: Array[NpcInquiryRule] = lihong.talk().inquiry_rules("留下")
	var carried: Array[String] = feather.aliases()
	var none: Array[String] = []
	var back: Dictionary[String, int] = {"回到了湖底": 1}
	var with_it: NpcInquiryRule = NpcInquiryRule.decide(rules, back, null, &"", &"", 0, {}, carried)
	_check(with_it != null and _said(with_it, "把我的羽还给我"), "终章: 璃虹 knows the feather in hand")
	var without: NpcInquiryRule = NpcInquiryRule.decide(rules, back, null, &"", &"", 0, {}, none)
	_check(without != null and _said(without, "没有那片羽"), "终章: without it, 没有那片羽")
	var early: Dictionary[String, int] = {}
	_check(_said(NpcInquiryRule.decide(rules, early, null, &"", &"", 0, {}, carried), "那片羽在你手里"), "before the 终章: 那片羽在你手里")


## 程不平's letter lost (a thief in 绮云镇, a corpse dissolved with it): 严廷殷, the 王府's gate
## (guanbei_test knocks) and the 任务 page each send the player back to 程不平 for another.
func _test_letter_pointers(catalog: ContentCatalog) -> void:
	var general: NpcDefinition = catalog.npc(&"canyon.npc.general")
	_check(general != null, "严廷殷")
	if general != null:
		var rules: Array[NpcInquiryRule] = general.talk().inquiry_rules("信")
		var none: Array[String] = []
		var written: Dictionary[String, int] = {"程不平写了信": 1}
		var lost: NpcInquiryRule = NpcInquiryRule.decide(rules, written, null, &"", &"", 0, {}, none)
		_check(_said(lost, "回乔阴") and _said(lost, "再写一封") and lost.mark_asker.is_empty(), "严廷殷, the letter lost: back to 程不平 in 乔阴")
		var held: NpcInquiryRule = NpcInquiryRule.decide(rules, written, null, &"", &"", 0, {}, catalog.item(&"native:choyin/magistrate_letter").aliases())
		_check(held != null and held.mark_asker == "严廷殷看了信", "严廷殷, the letter in hand: he reads it")
		var never: Dictionary[String, int] = {}
		_check(_said(NpcInquiryRule.decide(rules, never, null, &"", &"", 0, {}, none), "什么信"), "严廷殷, no letter ever written: 什么信？")
		var delivered: Dictionary[String, int] = {"程不平写了信": 1, "信递到了": 1}
		_check(not _said(NpcInquiryRule.decide(rules, delivered, null, &"", &"", 0, {}, none), "再写一封"), "严廷殷, the letter delivered: no errand back")
	var quest: StoryQuestDefinition = null
	for each: StoryQuestDefinition in catalog.story_quests():
		if each.quest_id == &"main.chapter6":
			quest = each
	var rows: int = 0
	for step: StoryQuestDefinition.Step in [] if quest == null else quest.steps:
		for row: StoryQuestDefinition.CheckRow in step.checklist:
			if row.condition != null and row.condition.key == "native:choyin/magistrate_letter" and row.missing.contains("程不平"):
				rows += 1
	_check(rows == 2, "第六章's 严廷殷 and 王府 steps: the letter's row says who writes another (%d)" % rows)


func _said(rule: NpcInquiryRule, text: String) -> bool:
	return rule != null and rule.lines.any(func(line: NpcLine) -> bool: return line.sentence("璃虹", "").contains(text))


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("quest items: " + label)
