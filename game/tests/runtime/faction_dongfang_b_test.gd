extends RefCounted

## 势力线第一批 东方神教 B (计划 build/plans/势力线第一批_计划.md §5 第 3–5 条, §11 Q7 Q8; DECISIONS「东方神教 B」):
## 朱鸿雪「差事」— three names, each near the 封物: the 黑冠道士 measuring the lake (fought; beaten is done), the
## 兵部画吏 at 黄石隘口 (beaten and spared he runs and drops his drawing), the old ice cutter (the small choice: 动手,
## or 搬走 and his chisel shown 朱鸿雪 — believed by one who told the 西厢 as it is, shown up at the split by one who
## kept it). 交差: the 黑木令 taken back for the 赤铜令. The 场院: the last name on the list by where the 宝衣 is
## (瑷伦 / you / 安妮儿 / burnt), 安妮儿 come for it; the big split — either 教主 takes the 赤铜令 for the 黄金令牌 and
## teaches 天山雪影剑 and 雪影心法 (those two only); 安妮儿's side sends 朱鸿雪's 220 after the deserving only,
## 朱鸿雪's shuts the 西厢's door. After every way of choosing the 终章 still goes down the lake.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const RealFight := preload("res://tests/support/real_fight.gd")
const Arrival := preload("res://tests/support/story_arrival.gd")
const QUEST: StringName = &"faction.dongfang"
const GOD: StringName = &"cloud.npc.god"
const ANNIE: StringName = &"latemoon.npc.room.annihi"
const ANNIE_YARD: StringName = &"native.npc.annie_yard"
const TAOIST: StringName = &"native.npc.lake_taoist"
const PAINTER: StringName = &"native.npc.war_painter"
const CUTTER: StringName = &"native.npc.ice_cutter"
const WOMAN: StringName = &"village.npc.woman1"
const BLACK: StringName = &"es2:d/latemoon/room/npc/obj/token"
const COPPER: StringName = &"native:cloud/copper_token"
const GOLD: StringName = &"es2:d/latemoon/room/npc/obj/gold_token"
const CHISEL: StringName = &"native:village/ice_chisel"
const SKETCH: StringName = &"native:canyon/dig_sketch"
const SWORD: StringName = &"native:lancheng/xuanmang"
const SNOW: Array[StringName] = [&"snowshade-force", &"snowshade-sword"]
const YARD: StringName = &"cloud.god2"
const YARD_POINT: StringName = &"cloud.god2.god.1"
const STREET: StringName = &"cloud.nwroad2"
const STREET_POINT: StringName = &"cloud.nwroad2.woodboxy_return"
const WEST: StringName = &"latemoon.room.westroom"
const WEST_POINT: StringName = &"latemoon.room.westroom.annihi.1"
const FIELD: StringName = &"village.field"
const FIELD_POINT: StringName = &"village.field.finale_runner.1"
const SHORE7: StringName = &"village.road7"
const SHORE7_POINT: StringName = &"village.road7.ice_cutter.1"
const BACKYARD: StringName = &"village.fmhousback"
const BACKYARD_POINT: StringName = &"village.fmhousback.woman1.1"
const PASS: StringName = &"canyon.canyon1"
const PASS_POINT: StringName = &"canyon.canyon1.chain_arrival"
const LAKESIDE: StringName = &"village.lakeside"
const ARRIVAL: StringName = &"village.lakeside.boat_return"
## 终章 A's ledger (story_finale_a_test.gd TABLE): cleared, then two bands set, so 安妮儿 is the third.
const TABLE: Array[String] = ["霍铮回了寨", "关北的骑兵欠你一阵", "大秦人留下了", "冰龙倒了", "冯策随你下湖", "宝衣给了安妮儿", "替南危水保密", "卫沧澜出了尚书府", "瑷伦守到决战", "带走了宝衣"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Callable in [_test_truth_spared_annie, _test_cover_killed_zhu, _test_caught, _test_versions, _test_mercy]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	# Every way of choosing: the 终章 still goes down the lake.
	for way: Array in [[true, true, true], [true, false, false], [false, true, true], [false, false, false], [false, true, false]]:
		var session: WorldSessionController = await _session(tree)
		await _test_down_the_lake(tree, session, way[0], way[1], way[2])
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"west", &"report", &"token", &"names", &"three", &"icer", &"copper", &"list", &"split"], "the steps: %s" % [ids])
	var icer: StoryQuestDefinition.Step = quest.step(&"icer")
	_check(icer.is_branch() and icer.weight == StoryQuestDefinition.WEIGHT_SMALL and icer.options.size() == 2, "the old ice cutter is the second small choice")
	_check(icer.objective.contains("安妮儿会知道") and icer.objective.contains("瞒过"), "its costs are said before it")
	var split: StoryQuestDefinition.Step = quest.step(&"split")
	_check(split.is_branch() and split.weight == StoryQuestDefinition.WEIGHT_BIG and split.options.size() == 2 and split.objective.contains("截一派的轿子") and split.objective.contains("守潭口"), "the 教主 is the big split, both costs said")
	_check(quest.step(&"three").checklist.size() == 3, "three names, three rows")
	_check(catalog.npc(GOD).talk().ask_confirm("教主").contains("截一派的轿子") and catalog.npc(ANNIE_YARD).talk().ask_confirm("教主").contains("只派该死的人"), "either side asked first, its cost written")
	_check(catalog.npc(CUTTER).talk().ask_confirm("动手").contains("安妮儿会知道") and catalog.npc(CUTTER).talk().ask_confirm("搬走").contains("当面揭穿"), "both ways with the old man asked first")
	_check(catalog.npc(CUTTER).dealings().is_fight_deferred(), "nobody fights the old man: 动手 is the one way")
	for spawn_id: StringName in [&"native.field.lake_taoist", &"native.canyon1.war_painter"]:
		var spawn: NpcSpawnDefinition = catalog.spawn(spawn_id)
		_check(spawn != null and spawn.present != null and not spawn.cleared_mark.is_empty() and spawn.until != null, "%s: on the stage while the names stand, beaten is done" % spawn_id)
	_check(catalog.spawn(&"native.road7.ice_cutter").present == null and catalog.spawn(&"native.road7.ice_cutter").until != null, "the old man lives in the village from New Game on")
	_check(catalog.npc(PAINTER).hooks().spared_drop == SKETCH and catalog.npc(PAINTER).hooks().spared_leave and catalog.npc(PAINTER).hooks().die_item_id == SKETCH, "the 画吏: spared he runs and drops his drawing; killed it is on him")
	for item_id: StringName in [COPPER, CHISEL, GOLD]:
		_check(catalog.item(item_id) != null and catalog.item(item_id).no_drop, "%s is never dropped" % item_id)
	_check(catalog.item(GOLD).display_name == "黄金令牌", "the 黄金令牌 is ES2's gold_token.c")
	for npc_id: StringName in [GOD, ANNIE]:
		var rules: Array[NpcTeaching.RecognizeRule] = catalog.npc(npc_id).teaching().recognize_rules
		_check(rules.size() == 1 and rules[0].accept and rules[0].skills.size() == 2 and SNOW.all(func(skill: StringName) -> bool: return rules[0].skills.has(skill)), "%s teaches the one who stood with them 天山雪影剑 and 雪影心法, those two" % npc_id)
	var mercy: QuestMercy = catalog.quest_mercy()
	_check(mercy != null and mercy.deserving.has("疯狗") and mercy.deserving.has("土匪首领") and not mercy.deserving.has("乞丐") and not mercy.deserving.has("李师师"), "朱鸿雪's 220: the deserving are beasts and bandits")
	var helpers: JournalEntryDefinition = catalog.conditions()["finale.helpers"]
	var state := CharacterState.new()
	for mark: String in ["霍铮回了寨", "关北的骑兵欠你一阵", "站了安妮儿"]:
		state.marks[mark] = 1
	_check(JournalLog.holds(helpers, state, {}, {}), "站了安妮儿 is a band at the lake, the 宝衣 hers or not")


## 照实说 earlier; the three names: the 道士 by day only, fought and beaten; the 画吏 fought, spared, his drawing
## on the ground; the old man talked into leaving, his chisel in hand; 交差 believed; the 场院 (瑷伦's name);
## 站安妮儿: the 黄金令牌, 西厢 teaches the two arts, the 沙盘 calls her a master now; the 声望 page.
func _test_truth_spared_annie(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	state.progression.combat_experience = 20000 # TEST-ONLY
	StoryFixtures.dongfang_held(session, true)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"names", "the 黑木令 held: the names next")
	# Before the names: nobody measures the lake, the old man has nothing to fear.
	var field: WorldMapController = MapPlaces.enter(session, FIELD, FIELD_POINT)
	await _settle(tree)
	_check(_first(session, FIELD, TAOIST) == null, "no 道士 before the names")
	field = MapPlaces.enter(session, SHORE7, SHORE7_POINT)
	await _settle(tree)
	var cutter: NpcRuntimeState = _first(session, SHORE7, CUTTER)
	_check(cutter != null and field.select_npc(cutter.character_id) and not field.ask_topics_selected().has("搬走") and not field.ask_topics_selected().has("动手"), "the old man by the willows, nothing to ask of him yet")
	_check(_said(_ask(field, cutter, "光"), "冰底下有光"), "he tells of the light under the ice")
	# 差事.
	var yard: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	var god: NpcRuntimeState = _first(session, YARD, GOD)
	_check(yard.select_npc(god.character_id) and yard.ask_topics_selected().has("差事"), "差事 is on 朱鸿雪's list for the token's bearer")
	var names: Array[String] = _ask(yard, god, "差事")
	_check(_said(names, "黑冠") and _said(names, "画吏") and _said(names, "凿冰") and state.marks.get("朱鸿雪说了三个名字", 0) == 1, "three names (%s)" % [names])
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"three" and _said(_ask(yard, god, "交差"), "还没办完"), "the three next; 交差 is early")
	# The 道士: by day on the 稻田's shore; 量水 and he fights; beaten, done.
	session.day_clock().set_day_seconds(43200) # TEST-ONLY: noon
	field = MapPlaces.enter(session, FIELD, FIELD_POINT)
	await _settle(tree)
	var taoist: NpcRuntimeState = _first(session, FIELD, TAOIST)
	_check(taoist != null, "by day the 黑冠道士 measures the lake")
	# DECISIONS「势力线的仗」: the two fought with real numbers — a character who also explored, at
	# 第五章's arrival (the names want 「宝衣一章」), a sword in hand; let go where they fall, dead where the sword kills outright.
	RealFight.ready_player(session, Arrival.exploring(&"main.chapter5"))
	_check(_said(_ask(field, taoist, "量水"), "湖底那东西"), "量水: what he measures")
	await _until_fight(tree, session)
	_check(session.combat_encounter_coordinator().has_active_encounter(), "and he draws")
	var steps: int = RealFight.fight_out(session)
	await _settle(tree)
	_check(steps < RealFight.MAX_STEPS and RealFight.player_stands(session), "the 道士 fought to the end, the player standing (%d steps; 气 %d/%d)" % [steps, state.vitality.current, state.vitality.maximum])
	session.record_journal()
	_check(state.marks.get("量水的道士倒了", 0) == 1, "beaten: 量水的道士倒了")
	# The 画吏 at 黄石隘口: fought, spared, his drawing on the ground.
	var gorge: WorldMapController = MapPlaces.enter(session, PASS, PASS_POINT)
	await _settle(tree)
	var painter: NpcRuntimeState = _first(session, PASS, PAINTER)
	_check(painter != null and _said(_ask(gorge, painter, "画图"), "第二只"), "the 画吏 under the rock wall: a second 石匣?")
	RealFight.Grown.heal(state)
	await _until_fight(tree, session)
	steps = RealFight.fight_out(session)
	await _settle(tree)
	_check(steps < RealFight.MAX_STEPS and RealFight.player_stands(session), "the 画吏 fought to the end, the player standing (%d steps; 气 %d/%d)" % [steps, state.vitality.current, state.vitality.maximum])
	session.record_journal()
	# Let go he runs and his drawing falls; a sword's wound kills without a fall, and it is on him.
	var left: Array[StringName] = RealFight.left_behind(session, SKETCH, PASS)
	_check(state.marks.get("兵部画吏倒了", 0) == 1 and (not left[0].is_empty() or not left[1].is_empty()) and _first(session, PASS, PAINTER) == null, "beaten: he is gone, his drawing on the ground or on his corpse")
	_check(StoryQuestLog.current_step(state, quest).step_id == &"icer", "the two done: the old man next")
	# The old man: 搬走, asked first; his chisel; he goes.
	field = MapPlaces.enter(session, SHORE7, SHORE7_POINT)
	await _settle(tree)
	cutter = _first(session, SHORE7, CUTTER)
	_check(field.select_npc(cutter.character_id) and field.ask_topics_selected().has("搬走") and field.ask_topics_selected().has("动手") and cutter.definition().talk().confirm_applies("搬走", state.marks), "搬走 and 动手 listed, asked first")
	_check(_said(_ask(field, cutter, "搬走"), "冰窟窿里") and state.marks.get("劝老冰匠搬走了", 0) == 1 and not _carried(session, CHISEL).is_empty(), "搬走: his chisel in hand")
	_check(_first(session, SHORE7, CUTTER) == null, "and he is gone")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"spare") and StoryQuestLog.current_step(state, quest).step_id == &"copper", "spare taken: 交差 next")
	var home: WorldMapController = MapPlaces.enter(session, BACKYARD, BACKYARD_POINT)
	await _settle(tree)
	_check(_said(_ask(home, _first(session, BACKYARD, WOMAN), "老冰匠"), "投亲"), "the 农妇: he went to his kin")
	# 交差: believed.
	yard = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	god = _first(session, YARD, GOD)
	var told: Array[String] = _ask(yard, god, "交差")
	_check(_said(told, "我也信你") and state.marks.get("持赤铜令", 0) == 1 and not _carried(session, COPPER).is_empty() and _carried(session, BLACK).is_empty() and _carried(session, CHISEL).is_empty(), "交差 believed: the 黑木令 and the chisel taken, the 赤铜令 given (%s)" % [told])
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"list" and _first(session, YARD, ANNIE_YARD) == null, "the last name next; 安妮儿 not here yet")
	var test: Callable = session.quest_condition_test()
	_check(test.call(catalog.conditions()["dongfang.token_holds"]), "the 赤铜令: the cult's killers know the bearer")
	# 西厢 meanwhile: she says she goes to the 场院.
	var manor: WorldMapController = MapPlaces.enter(session, WEST, WEST_POINT)
	await _settle(tree)
	_check(_said(_ask(manor, _first(session, WEST, ANNIE), "等谁"), "到场院去"), "安妮儿: to the 场院")
	# The 场院: 瑷伦's name (nothing of the 宝衣 done yet); no showing up for one who told the truth.
	var before: int = session.shared_ui().log_lines().size()
	yard = await _scene(tree, session)
	var said: Array[String] = session.shared_ui().log_lines()
	_check(_first(session, YARD, ANNIE_YARD) != null, "安妮儿 in the 场院")
	_check(_said(said, "名单上最后一个名字：瑷伦") and _said(said, "没碰过神教一根指头") and not _said(said, "我信过你一回") and state.marks.get("场院的话说完了", 0) == 1, "瑷伦's name, 安妮儿's answer, nothing shown up (%s)" % [said])
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"split", "the split next")
	var annie: NpcRuntimeState = _first(session, YARD, ANNIE_YARD)
	# DECISIONS「东方神教 B」: the 安妮儿 of the 场院 takes the 宝衣 too, as the 西厢's does (第四章 must not stop).
	var robe: StringName = yard.give_new_item_to_player(&"native:latemoon/cold_robe") # TEST-ONLY: 第四章's 宝衣 in hand
	_check(not robe.is_empty() and yard.select_npc(annie.character_id), "the 宝衣 carried to the 场院's 安妮儿")
	var robe_given: ItemHandlingResult = yard.give_to_selected(robe)
	_check(robe_given != null and robe_given.done() and state.marks.get("宝衣给了安妮儿", 0) == 1 and _carried(session, &"native:latemoon/cold_robe").is_empty(), "the 场院's 安妮儿 takes the 宝衣: 宝衣给了安妮儿 (%s)" % [[] if robe_given == null else robe_given.lines])
	state.marks.erase("宝衣给了安妮儿") # TEST-ONLY: the rest of this way is played without it
	god = _first(session, YARD, GOD)
	_check(yard.select_npc(annie.character_id) and yard.ask_topics_selected().has("教主") and annie.definition().talk().confirm_applies("教主", state.marks) and god.definition().talk().confirm_applies("教主", state.marks), "教主 on both, asked first")
	_check(not MapAtlas.takes_students(catalog.npc(ANNIE), state), "before the split 安妮儿 is no master on the 沙盘")
	_check(_said(_ask(yard, annie, "教主"), "教主令") and state.marks.get("站了安妮儿", 0) == 1 and not _carried(session, GOLD).is_empty() and _carried(session, COPPER).is_empty(), "站安妮儿: the 赤铜令 for the 黄金令牌")
	_check(_first(session, YARD, ANNIE_YARD) == null and not god.definition().talk().confirm_applies("教主", state.marks), "she leaves for the 西厢; the other side is gone")
	_check(_said(_ask(yard, god, "教主"), "我认输"), "朱鸿雪 gives in, and stays")
	_check(_said(_ask(yard, god, "交差"), "令是她给的"), "交差 after the split: the 黄金令")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"side_annie") and StoryQuestLog.is_done(state, quest), "side_annie taken: the line done")
	test = session.quest_condition_test()
	_check(test.call(catalog.conditions()["dongfang.token_holds"]), "the 黄金令牌: the cult's killers know the bearer")
	# 西厢: she teaches the two arts, nothing else; the 沙盘 marks her a master now; 朱鸿雪 does not.
	manor = MapPlaces.enter(session, WEST, WEST_POINT)
	await _settle(tree)
	var teacher: TeacherService = _teacher(manor, ANNIE)
	_check(teacher != null and teacher.teachable_skills().size() == 2 and SNOW.all(func(skill: StringName) -> bool: return teacher.teachable_skills().has(skill)), "安妮儿 teaches 天山雪影剑 and 雪影心法 (%s)" % [[] if teacher == null else teacher.teachable_skills()])
	_check(MapAtlas.takes_students(catalog.npc(ANNIE), state) and not MapAtlas.takes_students(catalog.npc(GOD), state), "the 沙盘 marks 安妮儿 a master, not 朱鸿雪")
	_check(catalog.npc(ANNIE).teaching().recognize(state.family.family_id, state.marks, &"snowshade-sword") != null and catalog.npc(ANNIE).teaching().recognize(state.family.family_id, state.marks, &"pyrobat-steps") == null, "asked for another of hers, the rule passes over")
	_check(_said(_ask(manor, _first(session, WEST, ANNIE), "教主"), "请教"), "教主 in the 西厢: come and learn")
	var faction: FactionDefinition = _faction(catalog)
	var shown: Array = faction.shown(session.quest_condition_test())
	_check(shown.has("你站到了安妮儿一边。一代教主收回了教主令，给了你一块黄金令牌。") and shown.has("你劝玉螺湖的老冰匠搬走了，拿他的冰凿去向朱鸿雪交了差。") and not shown.has("朱鸿雪换给你一块赤铜令。"), "the 声望 page (%s)" % [shown])


## 替她瞒 earlier; the old man done (动手, asked first, he is gone); 交差 with no chisel to show; the 宝衣 carried
## out (your name on the list), 安妮儿 knows of the old man; 站朱鸿雪: the 黄金令牌 from her, 安妮儿 leaves; the 西厢's
## door shut; 朱鸿雪 teaches the two arts.
func _test_cover_killed_zhu(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	state.progression.combat_experience = 20000 # TEST-ONLY
	StoryFixtures.dongfang_named(session, false)
	state.marks["带走了宝衣"] = 1 # TEST-ONLY: 第四章, the 宝衣 carried out of the manor
	for mark: String in ["量水的道士倒了", "兵部画吏倒了"]:
		state.marks[mark] = 1 # TEST-ONLY: the two beaten
	session.record_journal()
	var shore: WorldMapController = MapPlaces.enter(session, SHORE7, SHORE7_POINT)
	await _settle(tree)
	var cutter: NpcRuntimeState = _first(session, SHORE7, CUTTER)
	_check(cutter.definition().talk().confirm_applies("动手", state.marks), "动手 asked first")
	_check(_said(_ask(shore, cutter, "动手"), "冰窟窿边上") and state.marks.get("杀了老冰匠", 0) == 1 and _first(session, SHORE7, CUTTER) == null, "动手: he is gone")
	_check(not cutter.definition().talk().confirm_applies("搬走", state.marks), "and 搬走 is no more")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"do") and StoryQuestLog.current_step(state, quest).step_id == &"copper", "do taken: 交差 next")
	var home: WorldMapController = MapPlaces.enter(session, BACKYARD, BACKYARD_POINT)
	await _settle(tree)
	_check(_said(_ask(home, _first(session, BACKYARD, WOMAN), "老冰匠"), "死在湖边"), "the 农妇: he died by the lake")
	var yard: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	var god: NpcRuntimeState = _first(session, YARD, GOD)
	_check(_said(_ask(yard, god, "交差"), "没人再讲给孩子听") and not _carried(session, COPPER).is_empty() and _carried(session, BLACK).is_empty(), "交差: the 赤铜令")
	session.record_journal()
	var before: int = session.shared_ui().log_lines().size()
	yard = await _scene(tree, session)
	var said: Array[String] = session.shared_ui().log_lines()
	_check(_said(said, "交出来，或者你的名字也在上面") and _said(said, "是你动的手") and not _said(said, "我信过你一回"), "the 宝衣 yours: your name; 安妮儿 knows of the old man (%s)" % [said])
	god = _first(session, YARD, GOD)
	_check(_said(_ask(yard, god, "教主"), "黄金令") and state.marks.get("站了朱鸿雪", 0) == 1 and not _carried(session, GOLD).is_empty() and _carried(session, COPPER).is_empty(), "站朱鸿雪: the 黄金令牌")
	_check(_first(session, YARD, ANNIE_YARD) == null, "安妮儿 leaves the 场院")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"side_zhu") and StoryQuestLog.is_done(state, quest), "side_zhu taken: the line done")
	var teacher: TeacherService = _teacher(yard, GOD)
	_check(teacher != null and teacher.teachable_skills().size() == 2, "朱鸿雪 teaches the two arts (%s)" % [[] if teacher == null else teacher.teachable_skills()])
	_check(MapAtlas.takes_students(catalog.npc(GOD), state) and not MapAtlas.takes_students(catalog.npc(ANNIE), state), "the 沙盘: 朱鸿雪 a master, not 安妮儿")
	var manor: WorldMapController = MapPlaces.enter(session, WEST, WEST_POINT)
	await _settle(tree)
	var annie: NpcRuntimeState = _first(session, WEST, ANNIE)
	_check(annie != null and _said(_ask(manor, annie, "等谁"), "门关着") and _said(_ask(manor, annie, "教主"), "门关着"), "the 西厢's door shut")
	_check(_said(_ask(manor, annie, "宝衣"), "名字"), "the 宝衣 is still hers to speak of (§11 Q8)")
	var mercy: QuestMercy = catalog.quest_mercy()
	_check(not mercy.spares("乞丐", state), "站朱鸿雪: all 220 as ES2")


## 替她瞒 and the old man talked into leaving: 交差 takes the chisel, says little; at the split 朱鸿雪 shows it up.
## The 宝衣 given to 安妮儿: her name on the list.
func _test_caught(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.progression.combat_experience = 20000 # TEST-ONLY
	StoryFixtures.dongfang_named(session, false)
	state.marks["宝衣给了安妮儿"] = 1 # TEST-ONLY: 第四章
	for mark: String in ["量水的道士倒了", "兵部画吏倒了"]:
		state.marks[mark] = 1 # TEST-ONLY: the two beaten
	var shore: WorldMapController = MapPlaces.enter(session, SHORE7, SHORE7_POINT)
	await _settle(tree)
	_check(_said(_ask(shore, _first(session, SHORE7, CUTTER), "搬走"), "冰窟窿里"), "搬走")
	session.record_journal()
	var yard: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	var told: Array[String] = _ask(yard, _first(session, YARD, GOD), "交差")
	_check(_said(told, "没有说话") and not _said(told, "我也信你") and state.marks.get("持赤铜令", 0) == 1, "交差: she takes the chisel and says little (%s)" % [told])
	session.record_journal()
	var before: int = session.shared_ui().log_lines().size()
	await _scene(tree, session)
	var said: Array[String] = session.shared_ui().log_lines()
	_check(_said(said, "名单上最后一个名字：安妮儿") and _said(said, "香火"), "the 宝衣 hers: her name (%s)" % [said])
	_check(_said(said, "我信过你一回") and state.marks.get("朱鸿雪揭穿了冰凿", 0) == 1, "shown up: the chisel, the man alive")
	var shown: Array = _faction(GameContent.catalog()).shown(session.quest_condition_test())
	_check(shown.has("你拿老冰匠的冰凿骗过朱鸿雪，她当面揭穿了你。"), "the 声望 page says so")


## The last name, by where the 宝衣 is: burnt (安妮儿, the 封法 in one head) and the others, played anew.
func _test_versions(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.progression.combat_experience = 20000 # TEST-ONLY
	StoryFixtures.dongfang_coppered(session, true, true)
	var cases: Array = [
		[["宝衣给了安妮儿", "宝衣烧了"], "封物没了", "名单上最后一个名字：安妮儿"],
		[["冰匣开了"], "交出来", "你的名字也在上面"],
		[["瑷伦守到决战"], "守衣人身上", "名单上最后一个名字：瑷伦"],
	]
	for case: Array in cases:
		for mark: String in ["宝衣给了安妮儿", "宝衣烧了", "冰匣开了", "瑷伦守到决战", "带走了宝衣", "场院里两位教主", "场院的话说完了"]:
			state.marks.erase(mark) # TEST-ONLY: a fresh 场院
		for mark: String in case[0]:
			state.marks[mark] = 1 # TEST-ONLY
		var before: int = session.shared_ui().log_lines().size()
		await _scene(tree, session)
		var said: Array[String] = session.shared_ui().log_lines()
		_check(_said(said, case[1]) and _said(said, case[2]), "%s: %s (%s)" % [case[0], case[2], said])


## 站安妮儿: 朱鸿雪's 任务 only for the deserving (a running task on a spared one called off); 站朱鸿雪 or none: all.
func _test_mercy(_tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	var mercy: QuestMercy = catalog.quest_mercy()
	state.progression.combat_experience = 2000 # TEST-ONLY: the first tier (乞丐, 李师师, 疯狗 …)
	_check(not mercy.spares("乞丐", state), "no split: the 乞丐 is drawn as in ES2")
	state.marks["站了安妮儿"] = 1 # TEST-ONLY
	_check(mercy.spares("乞丐", state) and mercy.spares("杜宽", state) and not mercy.spares("疯狗", state), "站安妮儿: the 乞丐 and 杜宽 are spared, the 疯狗 not")
	var available: Callable = func(target: String) -> bool: return catalog.quest_target_available(target) and not mercy.spares(target, state)
	for draw: int in 6:
		state.quest.clear_task()
		var result: QuestGiver.Result = QuestGiver.give(state, catalog.quest_tiers(), available, func(n: int) -> int: return draw % maxi(n, 1))
		_check(result.outcome == QuestGiver.Outcome.GIVEN and mercy.deserving.has(result.quest.target), "draw %d: %s, one that deserves it" % [draw, "" if result.quest == null else result.quest.target])
	# A 教主's blood after the line is done (no more lapses): the mercy, the token and the lake all end.
	state.marks["杀了神教的教主"] = 1 # TEST-ONLY
	_check(not mercy.spares("乞丐", state) and not JournalLog.holds(catalog.conditions()["dongfang.annie_helps"], state, {}, {}), "her blood: no mercy, no 安妮儿 at the lake")
	var map: WorldMapController = session.active_map() as WorldMapController
	map.give_new_item_to_player(GOLD) # TEST-ONLY
	_check(not session.quest_condition_test().call(catalog.conditions()["dongfang.token_holds"]), "her blood: the cult's killers no longer know the 黄金令牌's bearer")


## After each way (`annie` side, `truth`, `killed`), at the 终章: 安妮儿 at the lake for her side or the 宝衣; the 点将;
## 等到天黑; the boat; the dive — down into the ice cave.
func _test_down_the_lake(tree: SceneTree, session: WorldSessionController, annie: bool, truth: bool, killed: bool) -> void:
	var state: CharacterState = session.player_runtime().state
	var way: String = "%s/%s/%s" % ["安妮儿" if annie else "朱鸿雪", "照实" if truth else "瞒", "动手" if killed else "搬走"]
	StoryFixtures.chapter10_done(session, "self", "expose", false)
	for mark: String in TABLE:
		state.marks.erase(mark) # TEST-ONLY: the earlier chapters' fixture marks cleared
	for mark: String in ["霍铮回了寨", "关北的骑兵欠你一阵", "冰龙倒了"]:
		state.marks[mark] = 1 # TEST-ONLY: two bands (the 冰龙 down: no band of its own)
	var robe: bool = not annie and killed # 站朱鸿雪 with the 宝衣 hers once (§11 Q8: she still comes)
	if robe:
		state.marks["宝衣给了安妮儿"] = 1 # TEST-ONLY
	StoryFixtures.dongfang_split(session, annie, truth, killed)
	(session.active_map() as WorldMapController).give_new_item_to_player(SWORD) # TEST-ONLY: as the 云台 gives it
	session.record_journal()
	var lake: WorldMapController = MapPlaces.enter(session, LAKESIDE, ARRIVAL)
	await _settle(tree)
	session.record_journal()
	var comes: bool = annie or robe
	_check((_first(session, LAKESIDE, &"native.npc.annie_lake") != null) == comes, "%s: 安妮儿 at the lake: %s" % [way, comes])
	_check(JournalLog.holds(GameContent.catalog().conditions()["finale.helpers"], state, {}, {}) == comes, "%s: three bands with her: %s" % [way, comes])
	var before: int = session.shared_ui().log_lines().size()
	for second: int in 8:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	var said: Array[String] = session.shared_ui().log_lines()
	if annie:
		_check(_said(said, "教主令在"), "%s: the 点将: 神教守潭口 (%s)" % [way, said])
	elif robe:
		_check(_said(said, "不是替神教来的"), "%s: the 点将: she keeps the 封法, not 朱鸿雪 (%s)" % [way, said])
	var ui: SharedGameplayUI = session.shared_ui()
	session.day_clock().set_day_seconds(43200) # TEST-ONLY: the day
	await _act(tree, lake, &"village.lakeside.wait")
	if ui.is_asking():
		ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	session.record_journal()
	await _act(tree, lake, &"village.lakeside.paddle")
	var middle: WorldMapController = session.active_map() as WorldMapController
	_check(middle != null and middle.map_id() == &"village.midlake", "%s: out on the boat" % way)
	if middle != null and middle.map_id() == &"village.midlake":
		await _act(tree, middle, &"village.lake.dive")
		if ui.is_asking():
			ui.confirm_prompt.confirm_button.pressed.emit()
		await _settle(tree)
	session.record_journal()
	_check(session.active_map().map_id() == &"village.icecave" and state.marks.get("终章下了湖底", 0) == 1, "%s: down the lake" % way)


## Into the 场院 anew (out into the street and back: the stage is judged on entering a map) and the scene's beats.
func _scene(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	MapPlaces.enter(session, STREET, STREET_POINT)
	await _settle(tree)
	var yard: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	for second: int in 18:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	return yard


func _teacher(map: WorldMapController, npc_id: StringName) -> TeacherService:
	for service: WorldService in map.service_nodes:
		var teacher: TeacherService = service as TeacherService
		if teacher != null and teacher.npc != null and NpcDefinition.unnamed_id(teacher.npc.definition().definition_id) == npc_id:
			return teacher
	return null


func _faction(catalog: ContentCatalog) -> FactionDefinition:
	for candidate: FactionDefinition in catalog.factions():
		if candidate.faction_id == &"dongfang":
			return candidate
	return null


func _until_fight(tree: SceneTree, session: WorldSessionController) -> void:
	for second: int in 4:
		if session.combat_encounter_coordinator().has_active_encounter():
			return
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)


func _act(tree: SceneTree, map: WorldMapController, service_id: StringName) -> void:
	var service: ActService = map.service(service_id) as ActService
	# The walk may end a step short of its route's own end and still stand within reach: reach decides.
	if service != null:
		await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, service_id))
	var reached: bool = service != null and service.in_reach()
	_check(reached, "within reach of %s" % service_id)
	if reached:
		service.interact()
	await _settle(tree)


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


## The instance id of the first of `definition_id` the player carries ("" when none).
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


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var map: WorldMapController = session.world_map_of(MapPlaces.map_of(zone_id))
	if map == null:
		return null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE) and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("神教", CharacterState.GENDER_MALE)
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
