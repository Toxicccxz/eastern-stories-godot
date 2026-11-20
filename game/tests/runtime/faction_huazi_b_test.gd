extends RefCounted

## 势力线第二批 花紫会 B (计划 势力线第二批_计划.md §5 花紫会 B, §7 第 1、4、6 行; DECISIONS「花紫会 B」「问话清偷窃记录」
## 「巡捕放过」): the 真龙头's 盟主 — the 狗洞 below the 尚书府's wall, only by night; the 护院 at the 客房's door on a round
## (caught, put out on 东街, again as often as one likes); 卫沧澜's 走 for one who came by the 狗洞 (天邪 B's step reads it);
## one whose 卫沧澜 is already out has a word. The 真龙头 home on 福林大街 and the scene with 陆得财; 认二十三个结 (花紫会
## votes 颜违, the caught steals wiped, the 巡捕 let 花紫会's own be, 陆得财 gone for good) or 认这些年管事的人 (the 真龙头
## back to the wall, 花紫会 votes 旧盟主); 九结弟子 either way; 这一票 from the one in 乔阴; the 虹台's seat.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"faction.huazi"
const MASTER: StringName = &"common.npc.beggar.master"
const HEAD: StringName = &"native.npc.lu_decai_true"
const HOME: StringName = &"native.npc.lu_decai_home"
const WEI: StringName = &"native.npc.wei_canglan"
const TRAINER: StringName = &"city.npc.shangshu.huyuan"
const TRAINER1: StringName = &"city.npc.shangshu.huyuan1"
const PATROL: StringName = &"choyin.npc.yamen_po"
const HOLE: StringName = &"city.street3.dog_hole"
const WALL: StringName = &"city.street3"
const WALL_POINT: StringName = &"city.street3.wall_return"
const FEIWU: StringName = &"city.shangshu.feiwu"
const ROAD2: StringName = &"city.shangshu.road2"
const KEFANG: StringName = &"city.shangshu.kefang"
const KEFANG_POINT: StringName = &"city.shangshu.kefang.wei_canglan.1"
const STREET: StringName = &"choyin.n_street1"
const GATE: StringName = &"choyin.n_gate"
const GATE_POINT: StringName = &"choyin.n_gate.road_arrival"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_votes()
	for test: Callable in [_test_stolen, _test_knots, _test_manager]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids.slice(-3) == [&"letter", &"rescue", &"split"], "the line ends rescue, split: %s" % [ids])
	var rescue: StoryQuestDefinition.Step = quest.step(&"rescue")
	_check(rescue.is_branch() and rescue.weight == StoryQuestDefinition.WEIGHT_ROUTE and rescue.options.size() == 2, "卫沧澜: a route of two (stolen, or already out), no choice")
	_check(rescue.objective.contains("夜里") and rescue.objective.contains("狗洞") and rescue.objective.contains("撞见") and rescue.objective.contains("「走」"), "the 狗洞 by night, the 护院, 走 are told")
	var split: StoryQuestDefinition.Step = quest.step(&"split")
	_check(split.is_branch() and split.weight == StoryQuestDefinition.WEIGHT_BIG and split.options.size() == 2 and split.options.all(func(option: StoryQuestDefinition.Option) -> bool: return option.reward.rank_title == "九结弟子" and option.reward.rank_family == &"family.huazi" and not option.reward.deed.is_empty()), "the split: the line's one big choice, 九结弟子 and a deed either way")
	_check(split.objective.contains("颜违") and split.objective.contains("旧盟主") and split.objective.contains("案底") and split.objective.contains("巡捕"), "what either side costs is said before the choice")
	_check(catalog.npc(HOME).talk().ask_confirm("龙头").contains("颜违") and catalog.npc(MASTER).talk().ask_confirm("龙头").contains("旧盟主"), "both are asked first, the vote said")
	_check(catalog.npc(HOME).talk().ask_confirm("龙头").contains("入席时") and catalog.npc(MASTER).talk().ask_confirm("龙头").contains("入席时") and split.objective.contains("入席时"), "a split taken once seated: the vote as it was cast, said first")
	var first_beat: Array = catalog.npc(HOME).hooks().calls[0].act.steps.map(func(step: ScriptedAct.Step) -> String: return step.flag if step.kind == ScriptedAct.Kind.NPC_MOOD else "")
	_check(first_beat.has("waiting"), "陆得财 is held for the scene from its first beat (he wanders otherwise)")
	_check(catalog.service(HOLE) != null, "the 狗洞 below the wall")
	for id: StringName in [TRAINER, TRAINER1]:
		var watch: NpcWatch = catalog.npc(id).dealings().watch
		_check(watch != null and watch.release_zone_id == WALL and watch.until_phase.is_empty() and watch.mark == "尚书府夜里被撞见", "%s keeps a round: caught, out on 东街 at once" % id)
		if watch == null:
			continue
		var state := CharacterState.new()
		var temps: Dictionary[String, int] = {}
		var held: Dictionary[StringName, bool] = {}
		_check(not JournalLog.holds(watch.when, state, temps, held, &"", {}, &"night"), "%s: no round for one the 真龙头 told nothing" % id)
		state.marks["真龙头说了狗洞"] = 1
		_check(not JournalLog.holds(watch.when, state, temps, held, &"", {}, &"afternoon"), "%s: by day, at the door as in ES2" % id)
		_check(JournalLog.holds(watch.when, state, temps, held, &"", {}, &"night") and JournalLog.holds(watch.when, state, temps, held, &"", {}, &"midnight"), "%s: by night, on the round" % id)
		state.marks["卫沧澜出了尚书府"] = 1
		_check(not JournalLog.holds(watch.when, state, temps, held, &"", {}, &"night"), "%s: 卫沧澜 out, back at the door" % id)
	var arrest: NpcArrest = catalog.npc(PATROL).dealings().patrol.arrest
	var state := CharacterState.new()
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	state.marks["认了二十三个结"] = 1
	_check(arrest.spares != null and not JournalLog.holds(arrest.spares, state, temps, held), "认了二十三个结, not of 花紫会: the 巡捕 take a thief as before")
	state.family = FamilyState.new(&"family.huazi", 5)
	_check(JournalLog.holds(arrest.spares, state, temps, held), "认了二十三个结, of 花紫会: the 巡捕 let them be")
	state.marks.erase("认了二十三个结")
	_check(not JournalLog.holds(arrest.spares, state, temps, held), "no split: 花紫会's own are taken as before")
	var wei: Array[NpcInquiryRule] = catalog.npc(WEI).talk().inquiry_rules("走")
	_check(wei[0].asker_marks == ["入了虹台的席"] and wei[0].asker_lacks == ["大会散了"] and wei[0].marks_asker.is_empty(), "修补 Z: while the 虹台 sits he does not go")
	_check(wei[1].asker_marks.has("钻了尚书府的狗洞") and wei[1].marks_asker.has("卫沧澜出了尚书府") and wei[1].marks_asker.has("花紫会偷出了卫沧澜") and wei[1].leaves, "卫沧澜's 走 for one who came by the 狗洞: out, and 花紫会's doing")
	for id: String in ["assembly.huazi.yan", "assembly.huazi.self", "assembly.day.huazi.yan", "assembly.day.huazi.backs", "assembly.day.huazi.self"]:
		_check(catalog.conditions().has(id), "%s exists" % id)
	_check(catalog.npc(HOME).teaching() != null and catalog.npc(HOME).teaching().recognize(&"", {"陆得财说了差事": 1}, &"stealing") != null, "the 真龙头 in 乔阴 teaches 偷窃 as 陆得财 did")


## The 虹台's 花紫会 vote: no line as before (旧盟主 once 终章); the split decides; 这一票 from the one in 乔阴.
func _test_votes() -> void:
	var state: CharacterState = _fresh(["终章"])
	_check(_holds(state, "assembly.huazi.old") and not _holds(state, "assembly.huazi.yan") and not _holds(state, "assembly.huazi.stated"), "no line: 旧盟主, not yet stated (as 大会 A)")
	state = _fresh(["认了二十三个结", "花紫会的票随了真龙头"])
	_check(_holds(state, "assembly.huazi.stated") and _holds(state, "assembly.huazi.yan") and not _holds(state, "assembly.huazi.old"), "认二十三个结: stated, 颜违")
	state = _fresh(["认了管事的陆得财", "花紫会的票随了陆得财"])
	_check(_holds(state, "assembly.huazi.stated") and _holds(state, "assembly.huazi.old") and not _holds(state, "assembly.huazi.yan"), "认管事的: stated, 旧盟主")
	state = _fresh(["终章", "认了二十三个结"])
	_check(_holds(state, "assembly.huazi.old"), "认二十三个结 once seated: the vote as it was cast")
	state = _fresh(["终章", "认了二十三个结", "花紫会的票随了真龙头"])
	var before: CharacterState = _fresh(["终章"])
	var said: NpcInquiryRule = NpcInquiryRule.decide(GameContent.catalog().npc(HOME).talk().inquiry_rules("虹台"), before.marks)
	_check(said != null and said.mark_asker.is_empty() and said.marks_asker.is_empty(), "the 真龙头 before the split: first say it on 福林大街, no vote stated")
	_check(_heard(state, HOME, "虹台", "开口就是") and state.marks.has("花紫会肯听你的") and _listed(state, HOME, "这一票"), "认二十三个结: the 真龙头 offers the vote")
	_check(_heard(state, HOME, "这一票", "你说了算") and _holds(state, "assembly.huazi.self") and not _holds(state, "assembly.huazi.yan") and not _holds(state, "assembly.huazi.old"), "这一票: 花紫会听你的")
	state = _fresh(["终章", "认了管事的陆得财", "花紫会的票随了陆得财"])
	_check(_heard(state, MASTER, "虹台", "开口就是") and _listed(state, MASTER, "这一票") and _heard(state, MASTER, "这一票", "你说了算") and _holds(state, "assembly.huazi.self"), "认管事的: 陆得财 offers the vote")
	state.marks["入了虹台的席"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.day.huazi.backs") and not _holds(state, "assembly.day.huazi.old"), "on the day: 花紫会 came and 听你的")
	state.marks["站出来参选"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.day.huazi.self"), "and stood: 花紫会 votes you")
	state = _fresh(["入了虹台的席", "认了二十三个结", "花紫会的票随了真龙头"])
	_check(_holds(state, "assembly.day.huazi.yan") and not _holds(state, "assembly.day.huazi.old"), "on the day: 颜违's")
	var spawns: ContentCatalog = GameContent.catalog()
	var seat_true: NpcSpawnDefinition = spawns.spawn(&"native.terrace.lu_decai_true")
	var seat: NpcSpawnDefinition = spawns.spawn(&"native.terrace.lu_decai")
	state = _fresh(["九派到了", "入了虹台的席", "认了二十三个结"])
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	_check(JournalLog.holds(seat_true.present, state, temps, held) and not JournalLog.holds(seat.present, state, temps, held), "认二十三个结: the 真龙头 in 花紫会's seat")
	state = _fresh(["九派到了", "入了虹台的席", "认了管事的陆得财"])
	_check(not JournalLog.holds(seat_true.present, state, temps, held) and JournalLog.holds(seat.present, state, temps, held), "认管事的: 陆得财 in it")


## By night through the 狗洞: told first; by day it will not do; caught on the round, out on 东街, again; in the 客房,
## 走: 卫沧澜 out, 花紫会's doing (天邪 B's 盟主的下落 holds); the 真龙头 off the wall and home on 福林大街.
func _test_stolen(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	state.marks["击了鼓"] = 1 # TEST-ONLY
	state.marks["湖底一章"] = 1 # TEST-ONLY: 卫沧澜 in the 客房
	StoryFixtures.huazi_found(session)
	StoryFixtures.huazi_letter(session)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"rescue", "卫沧澜 next")
	var city: WorldMapController = MapPlaces.enter(session, WALL, WALL_POINT)
	await _settle(tree)
	var hole: ActService = city.service(HOLE) as ActService
	await MapPlaces.drive(tree, city, MapPlaces.service_spot(city, HOLE, WALL))
	_check(hole != null and hole.in_reach(), "at the 柴草")
	hole.interact()
	await _settle(tree)
	_check(_said(_recent(session), "压得严严实实") and session.player_runtime().world_location().zone_id == WALL, "untold: only brushwood")
	var head: NpcRuntimeState = _first(session, WALL, HEAD)
	_check(_said(_ask(city, head, "盟主"), "狗洞") and state.marks.get("真龙头说了狗洞", 0) == 1, "盟主: the 狗洞 and the 护院's round")
	_check(not [&"night", &"midnight"].has(session.day_phase_id()), "still day (%s)" % session.day_phase_id())
	(city.service(HOLE) as ActService).interact()
	await _settle(tree)
	_check(_said(_recent(session), "夜里再来") and session.player_runtime().world_location().zone_id == WALL, "by day: not now")
	_check(session.wait_until_phase([&"night"]), "night")
	city = MapPlaces.enter(session, WALL, WALL_POINT)
	await _settle(tree)
	await MapPlaces.drive(tree, city, MapPlaces.service_spot(city, HOLE, WALL))
	(city.service(HOLE) as ActService).interact()
	await _settle(tree)
	var manor: WorldMapController = session.active_map() as WorldMapController
	_check(session.player_runtime().world_location().zone_id == FEIWU and state.marks.get("钻了尚书府的狗洞", 0) == 1, "by night: through the 狗洞 into the 废屋 (%s)" % session.player_runtime().world_location().zone_id)
	# The round: the 客房's door is left between their passes.
	var keepers: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in manor.resident_npcs():
		if NpcDefinition.unnamed_id(npc.definition().definition_id) == TRAINER1:
			keepers.append(npc)
	_check(keepers.size() == 1, "the 护院 at the 客房's door")
	if keepers.is_empty():
		return
	var keeper: NpcRuntimeState = keepers[0]
	var body: WorldCharacterBody2D = manor.npcs.runtime_body_for_character(keeper.character_id)
	var left: bool = false
	for frame: int in 600:
		manor.watches.tick(1.0 / 60.0)
		await tree.physics_frame
		if keeper.world_location().zone_id != ROAD2:
			left = true
			break
	_check(left, "by night he walks his round off the 小径 (%s)" % keeper.world_location().zone_id)
	# Caught: in front of him.
	manor.npc_life.npc_walker().cancel(keeper.character_id) # TEST-ONLY: he stands for the looking
	body.facing = Vector2.DOWN
	var player: WorldCharacterBody2D = manor.runtime_player_body()
	player.global_position = body.global_position + Vector2(0, 50) # TEST-ONLY
	await _settle(tree)
	manor.watches.tick(2.0)
	await _settle(tree)
	_check(state.marks.get("尚书府夜里被撞见", 0) == 1 and session.player_runtime().world_location().zone_id == WALL and session.day_phase_id() == &"night", "caught: put out on 东街, still night (%s, %s)" % [session.player_runtime().world_location().zone_id, session.day_phase_id()])
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"rescue", "caught: try again")
	# In the 客房 (TEST-ONLY: past the round), 走.
	var kefang: WorldMapController = MapPlaces.enter(session, KEFANG, KEFANG_POINT)
	await _settle(tree)
	state.marks["见过卫沧澜"] = 1 # TEST-ONLY: his greeting as one comes in
	var wei: NpcRuntimeState = _first(session, KEFANG, WEI)
	_check(_said(_ask(kefang, wei, "走"), "叫花子") and state.marks.get("卫沧澜出了尚书府", 0) == 1 and state.marks.get("花紫会偷出了卫沧澜", 0) == 1, "走: out by the 狗洞, 花紫会's doing")
	_check(_holds(state, "celestial.leader_settled"), "天邪 B's 盟主的下落 reads it")
	session.record_journal()
	_check(StoryQuestLog.took(state, catalog.story_quest(QUEST), &"stolen") and DeedLog.done(state, "夜里从尚书府的狗洞偷出了卫沧澜") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"split", "stolen, a deed; the split next")
	var missing: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.huazi_rescued)
	_check(missing.is_empty(), "played leaves what huazi_rescued writes: %s" % [missing])
	MapPlaces.enter(session, WALL, WALL_POINT)
	await _settle(tree)
	_check(_first(session, WALL, HEAD) == null, "the 真龙头 has left the wall")
	await _to_street(tree, session)
	_check(_first(session, STREET, HOME) != null, "and sits on 福林大街")


## 卫沧澜 already out: the 真龙头's word, then 福林大街: the scene (陆得财 held there), 认二十三个结: 陆得财 gone for good,
## the caught steals wiped, 九结弟子, the 巡捕 let 花紫会's own be; 这一票 from the 真龙头.
func _test_knots(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.huazi_joined(session)
	StoryFixtures.huazi_found(session)
	StoryFixtures.huazi_letter(session)
	state.marks["卫沧澜出了尚书府"] = 1 # TEST-ONLY: out by another way
	session.record_journal()
	var city: WorldMapController = MapPlaces.enter(session, WALL, WALL_POINT)
	await _settle(tree)
	_check(_said(_ask(city, _first(session, WALL, HEAD), "盟主"), "不是叫花子背出来的") and state.marks.get("真龙头说了盟主", 0) == 1 and not state.marks.has("真龙头说了狗洞"), "already out: a word")
	session.record_journal()
	_check(StoryQuestLog.took(state, catalog.story_quest(QUEST), &"out") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"split", "the route taken; the split next")
	var street: WorldMapController = await _to_street(tree, session)
	var lines: Array[String] = await _scene(tree, session, street)
	_check(_said(lines, "吃官饭") and _said(lines, "没让一个官差") and state.marks.get("两个陆得财说完了话", 0) == 1, "the scene on 福林大街: %s" % [lines.slice(-6)])
	var lu: NpcRuntimeState = _first(session, STREET, MASTER)
	var home: NpcRuntimeState = _first(session, STREET, HOME)
	_check(lu != null and lu.mood() != null and lu.mood().lasting, "陆得财 stays for it (a lasting mood: no wandering)")
	CrimeRecord.add_thief(state, 3) # TEST-ONLY: three caught steals
	_check(street.select_npc(home.character_id) and home.definition().talk().confirm_applies("龙头", state.marks, state.family.family_id), "认二十三个结 is asked first")
	_check(_said(_ask(street, home, "龙头"), "一笔勾销") and state.marks.get("认了二十三个结", 0) == 1 and state.marks.get("花紫会的票随了真龙头", 0) == 1 and CrimeRecord.thief(state) == 0, "认二十三个结: the caught steals wiped")
	await _settle(tree)
	_check(_first(session, STREET, MASTER) == null, "陆得财 leaves")
	session.record_journal()
	_check(StoryQuestLog.took(state, catalog.story_quest(QUEST), &"knots") and state.quests.has("faction.huazi#done") and state.affiliation.family_title == "九结弟子", "the split taken, 九结弟子, the line done (%s)" % state.affiliation.family_title)
	var missing: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.huazi_settled)
	_check(missing.is_empty(), "played leaves what huazi_settled writes: %s" % [missing])
	MapPlaces.enter(session, GATE, GATE_POINT)
	await _settle(tree)
	street = await _to_street(tree, session)
	_check(_first(session, STREET, MASTER) == null and _first(session, STREET, HOME) != null, "back on 福林大街: the 真龙头, no 陆得财")
	state.marks["终章"] = 1 # TEST-ONLY
	_check(_said(_ask(street, _first(session, STREET, HOME), "虹台"), "开口就是") and _said(_ask(street, _first(session, STREET, HOME), "这一票"), "你说了算") and _holds(state, "assembly.huazi.self"), "这一票 from the 真龙头")
	var ui: SharedGameplayUI = session.shared_ui()
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("吃上了官饭") and ui.standing_page.shown_text().contains("听你的"), "the 声望 page: %s" % ui.standing_page.shown_text())


## 卫沧澜 stolen; the split: 认这些年管事的人: the 真龙头 gone from 乔阴, back below the wall; 陆得财 stays; 旧盟主.
func _test_manager(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	state.marks["击了鼓"] = 1 # TEST-ONLY
	StoryFixtures.huazi_found(session)
	StoryFixtures.huazi_letter(session)
	StoryFixtures.huazi_rescued(session, true)
	CrimeRecord.add_thief(state, 2) # TEST-ONLY
	session.record_journal()
	var street: WorldMapController = await _to_street(tree, session)
	await _scene(tree, session, street)
	var lu: NpcRuntimeState = _first(session, STREET, MASTER)
	_check(_said(_ask(street, lu, "龙头"), "二十三个结的皮酒囊") and state.marks.get("认了管事的陆得财", 0) == 1 and state.marks.get("花紫会的票随了陆得财", 0) == 1 and CrimeRecord.thief(state) == 2, "认管事的: the 酒囊 on him; the steals stay on record")
	await _settle(tree)
	_check(_first(session, STREET, HOME) == null and _first(session, STREET, MASTER) != null, "the 真龙头 leaves 乔阴, 陆得财 stays")
	session.record_journal()
	_check(StoryQuestLog.took(state, catalog.story_quest(QUEST), &"manager") and state.quests.has("faction.huazi#done") and state.affiliation.family_title != "九结弟子", "the split taken; no 九结 for one not of 花紫会")
	_check(_holds(state, "assembly.huazi.old") and _holds(state, "assembly.huazi.stated"), "花紫会 votes 旧盟主")
	MapPlaces.enter(session, GATE, GATE_POINT)
	await _settle(tree)
	await _to_street(tree, session)
	_check(_first(session, STREET, HOME) == null, "he does not come back to 乔阴")
	var city: WorldMapController = MapPlaces.enter(session, WALL, WALL_POINT)
	await _settle(tree)
	_check(_said(_ask(city, _first(session, WALL, HEAD), "龙头"), "系在得财腰上"), "back below the wall")
	_check(_said(_ask(city, _first(session, WALL, HEAD), "盟主"), "接着看着庾家"), "盟主 back at the wall: no going home again")


## TEST-ONLY: 乔阴's 北门 then up 福林大街.
func _to_street(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	var map: WorldMapController = MapPlaces.enter(session, GATE, GATE_POINT)
	await _settle(tree)
	if map == null:
		return null
	await MapPlaces.drive_to_zone(tree, map, STREET)
	await _settle(tree)
	return map


## TEST-ONLY: the scene on 福林大街 as one comes onto it, through to its end.
func _scene(tree: SceneTree, session: WorldSessionController, street: WorldMapController) -> Array[String]:
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(street.scene_running() and session.player_runtime().state.marks.get("福林大街碰了面", 0) == 1, "the scene starts as the player comes onto the street")
	for second: int in 60:
		if not street.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not street.scene_running(), "the scene is over")
	return _recent(session, 30)


func _fresh(marks: Array) -> CharacterState:
	var state := CharacterState.new()
	for mark: String in marks:
		state.marks[mark] = 1
	return state


func _holds(state: CharacterState, condition_id: String) -> bool:
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	return JournalLog.holds(GameContent.catalog().conditions()[condition_id], state, temps, held)


## Asks `npc` `topic` as the rules decide (TEST-ONLY: the marks the answer sets set on the state).
func _heard(state: CharacterState, npc: StringName, topic: String, part: String) -> bool:
	var talk: NpcTalk = GameContent.catalog().npc(npc).talk()
	var rule: NpcInquiryRule = NpcInquiryRule.decide(talk.inquiry_rules(topic), state.marks)
	if rule == null:
		return false
	if not rule.mark_asker.is_empty():
		state.marks[rule.mark_asker] = 1 # TEST-ONLY
	for mark: String in rule.marks_asker:
		state.marks[mark] = 1 # TEST-ONLY
	return rule.lines.any(func(line: NpcLine) -> bool: return line.text.contains(part))


func _listed(state: CharacterState, npc: StringName, topic: String) -> bool:
	return GameContent.catalog().npc(npc).talk().listed_for(topic, state.marks)


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _recent(session: WorldSessionController, count: int = 6) -> Array[String]:
	var lines: Array[String] = session.shared_ui().log_lines()
	return lines.slice(maxi(0, lines.size() - count))


func _all(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> Array[NpcRuntimeState]:
	var found: Array[NpcRuntimeState] = []
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found.append(npc)
	return found


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var found: Array[NpcRuntimeState] = _all(session, zone_id, definition_id)
	return null if found.is_empty() else found[0]


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("花紫会", CharacterState.GENDER_MALE)
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
