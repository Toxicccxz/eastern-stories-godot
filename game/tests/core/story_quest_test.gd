extends RefCounted

## 任务系统 (owner, 2026-10-29; DECISIONS「任务系统」): quests from data (steps, a branch, mutual
## exclusion, rewards), the ledger's rules (StoryQuestLog), the `zone` condition, the QUEST
## 历练 kind, the deeds (DeedLog), the route to a quest's target (WorldRoute: portals and the
## 铁索 down), what the save keeps, and 寻剑令 as loaded.

var _count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_definitions()
	_test_refused()
	_test_ledger()
	_test_branch_and_only_after()
	_test_requires_and_excludes()
	_test_tracked_and_shown()
	_test_quest_reward()
	_test_deeds()
	_test_save()
	_test_route()
	_test_prologue_data()
	return {"assertions": _count, "failures": _failures.duplicate()}


func _quest(record: Dictionary, errors: Array[String]) -> StoryQuestDefinition:
	return StoryQuestDefinition.from_record(ContentRecordReader.new(record, "test", errors))


## A quest with three steps, the middle one a branch, and a reward.
func _sample() -> StoryQuestDefinition:
	var errors: Array[String] = []
	var quest: StoryQuestDefinition = _quest({
		"id": "t.main", "title": "试", "line": "main", "region": "某地", "summary": "去做三件事。",
		"starts": {"seen": "t.npc"},
		"steps": [
			{"id": "one", "objective": "一", "done": {"mark": "m1"}, "text": "做了一", "target": {"map": "snow.inn", "zone": "snow.inn.main_floor"}},
			{"id": "two", "objective": "二", "target": {"map": "snow.outdoor", "zone": "snow.square"}, "options": [
				{"id": "left", "done": {"heard": {"npc": "t.npc", "topic": "左"}}, "text": "走了左边", "reward": {"deed": "向左", "marks": ["went_left"]}},
				{"id": "right", "done": {"mark": "m_right"}, "text": "走了右边"},
			]},
			{"id": "left_only", "objective": "左后", "only_after": "left", "done": {"mark": "m3"}, "text": "左边之后"},
			{"id": "three", "objective": "三", "done": {"zone": "canyon.canyon1"}, "text": "到了"},
		],
		"reward": {"milestone": true, "deed": "做完了", "marks": ["t_done"]},
	}, errors)
	_check(errors.is_empty(), "the sample reads: %s" % [errors])
	return quest


func _test_definitions() -> void:
	var quest: StoryQuestDefinition = _sample()
	_check(quest.quest_id == &"t.main" and quest.line == "main" and quest.starts.when == JournalEntryDefinition.When.SEEN and quest.starts.key == "t.npc", "id, line and the start condition")
	_check(quest.steps.size() == 4 and quest.steps[0].condition.when == JournalEntryDefinition.When.MARK and quest.steps[0].target.zone_id == &"snow.inn.main_floor", "steps with conditions and targets")
	_check(quest.steps[1].is_branch() and quest.steps[1].options.size() == 2 and quest.steps[1].options[0].condition.when == JournalEntryDefinition.When.HEARD and quest.steps[1].options[0].condition.topic == "左", "a branch of two options")
	_check(quest.steps[2].only_after == &"left" and quest.step_of_option(&"left") == quest.steps[1], "only_after names an earlier option")
	_check(quest.steps[3].condition.when == JournalEntryDefinition.When.ZONE and quest.steps[3].condition.key == "canyon.canyon1", "the zone condition")
	_check(quest.reward.milestone and quest.reward.deed == "做完了" and quest.reward.marks == ["t_done"], "the reward")
	var errors: Array[String] = []
	var bare: StoryQuestDefinition = _quest({"id": "t.bare", "title": "裸", "region": "某地", "summary": "一句。", "steps": [{"id": "a", "objective": "甲", "done": {"mark": "x"}, "text": "甲了"}]}, errors)
	_check(errors.is_empty() and bare.starts == null and bare.line == "main" and bare.reward.is_empty(), "no start condition: there from the beginning; main by default")


func _test_refused() -> void:
	var base: Dictionary = {"id": "t.bad", "title": "坏", "region": "某地", "summary": "一句。"}
	var cases: Array[Array] = [
		[{"steps": [{"id": "a", "objective": "甲", "done": {"mark": "x"}, "text": "甲了"}], "line": "side"}, "an unknown line"],
		[{"steps": []}, "no steps"],
		[{"steps": [{"id": "a", "objective": "甲", "text": "甲了"}]}, "a step without done or options"],
		[{"steps": [{"id": "a", "objective": "甲", "done": {"mark": "x"}}]}, "a step without text"],
		[{"steps": [{"id": "a", "objective": "甲", "options": [{"id": "o", "done": {"mark": "x"}, "text": "o"}]}]}, "a branch of one option"],
		[{"steps": [{"id": "a", "objective": "甲", "done": {"mark": "x"}, "text": "甲了", "options": [{"id": "o", "done": {"mark": "y"}, "text": "o"}, {"id": "p", "done": {"mark": "z"}, "text": "p"}]}]}, "done and options together"],
		[{"steps": [{"id": "a", "objective": "甲", "only_after": "nope", "done": {"mark": "x"}, "text": "甲了"}]}, "only_after naming no earlier option"],
		[{"steps": [{"id": "a", "objective": "甲", "done": {"mark": "x"}, "text": "甲了"}, {"id": "a", "objective": "乙", "done": {"mark": "y"}, "text": "乙了"}]}, "duplicate step ids"],
		[{"steps": [{"id": "a", "objective": "甲", "done": {"somewhere": "x"}, "text": "甲了"}]}, "an unknown condition"],
	]
	for case: Array in cases:
		var errors: Array[String] = []
		var record: Dictionary = base.duplicate()
		record.merge(case[0], true)
		_quest(record, errors)
		_check(not errors.is_empty(), "refused: %s" % case[1])
	var errors: Array[String] = []
	var chain: JournalChainDefinition = JournalChainDefinition.from_record(ContentRecordReader.new({"id": "t.c", "title": "链", "region": "某地", "line": "errand", "entries": [{"id": "a", "when": {"zone": "snow.square"}, "text": "到广场"}]}, "test", errors))
	_check(errors.is_empty() and chain.line == "errand" and chain.entries[0].when == JournalEntryDefinition.When.ZONE, "a chain's line and a zone entry read")
	JournalChainDefinition.from_record(ContentRecordReader.new({"id": "t.c", "title": "链", "region": "某地", "line": "nowhere", "entries": [{"id": "a", "when": {"mark": "m"}, "text": "甲"}]}, "test", errors))
	_check(not errors.is_empty(), "a chain's unknown line is refused")


## Steps are done in order, one condition looked at at a time; nothing is taken back.
func _test_ledger() -> void:
	var quest: StoryQuestDefinition = _sample()
	var quests: Array[StoryQuestDefinition] = [quest]
	var state := CharacterState.new()
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	_check(StoryQuestLog.record(state, temps, held, &"", quests).is_empty() and not StoryQuestLog.is_started(state, quest), "nothing seen: not begun")
	_check(StoryQuestLog.objective(state, quests) == "" and StoryQuestLog.target(state, quests) == null and StoryQuestLog.tracked(state, quests) == null, "no objective, no target")
	state.marks["m1"] = 1
	state.seen_npcs["t.npc"] = 1
	var fresh: Array[StoryQuestLog.Fresh] = StoryQuestLog.record(state, temps, held, &"", quests)
	_check(fresh.size() == 2 and fresh[0].kind == StoryQuestLog.Kind.STARTED and fresh[1].kind == StoryQuestLog.Kind.STEP and fresh[1].step.step_id == &"one", "seen: begun, and the first step that already holds is done in the same look: %s" % [state.quests])
	_check(state.quests == {"t.main#started": 1, "t.main/one": 2}, "the ledger: %s" % [state.quests])
	var told: Array[String] = ColoredLine.texts(StoryQuestLog.told_lines(fresh[0], true, state)) + ColoredLine.texts(StoryQuestLog.told_lines(fresh[1], true, state))
	_check(told == ["【任务】试：去做三件事。", "【见闻】做了一", "下一步：二"], "told: %s" % [told])
	_check(ColoredLine.texts(StoryQuestLog.told_lines(fresh[1], false, state)) == ["【见闻】做了一"], "目标提示 off: no next")
	_check(StoryQuestLog.objective(state, quests) == "二" and StoryQuestLog.target(state, quests).zone_id == &"snow.square", "the second step is the objective and the target")
	state.marks["m3"] = 1
	_check(StoryQuestLog.record(state, temps, held, &"canyon.canyon1", quests).is_empty(), "later steps are not looked at before the branch: %s" % [state.quests])
	state.marks.erase("m1")
	_check(StoryQuestLog.step_done(state, quest, quest.steps[0]), "a mark gone does not take the step back")


func _test_branch_and_only_after() -> void:
	var quest: StoryQuestDefinition = _sample()
	var quests: Array[StoryQuestDefinition] = [quest]
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	# Left: the heard option, then the left-only step, then the end.
	var state := CharacterState.new()
	state.seen_npcs["t.npc"] = 1
	state.marks["m1"] = 1
	StoryQuestLog.record(state, temps, held, &"", quests)
	_check(StoryQuestLog.heard(state, &"t.npc", "右", quests).is_empty() and StoryQuestLog.heard(state, &"other", "左", quests).is_empty(), "another topic or NPC: nothing")
	var fresh: Array[StoryQuestLog.Fresh] = StoryQuestLog.heard(state, &"t.npc", "左", quests)
	_check(fresh.size() == 1 and fresh[0].option != null and fresh[0].option.option_id == &"left" and fresh[0].text() == "走了左边" and fresh[0].reward().deed == "向左", "the left option is taken by the ask")
	_check(state.quests.has("t.main/two/left") and state.marks.get("went_left", 0) == 1 and StoryQuestLog.took(state, quest, &"left") and not StoryQuestLog.took(state, quest, &"right"), "recorded with its mark")
	_check(StoryQuestLog.objective(state, quests) == "左后", "the left-only step follows")
	state.marks["m3"] = 1
	fresh = StoryQuestLog.record(state, temps, held, &"canyon.canyon1", quests)
	_check(fresh.size() == 3 and fresh[0].step.step_id == &"left_only" and fresh[1].step.step_id == &"three" and fresh[2].kind == StoryQuestLog.Kind.DONE, "the rest done in one look, then the end: %s" % [fresh.map(func(f: StoryQuestLog.Fresh) -> int: return f.kind)])
	_check(StoryQuestLog.is_done(state, quest) and state.marks.get("t_done", 0) == 1 and fresh[2].reward().milestone and StoryQuestLog.objective(state, quests) == "", "done: the reward's marks, no objective")
	_check(ColoredLine.texts(StoryQuestLog.told_lines(fresh[2], true, state)) == ["【任务完成】试"], "told done")
	# Right: the mark option; the left-only step is skipped.
	var other := CharacterState.new()
	other.seen_npcs["t.npc"] = 1
	other.marks["m1"] = 1
	other.marks["m_right"] = 1
	other.marks["m3"] = 1
	fresh = StoryQuestLog.record(other, temps, held, &"", quests)
	_check(fresh.size() == 3 and fresh[2].option != null and fresh[2].option.option_id == &"right", "the right option by its mark")
	_check(StoryQuestLog.current_step(other, quest) == quest.steps[3] and StoryQuestLog.objective(other, quests) == "三", "the left-only step is skipped: %s" % [other.quests])
	fresh = StoryQuestLog.record(other, temps, held, &"canyon.canyon1", quests)
	_check(fresh.size() == 2 and StoryQuestLog.is_done(other, quest) and not other.quests.has("t.main/left_only"), "standing in the zone ends it; the skipped step is never written")
	_check(StoryQuestLog.record(other, temps, held, &"canyon.canyon1", quests).is_empty(), "done is done")


func _test_requires_and_excludes() -> void:
	var errors: Array[String] = []
	var first: StoryQuestDefinition = _quest({"id": "t.first", "title": "甲", "region": "某地", "summary": "一。", "steps": [{"id": "a", "objective": "甲", "done": {"mark": "a"}, "text": "甲了"}]}, errors)
	var second: StoryQuestDefinition = _quest({"id": "t.second", "title": "乙", "region": "某地", "summary": "二。", "requires": ["t.first"], "steps": [{"id": "b", "objective": "乙", "done": {"mark": "b"}, "text": "乙了"}]}, errors)
	var rival: StoryQuestDefinition = _quest({"id": "t.rival", "title": "丙", "region": "某地", "summary": "三。", "excludes": ["t.second"], "steps": [{"id": "c", "objective": "丙", "done": {"mark": "c"}, "text": "丙了"}]}, errors)
	_check(errors.is_empty(), "three quests read: %s" % [errors])
	var quests: Array[StoryQuestDefinition] = [first, second, rival]
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	var state := CharacterState.new()
	StoryQuestLog.record(state, temps, held, &"", quests)
	_check(StoryQuestLog.is_started(state, first) and not StoryQuestLog.is_started(state, second) and StoryQuestLog.is_started(state, rival), "no start condition: begun at once; the one that requires waits; the rival begins")
	_check(not StoryQuestLog.can_start(state, second, quests), "excluded by the rival begun, and its requirement not done")
	state.marks["a"] = 1
	StoryQuestLog.record(state, temps, held, &"", quests)
	_check(StoryQuestLog.is_done(state, first) and not StoryQuestLog.is_started(state, second), "the requirement done, still excluded")
	var alone: Array[StoryQuestDefinition] = [first, second]
	var other := CharacterState.new()
	other.marks["a"] = 1
	StoryQuestLog.record(other, temps, held, &"", alone)
	_check(StoryQuestLog.is_done(other, first) and StoryQuestLog.is_started(other, second), "without the rival: the second begins once the first is done")
	_check(not StoryQuestLog.can_start(other, rival, quests), "the rival cannot begin once the one it excludes has")


func _test_tracked_and_shown() -> void:
	var errors: Array[String] = []
	var side: StoryQuestDefinition = _quest({"id": "t.side", "title": "边", "line": "region", "region": "某地", "summary": "边上。", "steps": [{"id": "a", "objective": "边甲", "done": {"mark": "s"}, "text": "边了"}]}, errors)
	var main: StoryQuestDefinition = _sample()
	var quests: Array[StoryQuestDefinition] = [side, main]
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	var state := CharacterState.new()
	StoryQuestLog.record(state, temps, held, &"", quests)
	_check(StoryQuestLog.tracked(state, quests) == side and StoryQuestLog.objective(state, quests) == "边甲", "the region quest alone: tracked")
	state.seen_npcs["t.npc"] = 1
	StoryQuestLog.record(state, temps, held, &"", quests)
	_check(StoryQuestLog.tracked(state, quests) == main and StoryQuestLog.objective(state, quests) == "一", "a main-line quest begun later is tracked first")
	var shown: Array[StoryQuestLog.Shown] = StoryQuestLog.shown(state, quests)
	_check(shown.size() == 2 and shown[0].quest == main and shown[0].objective == "一" and shown[0].entries.is_empty() and not shown[0].done, "shown: the newest first, with its objective")
	_check(StoryQuestLog.shown(state, quests, "region").size() == 1 and StoryQuestLog.shown(state, quests, "errand").is_empty(), "by column")
	state.marks["s"] = 1
	state.marks["m1"] = 1
	StoryQuestLog.record(state, temps, held, &"", quests)
	shown = StoryQuestLog.shown(state, quests)
	_check(shown[0].quest == main and shown[0].entries == ["做了一"] and shown[1].done and shown[1].entries == ["边了"] and shown[1].objective == "", "entries in order; the done one says so")
	_check(StoryQuestLog.tracked(state, quests) == main, "the done one is no longer tracked")


func _test_quest_reward() -> void:
	var rules: ProgressionRules = GameContent.catalog().progression()
	_check(MilestoneRewards.KIND_NAMES[ProgressionRules.Kind.QUEST] == "quest" and ProgressionRules.KIND_KEYS["quest"] == ProgressionRules.Kind.QUEST, "the QUEST kind")
	_check(rules.reward_exp(ProgressionRules.Kind.QUEST, 0, &"main.prologue") == 15 and rules.reward_exp(ProgressionRules.Kind.QUEST, 150, &"main.prologue") == 40, "progression.json: a quest is one unit (100%)")
	var errors: Array[String] = []
	var custom: ProgressionRules = ProgressionRules.from_record(ContentRecordReader.new({"stages": [{"min_exp": 0, "unit": 100, "potential_cap": 100}], "rewards": {"quest": 50}, "quest_percent": {"t.big": 300}}, "p", errors))
	_check(errors.is_empty() and custom.reward_exp(ProgressionRules.Kind.QUEST, 0, &"t.small") == 50 and custom.reward_exp(ProgressionRules.Kind.QUEST, 0, &"t.big") == 300, "quest_percent overrides the kind's percent for one quest")
	var state := CharacterState.new()
	var grant: MilestoneRewards.Grant = MilestoneRewards.grant(state, custom, ProgressionRules.Kind.QUEST, &"t.big", 0, false)
	_check(grant != null and grant.exp_gain == 300 and grant.key == "quest/t.big" and state.milestones.has("quest/t.big"), "given once, under quest/<id>")
	_check(MilestoneRewards.grant(state, custom, ProgressionRules.Kind.QUEST, &"t.big", 0, false) == null, "not twice")
	_check(ColoredLine.texts(MilestoneRewards.lines(grant, "试"))[0].begins_with("【历练】你办成了「试」：实战经验 +300"), "its line")


func _test_deeds() -> void:
	var state := CharacterState.new()
	_check(DeedLog.record(state, "", &"snow.square", []) == null and state.deeds.is_empty(), "nothing done: nothing written")
	var deed: DeedLog.Deed = DeedLog.record(state, "问了官家", &"snow.square", [&"native.npc.song_pu", &"native.npc.feng_ce"])
	_check(deed != null and deed.seen_by == [&"native.npc.feng_ce", &"native.npc.song_pu"] and state.deeds.size() == 1, "written with its witnesses in a stable order")
	DeedLog.record(state, "到了隘口", &"canyon.canyon1", [])
	_check(DeedLog.done(state, "问了官家") and not DeedLog.done(state, "没做") and DeedLog.witnessed_by(state, &"native.npc.feng_ce").size() == 1 and DeedLog.witnessed_by(state, &"nobody").is_empty(), "done and witnessed")
	_check(DeedLog.told_line(deed, "广场", ["冯策", "宋朴"]) == "【事迹】问了官家（在广场，冯策、宋朴看见了）" and DeedLog.told_line(state.deeds[1], "黄石隘口", []) == "【事迹】到了隘口（在黄石隘口，无人看见）" and DeedLog.told_line(deed, "", []) == "【事迹】问了官家", "told")
	_check(deed.duplicate_deed().equals(deed) and deed.is_valid() and not DeedLog.Deed.new("", &"", []).is_valid(), "copies and validity")


func _test_save() -> void:
	var plain: GameSaveResult = GameSaveJsonCodec.encode(GameSaveTestFixture.substantial())
	_check(not plain.text.contains("\"quests\"") and not plain.text.contains("\"deeds\""), "nothing written while there is none (old saves read as before)")
	var root: Dictionary = JSON.parse_string(plain.text)
	root["player"]["character"]["quests"] = {"main.prologue#started": "1", "main.prologue/waiter": "2"}
	root["player"]["character"]["deeds"] = [{"did": "问了官家", "where": "snow.square", "seen_by": ["native.npc.feng_ce"]}, {"did": "无人之地"}]
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(JSON.stringify(root, "	", false))
	_check(decoded.snapshot != null, "read: %s" % decoded.detail)
	if decoded.snapshot == null:
		return
	var character: GameSaveValueTypes.CharacterStateSnapshot = decoded.snapshot.player.character
	_check(character.quests == {"main.prologue#started": 1, "main.prologue/waiter": 2} and character.deeds.size() == 2 and character.deeds[0].did == "问了官家" and character.deeds[0].where == &"snow.square" and character.deeds[0].seen_by == [&"native.npc.feng_ce"] and character.deeds[1].where.is_empty() and character.deeds[1].seen_by.is_empty(), "the ledger and the deeds read back")
	var again: GameSaveResult = GameSaveJsonCodec.encode(decoded.snapshot)
	_check(again.text.contains("\"quests\"") and again.text.contains("\"deeds\"") and not again.text.contains("\"seen_by\": []"), "written again, empty lists left out")
	var restored: CharacterState = CharacterStateSnapshotRestorer.restore(character, EquipmentState.new())
	_check(restored != null and restored.quests == character.quests and restored.deeds.size() == 2 and restored.deeds[0].equals(character.deeds[0]), "restored into the state")
	root["player"]["character"]["quests"] = {}
	_check(GameSaveJsonCodec.decode(JSON.stringify(root)).snapshot == null, "an empty ledger is never written: refused")
	root["player"]["character"]["quests"] = {"main.prologue#started": "1"}
	root["player"]["character"]["deeds"] = [{"did": ""}]
	_check(GameSaveJsonCodec.decode(JSON.stringify(root)).snapshot == null, "a deed that did nothing is refused")


## From the inn to 黄石隘口: the inn's door, the road out of town, the 铁索 down.
func _test_route() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var chain: Array[WorldRoute.Step] = WorldRoute.chain(catalog, &"snow.inn", &"canyon.pass")
	var ways: Array[String] = []
	for step: WorldRoute.Step in chain:
		ways.append(String(step.portal.portal_id) if step.portal != null else String(step.service.service_id))
	_check(ways == ["snow.inn.east", "snow.sroad4.southwest", "canyon.road.chain"], "the chain: %s" % [ways])
	_check(chain.size() == 3 and chain[0].from_map == &"snow.inn" and chain[0].to_map == &"snow.outdoor" and chain[2].service != null and chain[2].to_map == &"canyon.pass" and chain[2].zone_id() == &"canyon.road", "each step's maps; the last is the 铁索 act")
	_check(WorldRoute.next_step(catalog, &"snow.inn", &"canyon.pass").portal.portal_id == &"snow.inn.east" and WorldRoute.next_step(catalog, &"canyon.pass", &"canyon.pass") == null, "the first step; none where there already")
	var back: Array[WorldRoute.Step] = WorldRoute.chain(catalog, &"canyon.pass", &"snow.inn")
	_check(back.size() == 3 and back[2].to_map == &"snow.inn", "and back in three maps: %s" % [back.map(func(s: WorldRoute.Step) -> String: return String(s.to_map))])
	_check(WorldRoute.chain(catalog, &"snow.inn", &"no.such.map").is_empty(), "no way: empty")


## 寻剑令 as loaded (data/story/prologue.json): three steps, a branch, a 历练 and deeds.
func _test_prologue_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.prologue")
	_check(quest != null and catalog.story_quests().has(quest), "loaded")
	if quest == null:
		return
	_check(quest.title == "寻剑令" and quest.line == "main" and quest.starts.when == JournalEntryDefinition.When.SEEN and quest.starts.key == "snow.npc.waiter", "the main line, from the waiter met")
	_check(quest.steps.size() == 5 and quest.steps[0].condition.topic == "官爷" and quest.steps[1].options.size() == 2 and quest.steps[1].options[0].condition.key == "native.npc.feng_ce" and quest.steps[2].condition.when == JournalEntryDefinition.When.ZONE and quest.steps[2].target.map_id == &"canyon.pass", "店小二 → the square (官家 / 江湖人) → 黄石隘口 (then the scene and the strip: story_scene_test)")
	_check(quest.reward.milestone and not quest.reward.deed.is_empty() and not quest.steps[1].options[0].reward.deed.is_empty() and not quest.steps[1].options[1].reward.deed.is_empty(), "a 历练 at the end, a deed for each way asked and the end")
	var lines: Dictionary[String, int] = {}
	for chain: JournalChainDefinition in catalog.journal_chains():
		lines[chain.line] = int(lines.get(chain.line, 0)) + 1
	_check(lines.get("errand", 0) == 3 and lines.get("main", 0) == 0 and lines.get("region", 0) == catalog.journal_chains().size() - 3, "journal.json: the three errands (新手链, 雪亭驿的信, 官府悬赏) under 差事, the rest under 地区: %s" % [lines])
	for npc_id: StringName in [&"native.npc.feng_ce", &"native.npc.song_pu", &"native.npc.white_officer", &"native.npc.courier", &"native.npc.onlooker"]:
		_check(catalog.npc(npc_id) != null, "the square's %s is defined" % npc_id)
	_check(catalog.npc(&"snow.npc.waiter").talk().inquiry_topics().has("官爷"), "店小二 answers 官爷")


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
