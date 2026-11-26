extends RefCounted

## 势力线复查 (2026-11-26; DECISIONS「势力线复查」), what the choices leave in the world and what was promised:
## the 逆灵宫 once its 余孽 are settled (nobody on its stages, the rope free, the 官兵 inside the gate, the rooms
## read as left); the 虹台's own verdict on the 北麓 the same; 玄冥子's night and 南危水's word; a family left after
## its line was walked takes its vote and its name back.

const SETTLED: String = "余孽有了去处"
const CRUSHED: String = "余孽交了官府"
const PARDONED: String = "招安了余孽"
const VERDICT: String = "虹台定了北麓"
const SOLDIERS: StringName = &"niling.yard.soldiers"
## What a player who walked every way of the 逆灵宫 carries: with these alone its people are all on their stages.
const WALKED: Array[String] = ["见过唤首", "祭坛的鬼卒倒了", "答应了做眼线", "林忌说了地牢", "被识破", "终章"]

var _count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_empty_temple()
	_test_empty_rooms()
	_test_verdict()
	_test_promises()
	_test_left_family()
	_test_owed()
	_test_celestial_after()
	return {"assertions": _count, "failures": _failures.duplicate()}


## 余孽有了去处: no spawn of the 逆灵宫's maps (nor the turn's 押车道士 and 追杀的道士) is on its stage; given to the
## 官府, two 官兵 stand where the 守门道士 stood.
func _test_empty_temple() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var checked: int = 0
	for spawn: NpcSpawnDefinition in catalog.spawns():
		var turn: bool = spawn.spawn_id in [&"native.mroad4.tribute_taoists", &"native.mroad4.niling_pursuers"]
		# One a scene summons (the 无头黑影, the 祭坛's 鬼卒) stands only while its scene plays.
		if (not String(spawn.map_id).begins_with("niling.") and not turn) or spawn.summoned:
			continue
		checked += 1
		for outcome: String in [CRUSHED, PARDONED, VERDICT]:
			var state: CharacterState = _fresh(WALKED + [SETTLED, outcome])
			state.quests["main.chapter3#started"] = 1 # TEST-ONLY
			state.quests["main.chapter3/choice/chase"] = 1 # TEST-ONLY: 第三章's own prisoners left with its choice
			var stays: bool = spawn.spawn_id == SOLDIERS and outcome == CRUSHED
			_check(_on_stage(spawn, state) == stays, "%s after %s: %s" % [spawn.spawn_id, outcome, "there" if stays else "gone"])
	_check(checked >= 20, "the 逆灵宫's spawns were looked at (%d)" % checked)
	# The 道观's own people stay its residents: until they leave, a room reset makes one who died anew
	# (the 卧底 line hangs on the 管事 and the 领诵).
	for spawn_id: StringName in [&"niling.winch.winch_taoist", &"niling.gatehouse.gatekeeper", &"niling.yard.gate_guards", &"niling.store.store_taoist", &"niling.front.chanters", &"niling.front.lead_chanter", &"niling.counting.steward"]:
		var own: NpcSpawnDefinition = catalog.spawn(spawn_id)
		_check(own != null and own.resident and own.remade_by_reset() and not own.away_for_a_while, "%s: a resident, remade by its room's reset" % spawn_id)
	var soldiers: NpcSpawnDefinition = catalog.spawn(SOLDIERS)
	_check(soldiers != null and soldiers.quantity == 2 and not _on_stage(soldiers, _fresh(WALKED)), "no 官兵 before the 余孽 are given up")
	var soldier: NpcDefinition = catalog.npc(&"native.npc.niling_soldier")
	_check(soldier != null and soldier.display_name == "官兵", "the 官兵")
	var guards: NpcSpawnDefinition = catalog.spawn(&"niling.yard.gate_guards")
	_check(guards != null and not _on_stage(guards, _fresh(WALKED + [SETTLED, CRUSHED])), "the 守门道士 are gone from where the 官兵 stand")


## The rooms that name their people, their fire or their lamp read as left: by the outcome where it shows.
func _test_empty_rooms() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var front: ZoneDefinition = catalog.zone(&"niling.front")
	_check(front.description_for(_fresh(WALKED).marks) == front.description and front.description.contains("诵经"), "before: the 前殿 chants")
	_check(front.description_for(_fresh([SETTLED, CRUSHED]).marks).contains("掀翻") and front.description_for(_fresh([SETTLED, PARDONED]).marks).contains("排得整整齐齐"), "the 前殿 after, by the outcome")
	for zone_id: StringName in [&"niling.gatehouse", &"niling.yard", &"niling.front", &"niling.alchemy", &"niling.corridor", &"niling.altar"]:
		var zone: ZoneDefinition = catalog.zone(zone_id)
		for outcome: String in [CRUSHED, PARDONED]:
			var text: String = zone.description_for(_fresh([SETTLED, outcome]).marks)
			_check(text != zone.description and not text.contains("诵经") and not text.contains("黑焰") and not text.contains("桌后坐着"), "%s after %s reads as left" % [zone_id, outcome])
	_check(catalog.zone(&"niling.gatehouse").description_for(_fresh([SETTLED, CRUSHED]).marks).contains("封条"), "the 官府's seal on the gate")


## The 盟主's word on the 北麓 (颜违's seat, the old 盟主's, the player's own answer) settles the 余孽 too: the second
## epilogue still tells whose people went up, 林忌 has nothing left to ask, the 卧底 line ends a third way.
func _test_verdict() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(&"faction.niling")
	var last: StoryQuestDefinition.Step = quest.step(&"aftermath")
	_check(last.options.size() == 3 and last.option(&"assembly") != null and last.option(&"assembly").reward.is_empty(), "the 卧底 line's last step ends a third way, with no deed")
	var state: CharacterState = _fresh(["终章", "后山的事了了", "林忌说了余孽", SETTLED, VERDICT])
	var lin: NpcTalk = catalog.npc(&"common.npc.taoist.taolord").talk()
	_check(_says(NpcInquiryRule.decide(lin.inquiry_rules("逆灵宫"), state.marks), "虹台上定了"), "林忌 of the 道观 after the verdict")
	_check(not lin.confirm_applies("剿", state.marks) and not lin.confirm_applies("招安", state.marks), "nothing left to confirm")
	_check(catalog.zone(&"niling.front").description_for(state.marks).contains("没有人跪着"), "the 前殿 emptied by neither of the player's ways")


## owner 第 2、3 问: 玄冥子's night has an ending line; 南危水 says his one sentence on the 虹台.
func _test_promises() -> void:
	var epilogues: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/epilogue.json"))
	var found: Dictionary[String, bool] = {}
	for epilogue: Dictionary in epilogues["epilogues"]:
		for card: Dictionary in epilogue["cards"]:
			for line: Dictionary in card["lines"]:
				if String(line["text"]).contains("玄冥子没有下湖"):
					found["xuan"] = epilogue["id"] == "ending" and card["id"] == "black_robe"
				if String(line["text"]).contains("南危水在虹台上说完那一句"):
					found["nan"] = epilogue["id"] == "assembly" and card["id"] == "waterfog"
	_check(found.get("xuan", false), "玄冥子's night: a line of the first epilogue's 黑衣人 card")
	_check(found.get("nan", false), "南危水 on the 虹台: a line of the second epilogue's 水烟阁 card")
	var world: String = FileAccess.get_file_as_string("res://data/waterfog/world.json")
	_check(world.contains("老松岭的那个人，替我死了") and world.find("老松岭的那个人，替我死了") < world.find('}, {"mark": "九派说过话"}, '), "南危水 says it on the day, before the count")


## owner 第 4 问: 封山 or 天邪 walked to the end, then left: the lapse's mark is set though the line is done; the
## vote goes back to what the family would have cast, the head and the 声望 page say so.
func _test_left_family() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quests: Array[StoryQuestDefinition] = catalog.story_quests()
	for row: Array in [[&"faction.fonxan", &"family.fonxan", "封山的线断了", "封山听你的", "assembly.fonxan", "跟了本宗"], [&"faction.celestial", &"family.celestial", "天邪的线断了", "天邪听你的", "assembly.celestial", "站了潘军禅"]]:
		var quest: StoryQuestDefinition = catalog.story_quest(row[0])
		_check(quest.lapses_after_done and quest.lapsed_mark == row[2], "%s: what it gave is taken back from one who leaves after its end" % row[0])
		var state: CharacterState = _fresh(["终章", row[3], row[5]])
		state.family = FamilyState.new(row[1], 14)
		state.quests[StoryQuestLog.key_started(quest)] = 1 # TEST-ONLY
		state.quests[StoryQuestLog.key_done(quest)] = 2 # TEST-ONLY: walked to its end
		var temps: Dictionary[String, int] = {}
		var held: Dictionary[StringName, bool] = {}
		StoryQuestLog.record(state, temps, held, &"", quests)
		_check(not state.marks.has(row[2]) and _holds(catalog.conditions()[row[4] + ".self"], state), "%s: a member's vote listens" % row[0])
		var test: Callable = func(condition: JournalEntryDefinition) -> bool: return JournalLog.holds(condition, state, temps, held)
		var change: StoryQuestLog.FamilyChange = StoryQuestLog.family_change(state, &"family.maoshan", quests, test)
		_check(change.takes_back.has(quest) and not change.ends.has(quest), "%s: the question before leaving names it" % row[0])
		state.family = FamilyState.new(&"family.maoshan", 5) # TEST-ONLY: joined another
		StoryQuestLog.record(state, temps, held, &"", quests)
		_check(state.marks.get(row[2], 0) == 1 and StoryQuestLog.is_done(state, quest) and not StoryQuestLog.is_lapsed(state, quest), "%s: the mark set, the line still done" % row[0])
		_check(not _holds(catalog.conditions()[row[4] + ".self"], state) and (_holds(catalog.conditions()[row[4] + ".old"], state) != _holds(catalog.conditions()[row[4] + ".yan"], state)), "%s: the vote back to the family's own" % row[0])
	var liu: NpcInquiryRule = NpcInquiryRule.decide(catalog.npc(&"common.npc.swordsman.master").talk().inquiry_rules("虹台"), _fresh(["终章", "跟了本宗", "封山听你的", "封山的线断了"]).marks)
	_check(_says(liu, "收回来") and liu.mark_asker.is_empty() and liu.marks_asker.is_empty(), "柳淳风 takes the name back and gives nothing")
	var pan: NpcInquiryRule = NpcInquiryRule.decide(catalog.npc(&"common.npc.fighter.executioner").talk().inquiry_rules("虹台"), _fresh(["终章", "站了潘军禅", "天邪听你的", "天邪的线断了"]).marks)
	_check(_says(pan, "刑堂都收回了") and pan.marks_asker.is_empty(), "潘军禅 the same")


## owner 第 6 问: what was owed is played: 安妮儿 pays a word back with a word, 淳风武馆's disciples do look to the player.
func _test_owed() -> void:
	var annie: String = FileAccess.get_file_as_string("res://data/latemoon/npcs.json")
	_check(annie.contains('"mark": "替安妮儿瞒了", "not_mark": "安妮儿还了一句"') and annie.contains("最后一个名字是我"), "安妮儿's reaction to one who covered for her, once")
	var snow: String = FileAccess.get_file_as_string("res://data/snow/npcs.json")
	_check(snow.contains('"mark": "替刘安禄瞒了", "not_mark": "弟子们问过你"') and snow.contains("要问，问他去"), "李火狮's reaction: the disciples asked")
	var pages: String = FileAccess.get_file_as_string("res://data/story/factions.json")
	_check(pages.contains("她还了你一句") and pages.contains("弟子们先看的是你"), "the 声望 page tells both")


## 复查 第 1 条: the 天邪 line reached its chair after the 虹台: no scene before the chair, nothing left to
## stand for; the split closes itself and the rank comes all the same.
func _test_celestial_after() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quests: Array[StoryQuestDefinition] = catalog.story_quests()
	var quest: StoryQuestDefinition = catalog.story_quest(&"faction.celestial")
	var state: CharacterState = _fresh(["终章", "大会散了", "潘军禅说了盟主的下落", "卫沧澜出了尚书府"])
	state.family = FamilyState.new(&"family.celestial", 3)
	state.quests[StoryQuestLog.key_started(quest)] = 1 # TEST-ONLY
	for step: StoryQuestDefinition.Step in quest.steps:
		if step.step_id == &"chair":
			break
		state.quests[StoryQuestLog.key_step(quest, step, null if step.options.is_empty() else step.options[0])] = state.quests.size() + 1 # TEST-ONLY: walked so far
	_check(not _holds(catalog.conditions()["celestial.chair"], state), "no scene before the chair once the 虹台 is over")
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	var fresh: Array[StoryQuestLog.Fresh] = StoryQuestLog.record(state, temps, held, &"", quests)
	_check(StoryQuestLog.took(state, quest, &"over") and StoryQuestLog.took(state, quest, &"late") and StoryQuestLog.is_done(state, quest), "the chair and the split close themselves")
	var ranked: bool = fresh.any(func(told: StoryQuestLog.Fresh) -> bool: return told.reward() != null and told.reward().rank_title == "执事" and told.reward().deed == "替水烟阁办完了山门、镖单和盟主下落三件事")
	_check(ranked and not state.marks.has("站了颜违") and not state.marks.has("站了潘军禅"), "the rank and the deed, and no side taken")
	var seen: CharacterState = _fresh(["终章", "大会散了", "正厅撞见了"])
	seen.family = FamilyState.new(&"family.celestial", 3)
	for npc_id: StringName in [&"waterfog.npc.elder7", &"common.npc.fighter.executioner"]:
		var talk: NpcTalk = catalog.npc(npc_id).talk()
		var none: Array[String] = []
		var rule: NpcInquiryRule = NpcInquiryRule.decide(talk.inquiry_rules("椅子"), seen.marks, null, &"", &"", 0, {}, none, seen.family.family_id)
		_check(not talk.confirm_applies("椅子", seen.marks) and _says(rule, "虹台上"), "%s: the chair is settled, nothing asked first" % npc_id)
		_check(rule != null and rule.mark_asker.is_empty(), "%s: no side written for a member after the 虹台" % npc_id)


func _says(rule: NpcInquiryRule, part: String) -> bool:
	return rule != null and rule.lines.any(func(line: NpcLine) -> bool: return line.text.contains(part))


func _on_stage(spawn: NpcSpawnDefinition, state: CharacterState) -> bool:
	return spawn != null and _holds(spawn.present, state) and not (spawn.until != null and _holds(spawn.until, state))


func _fresh(marks: Array) -> CharacterState:
	var state := CharacterState.new()
	for mark: String in marks:
		state.marks[mark] = 1 # TEST-ONLY
	return state


func _holds(condition: JournalEntryDefinition, state: CharacterState) -> bool:
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	return condition == null or JournalLog.holds(condition, state, temps, held)


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
