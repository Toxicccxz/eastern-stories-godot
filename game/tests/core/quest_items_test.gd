extends RefCounted

## DECISIONS「任务物品不丢」: what the story asks the player to carry stays with them, or is
## written again. Read over the data (res://data/**/*.json, raw) and the catalog, no session.
## 1. Everything a rule or an act asks the player to carry (`asker_carries`, `asker_not_carries`,
##    `carries`, `giver_carries`), every item a story step is done by or starts on and every native
##    quest item an NPC takes as a gift: a native item there is no_drop (it cannot be dropped,
##    given to the wrong one or put away). ES2's own things (es2:) keep ES2's rules.
## 2. What a thief or a 化尸 can still take (DECISIONS「Old Pine remainder B」, the owner's to
##    weigh) is written again by whoever wrote it: the rule that gives it once the asker carries it
##    no longer, while the step that needs it is not done.
## 3. An alias those rules ask for answers to one item only, but ES2's own (AMBIGUOUS).
## 4. The rules read the carried things by their real aliases: 终章's 璃虹 knows her feather.

const DATA_ROOT: String = "res://data"
const StoryReach := preload("res://tests/core/story_reach_test.gd")
## Keys whose value is an alias the player is asked to carry (or not).
const ALIAS_KEYS: Array[String] = ["asker_carries", "asker_not_carries", "carries"]
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
	return {"assertions": _count, "failures": _failures}


func _walk(value: Variant, path: String, story: bool, parent: String) -> void:
	if value is Dictionary:
		for key: Variant in value:
			var child: Variant = value[key]
			if child is String:
				if ALIAS_KEYS.has(key) and not _aliases.has(child):
					_aliases.append(child)
				elif key == "giver_carries" or (key == "item" and (story or parent == "accept_object")):
					_ids[StringName(child)] = path
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
		# A gift an NPC takes is a quest item's only when it is one (not 银子, not a dumpling).
		if item != null and (item.quest_item or _ids[id].contains("/story/")):
			asked[id] = "named in %s" % _ids[id]
	var native: int = 0
	for id: StringName in asked:
		if not String(id).begins_with("native:"):
			continue
		native += 1
		var item: ItemContentDefinition = catalog.item(id)
		_check(item != null and item.no_drop, "%s (%s) is no_drop" % [id, asked[id]])
	_check(native >= 20, "the story's things checked: %d" % native)


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


func _said(rule: NpcInquiryRule, text: String) -> bool:
	return rule != null and rule.lines.any(func(line: NpcLine) -> bool: return line.sentence("璃虹", "").contains(text))


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("quest items: " + label)
