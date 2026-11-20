extends RefCounted

## 势力线第三批 步玄 A (计划 势力线第三批_计划.md §5 步玄 A, §2 第 3 条; DECISIONS「步玄 A」「打着念」「目标跟着人走」): the
## line shows for 骆云舟's own and for a 桃林的客 (one who walked out of the 桃林 and asked him 「风泉」). The 问剑: he plants
## the 风泉之剑 on the 曼雩台, and at night the 剑灵 stands by the stone — a spar in which it says sword_soul.c's four lines,
## each stronger, and its fourth (剑神如意) wins the bout; struck before it, it owns you (大弟子 for 步玄's own); its four
## lines said, it is spent until 微曦 and back the next night. Then, once 第九章 began, the 家书 to the elder brother
## 骆建章 in the 尚书府's 客厅 (at the 相国府 once 庾子建 is in prison), and the three lines of the 兵部抄本 in 骆家's hand
## (asked of 骆建章 or of 韦执中, the copy in hand); then `home` points back at 骆云舟 (步玄 B's first step).

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"faction.buxuan"
const LUO: StringName = &"common.npc.scholar.master"
const SOUL: StringName = &"native.npc.sword_soul_spar"
const BROTHER: StringName = &"native.npc.luo_jianzhang"
const WEI: StringName = &"native.npc.wei_zhizhong"
const GARDENER: StringName = &"city.npc.shangshu.gardener"
const LETTER: StringName = &"native:choyin/luo_letter"
const COPY: StringName = &"native:imperial/war_ministry_copy"
const ENTRANCE: StringName = &"choyin.entrance"
const ENTRANCE_POINT: StringName = &"choyin.entrance.grove_return"
const KETING: StringName = &"city.shangshu.keting"
const YARD: StringName = &"city.shangshu.yuan"
const YARD_POINT: StringName = &"city.shangshu.yuan.gate_entry"
const HALL: StringName = &"city.xiangguo_hall"
const XIANGGUO_POINT: StringName = &"city.xiangguo_yard.gate_arrival"
const NIGHT_SECONDS: int = 19 * 3600
const NOON_SECONDS: int = 10 * 3600

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_chant_unit()
	for test: Callable in [_test_stranger, _test_guest, _test_disciple, _test_prison, _test_busy_rounds]:
		var session: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE if test == _test_guest else CharacterState.GENDER_MALE)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_FACTION and quest.title == "步玄派", "faction.buxuan: a 势力 line")
	if quest == null:
		return
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids.slice(0, 5) == [&"sword", &"letter", &"brother", &"copy", &"home"], "步玄 A's steps, then 步玄 B's: %s" % [ids])
	_check(quest.steps.slice(0, 5).all(func(step: StoryQuestDefinition.Step) -> bool: return not step.is_branch()), "no choice in 步玄 A: the split is 步玄 B's")
	var sword: StoryQuestDefinition.Step = quest.step(&"sword")
	_check(sword.reward.rank_title == "大弟子" and sword.reward.rank_family == &"family.buxuan" and not sword.reward.deed.is_empty(), "the 问剑: 大弟子 for 步玄's own, a deed")
	for step_id: StringName in [&"brother", &"copy"]:
		var step: StoryQuestDefinition.Step = quest.step(step_id)
		_check(step.target.map_id == &"city.shangshu" and step.target.zone_id == KETING and step.target_after_mark == "庾子建下狱" and step.target_after.map_id == &"city.xiangguo" and step.target_after.zone_id == HALL, "%s: the 客厅, the 相国府 once 庾子建 is in prison" % step_id)
		_check(step.target_for({}) == step.target and step.target_for({"庾子建下狱": 1}) == step.target_after, "%s: the target follows him" % step_id)
	_check(quest.step(&"brother").objective.contains("门房") and quest.step(&"brother").objective.contains("韦相国"), "the 尚书府's gate and 韦执中's note are said")
	_check(quest.step(&"home").target.npc_ids.has(LUO), "then back to 骆云舟 (步玄 B's first step)")
	var letter: ItemContentDefinition = catalog.item(LETTER)
	_check(letter != null and letter.quest_item and letter.no_drop and letter.give_to.has(BROTHER), "the 家书: a quest item, given to 骆建章")
	var soul: NpcDefinition = catalog.npc(SOUL)
	var hooks: NpcHooks = soul.hooks()
	_check(hooks != null and hooks.has_fight_chant() and hooks.fight_chant_stages.size() == 4 and hooks.spar_won_mark == "问剑过了" and hooks.always_kept, "the 剑灵: four lines in a fight, the 问剑 won, only knocked down")
	if hooks != null and hooks.fight_chant_stages.size() == 4:
		var says: Array = hooks.fight_chant_stages.map(func(stage: NpcHooks.FightStage) -> String: return stage.say)
		_check(says == ["剑气指天 ...", "剑心内敛 ...", "剑芒游光 ...", "剑神如意！"], "sword_soul.c's four lines: %s" % [says])
		var last: NpcHooks.FightStage = hooks.fight_chant_stages[3]
		_check(last.ends_spar and last.mark == "剑灵回了剑" and last.mark_lapses_at == &"dawn", "the fourth wins the bout and spends it until 微曦")
		_check(hooks.fight_chant_stages.slice(0, 3).all(func(stage: NpcHooks.FightStage) -> bool: return not stage.ends_spar and stage.applies.get(&"defense", 0) > 0), "each of the first three makes it stronger")
	_check(catalog.marks_lapsing().get("剑灵回了剑") == &"dawn", "the catalog knows which marks lapse")
	var luo: NpcDefinition = catalog.npc(LUO)
	_check(luo.teaching().apprentice.unmarks.has("桃林的客"), "one who kneels to him is a guest no more (leaving 步玄 ends the line)")
	_check(luo.talk().listed_for("风泉", {}) and not luo.talk().listed_for("问剑", {}) and luo.talk().listed_for("问剑", {"骆云舟说了风泉": 1}), "风泉 always listed; 问剑 once he told of it")
	var gardener: NpcDefinition = catalog.npc(GARDENER)
	_check(gardener.talk().listed_for("骆建章", {"骆云舟托了家书": 1}) and not gardener.talk().listed_for("骆建章", {}), "the 花匠's 骆建章 once the 家书 is in hand")
	var told: NpcInquiryRule = NpcInquiryRule.decide(gardener.talk().inquiry_rules("师兄"), {"林忌说了师弟": 1})
	_check(told != null and told.lines.any(func(line: NpcLine) -> bool: return line.text.contains("客厅里写字的那位")), "the 花匠's years: the man who writes in the 客厅")
	var spawn: NpcSpawnDefinition = catalog.spawn(&"native.entrance.sword_soul_spar")
	_check(spawn != null and spawn.staged and spawn.npc_definition_id == SOUL, "the 剑灵's place on the 曼雩台")


## The fight chant on its own (CombatNpcChat): a line a beat (`every` 1), each line's applies, the fourth's mark and
## ends_spar; a second fight drops what the first one's lines added.
func _test_chant_unit() -> void:
	var state := CharacterState.new(
		CharacterBaseAttributes.new(0, 0, 0, 0, 0, 0, 30),
		CharacterResourceState.new(200, 200, 200), CharacterResourceState.new(200, 200, 200), CharacterResourceState.new(200, 200, 200),
	)
	var npc := NpcRuntimeState.new(&"soul", GameContent.catalog().npc(SOUL), &"", &"", state)
	var binding := CombatSliceCharacterBinding.new(&"soul", npc.character_state, CombatRelationshipState.new(&"soul"), ActionBusyState.new(), ArmorState.new(), CombatSliceContentProfile.new(), &"here")
	var lines: Array[String] = []
	var marks: Array[String] = []
	var ends: Array[bool] = []
	var chat := CombatNpcChat.new(func(id: StringName) -> NpcRuntimeState: return npc if id == &"soul" else null)
	var random := ScriptedCombatRandomSource.new([])
	for beat: int in 10:
		var said: CombatNpcChatResult = chat.beat(binding, [], [], random, null)
		if said == null:
			continue
		lines.append(said.lines()[0].template)
		marks.append(said.chant_mark())
		ends.append(said.ends_spar())
	_check(lines.size() == 4 and lines[0].contains("剑气指天") and lines[3].contains("剑神如意"), "four lines, one a beat: %s" % [lines])
	_check(marks == ["", "", "", "剑灵回了剑"] and ends == [false, false, false, true], "only the fourth marks and ends the spar")
	var defense: int = npc.character_state.timed_applies.value(&"defense")
	_check(defense == 10 + 15 + 20 + 60, "its defense grew line by line: %d" % defense)
	var again := CombatNpcChat.new(func(id: StringName) -> NpcRuntimeState: return npc if id == &"soul" else null)
	again.beat(binding, [], [], random, null)
	_check(npc.character_state.timed_applies.value(&"defense") == 10, "a fight's first line drops what is left of an earlier one's")
	_check(npc.character_state.timed_applies.stop_prefixed(CombatNpcChat.FIGHT_CHANT_PREFIX) == 1 and npc.character_state.timed_applies.value(&"defense") == 0, "a fight chant's applies end together")


## A man of no family: 风泉 says go to the 桃林; with 骆家's card he hears 桃林走一趟; no line.
func _test_stranger(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var map: WorldMapController = await _entrance(tree, session)
	var luo: NpcRuntimeState = _first(session, ENTRANCE, LUO)
	_check(_said(_ask(map, luo, "风泉"), "先走一趟东边的桃林") and not state.marks.has("桃林的客"), "a stranger: the 桃林 first")
	state.marks["骆云舟给了名帖"] = 1 # TEST-ONLY: 第九章's card
	_check(_said(_ask(map, luo, "风泉"), "桃林走一趟，咱们说话"), "one with 骆家's card: 桃林走一趟")
	_check(_said(_ask(map, luo, "骆家"), "我是二小子") and not state.marks.has("骆云舟托了家书"), "骆家: only that he is the second son")
	session.record_journal()
	_check(not state.quests.has("faction.buxuan#started"), "no line")


## A woman of no family who walked out of the 桃林: a 桃林的客; the 问剑 (failed once by night, spent until 微曦, passed the
## next night: no rank), the 家书 once 第九章 began, 骆建章 in the 客厅, the 抄本 in his hand, the stub.
func _test_guest(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	state.marks["桃林"] = 1 # TEST-ONLY: out of the 桃林
	session.day_clock().set_day_seconds(NOON_SECONDS)
	var map: WorldMapController = await _entrance(tree, session)
	var luo: NpcRuntimeState = _first(session, ENTRANCE, LUO)
	var said: Array[String] = _ask(map, luo, "风泉")
	_check(_said(said, "桃林的客") and _said(said, "见过剑灵的人") and state.marks.get("桃林的客", 0) == 1 and state.marks.get("骆云舟说了风泉", 0) == 1, "风泉: a 桃林的客 (%s)" % [said])
	session.record_journal()
	_check(state.quests.has("faction.buxuan#started") and _step(session) == &"sword", "her line begins at the 问剑")
	_check(_said(_ask(map, luo, "问剑"), "剑神如意") and state.marks.get("骆云舟插了剑", 0) == 1, "问剑: the sword in the stone")
	_check(_first(session, ENTRANCE, SOUL) == null, "by day no 剑灵")
	session.day_clock().set_day_seconds(NIGHT_SECONDS)
	_check(_said(_ask(map, luo, "问剑"), "天黑以后它就出来"), "asked again at night")
	var soul: NpcRuntimeState = _first(session, ENTRANCE, SOUL)
	_check(soul != null, "at night the 剑灵 stands by the stone")
	if soul == null:
		return
	# TEST-ONLY: she can neither strike it nor be struck: the four lines run out.
	state.applies["attack"] = -2000
	state.applies["defense"] = 2000
	_check(map.select_npc(soul.character_id) and map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "she spars with it")
	var fight: Array[String] = _run(session)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(not coordinator.has_active_encounter() and coordinator.last_completion().terminal_result.kind == CombatEncounterResultKind.Value.SPAR_CONCLUDED, "the spar ends with its fourth line")
	_check(_said(fight, "剑气指天") and _said(fight, "剑芒游光") and _said(fight, "剑神如意") and _said(fight, "收剑而立"), "its four lines in the fight: %s" % [fight])
	_check(state.marks.get("剑灵回了剑", 0) == 1 and not state.marks.has("问剑过了"), "spent, not passed")
	_check(soul.character_state.timed_applies.value(&"defense") == 0 and soul.character_state.timed_applies.value(&"attack") == 0, "its lines' strength ended with the fight")
	_check(session.player_runtime().life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "only a spar: she stands")
	_check(not map.spar_consent(soul).accepted, "tonight it fights no more")
	_check(_said(_ask(map, luo, "问剑"), "明晚天黑了再来") and _first(session, ENTRANCE, SOUL) == null, "骆云舟: tomorrow night; the 剑灵 back in the sword")
	session.record_journal()
	var shown: Array[StoryQuestLog.Shown] = StoryQuestLog.shown(state, catalog.story_quests(), StoryQuestDefinition.LINE_FACTION, func(condition: JournalEntryDefinition) -> bool: return JournalLog.holds(condition, state, {}, {}))
	var rows: Array[String] = []
	for view: StoryQuestLog.Shown in shown:
		if view.quest.quest_id == QUEST:
			for checked: StoryQuestLog.Checked in view.checklist:
				rows.append(checked.row.label)
	_check(rows.any(func(label: String) -> bool: return label.contains("明晚天黑再来")), "the 任务 page says tomorrow night: %s" % [rows])
	_check(session.wait_until_phase([&"dawn"]) and not state.marks.has("剑灵回了剑"), "at 微曦 the try is new")
	state.marks["剑灵回了剑"] = 1 # TEST-ONLY: spent again; the clock walks into 微曦 (a phase turn, not a skip)
	session.day_clock().set_day_seconds(DayClock.DAY_SECONDS - 1)
	TestDay.use()
	session.advance_npc_heartbeat(0.2)
	TestDay.restore()
	_check(session.day_phase_id() == &"dawn" and not state.marks.has("剑灵回了剑"), "walked into 微曦: it lapses too")
	session.day_clock().set_day_seconds(NIGHT_SECONDS)
	_ask(map, luo, "问剑")
	soul = _first(session, ENTRANCE, SOUL)
	_check(soul != null, "the next night it is there again")
	if soul == null:
		return
	state.applies["attack"] = 2000 # TEST-ONLY: she strikes it before its lines run out
	state.applies["defense"] = 2000
	_check(map.select_npc(soul.character_id) and map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "she spars again")
	_run(session)
	state.applies.erase("attack")
	state.applies.erase("defense")
	_check(state.marks.get("问剑过了", 0) == 1, "struck before 剑神如意: the 问剑 is passed")
	session.record_journal()
	_check(_step(session) == &"letter" and state.affiliation.family_title != "大弟子", "on to the 家书; no rank for a guest")
	_check(_said(_ask(map, luo, "问剑"), "步玄认你"), "骆云舟: 步玄认你")
	_check(_said(_ask(map, luo, "骆家"), "等你进了京") and not state.marks.has("骆云舟托了家书"), "before 第九章: later")
	state.marks["湖底一章"] = 1 # TEST-ONLY: 第九章 began
	said = _ask(map, luo, "骆家")
	_check(_said(said, "骆建章") and _said(said, "十年没说过一句话") and state.marks.get("骆云舟托了家书", 0) == 1 and _carried(session, LETTER) != &"", "骆家: the 家书 (%s)" % [said])
	session.record_journal()
	_check(_step(session) == &"brother" and _target(session).zone_id == KETING, "on to the 客厅")
	# The 尚书府's 客厅 (TEST-ONLY: the 门房 paid).
	state.marks["尚书"] = 1
	var house: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	_check(house != null and house.place_player(KETING, MapPlaces.zone_spot(house, KETING)), "TEST-ONLY: in the 客厅")
	var brother: NpcRuntimeState = _first(session, KETING, BROTHER)
	_check(brother != null, "骆建章 writes in the 客厅")
	if brother == null:
		return
	_check(_said(_ask(house, brother, "骆云舟"), "十年没见了"), "骆云舟? his brother")
	_check(house.select_npc(brother.character_id), "TEST-ONLY: 骆建章 chosen")
	var given: ItemHandlingResult = house.give_to_selected(_carried(session, LETTER))
	_check(given != null and given.done() and state.marks.get("骆建章读了家书", 0) == 1 and _carried(session, LETTER) == &"", "the 家书 to 骆建章 (%s)" % [_recent(session)])
	_check(given != null and _said(given.lines, "最后一笔甩出格子"), "he reads it: 最后一笔甩出格子")
	session.record_journal()
	_check(_step(session) == &"copy", "on to the 抄本")
	_check(_said(_ask(house, brother, "抄本"), "拿来我看看") and not state.marks.has("骆建章说了抄本"), "抄本 without the copy: show me")
	house.give_new_item_to_player(COPY) # TEST-ONLY: 御书房's 樟木匣 opened
	said = _ask(house, brother, "抄本")
	_check(_said(said, "是我的字") and _said(said, "征民夫，设关卡，拿人") and state.marks.get("骆建章说了抄本", 0) == 1, "with the copy: his hand, the three lines (%s)" % [said])
	session.record_journal()
	_check(_step(session) == &"home" and state.quests.has("faction.buxuan/copy"), "the stub: back to 骆云舟")


## Owner 2026-11-19 (DECISIONS「打着念」): the four lines count rounds, a round it is busy (失衡) included:
## held busy every round, it still says its fourth line and wins the spar.
func _test_busy_rounds(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.marks["桃林"] = 1 # TEST-ONLY: out of the 桃林
	session.day_clock().set_day_seconds(NIGHT_SECONDS)
	var map: WorldMapController = await _entrance(tree, session)
	var luo: NpcRuntimeState = _first(session, ENTRANCE, LUO)
	_ask(map, luo, "风泉")
	_ask(map, luo, "问剑")
	var soul: NpcRuntimeState = _first(session, ENTRANCE, SOUL)
	_check(soul != null, "the 剑灵 by the stone")
	if soul == null:
		return
	state.applies["attack"] = -2000 # TEST-ONLY: neither side lands a blow
	state.applies["defense"] = 2000
	_check(map.select_npc(soul.character_id) and map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the spar")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var said: Array[String] = []
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 40:
		soul.busy.start_busy(5) # TEST-ONLY: reeling every round, as a heavy blow leaves it
		for event: CombatSchedulerEvent in coordinator.advance_scheduler(1.0).events():
			if event.chat != null:
				for line: VisionLine in event.chat.lines():
					said.append(line.template)
		rounds += 1
	state.applies.erase("attack")
	state.applies.erase("defense")
	_check(not coordinator.has_active_encounter() and rounds <= 8, "busy every round, the spar still ends with its fourth line (%d rounds)" % rounds)
	_check(_said(said, "剑气指天") and _said(said, "剑神如意") and state.marks.get("剑灵回了剑", 0) == 1, "its four lines though it never struck: %s" % [said])


## 骆云舟's own (a man): the line shows as he kneels; 风泉 tells of the 剑灵 (no 桃林的客); the 问剑 passed is 大弟子.
func _test_disciple(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	_join(session)
	session.record_journal()
	_check(state.quests.has("faction.buxuan#started"), "步玄's own: the line shows")
	session.day_clock().set_day_seconds(NIGHT_SECONDS)
	var map: WorldMapController = await _entrance(tree, session)
	var luo: NpcRuntimeState = _first(session, ENTRANCE, LUO)
	_check(_said(_ask(map, luo, "风泉"), "见过剑灵的人") and state.marks.get("骆云舟说了风泉", 0) == 1 and not state.marks.has("桃林的客"), "风泉 for his own")
	_ask(map, luo, "问剑")
	var soul: NpcRuntimeState = _first(session, ENTRANCE, SOUL)
	_check(soul != null, "the 剑灵 at night")
	if soul == null:
		return
	state.applies["attack"] = 2000 # TEST-ONLY
	state.applies["defense"] = 2000
	_check(map.select_npc(soul.character_id) and map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "he spars with it")
	_run(session)
	state.applies.erase("attack")
	state.applies.erase("defense")
	session.record_journal()
	_check(state.marks.get("问剑过了", 0) == 1 and state.affiliation.family_title == "大弟子", "passed: 大弟子")
	state.family = FamilyState.new(&"family.fonxan", 14) # TEST-ONLY: he left for another family
	session.record_journal()
	_check(state.marks.get("步玄的线断了", 0) == 1, "another family's: the line ends")
	_check(_said(_ask(map, luo, "风泉"), "不劳你了"), "骆云舟 says no more")


## 庾子建 in prison: 骆建章 at the 相国府, not in the 尚书府; 韦执中's 骆建章, and his 抄本的字 with the copy calls the
## brother out (both marks at once). And 韦执中's note to the 门房 while 庾子建 is in office (a guest of the 相国).
func _test_prison(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	for mark: String in ["桃林", "桃林的客", "骆云舟说了风泉", "骆云舟插了剑", "问剑过了", "湖底一章", "骆云舟托了家书", "相国见了名帖", "相国府开了门"]:
		state.marks[mark] = 1 # TEST-ONLY: 问剑 passed, the 家书 in hand, the 相国 met
	var wei_rule: NpcInquiryRule = NpcInquiryRule.decide(catalog.npc(WEI).talk().inquiry_rules("骆建章"), state.marks)
	_check(wei_rule != null and wei_rule.marks_asker.has("尚书") and wei_rule.marks_asker.has("相国写了条子"), "庾子建 in office: 韦执中 writes a note for the 门房")
	var read: Dictionary[String, int] = state.marks.duplicate()
	read["骆建章读了家书"] = 1
	wei_rule = NpcInquiryRule.decide(catalog.npc(WEI).talk().inquiry_rules("骆建章"), read)
	_check(wei_rule != null and wei_rule.marks_asker.has("尚书"), "the 家书 read, the 抄本 still to come: another note")
	var paid: JournalEntryDefinition = null
	for chain: JournalChainDefinition in catalog.journal_chains():
		if chain.chain_id == &"city.shangshu":
			for entry: JournalEntryDefinition in chain.entries:
				if entry.entry_id == &"porter":
					paid = entry
	_check(paid != null and JournalLog.holds(paid, _fresh({"尚书": 1}), {}, {}) and not JournalLog.holds(paid, _fresh({"尚书": 1, "相国写了条子": 1}), {}, {}), "the 门房's gold is not written for one who came with the note")
	state.marks["庾子建下狱"] = 1 # TEST-ONLY: 揭发
	var xiangguo: WorldMapController = MapPlaces.enter(session, &"city.xiangguo_yard", XIANGGUO_POINT)
	await _settle(tree)
	xiangguo.give_new_item_to_player(LETTER) # TEST-ONLY: 骆云舟's letter
	_check(xiangguo.place_player(HALL, MapPlaces.zone_spot(xiangguo, HALL)), "TEST-ONLY: in the 相国府's hall")
	var brother: NpcRuntimeState = _first(session, HALL, BROTHER)
	_check(brother != null, "骆建章 at the 相国府")
	_check(_first(session, KETING, BROTHER) == null, "not in the 尚书府")
	session.record_journal()
	var target: StoryQuestDefinition.Target = _target(session)
	_check(target != null and target.zone_id == HALL, "the step leads to the 相国府")
	var wei: NpcRuntimeState = _first(session, HALL, WEI)
	_check(_said(_ask(xiangguo, wei, "骆建章"), "建章在老夫这里"), "韦执中: he is here")
	if brother == null or wei == null:
		return
	_check(xiangguo.select_npc(brother.character_id) and xiangguo.give_to_selected(_carried(session, LETTER)).done() and state.marks.get("骆建章读了家书", 0) == 1, "the 家书 to him at the 相国府")
	xiangguo.give_new_item_to_player(COPY) # TEST-ONLY
	var said: Array[String] = _ask(xiangguo, wei, "抄本的字")
	_check(_said(said, "是骆家的字") and _said(said, "我落的笔") and state.marks.get("韦执中认了骆家的字", 0) == 1 and state.marks.get("骆建章说了抄本", 0) == 1, "韦执中 knows the hand and calls him out (%s)" % [said])
	session.record_journal()
	_check(_step(session) == &"home", "the stub next")


func _fresh(marks: Dictionary) -> CharacterState:
	var state := CharacterState.new()
	for mark: String in marks:
		state.marks[mark] = marks[mark]
	return state


func _join(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.family = FamilyState.new(&"family.buxuan", 8) # TEST-ONLY: knelt to 骆云舟
	state.apprenticeship.master_teacher_id = LUO
	state.apprenticeship.legacy_master_name = "骆云舟"
	var affiliation := CharacterAffiliationState.new()
	affiliation.class_id = &"scholar"
	affiliation.has_family_rank = true
	affiliation.family_title = "弟子"
	affiliation.entry_time_status = CharacterAffiliationState.EntryTime.RECORDED
	state.affiliation = affiliation


func _entrance(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	var map: WorldMapController = MapPlaces.enter(session, ENTRANCE, ENTRANCE_POINT)
	await _settle(tree)
	return map


## Advances the encounter one combat round at a time until it is gone; what the NPCs' chat() said in it.
func _run(session: WorldSessionController) -> Array[String]:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var said: Array[String] = []
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 300:
		for event: CombatSchedulerEvent in coordinator.advance_scheduler(1.0).events():
			if event.chat != null:
				for line: VisionLine in event.chat.lines():
					said.append(line.template)
		rounds += 1
	_check(not coordinator.has_active_encounter(), "the spar ended (%d rounds)" % rounds)
	return said


## Where the line's current step leads the player now (StoryQuestLog.target() follows the quest it tracks).
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
	session.configure_source_entry("步玄", gender)
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
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
