extends RefCounted

## 势力线第二批 振远 B (计划 势力线第二批_计划.md §4 振远 B, §7 第 6 行; DECISIONS「振远 B」): once the 镖 is in 京师
## 陈天星's「旧账」(the 总账: the 绮云 分局 opened on the 兵部's 抚恤银) — told from the 镖路 already known (the letter
## or the 镖单) or from 贺平's word (handed to the 官府) — then 陈剑秋's「旧账」, then the split: 到此为止 at 陈剑秋 (the
## book burnt by 陈天星 the next visit, 春风快意刀 from 陈剑秋, 振远 votes 颜违) or 查到底 at 陈天星 (the book to the
## 乔阴 县衙, 镖路查清了 for the 揭发 when not yet known, the 分局 shut, 振远 votes the old 盟主). 走完 the line, the
## one who sided asks 振远's「这一票」; the 虹台's day counts 振远 among those that may 听你的.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"faction.zhenyuan"
const JIANQIU: StringName = &"cloud.npc.b_header"
const TIANXING: StringName = &"city.npc.chen"
const LETTER: StringName = &"native:city/he_letter"
const BUREAU: StringName = &"cloud.biaoju"
const BUREAU_POINT: StringName = &"cloud.biaoju.eroad2_entry"
const HQ: StringName = &"city.biaoju"
const HQ_POINT: StringName = &"city.biaoju.street1_entry"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_votes()
	for test: Callable in [_test_stop_handed, _test_dig_freed, _test_dig_handed_proof]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	var ids: Array = [] if quest == null else quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"take", &"road", &"robber", &"deliver", &"letter", &"ledger", &"uncle", &"books"], "its steps: %s" % [ids])
	var books: StoryQuestDefinition.Step = quest.step(&"books")
	_check(books.is_branch() and books.weight == StoryQuestDefinition.WEIGHT_BIG and books.options.size() == 2 and books.options.all(func(option: StoryQuestDefinition.Option) -> bool: return not option.reward.deed.is_empty()), "the 旧账 is the line's one big choice, each side a deed")
	_check(books.objective.contains("颜违") and books.objective.contains("旧盟主") and books.objective.contains("春风快意刀") and books.objective.contains("人证物证"), "what either side costs is said before the choice")
	var jianqiu: NpcDefinition = catalog.npc(JIANQIU)
	var tianxing: NpcDefinition = catalog.npc(TIANXING)
	_check(jianqiu.talk().ask_confirm("到此为止").contains("颜违") and tianxing.talk().ask_confirm("查到底").contains("旧盟主"), "到此为止 and 查到底 are asked first, the vote said")
	var rules: Array[NpcTeaching.RecognizeRule] = jianqiu.teaching().recognize_rules
	_check(rules.size() == 1 and rules[0].accept and rules[0].skills == [&"spring-blade"], "陈剑秋 teaches the one who stopped it 春风快意刀, that only")
	for id: String in ["assembly.zhenyuan.self", "assembly.day.zhenyuan.backs", "assembly.day.zhenyuan.self"]:
		_check(catalog.conditions().has(id), "%s exists" % id)


## The 虹台's 振远 vote: no line as before; the split decides; 「这一票」 after; the day's tallies count 振远.
func _test_votes() -> void:
	var state: CharacterState = _fresh(["终章"])
	_check(_holds(state, "assembly.zhenyuan.yan") and not _holds(state, "assembly.zhenyuan.stated"), "no line: 颜违, not yet stated (as 大会 A)")
	state = _fresh(["终章", "振远改投旧盟主"])
	_check(_holds(state, "assembly.zhenyuan.old"), "no split, 改投: 旧盟主 (as 大会 A)")
	state = _fresh(["终章", "振远改投旧盟主", "振远旧账到此为止", "振远的票随了到此为止"])
	_check(_holds(state, "assembly.zhenyuan.stated") and _holds(state, "assembly.zhenyuan.yan") and not _holds(state, "assembly.zhenyuan.old"), "到此为止: stated, 颜违 (an earlier 改投 does not undo it)")
	state = _fresh(["振远旧账查到底", "振远的票随了查到底"])
	_check(_holds(state, "assembly.zhenyuan.stated") and _holds(state, "assembly.zhenyuan.old") and not _holds(state, "assembly.zhenyuan.yan"), "查到底: stated, 旧盟主")
	state = _fresh(["终章", "振远旧账到此为止", "振远的票随了到此为止"])
	_check(_heard(state, JIANQIU, "虹台", "开口就是") and state.marks.has("振远肯听你的") and _listed(state, JIANQIU, "这一票") and not _listed(state, TIANXING, "这一票"), "到此为止: 陈剑秋 offers the vote")
	_check(_heard(state, JIANQIU, "这一票", "你说了算") and _holds(state, "assembly.zhenyuan.self") and not _holds(state, "assembly.zhenyuan.yan") and not _holds(state, "assembly.zhenyuan.old"), "这一票: 振远听你的, neither 颜违 nor 旧盟主")
	_check(_heard(state, JIANQIU, "改投", "不改"), "到此为止: no 改投")
	state = _fresh(["终章", "振远旧账查到底", "振远的票随了查到底"])
	_check(_heard(state, JIANQIU, "虹台", "去京师问他") and not state.marks.has("振远肯听你的"), "查到底: 陈剑秋 sends you to 陈天星")
	_check(_heard(state, TIANXING, "虹台", "你要这一票") and _listed(state, TIANXING, "这一票") and not _listed(state, JIANQIU, "这一票"), "查到底: 陈天星 offers the vote")
	_check(_heard(state, TIANXING, "这一票", "你说了算") and _holds(state, "assembly.zhenyuan.self"), "这一票: 振远听你的")
	state.marks["入了虹台的席"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.day.zhenyuan.backs") and not _holds(state, "assembly.day.zhenyuan.yan") and not _holds(state, "assembly.day.zhenyuan.old"), "on the day: 振远 came and 听你的")
	state.marks["听你的投旧盟主"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.day.zhenyuan.old") and not _holds(state, "assembly.day.zhenyuan.self"), "sent to the old 盟主")
	state = _fresh(["入了虹台的席", "振远听你的", "站出来参选"])
	_check(_holds(state, "assembly.day.zhenyuan.self"), "you stood: 振远 votes you")
	var five: Array = ["入了虹台的席", "站出来参选", "侮天鬼灭了", "振远听你的", "封山听你的", "天邪听你的", "茅山听你的", "晚月庄听你的", "振远表了态", "封山表了态", "天邪表了态", "茅山表了态", "晚月庄表了态"]
	state = _fresh(five)
	_check(_holds(state, "assembly.day.can_stand") and _holds(state, "assembly.day.self_wins") and _holds(state, "assembly.self_backed"), "振远 is one of the five that may 听你的 (§11 Q9)")
	state = _fresh(["振远旧账到此为止"])
	_check(not _holds(state, "assembly.self_backed"), "到此为止 alone gives no vote")
	# 修补 Z (DECISIONS「振远 B」): the split after one sat on the 虹台 happens, the vote stays as it was.
	state = _fresh(["终章", "陈剑秋说了抚恤银", "振远改投旧盟主", "入了虹台的席"])
	_check(_heard(state, JIANQIU, "到此为止", "多谢") and state.marks.has("振远旧账到此为止") and not state.marks.has("振远的票随了到此为止") and _holds(state, "assembly.zhenyuan.old"), "到此为止 after 入席: the vote stays 旧盟主")
	state = _fresh(["终章", "陈剑秋说了抚恤银", "入了虹台的席"])
	_check(_heard(state, TIANXING, "查到底", "查到底") and state.marks.has("振远旧账查到底") and not state.marks.has("振远的票随了查到底") and _holds(state, "assembly.zhenyuan.yan"), "查到底 after 入席: the vote stays 颜违")
	_check(_heard(state, TIANXING, "虹台", "剑秋去坐") and not state.marks.has("振远肯听你的") and _heard(state, JIANQIU, "虹台", "颜违"), "and neither says otherwise: 陈天星 does not claim the vote, 陈剑秋 says 颜违")
	state = _fresh(["终章", "陈剑秋说了抚恤银", "镖路查清了"])
	_check(_heard(state, TIANXING, "查到底", "查到底") and state.marks.has("振远的票随了查到底") and _holds(state, "assembly.zhenyuan.old"), "查到底 before 入席: the vote follows")
	_check(_heard(_fresh(["终章", "大会散了"]), TIANXING, "虹台", "照旧走镖") and _heard(_fresh(["终章", "大会散了", "振远旧账查到底"]), TIANXING, "虹台", "县衙"), "after the 虹台: the 县衙 only for the one who dug")
	_check(_heard(_fresh(["振远旧账查到底"]), TIANXING, "镖单", "押去乔阴县衙"), "查到底: 陈天星 no longer holds the books")
	var act: String = FileAccess.get_file_as_string("res://data/waterfog/world.json")
	_check(act.contains("你，六票。"), "six that 听你的 are counted as six")
	_check(act.contains("振远镖局——投你。") and act.contains("振远这一票，在你手里。") and act.contains("那本账烧了") and act.contains("天星把账送进了县衙"), "the 虹台's day speaks to the split and counts 振远 for you")


## Handed to the 官府, no 天邪 line: 陈天星 tells the 旧账 from 贺平's word; 到此为止 at 陈剑秋 (春风快意刀; 镖路 stays
## unknown); next time in 京师 陈天星 burns the book; the 声望 page.
func _test_stop_handed(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.zhenyuan_delivered(session, false)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"ledger", "delivered: the 旧账 next")
	var hq: WorldMapController = MapPlaces.enter(session, HQ, HQ_POINT)
	await _beats(tree, session, 2)
	var chen: NpcRuntimeState = _first(session, HQ, TIANXING)
	_check(hq.select_npc(chen.character_id) and hq.ask_topics_selected().has("旧账") and not hq.ask_topics_selected().has("查到底"), "陈天星: 旧账 listed, 查到底 not yet")
	_check(_said(_ask(hq, chen, "旧账"), "供词") and state.marks.get("陈天星说了旧账", 0) == 1 and not state.marks.has("镖路查清了"), "旧账 from 贺平's word: the 抚恤银, the 镖路 still unknown")
	session.record_journal()
	_check(state.quests.has("faction.zhenyuan/ledger") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"uncle", "ledger done; 陈剑秋 next")
	var bureau: WorldMapController = MapPlaces.enter(session, BUREAU, BUREAU_POINT)
	await _beats(tree, session, 2)
	var jianqiu: NpcRuntimeState = _first(session, BUREAU, JIANQIU)
	_check(bureau.select_npc(jianqiu.character_id) and not bureau.ask_topics_selected().has("到此为止"), "到此为止 not before he has spoken")
	_check(_said(_ask(bureau, jianqiu, "旧账"), "十一个人") and state.marks.get("陈剑秋说了抚恤银", 0) == 1, "陈剑秋: 死了十一个人，兵部给钱，我拿了")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"books", "the split next")
	_check(catalog.npc(JIANQIU).teaching().recognize(&"", state.marks, &"spring-blade") == null, "before: no 春风快意刀 for the stranger")
	_check(jianqiu.definition().talk().confirm_applies("到此为止", state.marks), "到此为止 is asked first")
	_check(_said(_ask(bureau, jianqiu, "到此为止"), "春风快意刀") and state.marks.get("振远旧账到此为止", 0) == 1, "到此为止")
	_check(not jianqiu.definition().talk().confirm_applies("到此为止", state.marks), "not asked again")
	session.record_journal()
	_check(state.quests.has("faction.zhenyuan/books/stop") and state.quests.has("faction.zhenyuan#done") and DeedLog.done(state, "劝陈剑秋把振远的旧账烧了：到此为止"), "the line done, its deed")
	_check(catalog.npc(JIANQIU).teaching().recognize(&"", state.marks, &"spring-blade") != null and catalog.npc(JIANQIU).teaching().recognize(&"", state.marks, &"blade") == null, "陈剑秋 recognizes the one who stopped it, for 春风快意刀 only")
	var teacher: TeacherService = _teacher(session.active_map() as WorldMapController, JIANQIU)
	_check(teacher != null and teacher.teachable_skills() == [&"spring-blade"], "he teaches 春风快意刀 only (%s)" % [[] if teacher == null else teacher.teachable_skills()])
	_check(not state.marks.has("镖路查清了"), "到此为止: the 镖路 not known")
	hq = MapPlaces.enter(session, HQ, HQ_POINT)
	await _beats(tree, session, 3)
	_check(state.marks.get("陈天星烧了账本", 0) == 1, "陈天星 burns the book the next visit")
	chen = _first(session, HQ, TIANXING)
	_check(_said(_ask(hq, chen, "旧账"), "生意") and _said(_ask(hq, chen, "查到底"), "生意") and not chen.definition().talk().confirm_applies("查到底", state.marks), "陈天星 talks business only; 查到底 not asked")
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("抚恤银") and ui.standing_page.shown_text().contains("那本总账烧了"), "the 声望 page: %s" % ui.standing_page.shown_text())
	var missing: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.zhenyuan_settled.bind(true, false))
	_check(missing.is_empty(), "played leaves what zhenyuan_settled(stop, hand) writes: %s" % [missing])


## Let go with the letter (镖路查清了): 陈天星's 旧账 from the 镖路; 查到底 at 陈天星 before or after 陈剑秋 (not before);
## the 分局 shut next time in 绮云; 走镖 refused; the 虹台 voice.
func _test_dig_freed(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.zhenyuan_delivered(session, true)
	var hq: WorldMapController = MapPlaces.enter(session, HQ, HQ_POINT)
	await _beats(tree, session, 2)
	var chen: NpcRuntimeState = _first(session, HQ, TIANXING)
	_check(_said(_ask(hq, chen, "旧账"), "家信") and not state.marks.has("陈天星说了旧账"), "the letter not yet shown: 先给我看")
	_check(hq.select_npc(chen.character_id), "陈天星 selected")
	var given: ItemHandlingResult = hq.give_to_selected(_carried(session, LETTER))
	_check(given != null and state.marks.get("镖路查清了", 0) == 1, "the letter: 镖路查清了")
	_check(_said(_ask(hq, chen, "旧账"), "老松岭那一笔查清了") and state.marks.get("陈天星说了旧账", 0) == 1, "旧账 from the 镖路")
	_check(not chen.definition().talk().confirm_applies("查到底", state.marks), "查到底 not before 陈剑秋 has spoken")
	var bureau: WorldMapController = MapPlaces.enter(session, BUREAU, BUREAU_POINT)
	await _beats(tree, session, 2)
	_ask(bureau, _first(session, BUREAU, JIANQIU), "旧账")
	hq = MapPlaces.enter(session, HQ, HQ_POINT)
	await _beats(tree, session, 2)
	chen = _first(session, HQ, TIANXING)
	_check(chen.definition().talk().confirm_applies("查到底", state.marks), "查到底 is asked first")
	_check(_said(_ask(hq, chen, "查到底"), "乔阴县衙") and state.marks.get("振远旧账查到底", 0) == 1, "查到底: the book to the 县衙")
	session.record_journal()
	_check(state.quests.has("faction.zhenyuan/books/dig") and state.quests.has("faction.zhenyuan#done"), "the line done")
	_check(not catalog.npc(JIANQIU).talk().confirm_applies("到此为止", state.marks), "the other side closed")
	bureau = MapPlaces.enter(session, BUREAU, BUREAU_POINT)
	await _beats(tree, session, 3)
	var jianqiu: NpcRuntimeState = _first(session, BUREAU, JIANQIU)
	_check(state.marks.get("陈剑秋关了分局", 0) == 1, "陈剑秋 shuts the 分局 the next visit")
	_check(_said(_ask(bureau, jianqiu, "走镖"), "不接镖") and catalog.npc(JIANQIU).teaching().recognize(&"", state.marks, &"spring-blade") == null, "no 镖, no 春风快意刀 for the one who dug")
	var missing: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.zhenyuan_settled.bind(false, true))
	_check(missing.is_empty(), "played leaves what zhenyuan_settled(dig, free) writes: %s" % [missing])


## Handed to the 官府 and 查到底: the book makes the 镖路 known — one of the 揭发's proofs, once.
func _test_dig_handed_proof(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.zhenyuan_delivered(session, false)
	for mark: String in ["陈天星说了旧账", "陈剑秋说了抚恤银"]:
		state.marks[mark] = 1 # TEST-ONLY: both have spoken
	var hq: WorldMapController = MapPlaces.enter(session, HQ, HQ_POINT)
	await _beats(tree, session, 2)
	_check(not state.marks.has("镖路查清了"), "before: the 镖路 unknown")
	_check(_said(_ask(hq, _first(session, HQ, TIANXING), "查到底"), "点名要的") and state.marks.get("镖路查清了", 0) == 1, "查到底: the 底账 too — 镖路查清了")
	var proof: String = FileAccess.get_file_as_string("res://data/imperial/world.json")
	_check(proof.contains("\"mark\": \"镖路查清了\""), "镖路查清了 is one of the 揭发's proofs (imperial/world.json)")
	session.record_journal()
	_check(session.player_runtime().state.quests.has("faction.zhenyuan/books/dig"), "the line done")


func _fresh(marks: Array) -> CharacterState:
	var state := CharacterState.new()
	for mark: String in marks:
		state.marks[mark] = 1 # TEST-ONLY
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
		state.marks[rule.mark_asker] = 1 # TEST-ONLY: as the ask records it
	for mark: String in rule.marks_asker:
		state.marks[mark] = 1 # TEST-ONLY
	return rule.lines.any(func(line: NpcLine) -> bool: return line.text.contains(part))


func _listed(state: CharacterState, npc: StringName, topic: String) -> bool:
	return GameContent.catalog().npc(npc).talk().listed_for(topic, state.marks)


func _teacher(map: WorldMapController, npc_id: StringName) -> TeacherService:
	if map == null:
		return null
	for service: WorldService in map.service_nodes:
		var teacher: TeacherService = service as TeacherService
		if teacher != null and teacher.npc != null and NpcDefinition.unnamed_id(teacher.npc.definition().definition_id) == npc_id:
			return teacher
	return null


func _beats(tree: SceneTree, session: WorldSessionController, seconds: int) -> void:
	await _settle(tree)
	for second: int in seconds:
		session.advance_npc_heartbeat(1.0)
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
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				return npc
	return null


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("振远", CharacterState.GENDER_MALE)
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


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
