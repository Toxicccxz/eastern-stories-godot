extends RefCounted

## 势力线第三批 绝尘 A (计划 势力线第三批_计划.md §7 绝尘 A, §2 第 1、2 条, §8 第 8 行; DECISIONS「绝尘 A」「绝尘的经验门槛」
## 「八卦阵与追风剑」): the 绝尘 gate is a knob (pacing.json `exp_gates`: 20000 for the 迷阵's wind and 绝尘子's
## apprentice check; ES2's 100000 kept in their data, asked again under Es2Pacing.use_es2_exp_gates()); out of the
## 八卦阵 one is marked 走出了八卦阵 as well, which the stream's search never takes, and the 追风剑 is found once. The
## line shows for 绝尘子's own and for a 过阵的客 (one out of the 八卦阵 who asks 绝尘子「青石村」). From 第五章: the
## 妇人 at the north road, 村长's 山洞, two 鬼卒 and 阿牛 in the cave while the boy is in it, the boy led out to his
## mother (follows_player), 村长 finishing 国之将亡，必有妖孽, 绝尘子 told (大弟子 for his own), 了尘; the stub.

const MapPlaces := preload("res://tests/support/map_places.gd")
const FollowerWalk := preload("res://tests/support/follower_walk.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Es2PacingScript := preload("res://tests/support/es2_pacing.gd")
const QUEST: StringName = &"faction.juechen"
const FAMILY: StringName = &"family.juechen"
const MASTER: StringName = &"common.npc.juechen.master"
const ELDER: StringName = &"green.npc.oldman2"
const GHOUL: StringName = &"native.npc.hell_runner_tomb"
const KID: StringName = &"native.npc.green_cave_kid"
const MOTHER: StringName = &"native.npc.green_mother"
const LIAOCHEN: StringName = &"native.npc.juechen_liaochen"
const WINDSWORD: StringName = &"es2:d/green/obj/windsword"
const PATH0: StringName = &"green.path0"
const PATH0_POINT: StringName = &"green.path0.cave_return"
const HOUSE4: StringName = &"green.house4"
const HOUSE4_POINT: StringName = &"green.house4.field0_entry"
const CAVE0: StringName = &"green.cave0"
const CAVE0_POINT: StringName = &"green.cave0.cave1_return"
const CAVE1: StringName = &"green.cave1"
const CAVE1_POINT: StringName = &"green.cave1.cave0_entry"
const CAVE2: StringName = &"green.cave2"
const CAVE2_POINT: StringName = &"green.cave2.mpath0_entry"
const HALL: StringName = &"green.cavehall"
const HALL_POINT: StringName = &"green.cavehall.stoneroom_arrival"
const WATER: StringName = &"green.water"
const WATER_POINT: StringName = &"green.water.stoneroom_return"
const EIGHT7: StringName = &"green.eight7"
const EIGHT7_POINT: StringName = &"green.eight7.south_arrival"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_gate()
	_test_data()
	for test: Callable in [_test_guest, _test_disciple]:
		var session: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE if test == _test_guest else CharacterState.GENDER_MALE)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


## The knob: 20000 for the wind and 绝尘子; ES2's 100000 kept in the data and asked again at ES2's pace.
func _test_gate() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var wind: ZoneExitRuleDefinition = catalog.exit_rules_between(&"green.entrance", &"green.eight0")[0]
	var master: NpcDefinition = catalog.npc(MASTER)
	_check(catalog.pacing().exp_gate(&"juechen", 0) == 20000, "pacing.json: the 绝尘 gate is 20000")
	_check(wind.exp_gate == &"juechen" and wind.value == 20000 and wind.es2_value == 100000, "the wind: 20000, entrance.c's 100000 kept")
	_check(wind.refuses(ZoneExitRuleDefinition.Leaver.new(false, 19999), false) and not wind.refuses(ZoneExitRuleDefinition.Leaver.new(false, 20000), false), "the wind turns back anyone below 20000")
	_check(master.teaching().apprentice.requires.get(&"combat_exp", 0) == 20000 and master.teaching().apprentice.requires.get(&"spi", 0) == 24, "绝尘子 asks spi 24 and 20000 combat_exp")
	var student := CharacterState.new()
	student.attributes.spirituality = 24
	student.progression.combat_experience = 19999
	_check(not NpcApprenticeship.qualifies(student, master.teaching().apprentice), "19999: 尚缺江湖历练")
	student.progression.combat_experience = 20000
	_check(NpcApprenticeship.qualifies(student, master.teaching().apprentice), "20000: taken")
	var production: PacingDefinition = Es2PacingScript.use_es2_exp_gates()
	_check(wind.value == 100000 and master.teaching().apprentice.requires.get(&"combat_exp", 0) == 100000 and not NpcApprenticeship.qualifies(student, master.teaching().apprentice), "at ES2's gates: 100000 again")
	Es2PacingScript.restore(production)
	var es2: PacingDefinition = Es2PacingScript.use()
	_check(wind.value == 100000, "Es2Pacing.use(): ES2's own gate")
	Es2PacingScript.restore(es2)
	_check(wind.value == 20000 and master.teaching().apprentice.requires.get(&"combat_exp", 0) == 20000, "restored: the knob's")
	# Every gate the knob names is asked by something (a key nothing reads fails).
	for gate: StringName in catalog.pacing().exp_gates:
		var asked: bool = catalog.exit_rules().any(func(rule: ZoneExitRuleDefinition) -> bool: return rule.exp_gate == gate)
		for npc: NpcDefinition in catalog.npcs():
			if npc.teaching() != null and npc.teaching().apprentice != null:
				asked = asked or npc.teaching().apprentice.checks.any(func(check: NpcTeaching.RequirementCheck) -> bool: return check.exp_gate == gate)
		_check(asked, "the gate %s is asked by something" % gate)
	# And every gate the data names is one pacing.json sets (a misspelt name would quietly ask ES2's).
	var gates: Dictionary[StringName, int] = catalog.pacing().exp_gates
	for rule: ZoneExitRuleDefinition in catalog.exit_rules():
		_check(rule.exp_gate.is_empty() or gates.has(rule.exp_gate), "%s's gate %s is in pacing.json" % [rule.rule_id, rule.exp_gate])
	for npc: NpcDefinition in catalog.npcs():
		if npc.teaching() != null and npc.teaching().apprentice != null:
			for check: NpcTeaching.RequirementCheck in npc.teaching().apprentice.checks:
				_check(check.exp_gate.is_empty() or gates.has(check.exp_gate), "%s's gate %s is in pacing.json" % [npc.definition_id, check.exp_gate])


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_FACTION and quest.title == "绝尘派", "faction.juechen: a 势力 line")
	if quest == null:
		return
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids.slice(0, 6) == [&"elder", &"cave", &"saying", &"report", &"liaochen", &"xuanchen"], "绝尘 A's steps, then the stub (绝尘 B fills it): %s" % [ids])
	_check(quest.steps.slice(0, 6).all(func(step: StoryQuestDefinition.Step) -> bool: return not step.is_branch()), "no choice in 绝尘 A (the split is 绝尘 B's)")
	var report: StoryQuestDefinition.Step = quest.step(&"report")
	_check(report.reward.rank_title == "大弟子" and report.reward.rank_family == FAMILY and not report.reward.deed.is_empty(), "绝尘子 told: 大弟子 for his own, a deed")
	_check(quest.step(&"xuanchen").target.npc_ids.has(LIAOCHEN), "then 了尘 again (绝尘 B)")
	var out: PortalDefinition = catalog.portal(&"green.eight7.south")
	_check(out.set_mark == "八卦阵" and out.also_mark == "走出了八卦阵", "out of 乾 south: 八卦阵 and 走出了八卦阵")
	var water: WorldLandmarkDefinition = catalog.landmark(&"green.water.landmark.water")
	_check(water.mark == "八卦阵" and water.once_mark == "搜到了追风剑", "the stream: found once")
	for spawn_id: StringName in [&"native.cave1.ghoul", &"native.cave2.ghoul", &"native.cave2.kid", &"native.path0.mother"]:
		var spawn: NpcSpawnDefinition = catalog.spawn(spawn_id)
		_check(spawn != null and spawn.staged, "%s is on the story's stage" % spawn_id)
	_check(catalog.spawn(&"native.cave1.ghoul").cleared_mark == "洞口的鬼卒倒了" and catalog.spawn(&"native.cave2.ghoul").cleared_mark == "洞底的鬼卒倒了", "each 鬼卒 marks its own beating")
	_check(catalog.spawn(&"native.cavehall.liaochen").present == null, "了尘 lives in the hall (until 绝尘 B's 玄尘)")
	for id: StringName in [KID, MOTHER, LIAOCHEN]:
		_check(catalog.npc(id).hooks() != null and catalog.npc(id).hooks().always_kept, "%s can only be knocked down" % id)
		_check(NpcLifeBook.entry(id) != null, "%s has its life" % id)
	_check(catalog.npc(KID).hooks().follows_every_way, "阿牛 follows every way he is led")
	var juechen: NpcTalk = catalog.npc(MASTER).talk()
	var rule: NpcInquiryRule = NpcInquiryRule.decide(juechen.inquiry_rules("虹台"), {"终章": 1, "走出了八卦阵": 1})
	_check(rule != null and rule.marks_asker.has("绝尘子肯下山"), "虹台: 绝尘子 reads 走出了八卦阵")


## A woman of no family: out of the 八卦阵 (both marks); the 追风剑 once; 绝尘子's 青石村: a 过阵的客, the line; 第五章:
## the 妇人, 村长, the cave (two 鬼卒, 阿牛), the boy led home, 村长's saying, 绝尘子 (no rank), 了尘; the stub.
func _test_guest(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.progression.combat_experience = 20000 # TEST-ONLY: at the gate
	var maze: WorldMapController = await _enter(tree, session, EIGHT7, EIGHT7_POINT)
	_check(await MapPlaces.take_passage(tree, maze, &"green.eight7.south"), "south out of 乾")
	await _settle(tree)
	_check(state.marks.get("八卦阵", 0) == 1 and state.marks.get("走出了八卦阵", 0) == 1, "marked 八卦阵 and 走出了八卦阵")
	# The stream: found once; the search takes 八卦阵, never 走出了八卦阵.
	var mountain: WorldMapController = await _enter(tree, session, WATER, WATER_POINT)
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([1, 1, 1])) # TEST-ONLY: every draw finds
	_check(mountain.select_landmark(&"green.water.landmark.water"), "the water")
	mountain.traverse_selected_portal()
	_check(_said(_recent(session, 2), "追风剑") and _carried(session, WINDSWORD) != &"" and state.marks.get("搜到了追风剑", 0) == 1 and not state.marks.has("八卦阵"), "the 追风剑: found, the 八卦阵 mark taken with it")
	_check(state.marks.get("走出了八卦阵", 0) == 1, "走出了八卦阵 stays")
	state.marks["八卦阵"] = 1 # TEST-ONLY: the 迷阵 walked again
	mountain.traverse_selected_portal()
	_check(_recent(session, 1)[0] == "你在水中忙了半天，结果一无所获。" and _count_carried(session, WINDSWORD) == 1, "one 追风剑 only")
	state.marks.erase("八卦阵") # TEST-ONLY: and a search that found nothing
	_check(state.marks.get("走出了八卦阵", 0) == 1, "走出了八卦阵 is never taken")
	# 绝尘子's 青石村: a 过阵的客.
	var house: WorldMapController = await _enter(tree, session, HALL, HALL_POINT)
	var said: Array[String] = _ask(house, _first(session, HALL, MASTER), "青石村")
	_check(_said(said, "你走得出老道的阵") and _said(said, "绝尘派不问世事") and state.marks.get("过阵的客", 0) == 1, "绝尘子: a 过阵的客 (%s)" % [said])
	_check(_first(session, HALL, LIAOCHEN) != null, "了尘 in the hall")
	session.record_journal()
	_check(state.quests.has("faction.juechen#started") and _step(session) == &"elder", "her line begins: 村长")
	_check(_rows(state).any(func(label: String) -> bool: return label.contains("等主线第五章")), "before 第五章: wait")
	var home: WorldMapController = await _enter(tree, session, HOUSE4, HOUSE4_POINT)
	said = _ask(home, _first(session, HOUSE4, ELDER), "山洞")
	_check(_said(said, "绝对不可以打开") and not state.marks.has("村长说了山洞"), "before 第五章 村长 only says the door stays shut (%s)" % [said])
	var village: WorldMapController = await _enter(tree, session, PATH0, PATH0_POINT)
	_check(_first(session, PATH0, MOTHER) == null, "before 第五章 nobody calls at the north road")
	# 第五章.
	state.marks["宝衣一章"] = 1 # TEST-ONLY: 第五章
	await _enter(tree, session, HOUSE4, HOUSE4_POINT)
	village = await _enter(tree, session, PATH0, PATH0_POINT)
	_check(_first(session, PATH0, MOTHER) != null, "the 妇人 at the north road")
	var lines: Array[String] = await _scene(tree, session, village)
	_check(_said(lines, "又钻到北边那个山洞里去了") and state.marks.get("妇人喊了孩子", 0) == 1, "she calls for her two (%s)" % [lines.slice(-4)])
	_check(_first(session, CAVE2, KID) == null, "nobody in the cave before 村长's word")
	home = await _enter(tree, session, HOUSE4, HOUSE4_POINT)
	said = _ask(home, _first(session, HOUSE4, ELDER), "山洞")
	_check(_said(said, "又钻进去了") and state.marks.get("村长说了山洞", 0) == 1, "村长: the door is his; the boy went in (%s)" % [said])
	session.record_journal()
	_check(_step(session) == &"cave" and _target(session).zone_id == CAVE2, "into the cave, to the boy")
	# The cave: two 鬼卒 and the boy.
	await _enter(tree, session, CAVE0, CAVE0_POINT)
	var cave: WorldMapController = await _enter(tree, session, CAVE2, CAVE2_POINT)
	_check(_first(session, CAVE1, GHOUL) != null and _first(session, CAVE2, GHOUL) != null, "a 鬼卒 in each room of the cave")
	_check(_first(session, CAVE2, KID) != null, "阿牛 at the far end")
	_check(_rows(state).any(func(label: String) -> bool: return label.contains("洞口那个鬼卒")), "the step lists its two 鬼卒")
	_check(session.combat_encounter_coordinator().has_active_encounter(), "the 鬼卒 fall on the player")
	await _flee(tree, session) # TEST-ONLY: out of the fight
	var unbeaten: NpcInquiryRule = NpcInquiryRule.decide(GameContent.catalog().npc(KID).talk().inquiry_rules("回家"), state.marks)
	_check(unbeaten != null and unbeaten.mark_asker.is_empty() and unbeaten.lines.any(func(line: NpcLine) -> bool: return line.text.contains("有鬼")), "while they stand, he will not come")
	_check(not state.marks.has("洞口的鬼卒倒了") and not state.marks.has("洞底的鬼卒倒了"), "not beaten yet")
	for zone_id: StringName in [CAVE1, CAVE2]:
		_first(session, zone_id, GHOUL).set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY: knocked down
	WorldSpawnClearings.note(session)
	_check(state.marks.get("洞口的鬼卒倒了", 0) == 1 and state.marks.get("洞底的鬼卒倒了", 0) == 1, "both knocked down: their cleared_marks")
	await _enter(tree, session, CAVE0, CAVE0_POINT)
	cave = await _enter(tree, session, CAVE2, CAVE2_POINT)
	_check(_first(session, CAVE1, GHOUL) == null and _first(session, CAVE2, GHOUL) == null, "beaten, they are gone for good")
	var kid: NpcRuntimeState = _first(session, CAVE2, KID)
	said = _ask(cave, kid, "回家")
	_check(_said(said, "我要回家") and state.marks.get("阿牛跟着你", 0) == 1 and kid.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "阿牛 follows (%s)" % [said])
	_check(_target(session).zone_id == PATH0, "the step's target is his mother now")
	var leading: NpcInquiryRule = NpcInquiryRule.decide(GameContent.catalog().npc(ELDER).talk().inquiry_rules("山洞"), state.marks)
	_check(leading != null and leading.lines.any(func(line: NpcLine) -> bool: return line.text.contains("北边路口")), "村长 to one leading the boy: to his mother")
	_check(await _go_with(tree, session, CAVE0, KID) != null, "out of the cave, he behind: %s" % FollowerWalk.failure)
	_check(_first(session, CAVE0, KID) != null, "he came along")
	village = await _go_with(tree, session, PATH0, KID)
	_check(village != null, "down to the north road, he behind: %s" % FollowerWalk.failure)
	_check(_first(session, PATH0, KID) != null, "he came down with the player")
	lines = await _scene(tree, session, village)
	_check(_said(lines, "叫你们别去") and state.marks.get("孩子回了家", 0) == 1, "his mother (%s)" % [lines.slice(-6)])
	_check(_first(session, PATH0, KID) == null and _first(session, PATH0, MOTHER) == null, "they went home together")
	session.record_journal()
	_check(_step(session) == &"saying", "back to 村长")
	home = await _enter(tree, session, HOUSE4, HOUSE4_POINT)
	said = _ask(home, _first(session, HOUSE4, ELDER), "山洞")
	_check(_said(said, "国之将亡") and _said(said, "必有妖孽") and state.marks.get("村长说完了那句话", 0) == 1, "村长 finishes it (%s)" % [said])
	_check(_said(_ask(home, _first(session, HOUSE4, ELDER), "山洞"), "是真的出来了"), "and says it again")
	session.record_journal()
	_check(_step(session) == &"report" and _rows(state).any(func(label: String) -> bool: return label.contains("再走一回八卦阵")), "to 绝尘子; not his own: through the 八卦阵 again")
	await _enter(tree, session, CAVE0, CAVE0_POINT)
	await _enter(tree, session, CAVE2, CAVE2_POINT)
	_check(_first(session, CAVE2, KID) == null and _first(session, CAVE2, GHOUL) == null, "the cave is empty again")
	house = await _enter(tree, session, HALL, HALL_POINT)
	said = _ask(house, _first(session, HALL, MASTER), "青石村")
	_check(_said(said, "洞里有东西，老道知道") and _said(said, "阵守得住石室") and state.marks.get("绝尘子听了山洞", 0) == 1, "绝尘子: 不问世事 (%s)" % [said])
	session.record_journal()
	_check(_step(session) == &"liaochen" and state.affiliation.family_title != "大弟子", "on to 了尘; no rank for a 过阵的客")
	said = _ask(house, _first(session, HALL, LIAOCHEN), "山洞")
	_check(_said(said, "师父知道洞里有东西") and state.marks.get("了尘说了洞里的事", 0) == 1, "了尘 (%s)" % [said])
	session.record_journal()
	_check(_step(session) == &"xuanchen", "the stub: 了尘 again (绝尘 B)")
	state.marks["终章"] = 1 # TEST-ONLY: the 虹台 asked
	said = _ask(house, _first(session, HALL, MASTER), "虹台")
	_check(_said(said, "你走得过老道的八卦阵") and state.marks.get("绝尘子肯下山", 0) == 1, "绝尘子 would come down for one whose 八卦阵 mark the stream took (%s)" % [said])


## 绝尘子's own (a man, taken at the knob's 20000): the line from the 拜师, waiting for 第五章; 村长 for his own;
## 绝尘子 told: 大弟子; leaving 绝尘派 ends the line and the cave is empty.
func _test_disciple(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	var master: NpcDefinition = catalog.npc(MASTER)
	state.attributes.spirituality = 24 # TEST-ONLY
	state.progression.combat_experience = 20000 # TEST-ONLY
	var request := NpcApprenticeship.new()
	_check(request.request(state, master, catalog.family(FAMILY), 1, "兄弟") == NpcApprenticeship.Outcome.RECRUITED and state.family.family_id == FAMILY, "taken at 20000 (%s)" % [request.lines])
	state.apprenticeship.master_teacher_id = MASTER # TEST-ONLY: as the panel records it
	session.record_journal()
	_check(state.quests.has("faction.juechen#started") and _step(session) == &"elder", "绝尘子's own: the line shows")
	_check(not state.marks.has("过阵的客"), "no 过阵的客 for his own")
	var house: WorldMapController = await _enter(tree, session, HALL, HALL_POINT)
	var said: Array[String] = _ask(house, _first(session, HALL, MASTER), "青石村")
	_check(_said(said, "绝尘派不问世事") and not state.marks.has("过阵的客"), "青石村 to his own: 不问世事 (%s)" % [said])
	state.marks["宝衣一章"] = 1 # TEST-ONLY
	var home: WorldMapController = await _enter(tree, session, HOUSE4, HOUSE4_POINT)
	said = _ask(home, _first(session, HOUSE4, ELDER), "山洞")
	_check(_said(said, "又钻进去了") and state.marks.get("村长说了山洞", 0) == 1, "村长 tells his own (%s)" % [said])
	state.marks["孩子回了家"] = 1 # TEST-ONLY: the boy led home
	said = _ask(home, _first(session, HOUSE4, ELDER), "山洞")
	_check(_said(said, "必有妖孽"), "the saying")
	house = await _enter(tree, session, HALL, HALL_POINT)
	_ask(house, _first(session, HALL, MASTER), "青石村")
	session.record_journal()
	_check(state.affiliation.family_title == "大弟子" and _step(session) == &"liaochen", "绝尘子 told: 大弟子")
	state.marks.erase("孩子回了家") # TEST-ONLY: the cave as it was, to see the line lapse empty it
	state.family = FamilyState.new(&"family.latemoon", 3) # TEST-ONLY: left 绝尘派
	session.record_journal()
	_check(state.quests.has("faction.juechen#lapsed") and state.marks.get("绝尘的线断了", 0) == 1, "left 绝尘派: the line lapsed")
	await _enter(tree, session, CAVE0, CAVE0_POINT)
	await _enter(tree, session, CAVE2, CAVE2_POINT)
	_check(_first(session, CAVE2, KID) == null and _first(session, CAVE2, GHOUL) == null, "one who left: no 鬼卒, no boy")
	var lapsed: NpcInquiryRule = NpcInquiryRule.decide(catalog.npc(ELDER).talk().inquiry_rules("山洞"), {"宝衣一章": 1, "村长说了山洞": 1, "绝尘的线断了": 1})
	_check(lapsed != null and lapsed.mark_asker.is_empty() and lapsed.lines.any(func(line: NpcLine) -> bool: return line.text.contains("绝对不可以打开")), "村长 sends one who left into the cave no more")


## TEST-ONLY: flee the fight under way (story_chapter3c_test's).
func _flee(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		for info: CombatTacticalActionInfo in coordinator.action_infos():
			if info.action_id == CombatFleeTacticalPolicy.ACTION_ID:
				coordinator.submit_player_action(CombatTacticalRequest.new(StringName("flee:%d" % rounds), coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.shared_ui().dismiss_current_panel()
	for _frame: int in range(3):
		await tree.physics_frame


func _enter(tree: SceneTree, session: WorldSessionController, zone_id: StringName, point_id: StringName) -> WorldMapController:
	var map: WorldMapController = MapPlaces.enter(session, zone_id, point_id)
	await _settle(tree)
	return map


## TEST-ONLY: the player walks to `zone_id` through the doors, waiting at each for `follower_id` to come up
## (FollowerWalk: go.c follow_me(), no handoff that carries him along for the suite).
func _go_with(tree: SceneTree, session: WorldSessionController, zone_id: StringName, follower_id: StringName) -> WorldMapController:
	var map: WorldMapController = await FollowerWalk.go_with(tree, session, zone_id, follower_id)
	await _settle(tree)
	return map


## TEST-ONLY: a scene as one comes into its room, through to its end.
func _scene(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> Array[String]:
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(map.scene_running(), "a scene starts as the player comes in")
	for second: int in 60:
		if not map.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not map.scene_running(), "the scene is over")
	return _recent(session, 30)


func _rows(state: CharacterState) -> Array[String]:
	var rows: Array[String] = []
	var shown: Array[StoryQuestLog.Shown] = StoryQuestLog.shown(state, GameContent.catalog().story_quests(), StoryQuestDefinition.LINE_FACTION, func(condition: JournalEntryDefinition) -> bool: return JournalLog.holds(condition, state, {}, {}))
	for view: StoryQuestLog.Shown in shown:
		if view.quest.quest_id == QUEST:
			for checked: StoryQuestLog.Checked in view.checklist:
				rows.append(checked.row.label)
	return rows


## Where the line's current step leads the player now.
func _target(session: WorldSessionController) -> StoryQuestDefinition.Target:
	var state: CharacterState = session.player_runtime().state
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(state, GameContent.catalog().story_quest(QUEST))
	return null if step == null else step.target_for(state.marks)


func _step(session: WorldSessionController) -> StringName:
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(session.player_runtime().state, GameContent.catalog().story_quest(QUEST))
	return &"" if step == null else step.step_id


func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	var map: WorldMapController = session.active_map() as WorldMapController
	if map == null:
		return &""
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


func _count_carried(session: WorldSessionController, definition_id: StringName) -> int:
	var map: WorldMapController = session.active_map() as WorldMapController
	var found: int = 0
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			found += 1
	return found


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _recent(session: WorldSessionController, count: int = 6) -> Array[String]:
	var lines: Array[String] = session.shared_ui().log_lines()
	return lines.slice(maxi(0, lines.size() - count))


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				return npc
	return null


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree, gender: StringName) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("绝尘", gender)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	return session


func _settle(tree: SceneTree) -> void:
	for frame: int in 3:
		await tree.process_frame
		await tree.physics_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
