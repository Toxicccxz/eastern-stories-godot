extends RefCounted

## 势力线第二批 官府 B (计划 势力线第二批_计划.md §6 官府 B; DECISIONS「官府 B」): 严廷殷 owns the seal on the 路引
## (once his letter was read) and sends the player to 李信; 李信's 印鉴 is his ledger of the three days (one who settled
## with 庾子建 and gave the 密信 to 程不平 hears the case can be opened again); 赫造基 owns the stamping once the 拓模 was
## bought. The split: 整肃 with 严廷殷 (the 军师 fights, only knocked down; the 铁卫营 a band at the lake) or 揭发 with
## 李信 (严廷殷 and the 军师 gone once one walks into the 帅帐, the gate takes no toll, the ledger one more piece for
## 第九章's 揭发). The 卫沧澜 route: 於兰天武 come to court fetches him; out by another way, the step passes. The epilogue.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const RealFight := preload("res://tests/support/real_fight.gd")
const Arrival := preload("res://tests/support/story_arrival.gd")
const QUEST: StringName = &"faction.court"
const JUDGE: StringName = &"choyin.npc.judgeman"
const GENERAL: StringName = &"canyon.npc.general"
const VICE: StringName = &"canyon.npc.vice_general"
const ADVISER: StringName = &"canyon.npc.adviser"
const UNCLE: StringName = &"common.npc.fighter.champion"
const GATE_SOLDIER: StringName = &"native.npc.pass_gate_soldier"
const CAMP7: StringName = &"canyon.camp7"
const CAMP8: StringName = &"canyon.camp8"
const GATE: StringName = &"canyon.canyon7"
const GATE_POINT: StringName = &"canyon.canyon7.gate_return"
const HALL: StringName = &"choyin.yamen"
const HALL_POINT: StringName = &"choyin.yamen.hall_entry"
const FRONT: StringName = &"imperial.front_hall"
const FRONT_POINT: StringName = &"imperial.front_hall.uncle.1"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Callable in [_test_seal_and_ledger, _test_reopened, _test_purge, _test_expose, _test_expose_cut_short, _test_uncle]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"badge", &"toll_snow", &"toll_cloud", &"passes", &"seal", &"ledger", &"adviser", &"split", &"arrest", &"uncle"], "its steps: %s" % [ids])
	_check(quest.branches_of(StoryQuestDefinition.WEIGHT_BIG) == 1 and quest.branches_of(StoryQuestDefinition.WEIGHT_SMALL) == 0, "one big choice: the split")
	_check(quest.step(&"uncle").weight == StoryQuestDefinition.WEIGHT_ROUTE and quest.step(&"uncle").options.size() == 3, "卫沧澜: a route, not a choice")
	_check(quest.step(&"arrest").only_after == &"purge" and quest.step(&"arrest").keeps.is_empty() and catalog.npc(ADVISER).hooks().kept_when != null, "the 军师 is taken on 整肃 only; no step keeps him (an ES2 resident), his kept_when does")
	var quests: Array[StoryQuestDefinition] = catalog.story_quests()
	var fresh := CharacterState.new()
	_check(not StoryKeeps.keeps(fresh, catalog.npc(ADVISER), quests), "from New Game the 军师 is as ES2: he can be killed")
	fresh.marks["跟严廷殷整肃"] = 1
	_check(StoryKeeps.keeps(fresh, catalog.npc(ADVISER), quests), "整肃 chosen: only knocked down")
	fresh.marks["赫造基被拿下了"] = 1
	_check(not StoryKeeps.keeps(fresh, catalog.npc(ADVISER), quests), "taken: no longer kept")
	_check(not quest.step(&"split").option(&"purge").reward.deed.is_empty() and not quest.step(&"split").option(&"expose").reward.deed.is_empty(), "a deed either way")
	var general: NpcDefinition = catalog.npc(GENERAL)
	var vice: NpcDefinition = catalog.npc(VICE)
	var admitted: Dictionary = {"赫造基认了盖印": 1}
	_check(general.talk().ask_confirm("整肃").contains("铁卫营") and general.talk().confirm_applies("整肃", admitted), "整肃 asked first, the 帮手 said")
	_check(vice.talk().ask_confirm("揭发").contains("不收过路费") and vice.talk().ask_confirm("揭发").contains("物证") and vice.talk().confirm_applies("揭发", admitted), "揭发 asked first, the toll and the evidence said")
	_check(not general.talk().confirm_applies("整肃", {"赫造基认了盖印": 1, "跟李信揭发": 1}) and not vice.talk().confirm_applies("揭发", {"赫造基认了盖印": 1, "跟严廷殷整肃": 1}), "one side taken: the other not asked")
	var adviser: NpcDefinition = catalog.npc(ADVISER)
	_check(adviser.hooks().spared_mark == "赫造基被拿下了" and adviser.hooks().spared_leave and adviser.hooks().spared_only_in_mood == "cornered" and not adviser.hooks().always_kept, "the 军师: spared in the fight he starts, taken away; any other time as ES2")
	var helpers: JournalEntryDefinition = catalog.conditions()["finale.helpers"]
	_check(helpers.amount == 3 and helpers.parts.size() == 11, "帮手: three of eleven")
	var state := CharacterState.new()
	for mark: String in ["霍铮回了寨", "大秦人留下了", "冰龙倒了"]:
		state.marks[mark] = 1
	_check(not JournalLog.holds(helpers, state, {}, {}), "two bands are not enough (the 冰龙 down)")
	state.marks["跟严廷殷整肃"] = 1
	_check(not JournalLog.holds(helpers, state, {}, {}), "整肃 chosen, the 军师 not taken: no band yet")
	state.marks["赫造基被拿下了"] = 1
	_check(JournalLog.holds(helpers, state, {}, {}), "铁卫营守官道 is the third band")
	var expose: ServiceDefinition = catalog.service(&"imperial.front_hall.expose")
	var told: int = 0
	for act: ScriptedAct in expose.act.acts:
		for step: ScriptedAct.Step in act.steps:
			if step.only_when != null and step.only_when.when == JournalEntryDefinition.When.MARK and step.only_when.key == "跟李信揭发":
				told += 1
	_check(told == 2, "李信's ledger is told in both short-of-evidence branches (%d)" % told)
	var ending: EpilogueDefinition = catalog.epilogue(&"ending")
	var canyon: Array = ending.cards.filter(func(card: EpilogueDefinition.Card) -> bool: return card.card_id == &"canyon")
	_check(canyon.size() == 1 and canyon[0].lines.size() == 2, "the ending has a 天驼关 card: 整肃 or 揭发")


## The seal (after 第六章's letter), 李信's ledger, the 军师 (after the 拓模): the fixtures match what was played.
func _test_seal_and_ledger(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.court_reported(session)
	state.marks["军营"] = 1 # TEST-ONLY: on the 大队长's roll (第六章)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"seal", "the seal next")
	var camp: WorldMapController = MapPlaces.enter(session, CAMP8, &"canyon.camp8.general.1")
	var general: NpcRuntimeState = await _beside(tree, session, camp, &"canyon.camp8.general.1")
	_check(camp.select_npc(general.character_id) and camp.ask_topics_selected().has("路引") and not camp.ask_topics_selected().has("整肃"), "路引 listed to the 捕快; 整肃 not yet")
	_check(_said(_ask(camp, general, "路引"), "先拿信来") and not state.marks.has("严廷殷认了路引"), "before his letter: the letter first")
	state.marks["严廷殷看了信"] = 1 # TEST-ONLY: 第六章's letter shown
	_check(_said(_ask(camp, general, "路引"), "是我的印") and state.marks.get("严廷殷认了路引", 0) == 1, "the seal is his")
	_check(_said(_ask(camp, general, "路引"), "去问李信"), "asked again: 李信")
	var adviser: NpcRuntimeState = MapPlaces.npc_at(session, &"canyon.camp8.adviser.1")
	_check(camp.select_npc(adviser.character_id) and not camp.ask_topics_selected().has("路引"), "the 军师's 路引 not listed before the ledger")
	camp = MapPlaces.enter(session, CAMP7, &"canyon.camp7.vice_general.1")
	var vice: NpcRuntimeState = await _beside(tree, session, camp, &"canyon.camp7.vice_general.1")
	_check(vice != null and camp.select_npc(vice.character_id) and camp.ask_topics_selected().has("印鉴") and not camp.ask_topics_selected().has("揭发"), "李信: 印鉴 listed; 揭发 not yet")
	var said: Array[String] = _ask(camp, vice, "印鉴")
	_check(_said(said, "四百张") and _said(said, "照模子浇的印") and _said(said, "赫造基") and not _said(said, "再开一回堂") and state.marks.get("李信说了那三天的账", 0) == 1 and not state.marks.has("庾子建的案子又开了"), "the ledger: %s" % [said])
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"adviser", "the 军师 next")
	camp = MapPlaces.enter(session, CAMP8, &"canyon.camp8.adviser.1")
	adviser = await _beside(tree, session, camp, &"canyon.camp8.adviser.1")
	_check(_said(_ask(camp, adviser, "路引"), "八两银子") and not state.marks.has("赫造基认了盖印"), "the 拓模 not bought: his price")
	state.marks["赫造基说了拓模"] = 1 # TEST-ONLY: 第六章's eight taels
	_check(_said(_ask(camp, adviser, "路引"), "一夜盖完") and state.marks.get("赫造基认了盖印", 0) == 1, "he owns the stamping")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"split", "the split next")
	var missing: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.court_admitted)
	_check(missing.is_empty(), "played leaves what court_admitted writes: %s" % [missing])
	_check(camp.select_npc(general.character_id) and camp.ask_topics_selected().has("整肃"), "整肃 listed now")
	session.shared_ui().standing_page.fill(session.quest_condition_test())
	_check(session.shared_ui().standing_page.shown_text().contains("副将李信记了一本账"), "the 声望 page")


## Settled with 庾子建 and the 密信 with 程不平: 李信 adds the case can be opened again; 程不平 and the epilogue say so.
func _test_reopened(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.court_reported(session)
	for mark: String in ["军营", "严廷殷看了信", "严廷殷认了路引", "私了了庾子建", "密信给了官府"]:
		state.marks[mark] = 1 # TEST-ONLY: 第九章 settled, the letter with 程不平
	session.record_journal()
	var camp: WorldMapController = MapPlaces.enter(session, CAMP7, &"canyon.camp7.vice_general.1")
	var vice: NpcRuntimeState = await _beside(tree, session, camp, &"canyon.camp7.vice_general.1")
	var said: Array[String] = _ask(camp, vice, "印鉴")
	_check(_said(said, "四百张") and _said(said, "再开一回堂") and state.marks.get("庾子建的案子又开了", 0) == 1, "settled, the letter with 程不平: the case opened again: %s" % [said])
	_check(_said(_ask(camp, vice, "印鉴"), "四百张") or _said(_ask(camp, vice, "印鉴"), "盖印的是军师"), "asked again: the ledger")
	state.marks.erase("庾子建的案子又开了") # TEST-ONLY: heard the ledger before settling
	state.marks.erase("李信的账送了乔阴") # TEST-ONLY
	_check(_said(_ask(camp, vice, "印鉴"), "再开一回堂") and state.marks.get("庾子建的案子又开了", 0) == 1, "heard the ledger first, settled after: the case still opens")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var judge: NpcRuntimeState = _first(session, HALL, JUDGE)
	_check(_said(_ask(hall, judge, "捕快"), "又开了一回堂"), "程不平: the case opened again")
	var ending: EpilogueDefinition = GameContent.catalog().epilogue(&"ending")
	var told: String = str(ending.shown(session.quest_condition_test()))
	_check(told.contains("又摊开了庾子建的卷宗"), "the 乔阴 card says so")


## 整肃: asked first; the 军师 is cornered when asked (his mood), attacked he is only knocked down and taken away; the 铁卫营 a band;
## the gate takes its five taels as ever; the 天驼关 card.
func _test_purge(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.court_admitted(session)
	session.record_journal()
	var camp: WorldMapController = MapPlaces.enter(session, CAMP8, &"canyon.camp8.general.1")
	var general: NpcRuntimeState = await _beside(tree, session, camp, &"canyon.camp8.general.1")
	_check(general.definition().talk().confirm_applies("整肃", state.marks), "整肃 asked first")
	_check(_said(_ask(camp, general, "整肃"), "军师交给你拿下") and state.marks.get("跟严廷殷整肃", 0) == 1, "整肃 chosen")
	session.record_journal()
	_check(state.quests.has("faction.court/split/purge") and DeedLog.done(state, "在天驼关跟严廷殷整肃，那三天的账不上京") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"arrest", "the 军师 next")
	_check(StoryKeeps.keeps(state, catalog.npc(ADVISER), catalog.story_quests()), "the 军师 only knocked down now")
	camp = MapPlaces.enter(session, CAMP7, &"canyon.camp7.vice_general.1")
	var vice: NpcRuntimeState = await _beside(tree, session, camp, &"canyon.camp7.vice_general.1")
	_check(not vice.definition().talk().confirm_applies("揭发", state.marks) and _said(_ask(camp, vice, "揭发"), "将军定了"), "李信: 整肃 chosen, no 揭发")
	camp = MapPlaces.enter(session, CAMP8, &"canyon.camp8.adviser.1")
	var adviser: NpcRuntimeState = await _beside(tree, session, camp, &"canyon.camp8.adviser.1")
	# 势力线复查: he is cornered the moment the one who came for him walks in, asked or not (beaten before
	# the question, he was ES2's 300000 and his fall counted for nothing).
	await _settle(tree)
	_check(adviser.has_flag(StringName(NpcMood.FLAG_PREFIX + "cornered")) and state.marks.get("赫造基退到了帐柱边", 0) == 1 and _said(session.shared_ui().log_lines(), "束手就擒"), "the 军师 backs to the tent pole on sight")
	_check(_said(_ask(camp, adviser, "路引"), "束手就擒"), "asked: the same answer")
	await _settle(tree)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "he waits for the player to attack (a kill: kept, then spared)")
	# DECISIONS「势力线的仗」: fought with real numbers — a character who also explored, at 第六章's
	# arrival (the earliest from which 整肃 is reached), a sword in hand; the 军师 as his `cornered` makes him.
	var cornered: NpcMood = catalog.npc(ADVISER).hooks().moods["cornered"]
	_check(cornered.combat_exp > 0 and adviser.character_state.progression.combat_experience == cornered.combat_exp and cornered.combat_exp < catalog.npc(ADVISER).combat_experience, "cornered, he fights as the scene's 军师 (%d), not ES2's %d" % [cornered.combat_exp, catalog.npc(ADVISER).combat_experience])
	adviser.end_mood() # TEST-ONLY: the mood's end gives his record's strength back
	_check(adviser.character_state.progression.combat_experience == catalog.npc(ADVISER).combat_experience, "out of the mood: ES2's 300000 again")
	adviser.put_in_mood(cornered) # TEST-ONLY: and back in it
	_check(adviser.character_state.progression.combat_experience == cornered.combat_exp, "in it again: the scene's")
	RealFight.ready_player(session, Arrival.exploring(&"main.chapter6"))
	camp.select_npc(adviser.character_id)
	camp.attack_selected()
	_check(session.combat_encounter_coordinator().has_active_encounter(), "attacked: the fight")
	var steps: int = RealFight.fight_out(session)
	await _settle(tree)
	_check(steps < RealFight.MAX_STEPS and RealFight.player_stands(session), "the fight to its end, the player standing (%d steps)" % steps)
	_check(state.marks.get("赫造基被拿下了", 0) == 1 and adviser.has_flag(NpcDefinition.FLAG_LEAVES_WHEN_FREE), "knocked down (kept: 放过 is all there is): taken away")
	session.record_journal()
	_check(state.quests.has("faction.court/arrest") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"uncle", "the 卫沧澜 route next")
	var missing: Array[String] = StoryFixtures.missing_after_play(session, func(played: WorldSessionController) -> void: StoryFixtures.court_admitted(played); StoryFixtures.court_split(played, true))
	_check(missing.is_empty(), "played leaves what court_split(purge) writes: %s" % [missing])
	_check(_rule_says(general.definition(), "整肃", state.marks, "铁卫营欠你一回"), "严廷殷: the 铁卫营 owes you")
	for mark: String in ["霍铮回了寨", "大秦人留下了"]:
		state.marks[mark] = 1 # TEST-ONLY
	_check(bool(session.quest_condition_test().call(catalog.conditions()["finale.helpers"])), "the 铁卫营 is the third band")
	var ending: EpilogueDefinition = catalog.epilogue(&"ending")
	var told: String = str(ending.shown(session.quest_condition_test()))
	_check(told.contains("出关留五两") and not told.contains("李信"), "the 天驼关 card: 整肃")
	var soldier: NpcDefinition = catalog.npc(GATE_SOLDIER)
	var purged: Dictionary[String, int] = {"跟严廷殷整肃": 1}
	_check(_rule_says(soldier, "过路钱", purged, "五两"), "整肃: the gate's toll stands")


## 揭发: asked first; walking into the 帅帐, 严廷殷 goes and the 军师 with him; the gate lets one through for nothing;
## the ledger counts in 第九章's 揭发; 李信 takes the 印鉴 that 严廷殷 took; the card.
func _test_expose(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.court_admitted(session)
	session.record_journal()
	var camp: WorldMapController = MapPlaces.enter(session, CAMP7, &"canyon.camp7.vice_general.1")
	var vice: NpcRuntimeState = await _beside(tree, session, camp, &"canyon.camp7.vice_general.1")
	_check(vice.definition().talk().confirm_applies("揭发", state.marks), "揭发 asked first")
	var said: Array[String] = _ask(camp, vice, "揭发")
	_check(_said(said, "账抄两份") and _said(said, "算一样") and state.marks.get("跟李信揭发", 0) == 1, "揭发 before 第九章 is decided: the ledger is one more piece: %s" % [said])
	session.record_journal()
	_check(state.quests.has("faction.court/split/expose") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"uncle", "揭发: no 军师 to take; the 卫沧澜 route next")
	var missing: Array[String] = StoryFixtures.missing_after_play(session, func(played: WorldSessionController) -> void: StoryFixtures.court_admitted(played); StoryFixtures.court_split(played, false))
	_check(missing.is_empty(), "played leaves what court_split(expose) writes: %s" % [missing])
	# The gate: through for nothing.
	state.marks.erase("过了关门") # TEST-ONLY: never through before
	state.marks.erase("军营") # TEST-ONLY: not on the roll either
	var gate: WorldMapController = MapPlaces.enter(session, GATE, GATE_POINT)
	await _beats(tree, session, 3)
	_check(state.marks.get("过了关门", 0) == 1, "the gate lets one through: no toll")
	var soldier: NpcRuntimeState = _first(session, GATE, GATE_SOLDIER)
	_check(_said(_ask(gate, soldier, "关北"), "朝廷知道了") and _said(_ask(gate, soldier, "过路钱"), "不收了"), "the gate's words")
	state.marks["军营"] = 1 # TEST-ONLY
	# The 帅帐: 严廷殷 and the 军师 go.
	camp = MapPlaces.enter(session, CAMP8, &"canyon.camp8.general.1")
	await _beats(tree, session, 14)
	_check(state.marks.get("严廷殷交了关", 0) == 1, "his farewell is a scene")
	_check(_count_in(session, CAMP8, GENERAL) == 0 and _count_in(session, CAMP8, ADVISER) == 0, "the 帅帐 is empty: %s %s" % [_where(session, GENERAL), _where(session, ADVISER)])
	gate = MapPlaces.enter(session, GATE, GATE_POINT)
	await _settle(tree)
	camp = MapPlaces.enter(session, CAMP8, &"canyon.camp8.general.1")
	await _beats(tree, session, 2)
	_check(_count_in(session, CAMP8, GENERAL) == 0 and _count_in(session, CAMP8, ADVISER) == 0, "gone for good")
	# The 印鉴 chain goes on through 李信.
	var takes: Array = vice.definition().dealings().object_rules.filter(func(rule: NpcObjectRule) -> bool: return rule.giver_mark == "跟李信揭发")
	_check(takes.size() == 2 and takes[0].item == &"es2:d/canyon/npc/obj/seal" and takes[0].gives == &"es2:d/canyon/npc/obj/old_sword" and takes[0].accept and takes[1].item == &"es2:d/canyon/npc/obj/fake_seal" and takes[1].set_temps.has("将军/kick") and not takes[1].accept, "李信 takes the 印鉴 (the 古剑) and throws out the fake (将军/kick) once 严廷殷 is gone")
	# 第九章's 揭发 counts the ledger.
	var expose: ServiceDefinition = catalog.service(&"imperial.front_hall.expose")
	var counted: bool = false
	for act: ScriptedAct in expose.act.acts:
		if act.ask.is_empty() or act.when == null:
			continue
		var probe := CharacterState.new()
		for mark: String in ["对出了原令", "跟李信揭发", "陈显祖作了证"]:
			probe.marks[mark] = 1
		var one := CharacterState.new()
		for mark: String in ["对出了原令", "陈显祖作了证"]:
			one.marks[mark] = 1
		counted = JournalLog.holds(act.when, probe, {}, {}) and not JournalLog.holds(act.when, one, {}, {})
		break
	_check(counted, "原令, 陈显祖 and 李信's ledger: two pieces, enough for 揭发 (陈显祖 alone is not)")
	var ending: EpilogueDefinition = catalog.epilogue(&"ending")
	var told: String = str(ending.shown(session.quest_condition_test()))
	_check(told.contains("将军营帐里坐着李信") and not told.contains("出关留五两"), "the 天驼关 card: 揭发")
	session.shared_ui().standing_page.fill(session.quest_condition_test())
	_check(session.shared_ui().standing_page.shown_text().contains("你跟李信揭发了天驼关"), "the 声望 page")


## 揭发, the farewell begun and cut short (its scene_mark written, the rest never played): next time in, 严廷殷 and
## the 军师 go without a word.
func _test_expose_cut_short(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.court_admitted(session)
	StoryFixtures.court_split(session, false)
	state.marks["严廷殷交了关"] = 1 # TEST-ONLY: the scene begun, cut short
	session.record_journal()
	MapPlaces.enter(session, GATE, GATE_POINT)
	await _settle(tree)
	MapPlaces.enter(session, CAMP8, &"canyon.camp8.general.1")
	await _beats(tree, session, 4)
	_check(_count_in(session, CAMP8, GENERAL) == 0 and _count_in(session, CAMP8, ADVISER) == 0, "cut short: they still go: %s %s" % [_where(session, GENERAL), _where(session, ADVISER)])


## 卫沧澜: the 皇叔 come to court fetches him (the step's route `uncle`); out by another way, `out`; 第九章 settled
## without the 皇叔, `none`. The 虹台's line for one the 皇叔 fetched.
func _test_uncle(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	StoryFixtures.chapter9_done(session, "uncle")
	StoryFixtures.court_admitted(session)
	StoryFixtures.court_split(session, false)
	state.marks.erase("卫沧澜出了尚书府") # TEST-ONLY: still in the 客房
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest) != null and StoryQuestLog.current_step(state, quest).step_id == &"uncle", "the 皇叔 in court, 卫沧澜 in the 客房: the route waits")
	var hall: WorldMapController = MapPlaces.enter(session, FRONT, FRONT_POINT)
	await _settle(tree)
	var uncle: NpcRuntimeState = _first(session, FRONT, UNCLE)
	_check(uncle != null and hall.select_npc(uncle.character_id) and hall.ask_topics_selected().has("卫沧澜"), "於兰天武 in the 养心殿: 卫沧澜 listed")
	var said: Array[String] = _ask(hall, uncle, "卫沧澜")
	_check(_said(said, "手诏") and _said(said, "庾子建亲自开的门") and state.marks.get("皇叔要回了卫沧澜", 0) == 1 and state.marks.get("卫沧澜出了尚书府", 0) == 1 and state.marks.get("见过卫沧澜", 0) == 1, "the 皇叔 fetches him (met: no stranger's greeting in the 水烟阁): %s" % [said])
	session.record_journal()
	_check(state.quests.has("faction.court/uncle/uncle") and state.quests.has("faction.court#done") and DeedLog.done(state, "请皇叔拿手诏从尚书府要回了卫沧澜"), "the route `uncle`; the line done")
	_check(_said(_ask(hall, uncle, "卫沧澜"), "送回水烟阁"), "asked again")
	var wp: String = FileAccess.get_file_as_string("res://data/waterfog/world.json")
	_check(wp.contains("欠朝廷一份——交官府看着"), "the 虹台: 卫沧澜 owes the court")
	# Out by another way: the step passes as `out`; settled without the 皇叔: `none`.
	for pair: Array in [[["卫沧澜出了尚书府"], &"out"], [["私了了庾子建"], &"none"]]:
		var probe := CharacterState.new()
		for mark: String in pair[0]:
			probe.marks[mark] = 1
		var step: StoryQuestDefinition.Step = quest.step(&"uncle")
		var first: StringName = &""
		for option: StoryQuestDefinition.Option in step.options:
			if JournalLog.holds(option.condition, probe, {}, {}):
				first = option.option_id
				break
		_check(first == pair[1], "%s: the route is %s (%s)" % [pair[0], pair[1], first])
	var probe := CharacterState.new()
	probe.marks["皇叔入朝"] = 1
	_check(not quest.step(&"uncle").options.any(func(option: StoryQuestDefinition.Option) -> bool: return JournalLog.holds(option.condition, probe, {}, {})), "the 皇叔 in court, 卫沧澜 inside: the route waits")


## Whether the rule `npc` answers `topic` with for these marks says `part`.
func _rule_says(npc: NpcDefinition, topic: String, marks: Dictionary[String, int], part: String) -> bool:
	var rule: NpcInquiryRule = NpcInquiryRule.decide(npc.talk().inquiry_rules(topic), marks)
	return rule != null and rule.lines.any(func(line: NpcLine) -> bool: return line.text.contains(part))


func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, point_id: StringName, offset: Vector2 = Vector2(0, 56)) -> NpcRuntimeState:
	var npc: NpcRuntimeState = MapPlaces.npc_at(session, point_id)
	var body: Node2D = null if npc == null else map.runtime_body_for_character(npc.character_id)
	_check(npc != null and body != null and map.place_player(npc.world_location().zone_id, body.global_position + offset), "TEST-ONLY: beside %s" % point_id)
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	return npc


func _beats(tree: SceneTree, session: WorldSessionController, seconds: int) -> void:
	await _settle(tree)
	for second: int in seconds:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _all(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> Array[NpcRuntimeState]:
	var found: Array[NpcRuntimeState] = []
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found.append(npc)
	return found


func _where(session: WorldSessionController, definition_id: StringName) -> Array:
	var found: Array = []
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
				found.append([npc.world_location().zone_id, npc.exists_in_map, npc.life_status, npc.has_flag(NpcDefinition.FLAG_GONE)])
	return found


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	return _all(session, zone_id, definition_id).size()


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var found: Array[NpcRuntimeState] = _all(session, zone_id, definition_id)
	return null if found.is_empty() else found[0]


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("官府", CharacterState.GENDER_MALE)
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
