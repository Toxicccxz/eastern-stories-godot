extends RefCounted

## 势力线第一批 封山 A, the generic pieces (计划 build/plans/势力线第一批_计划.md §2; DECISIONS「具名条件」
## 「势力名册」「晋阶」「问话看门派」「势力线的选择」): named conditions (`cond`) and how they are linked,
## the 声望 page's houses (FactionDefinition), a reward's `rank`, a plain step's reward, an inquiry
## rule's `asker_family`, a branch's `weight`, and what the loaded data keeps of each.

var _count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_named_conditions()
	_test_named_condition_errors()
	_test_factions()
	_test_rank_and_step_reward()
	_test_asker_family()
	_test_weight()
	_test_loaded_data()
	return {"assertions": _count, "failures": _failures.duplicate()}


func _condition(record: Dictionary, errors: Array[String]) -> JournalEntryDefinition:
	var condition := JournalEntryDefinition.new()
	JournalEntryDefinition.read_when(ContentRecordReader.new({"when": record}, "test", errors), condition, "when")
	return condition


func _holds(condition: JournalEntryDefinition, state: CharacterState) -> bool:
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	return JournalLog.holds(condition, state, temps, held)


func _test_named_conditions() -> void:
	JournalEntryDefinition.forget_unlinked() # TEST-ONLY: nothing left of another suite
	var errors: Array[String] = []
	var named: Dictionary[String, JournalEntryDefinition] = {
		"t.two_of_three": _condition({"at_least": {"n": 2, "of": [{"mark": "a"}, {"mark": "b"}, {"cond": "t.c_or_d"}]}}, errors),
		"t.c_or_d": _condition({"any": [{"mark": "c"}, {"mark": "d"}]}, errors),
		"t.alias": _condition({"cond": "t.two_of_three"}, errors),
	}
	var direct: JournalEntryDefinition = _condition({"cond": "t.two_of_three"}, errors)
	var nested: JournalEntryDefinition = _condition({"all": [{"mark": "z"}, {"not": {"cond": "t.alias"}}]}, errors)
	_check(errors.is_empty() and direct.when == JournalEntryDefinition.When.COND and direct.key == "t.two_of_three", "read: a cond waits for its name: %s" % [errors])
	JournalEntryDefinition.link_named(named, errors)
	_check(errors.is_empty(), "linked without complaint: %s" % [errors])
	_check(direct.when == JournalEntryDefinition.When.AT_LEAST and direct.amount == 2 and direct.parts.size() == 3, "a cond becomes what it names (an at_least of three)")
	_check(direct.parts[2].when == JournalEntryDefinition.When.ANY and direct.parts[2].parts.size() == 2, "a cond inside a named condition is linked too")
	_check(named["t.alias"].when == JournalEntryDefinition.When.AT_LEAST, "a name for a name")
	var state := CharacterState.new()
	state.marks["a"] = 1
	_check(not _holds(direct, state), "one of three: not yet")
	state.marks["d"] = 1
	_check(_holds(direct, state), "a and (c or d): two of three")
	state.marks["z"] = 1
	_check(not _holds(nested, state), "z and not the named one: it holds, so no")
	state.marks.erase("d")
	_check(_holds(nested, state), "z and not the named one")
	# A count row that names its at_least reads, and counts once linked.
	var quest_errors: Array[String] = []
	var quest: StoryQuestDefinition = StoryQuestDefinition.from_record(ContentRecordReader.new({
		"id": "t.q", "title": "试", "line": "faction", "region": "某地", "summary": "试",
		"steps": [{"id": "one", "objective": "一", "done": {"mark": "never"}, "text": "一", "checklist": [{"label": "帮手", "count": true, "when": {"cond": "t.two_of_three"}}]}],
	}, "test", quest_errors))
	JournalEntryDefinition.link_named(named, quest_errors)
	_check(quest_errors.is_empty(), "a count row may name its at_least: %s" % [quest_errors])
	state.marks["b"] = 1
	var rows: Array[StoryQuestLog.Checked] = StoryQuestLog.checked(quest.steps[0], func(condition: JournalEntryDefinition) -> bool: return _holds(condition, state))
	_check(rows.size() == 1 and rows[0].have == 2 and rows[0].want == 2 and rows[0].tick == StoryQuestLog.Checked.Tick.DONE, "the row counts the named condition's parts: 2／2")


func _test_named_condition_errors() -> void:
	JournalEntryDefinition.forget_unlinked() # TEST-ONLY
	var errors: Array[String] = []
	var unknown: JournalEntryDefinition = _condition({"cond": "t.nobody"}, errors)
	var named: Dictionary[String, JournalEntryDefinition] = {}
	JournalEntryDefinition.link_named(named, errors)
	_check(errors.size() == 1 and errors[0].contains("t.nobody") and unknown.when == JournalEntryDefinition.When.COND, "a name nobody defined is reported: %s" % [errors])
	errors.clear()
	named = {
		"t.ring_a": _condition({"all": [{"mark": "a"}, {"cond": "t.ring_b"}]}, errors),
		"t.ring_b": _condition({"cond": "t.ring_a"}, errors),
	}
	JournalEntryDefinition.link_named(named, errors)
	_check(not errors.is_empty() and errors.any(func(error: String) -> bool: return error.contains("names itself")), "a ring is reported: %s" % [errors])
	errors.clear()
	named = {"t.heard": _condition({"heard": {"npc": "t.npc", "topic": "x"}}, errors)}
	JournalEntryDefinition.link_named(named, errors)
	_check(errors.size() == 1 and errors[0].contains("cannot be named"), "heard cannot be named: %s" % [errors])
	JournalEntryDefinition.forget_unlinked() # TEST-ONLY: leave nothing for the next suite


func _test_factions() -> void:
	var errors: Array[String] = []
	var faction: FactionDefinition = FactionDefinition.from_record(ContentRecordReader.new({
		"id": "t.house", "name": "某派", "layer": "sect", "place": "某地",
		"lines": [{"text": "认得你", "when": {"mark": "met"}}, {"text": "欠你一回", "when": {"mark": "owed"}}],
	}, "test", errors))
	_check(errors.is_empty() and faction.faction_id == &"t.house" and faction.layer == FactionDefinition.LAYER_SECT and faction.lines.size() == 2, "a house reads: %s" % [errors])
	var state := CharacterState.new()
	var test: Callable = func(condition: JournalEntryDefinition) -> bool: return _holds(condition, state)
	_check(faction.shown(test).is_empty(), "nothing holds: nothing to say (the house is left off the page)")
	state.marks["owed"] = 1
	_check(faction.shown(test) == ["欠你一回"], "only the sentences that hold")
	state.marks["met"] = 1
	_check(faction.shown(test) == ["认得你", "欠你一回"], "in authored order")
	_check(faction.shown(Callable()).is_empty(), "no test: nothing")
	FactionDefinition.from_record(ContentRecordReader.new({"id": "t.bad", "name": "某派", "layer": "guild", "place": "某地", "lines": [{"text": "x", "when": {"mark": "m"}}]}, "test", errors))
	_check(errors.size() == 1 and errors[0].contains("layer"), "an unknown layer is refused: %s" % [errors])
	errors.clear()
	FactionDefinition.from_record(ContentRecordReader.new({"id": "t.bad", "name": "某派", "layer": "tie", "place": "某地", "lines": [{"text": "x"}]}, "test", errors))
	_check(not errors.is_empty(), "a sentence without a `when` is refused (every sentence is about something that happened)")
	errors.clear()
	FactionDefinition.from_record(ContentRecordReader.new({"id": "t.bad", "name": "某派", "layer": "secret", "place": "某地"}, "test", errors))
	_check(not errors.is_empty(), "a house that says nothing is refused")


func _quest(record: Dictionary, errors: Array[String]) -> StoryQuestDefinition:
	return StoryQuestDefinition.from_record(ContentRecordReader.new(record, "test", errors))


func _test_rank_and_step_reward() -> void:
	var errors: Array[String] = []
	var quest: StoryQuestDefinition = _quest({
		"id": "t.line", "title": "某派", "line": "faction", "region": "某地", "summary": "试",
		"steps": [
			{"id": "one", "objective": "一", "done": {"mark": "m1"}, "text": "做了一", "reward": {"deed": "办了一件事", "marks": ["did_one"], "rank": {"family": "family.fonxan", "title": "大弟子"}}},
			{"id": "two", "objective": "二", "done": {"mark": "m2"}, "text": "做了二"},
		],
	}, errors)
	_check(errors.is_empty() and quest.steps[0].reward.rank_family == &"family.fonxan" and quest.steps[0].reward.rank_title == "大弟子" and quest.steps[1].reward.is_empty(), "a plain step's reward with a rank: %s" % [errors])
	var quests: Array[StoryQuestDefinition] = [quest]
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	# One of the family rises.
	var member := CharacterState.new()
	member.family = FamilyState.new(&"family.fonxan", 14)
	member.affiliation.has_family_rank = true
	member.affiliation.family_title = "弟子"
	member.marks["m1"] = 1
	var fresh: Array[StoryQuestLog.Fresh] = StoryQuestLog.record(member, temps, held, &"", quests)
	var step: StoryQuestLog.Fresh = fresh.filter(func(entry: StoryQuestLog.Fresh) -> bool: return entry.kind == StoryQuestLog.Kind.STEP)[0]
	_check(step.reward() == quest.steps[0].reward and step.reward().deed == "办了一件事", "the step's own reward is what it gives")
	_check(member.affiliation.family_title == "大弟子" and member.marks.get("did_one", 0) == 1, "one of the family: 大弟子, and the mark")
	_check(NpcApprenticeship.family_title("封山剑派", 14, member.affiliation.family_title) == "封山剑派第十四代大弟子", "the title as assign_apprentice() would write it now")
	# One of another family, and one of none, get the mark and no rank.
	var other := CharacterState.new()
	other.family = FamilyState.new(&"family.celestial", 5)
	other.affiliation.has_family_rank = true
	other.affiliation.family_title = "弟子"
	other.marks["m1"] = 1
	StoryQuestLog.record(other, temps, held, &"", quests)
	_check(other.affiliation.family_title == "弟子" and other.marks.get("did_one", 0) == 1, "another family: the mark, no rank")
	var nobody := CharacterState.new()
	nobody.marks["m1"] = 1
	StoryQuestLog.record(nobody, temps, held, &"", quests)
	_check(nobody.affiliation.family_title == "" and not nobody.affiliation.has_family_rank, "no family: no rank")
	member.marks["m2"] = 1
	fresh = StoryQuestLog.record(member, temps, held, &"", quests)
	_check(fresh.size() == 2 and fresh[0].reward() == null and fresh[1].kind == StoryQuestLog.Kind.DONE, "a step with no reward gives none; the quest ends")
	# What is refused.
	errors.clear()
	_quest({"id": "t.bad", "title": "试", "line": "faction", "region": "某地", "summary": "试", "steps": [
		{"id": "one", "objective": "一", "weight": "small", "reward": {"deed": "x"}, "options": [{"id": "a", "done": {"mark": "a"}, "text": "甲"}, {"id": "b", "done": {"mark": "b"}, "text": "乙"}]},
	]}, errors)
	_check(errors.size() == 1 and errors[0].contains("options carry the rewards"), "a branch's own reward is refused: %s" % [errors])
	errors.clear()
	_quest({"id": "t.bad", "title": "试", "line": "faction", "region": "某地", "summary": "试", "steps": [
		{"id": "one", "objective": "一", "done": {"mark": "m"}, "text": "一", "reward": {"milestone": true}},
	]}, errors)
	_check(errors.size() == 1 and errors[0].contains("历练"), "a step's 历练 is refused (it is the quest's): %s" % [errors])


func _test_asker_family() -> void:
	var errors: Array[String] = []
	var own: NpcInquiryRule = NpcInquiryRule.from_record(ContentRecordReader.new({"asker_family": "family.fonxan", "say": "自家的事"}, "test", errors))
	var anyone: NpcInquiryRule = NpcInquiryRule.from_record(ContentRecordReader.new({"say": "不劳费心"}, "test", errors))
	_check(errors.is_empty() and own.asker_family == &"family.fonxan" and anyone.asker_family.is_empty(), "asker_family reads: %s" % [errors])
	var marks: Dictionary[String, int] = {}
	var no_flags: Dictionary[StringName, bool] = {}
	var nothing: Array[String] = []
	_check(own.matches(marks, &"", &"", 0, no_flags, nothing, &"family.fonxan"), "one of the family is answered")
	_check(not own.matches(marks, &"", &"", 0, no_flags, nothing, &"family.celestial") and not own.matches(marks), "another family, or none, is not")
	var rules: Array[NpcInquiryRule] = [own, anyone]
	_check(NpcInquiryRule.decide(rules, marks, null, &"", &"", 0, no_flags, nothing, &"family.fonxan") == own, "decide: the family's own rule first")
	_check(NpcInquiryRule.decide(rules, marks) == anyone, "decide: a stranger falls through to the next")
	# A topic listed only to one who holds its marks (李火狮's two answers on the 门房).
	var trainer: NpcDefinition = GameContent.catalog().npc(&"snow.npc.fist_trainer")
	var nobody: Dictionary[String, int] = {}
	var asked: Dictionary[String, int] = {"李火狮说了门房": 1}
	var forgotten: Array[String] = []
	_check(NpcInquiry.topics(trainer).has("说破门房的来历") and NpcInquiry.topics(trainer, forgotten, nobody).has("门房") and not NpcInquiry.topics(trainer, forgotten, nobody).has("说破门房的来历") and NpcInquiry.topics(trainer, forgotten, asked).has("说破门房的来历"), "listed_marks: off the list until the mark is held; with no marks given, every topic")
	# A `cond` read once the catalog is built (a stage prop's look) is linked against the catalog's.
	var late: JournalEntryDefinition = WorldStoryPresence._look_when({"present": {"cond": "finale.helpers"}}, "present")
	_check(late != null and late.when == JournalEntryDefinition.When.AT_LEAST and late.parts.size() == 8, "a look's cond is linked as it is read")


func _test_weight() -> void:
	var errors: Array[String] = []
	var quest: StoryQuestDefinition = _quest({"id": "t.w", "title": "试", "line": "faction", "region": "某地", "summary": "试", "steps": [
		{"id": "s1", "objective": "一", "weight": "small", "options": [{"id": "a", "done": {"mark": "a"}, "text": "甲"}, {"id": "b", "done": {"mark": "b"}, "text": "乙"}]},
		{"id": "s2", "objective": "二", "weight": "big", "options": [{"id": "c", "done": {"mark": "c"}, "text": "丙"}, {"id": "d", "done": {"mark": "d"}, "text": "丁"}]},
		{"id": "s3", "objective": "三", "done": {"mark": "e"}, "text": "三"},
	]}, errors)
	_check(errors.is_empty() and quest.branches_of(StoryQuestDefinition.WEIGHT_SMALL) == 1 and quest.branches_of(StoryQuestDefinition.WEIGHT_BIG) == 1 and quest.branches_of("") == 0, "weights read and are counted: %s" % [errors])
	errors.clear()
	_quest({"id": "t.bad", "title": "试", "line": "faction", "region": "某地", "summary": "试", "steps": [
		{"id": "s1", "objective": "一", "weight": "huge", "options": [{"id": "a", "done": {"mark": "a"}, "text": "甲"}, {"id": "b", "done": {"mark": "b"}, "text": "乙"}]},
	]}, errors)
	_check(errors.size() == 1 and errors[0].contains("weight"), "an unknown weight is refused: %s" % [errors])
	errors.clear()
	_quest({"id": "t.bad", "title": "试", "line": "faction", "region": "某地", "summary": "试", "steps": [
		{"id": "s1", "objective": "一", "weight": "small", "done": {"mark": "m"}, "text": "一"},
	]}, errors)
	_check(errors.size() == 1 and errors[0].contains("weight"), "a plain step has no weight: %s" % [errors])


## What the loaded data keeps (the rule owner 2026-11-09 set for every 势力 line, and the roster).
func _test_loaded_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var lines: int = 0
	for quest: StoryQuestDefinition in catalog.story_quests():
		if quest.line != StoryQuestDefinition.LINE_FACTION:
			continue
		lines += 1
		var unweighed: int = quest.branches_of("")
		_check(unweighed == 0, "%s: every branch of a 势力 line says its weight" % quest.quest_id)
		_check(quest.branches_of(StoryQuestDefinition.WEIGHT_BIG) <= 1 and quest.branches_of(StoryQuestDefinition.WEIGHT_SMALL) <= 2, "%s: 1 个大分裂 + 最多 2 个小选择 (big %d, small %d)" % [quest.quest_id, quest.branches_of(StoryQuestDefinition.WEIGHT_BIG), quest.branches_of(StoryQuestDefinition.WEIGHT_SMALL)])
	_check(lines >= 1, "there is a 势力 line")
	var factions: Array[FactionDefinition] = catalog.factions()
	var sects: Array[FactionDefinition] = factions.filter(func(faction: FactionDefinition) -> bool: return faction.layer == FactionDefinition.LAYER_SECT)
	var secrets: Array[FactionDefinition] = factions.filter(func(faction: FactionDefinition) -> bool: return faction.layer == FactionDefinition.LAYER_SECRET)
	_check(factions.size() == 12 and sects.size() == 9 and secrets.size() == 2, "the roster: 剧情总纲 §4's twelve, nine 门派 and two 秘密 (%d, %d, %d)" % [factions.size(), sects.size(), secrets.size()])
	# The finale's 帮手 list has one home now and is an at_least of eight wherever it is asked (封山 B added 封山守渡口).
	var gather: StoryQuestDefinition.Step = catalog.story_quest(&"main.finale").step(&"gather")
	var count_rows: Array[StoryQuestDefinition.CheckRow] = gather.checklist.filter(func(row: StoryQuestDefinition.CheckRow) -> bool: return row.counts)
	_check(count_rows.size() == 1 and count_rows[0].condition.when == JournalEntryDefinition.When.AT_LEAST and count_rows[0].condition.amount == 3 and count_rows[0].condition.parts.size() == 8, "main.finale: 帮手 counts three of eight (finale.helpers)")
	for path: String in ["res://data/story/finale.json", "res://data/village/world.json", "res://data/native/npcs.json"]:
		var text: String = FileAccess.get_file_as_string(path)
		_check(not text.contains("关北的骑兵欠你一阵\"}, {\"mark\": \"大秦人留下了\"}, {\"not\"") and text.contains("finale.helpers"), "%s names the list, never writes it out" % path)


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
