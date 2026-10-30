extends RefCounted

## 第四章 宝衣 (owner's plan, 2026-10-30; DECISIONS「第四章 宝衣」), from the two third-chapter ledgers
## (StoryFixtures), three sessions:
## - kept (rescued, a woman): 潘军禅 says 归月神族保管; the manor; 安妮儿 waits; 瑷伦 admits the robe and
##   asks for her three lashes (her story trial on the popup, not her 拜师); stood, her one question,
##   answered 斩鬼 (she names the dance to a woman); the second 密室's 八卦图 offers 有凤来仪, danced the
##   冰匣 open, the robe at her feet; given back to 瑷伦: her mood 守衣, the quest done, the manor as it was.
## - taken (chased, a man): 南危水 says it; the trial; 不知道 answered (no dance for a man); his own
##   有凤来仪 is 不得要领; 芳绫 asked to dance follows him (her mood), dances the 冰匣 open and stops
##   following; the robe cannot be given to 蓝筱薇 (give_to); carried out of the gate: 带走; 瑷伦 refuses
##   it back; the night on the next visit: the 婢女 and 昭蓉 dead on the floor, the 东方神教杀手 in the
##   前厅 (attacks; spared, her 令牌 falls), 芙云, 梦玉楼 and the 凤凰 gone, 瑷伦, 安妮儿 and the 老妇 speak.
## - annie (rescued, a man): 蓝筱薇 fetched from the 内厅 dances; the robe given to 安妮儿: 配得上.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const ROBE: StringName = &"native:latemoon/cold_robe"
const TOKEN: StringName = &"es2:d/latemoon/room/npc/obj/token"
const CLUMSY: String = "你在卦象中跳起舞来。但似乎不得要领！"
const GONE_LINE: String = "这样东西不能随便给人。"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var kept: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE)
	await _test_kept(tree, kept)
	kept.free()
	await tree.process_frame
	var taken: WorldSessionController = await _session(tree, CharacterState.GENDER_MALE)
	await _test_taken(tree, taken)
	taken.free()
	await tree.process_frame
	var annie: WorldSessionController = await _session(tree, CharacterState.GENDER_MALE)
	await _test_annie(tree, annie)
	annie.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.chapter4")
	_check(quest != null and quest.requires == [&"main.chapter3"] and quest.steps.size() == 8 and quest.steps[7].options.size() == 3, "the chapter: eight steps after the third, a three-way end")
	var robe: ItemContentDefinition = catalog.item(ROBE)
	_check(robe != null and robe.no_drop and robe.give_to == [&"latemoon.npc.room.elon", &"latemoon.npc.room.annihi"] and robe.category == ItemContentDefinition.CATEGORY_ARMOR, "the 宝衣: worn, no_drop, given only to 瑷伦 or 安妮儿")
	var elon: NpcDefinition = catalog.npc(&"latemoon.npc.room.elon")
	_check(elon != null and elon.hooks() != null and elon.hooks().trials.size() == 1 and elon.hooks().trials[0].blows.size() == 3 and elon.hooks().trials[0].mark == "接下了瑷伦三鞭" and elon.teaching().apprentice.kind == NpcTeaching.Kind.TRIAL, "瑷伦: her story trial of three lashes beside her 拜师 trial")
	var floor_mi: ServiceDefinition = catalog.service(&"latemoon.miroom.dance")
	_check(floor_mi != null and floor_mi.dance.steps.size() == 2 and floor_mi.dance.steps[0].gender == "女性" and floor_mi.dance.steps[0].act != null and floor_mi.dance.steps[0].unless_mark == "冰匣开了" and floor_mi.dance.steps[1].always, "the second 密室's 八卦图: 有凤来仪 (women, the 冰匣's act) and 西出阳关 for anyone")
	var killer: NpcDefinition = catalog.npc(&"native.npc.cult_killer")
	_check(killer != null and killer.hooks() != null and killer.hooks().spared_drop == TOKEN and killer.hooks().die_item_id == TOKEN, "the killer unmasked: her 令牌 falls spared or dead")


## A woman from the rescue: the lead, the trial, 斩鬼, her own dance, the robe kept by 瑷伦.
func _test_kept(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter4")
	StoryFixtures.chapter3_rescued(session)
	session.record_journal()
	_check(state.quests.has("main.chapter4#started") and StoryQuestLog.objective(state, quests).begins_with("寒於的宝衣在哪"), "the chapter begins as the third ends: %s" % [StoryQuestLog.objective(state, quests)])
	# 潘军禅 in the 水烟阁's hall (TEST-ONLY: straight there).
	var pavilion: WorldMapController = MapPlaces.enter(session, &"waterfog.entrance", &"waterfog.entrance.yard_arrival")
	_check(pavilion != null, "in the pavilion")
	await _settle(tree)
	var pan: NpcRuntimeState = await _beside(tree, session, pavilion, &"waterfog.guildhall.executioner.1")
	var said: Array[String] = _ask(pavilion, pan, "宝衣")
	session.record_journal()
	_check(said.any(func(line: String) -> bool: return line.contains("归月神族保管")) and state.marks.get("潘军禅说了宝衣", 0) == 1 and state.quests.has("main.chapter4/lead/pan") and StoryQuestLog.objective(state, quests).begins_with("去晚月庄"), "潘军禅: 归月神族保管, 晚月庄; the manor next: %s" % [said])
	_check(_ask(pavilion, pan, "宝衣").any(func(line: String) -> bool: return line.contains("我说过了")), "asked again: said")
	# The manor's 前厅 (TEST-ONLY: straight there), then the west wing.
	var manor: WorldMapController = MapPlaces.enter(session, &"latemoon.latemoon1", &"latemoon.latemoon1.dance_arrival")
	_check(manor != null, "in the 前厅")
	await _settle(tree)
	session.record_journal()
	_check(state.quests.has("main.chapter4/manor") and StoryQuestLog.objective(state, quests).begins_with("西厢的客人安妮儿"), "the 前厅 reached; 安妮儿 next")
	_check(_count_in(session, &"latemoon.latemoon1", &"latemoon.npc.servant") == 2 and _count_in(session, &"latemoon.latemoon1", &"native.npc.cult_killer") == 0, "two 婢女, no killer: the manor as ES2 made it")
	var annie: NpcRuntimeState = await _beside(tree, session, manor, &"latemoon.room.westroom.annihi.1")
	said = _ask(manor, annie, "宝衣")
	session.record_journal()
	_check(said.any(func(line: String) -> bool: return line.contains("配得上它的人")) and state.marks.get("安妮儿说了等", 0) == 1 and state.quests.has("main.chapter4/annie"), "安妮儿 waits for one who is worthy")
	# 瑷伦: her admission, her trial, her question.
	var elon: NpcRuntimeState = await _beside(tree, session, manor, &"latemoon.room.eastroom.elon.1")
	_check(manor.npc_life.story_trials_offered(elon).is_empty(), "no lashes offered before she is asked")
	said = _ask(manor, elon, "宝衣")
	session.record_journal()
	_check(said.any(func(line: String) -> bool: return line.contains("接我三鞭")) and state.marks.get("瑷伦说了三鞭", 0) == 1 and state.quests.has("main.chapter4/keeper") and StoryQuestLog.objective(state, quests).begins_with("接瑷伦三鞭"), "瑷伦: 守了几百年, 接我三鞭: %s" % [said])
	var trials: Array[NpcTrial] = manor.npc_life.story_trials_offered(elon)
	_check(trials.size() == 1 and trials[0].label == "接她三鞭" and trials[0].confirm.begins_with("瑷伦的三鞭是真打"), "her trial is now a row of the popup, asked first")
	state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY: stand the lashes
	var result: NpcApprenticeTrial.Result = manor.npc_life.take_story_trial(elon, trials[0])
	await _told(tree, session, manor, elon)
	_check(result.outcome == NpcApprenticeTrial.Outcome.PASSED and result.blows == 3 and state.marks.get("接下了瑷伦三鞭", 0) == 1 and DeedLog.done(state, "接下了守衣人瑷伦的三鞭"), "three lashes stood: the mark and the deed; outcome %s" % result.outcome)
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("小心了，这是第一鞭")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("站得住。那就再问你一句")), "elon.c's lines, then her question: %s" % [ui.log_lines().slice(maxi(0, ui.log_lines().size() - 8))])
	_check(manor.npc_life.story_trials_offered(elon).is_empty() and not NpcApprenticeship.is_master_of(state, elon.definition()), "not offered twice; no 拜师 came of it")
	session.record_journal()
	_check(state.quests.has("main.chapter4/lashes") and StoryQuestLog.objective(state, quests).begins_with("瑷伦问"), "the question next: %s" % [StoryQuestLog.objective(state, quests)])
	said = _ask(manor, elon, "为了斩鬼")
	session.record_journal()
	_check(said.any(func(line: String) -> bool: return line.contains("冰匣")) and said.any(func(line: String) -> bool: return line.contains("我教你记住它的名字")) and state.marks.get("答瑷伦：斩鬼", 0) == 1 and state.marks.get("瑷伦说了冰匣", 0) == 1 and state.marks.get("dance_yu_fong", 0) == 1, "斩鬼: the 冰匣, and a woman learns the dance's name: %s" % [said])
	_check(state.quests.has("main.chapter4/question/slay") and DeedLog.done(state, "对守衣人说，要拿寒於宝衣去斩鬼") and StoryQuestLog.objective(state, quests).begins_with("宝衣在第二密室"), "the answer recorded, the 冰匣 next")
	_check(_ask(manor, elon, "不知道").any(func(line: String) -> bool: return line.contains("你答过了")), "one answer only")
	# The second 密室 (TEST-ONLY: straight there): her own 有凤来仪 opens the 冰匣.
	var secret: WorldMapController = MapPlaces.enter(session, &"latemoon.miroom", &"latemoon.miroom.dance_arrival")
	_check(secret != null, "in the second 密室")
	await _settle(tree)
	_check(secret.select_landmark(&"latemoon.miroom.landmark.ice_chest") and secret.inspect_selected() and ui.inspection_text.text.contains("凤仪起，匣自开"), "the 冰匣 looked at")
	ui.dismiss_current_panel()
	var floor_mi: DanceService = secret.service(&"latemoon.miroom.dance") as DanceService
	_check(secret.place_player(&"latemoon.miroom", Vector2(330, 740)), "TEST-ONLY: by the 八卦图")
	await _settle(tree)
	_check(floor_mi != null and floor_mi.in_reach(), "on the 八卦图")
	var names: Array[String] = []
	for step: DanceDefinition.Step in floor_mi.known_steps():
		names.append(step.name)
	_check(names == ["有凤来仪", "西出阳关"], "both dances offered here now: %s" % [names])
	state.spirit = CharacterResourceState.new(200, 200, 200) # TEST-ONLY
	var danced: DanceDefinition.Result = floor_mi.dance(floor_mi.known_steps()[0])
	await _settle(tree)
	_check(not danced.refused and danced.act != null and danced.portal_id.is_empty() and state.spirit.current == 150 and session.active_map_id() == &"latemoon.secret", "「有凤来仪」 here: 50 sen, nobody moves")
	_check(not secret.floor_item_of(ROBE, &"latemoon.miroom").is_empty() and state.marks.get("冰匣开了", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("冰匣的盖子无声地滑开了")), "the 冰匣 opens, the robe on the floor")
	session.record_journal()
	_check(state.quests.has("main.chapter4/chest") and StoryQuestLog.objective(state, quests).begins_with("宝衣到手"), "the choice next: %s" % [StoryQuestLog.objective(state, quests)])
	names.clear()
	for step: DanceDefinition.Step in floor_mi.known_steps():
		names.append(step.name)
	_check(names == ["西出阳关"], "the 冰匣 danced open: only the way out is offered")
	var robe: StringName = secret.floor_item_of(ROBE, &"latemoon.miroom")
	_check(secret.select_floor_item(robe) and secret.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN, "picked up")
	# Back to 瑷伦 (TEST-ONLY: straight there): the robe given back is kept.
	manor = MapPlaces.enter(session, &"latemoon.latemoon1", &"latemoon.latemoon1.dance_arrival")
	await _settle(tree)
	elon = await _beside(tree, session, manor, &"latemoon.room.eastroom.elon.1")
	_check(manor.select_npc(elon.character_id), "瑷伦 selected")
	var given: ItemHandlingResult = manor.give_to_selected(robe)
	session.record_journal()
	_check(given.done() and given.lines.any(func(line: String) -> bool: return line.contains("我守到决战那日")) and state.marks.get("瑷伦守到决战", 0) == 1, "given back: 我守到决战那日: %s" % [given.lines])
	_check(elon.has_flag(StringName(NpcMood.FLAG_PREFIX + "keeping")) and elon.definition().hooks().moods["keeping"].title == "守衣人" and elon.definition().hooks().moods["keeping"].lasting and _carries(manor, elon, ROBE), "her mood 守衣 (lasting), the robe on her")
	_check(state.quests.has("main.chapter4/choice/keep") and StoryQuestLog.is_done(state, quest) and DeedLog.done(state, "把寒於宝衣留给了守衣人瑷伦") and DeedLog.done(state, "找到了寒於宝衣") and state.marks.get("宝衣一章", 0) == 1, "the chapter done by keeping")
	_check(_ask(manor, elon, "宝衣").any(func(line: String) -> bool: return line.contains("衣在我身上")), "瑷伦: 衣在我身上")
	# The manor as it was: out and in again.
	var road: WorldMapController = MapPlaces.enter(session, &"cloud.wroad0", &"cloud.wroad0.latemoon_return")
	_check(road != null, "out to the road")
	manor = MapPlaces.enter(session, &"latemoon.latemoon1", &"latemoon.latemoon1.dance_arrival")
	await _settle(tree)
	_check(manor != null and _count_in(session, &"latemoon.latemoon1", &"latemoon.npc.servant") == 2 and _count_in(session, &"latemoon.latemoon1", &"native.npc.cult_killer") == 0 and _count_in(session, &"latemoon.room.bathroom", &"latemoon.npc.room.fireangel") == 1 and _count_in(session, &"latemoon.room.lstudio", &"latemoon.npc.room.killer") == 1, "kept: the 婢女, the 凤凰 and the 书房's killer where ES2 put them")
	var snapshot: GameSaveSnapshot = _capture(session)
	_check(snapshot != null, "Save")


## A man from the chase: 南危水, the trial, 不知道, his clumsy dance, 芳绫's, the robe carried out; the night.
func _test_taken(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter4")
	StoryFixtures.chapter3_chased(session)
	session.record_journal()
	_check(state.quests.has("main.chapter4#started"), "the chapter begins after the chase too")
	# 南危水 upstairs (kept his secret: the fixture's second chapter).
	var upstairs: WorldMapController = MapPlaces.enter(session, &"waterfog.west_2f", &"waterfog.west_2f.stairs_arrival")
	_check(upstairs != null, "upstairs")
	await _settle(tree)
	var nan: NpcRuntimeState = await _beside(tree, session, upstairs, &"waterfog.forehall.elder5.1")
	var said: Array[String] = _ask(upstairs, nan, "宝衣")
	session.record_journal()
	_check(said.any(func(line: String) -> bool: return line.contains("老夫欠你一桩事")) and said.any(func(line: String) -> bool: return line.contains("月神族")) and state.marks.get("南危水说了宝衣", 0) == 1 and state.quests.has("main.chapter4/lead/nan"), "南危水, to one who kept his secret: %s" % [said])
	# The manor: 安妮儿, 瑷伦, the lashes, 不知道 (no dance for a man).
	var manor: WorldMapController = MapPlaces.enter(session, &"latemoon.latemoon1", &"latemoon.latemoon1.dance_arrival")
	await _settle(tree)
	session.record_journal()
	var annie: NpcRuntimeState = await _beside(tree, session, manor, &"latemoon.room.westroom.annihi.1")
	_ask(manor, annie, "宝衣")
	var elon: NpcRuntimeState = await _beside(tree, session, manor, &"latemoon.room.eastroom.elon.1")
	_ask(manor, elon, "宝衣")
	session.record_journal()
	state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY
	var trials: Array[NpcTrial] = manor.npc_life.story_trials_offered(elon)
	_check(trials.size() == 1, "a man is offered her lashes too (her 拜师 is women's only)")
	_check(manor.npc_life.take_story_trial(elon, trials[0]).outcome == NpcApprenticeTrial.Outcome.PASSED, "stood")
	session.record_journal()
	said = _ask(manor, elon, "不知道")
	session.record_journal()
	_check(said.any(func(line: String) -> bool: return line.contains("男子跳不成")) and said.any(func(line: String) -> bool: return line.contains("芳绫")) and state.marks.get("答瑷伦：不知", 0) == 1 and state.marks.get("dance_yu_fong", 0) == 0, "不知道: a man is sent to 筱薇 or 芳绫, taught no dance: %s" % [said])
	_check(state.quests.has("main.chapter4/question/unsure") and StoryQuestLog.objective(state, quests).begins_with("宝衣在第二密室"), "the 冰匣 next")
	# 芳绫 in the 禁闭房 comes along.
	var funlin: NpcRuntimeState = await _beside(tree, session, manor, &"latemoon.latemoon6.funlin.1")
	said = _ask(manor, funlin, "替跳")
	_check(said.any(func(line: String) -> bool: return line.contains("带我去")) and funlin.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) and funlin.has_flag(StringName(NpcMood.FLAG_PREFIX + "going")) and state.marks.get("芳绫跟你去了", 0) == 1, "芳绫: 关着也闷死了, she follows: %s" % [said])
	_check(_ask(manor, funlin, "替跳").any(func(line: String) -> bool: return line.contains("走呀走呀")), "asked again on the way")
	# The second 密室 (TEST-ONLY: straight there, 芳绫 brought along as she would walk).
	var secret: WorldMapController = MapPlaces.enter(session, &"latemoon.miroom", &"latemoon.miroom.dance_arrival")
	_check(secret != null, "in the second 密室")
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	if _count_in(session, &"latemoon.miroom", &"latemoon.npc.funlin") == 0:
		_check(session.bring_npc_onto(funlin, manor, secret, &"latemoon.miroom"), "TEST-ONLY: 芳绫 brought along (she follows every way)")
	_check(_count_in(session, &"latemoon.miroom", &"latemoon.npc.funlin") == 1, "芳绫 came along into the 密室")
	# TEST-ONLY: a step out from under her feet (the route-finder treats her body as a wall),
	# to a spot within reach of the 八卦图 and of 请人替跳 beside it.
	_check(secret.place_player(&"latemoon.miroom", Vector2(330, 740)), "a step aside")
	await _settle(tree)
	var floor_mi: DanceService = secret.service(&"latemoon.miroom.dance") as DanceService
	_check(floor_mi != null and floor_mi.in_reach(), "the 八卦图 in reach")
	state.spirit = CharacterResourceState.new(300, 300, 300) # TEST-ONLY
	var known: Array[DanceDefinition.Step] = floor_mi.known_steps()
	_check(known.size() == 1 and known[0].name == "西出阳关", "a man who never heard the dance named: only the way out")
	var yu_fong: DanceDefinition.Step = floor_mi.definition.dance.steps[0]
	var clumsy: DanceDefinition.Result = floor_mi.dance(yu_fong)
	_check(not clumsy.refused and clumsy.act == null and ui.log_lines()[-1] == CLUMSY and state.spirit.current == 220 and secret.floor_item_of(ROBE, &"latemoon.miroom").is_empty(), "his own 有凤来仪: 不得要领, the 80 sen gone, the 冰匣 shut")
	var proxy: ActService = secret.service(&"latemoon.miroom.proxy_dance") as ActService
	_check(proxy != null and proxy.in_reach() and proxy.verb() == "请人替跳", "八卦图 · 请人替跳 in reach")
	proxy.interact()
	await _settle(tree)
	var lines: Array[String] = _recent(ui)
	_check(lines.any(func(line: String) -> bool: return line.contains("看我的")) and lines.any(func(line: String) -> bool: return line.contains("冰匣的盖子无声地滑开了")) and lines.any(func(line: String) -> bool: return line.contains("蓝姐姐要骂")), "芳绫 dances: %s" % [lines])
	_check(not secret.floor_item_of(ROBE, &"latemoon.miroom").is_empty() and state.marks.get("冰匣开了", 0) == 1 and state.marks.get("芳绫替你跳了", 0) == 1, "the 冰匣 open, the robe on the floor, the mark")
	_check(not funlin.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) and funlin.world_location().zone_id == &"latemoon.miroom", "芳绫 stops following (unfollow) and stays where she danced")
	session.record_journal()
	_check(state.quests.has("main.chapter4/chest"), "the 冰匣 step done by her dance")
	var robe: StringName = secret.floor_item_of(ROBE, &"latemoon.miroom")
	_check(secret.select_floor_item(robe) and secret.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN, "picked up")
	# The robe is nobody else's to take (give_to); worn, it still counts; dropping is refused.
	_check(secret.select_npc(funlin.character_id) and secret.give_to_selected(robe).lines.has(GONE_LINE) and session.player_held_item_ids().get(ROBE, false), "芳绫 cannot be given it: 这样东西不能随便给人")
	_check(secret.drop_item(robe).lines.any(func(line: String) -> bool: return line.contains("这件衣不能随便丢")) and session.player_held_item_ids().get(ROBE, false), "nor dropped")
	# TEST-ONLY: the 布衣 off first (one piece of cloth at a time, as wear.c has it).
	for slot: StringName in session.player_runtime().armor.occupied_slots():
		var before: EquippedArmorRef = session.player_runtime().armor.equipped_ref_in_slot(slot)
		if before != null and before.armor_type == &"cloth":
			session.remove_player_item(before.item_instance_id)
	var worn: OldPineArmorInteractionResult = session.wear_player_item(robe)
	_check(worn.succeeded and session.player_worn_item_ids().get(ROBE, false), "worn: outcome %s, worn %s" % [worn.outcome, session.player_worn_item_ids()])
	if session.player_worn_item_ids().get(ROBE, false):
		_check(session.remove_player_item(robe).succeeded, "and taken off again, to carry it out")
	# Out of the gate with it: 带走.
	manor = MapPlaces.enter(session, &"latemoon.entrance", &"latemoon.entrance.cloud_entry")
	await _settle(tree)
	session.record_journal()
	_check(manor != null and state.quests.has("main.chapter4/choice/take") and state.marks.get("带走了宝衣", 0) == 1 and StoryQuestLog.is_done(state, quest) and DeedLog.done(state, "带走了寒於宝衣"), "out of the gate wearing it: 带走, the chapter done")
	# 瑷伦 will not have it back (TEST-ONLY: straight to her); then the night: out, and in again.
	elon = await _beside(tree, session, manor, &"latemoon.room.eastroom.elon.1")
	_check(manor.select_npc(elon.character_id), "瑷伦 selected")
	var refused: ItemHandlingResult = manor.give_to_selected(robe)
	_check(refused.lines.any(func(line: String) -> bool: return line.contains("出了庄门的衣")) and session.player_held_item_ids().get(ROBE, false), "瑷伦 refuses the robe that left: 出了庄门的衣: %s" % [refused.lines])
	var road: WorldMapController = MapPlaces.enter(session, &"cloud.wroad0", &"cloud.wroad0.latemoon_return")
	_check(road != null, "out to the road")
	manor = MapPlaces.enter(session, &"latemoon.latemoon1", &"latemoon.latemoon1.dance_arrival")
	_check(manor != null, "and in again: the night")
	await _settle(tree)
	_check(_count_in(session, &"latemoon.latemoon1", &"latemoon.npc.servant") == 0 and _floor_count(manor, &"native:latemoon/body_maid") == 2, "the two 婢女 dead on the 前厅's floor")
	_check(_count_in(session, &"latemoon.latemoon2", &"latemoon.npc.zauron") == 0 and _floor_count(manor, &"native:latemoon/body_zhaorong") == 1, "昭蓉 dead at the 内厅's door")
	_check(_count_in(session, &"latemoon.room.lstudio", &"latemoon.npc.room.killer") == 0 and _count_in(session, &"latemoon.latemoon1", &"native.npc.cult_killer") == 1, "the 书房's masked killer gone; the 东方神教杀手 in the 前厅")
	_check(_count_in(session, &"latemoon.room.guest1", &"latemoon.npc.room.guest") == 0 and _count_in(session, &"latemoon.room.guest2", &"latemoon.npc.room.tguest") == 0 and _count_in(session, &"latemoon.room.bathroom", &"latemoon.npc.room.fireangel") == 0, "芙云, 梦玉楼 gone; the 凤凰 dark (庄失去护佑)")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(session.combat_encounter_coordinator().has_active_encounter(), "she falls on the player")
	var killer: NpcRuntimeState = MapPlaces.npc_at(session, &"latemoon.latemoon1.cult_killer.1")
	# TEST-ONLY: 放过 as she lay — her mood, the mark, the 令牌 dropped for the 老妇's chain.
	session.npc_spared(killer)
	await _flee(tree, session)
	_check(killer.has_flag(StringName(NpcMood.FLAG_PREFIX + "seen")) and state.marks.get("放过了神教杀手", 0) == 1 and not manor.floor_item_of(TOKEN, &"latemoon.latemoon1").is_empty(), "spared: 认出, the mark, her 令牌 on the floor")
	# The three who speak of it.
	elon = await _beside(tree, session, manor, &"latemoon.room.eastroom.elon.1")
	_check(elon.has_flag(StringName(NpcMood.FLAG_PREFIX + "bereft")) and state.marks.get("瑷伦叹过", 0) == 1 and _recent(ui).any(func(line: String) -> bool: return line.contains("那是衣走了的价钱")), "瑷伦: 衣出了庄 (her mood 失衣)")
	annie = await _beside(tree, session, manor, &"latemoon.room.westroom.annihi.1")
	_check(annie.has_flag(StringName(NpcMood.FLAG_PREFIX + "remembers")) and _recent(ui).any(func(line: String) -> bool: return line.contains("你的名字，我记下了")), "安妮儿: 记住你")
	var old: NpcRuntimeState = await _beside(tree, session, manor, &"latemoon.room.lstudio.old.1")
	_check(old.has_flag(StringName(NpcMood.FLAG_PREFIX + "broken")) and _recent(ui).any(func(line: String) -> bool: return line.contains("我一直没拦住")), "the 老妇: 是她")
	var snapshot: GameSaveSnapshot = _capture(session)
	_check(snapshot != null, "Save")


## A man from the rescue who gives the robe to 安妮儿, 蓝筱薇 having danced for him.
func _test_annie(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter4")
	StoryFixtures.chapter3_rescued(session)
	session.record_journal()
	var pavilion: WorldMapController = MapPlaces.enter(session, &"waterfog.entrance", &"waterfog.entrance.yard_arrival")
	await _settle(tree)
	_ask(pavilion, await _beside(tree, session, pavilion, &"waterfog.guildhall.executioner.1"), "宝衣")
	var manor: WorldMapController = MapPlaces.enter(session, &"latemoon.latemoon1", &"latemoon.latemoon1.dance_arrival")
	await _settle(tree)
	session.record_journal()
	var annie: NpcRuntimeState = await _beside(tree, session, manor, &"latemoon.room.westroom.annihi.1")
	_ask(manor, annie, "宝衣")
	var elon: NpcRuntimeState = await _beside(tree, session, manor, &"latemoon.room.eastroom.elon.1")
	_ask(manor, elon, "宝衣")
	session.record_journal()
	state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY
	manor.npc_life.take_story_trial(elon, manor.npc_life.story_trials_offered(elon)[0])
	session.record_journal()
	var said: Array[String] = _ask(manor, elon, "交给安妮儿")
	session.record_journal()
	_check(said.any(func(line: String) -> bool: return line.contains("拿得走就拿")) and state.marks.get("答瑷伦：给安妮儿", 0) == 1 and state.quests.has("main.chapter4/question/for_annie"), "交给安妮儿: she does not stop him: %s" % [said])
	# 蓝筱薇 from the 内厅 next door.
	var secret: WorldMapController = MapPlaces.enter(session, &"latemoon.miroom", &"latemoon.miroom.dance_arrival")
	_check(secret != null, "in the second 密室")
	await _settle(tree)
	_check(_count_in(session, &"latemoon.miroom2", &"latemoon.npc.shaowei") == 1, "蓝筱薇 in the 内厅")
	var proxy: ActService = secret.service(&"latemoon.miroom.proxy_dance") as ActService
	_check(await MapPlaces.drive(tree, secret, MapPlaces.service_spot(secret, &"latemoon.miroom.proxy_dance")) and proxy.in_reach(), "at the 八卦图")
	proxy.interact()
	await _settle(tree)
	var lines: Array[String] = _recent(ui)
	_check(lines.any(func(line: String) -> bool: return line.contains("替你跳一支")) and lines.any(func(line: String) -> bool: return line.contains("原来是要给人跳的")), "蓝筱薇 comes and dances: %s" % [lines])
	_check(_count_in(session, &"latemoon.miroom", &"latemoon.npc.shaowei") == 1 and state.marks.get("蓝筱薇替你跳了", 0) == 1 and state.marks.get("冰匣开了", 0) == 1, "she stands here now; the 冰匣 open")
	var robe: StringName = secret.floor_item_of(ROBE, &"latemoon.miroom")
	_check(not robe.is_empty() and secret.select_floor_item(robe) and secret.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN, "the robe picked up")
	proxy.interact()
	await _settle(tree)
	_check(_recent(ui, 3).any(func(line: String) -> bool: return line.contains("冰匣已经开了")), "asked again: 冰匣已经开了: %s" % [_recent(ui, 3)])
	# To 安妮儿.
	manor = MapPlaces.enter(session, &"latemoon.latemoon1", &"latemoon.latemoon1.dance_arrival")
	await _settle(tree)
	annie = await _beside(tree, session, manor, &"latemoon.room.westroom.annihi.1")
	_check(manor.select_npc(annie.character_id), "安妮儿 selected")
	var given: ItemHandlingResult = manor.give_to_selected(robe)
	session.record_journal()
	_check(given.done() and given.lines.any(func(line: String) -> bool: return line.contains("东方神教记得你")) and state.marks.get("宝衣给了安妮儿", 0) == 1 and annie.has_flag(StringName(NpcMood.FLAG_PREFIX + "worthy")), "given to 安妮儿: 配得上: %s" % [given.lines])
	_check(state.quests.has("main.chapter4/choice/to_annie") and StoryQuestLog.is_done(state, quest) and DeedLog.done(state, "把寒於宝衣交给了东方神教的安妮儿"), "the chapter done by the hidden way")
	_check(_ask(manor, annie, "宝衣").any(func(line: String) -> bool: return line.contains("它在我这里")), "安妮儿: 它在我这里")
	# The night follows this way too.
	var road: WorldMapController = MapPlaces.enter(session, &"cloud.wroad0", &"cloud.wroad0.latemoon_return")
	_check(road != null, "out")
	manor = MapPlaces.enter(session, &"latemoon.latemoon1", &"latemoon.latemoon1.dance_arrival")
	await _settle(tree)
	_check(manor != null and _count_in(session, &"latemoon.latemoon1", &"native.npc.cult_killer") == 1 and _count_in(session, &"latemoon.room.bathroom", &"latemoon.npc.room.fireangel") == 0, "the night: the killer in the 前厅, the 凤凰 dark")
	await _flee(tree, session)
	elon = await _beside(tree, session, manor, &"latemoon.room.eastroom.elon.1")
	_check(elon.has_flag(StringName(NpcMood.FLAG_PREFIX + "bereft")) and _recent(ui).any(func(line: String) -> bool: return line.contains("一句话就换了主")), "瑷伦: 一句话就换了主")


## TEST-ONLY: the player beside the NPC of `point_id`, a heart beat after (its reaction call).
func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, point_id: StringName) -> NpcRuntimeState:
	var npc: NpcRuntimeState = MapPlaces.npc_at(session, point_id)
	var body: Node2D = null if npc == null else map.runtime_body_for_character(npc.character_id)
	_check(npc != null and body != null and map.place_player(npc.world_location().zone_id, body.global_position + Vector2(0, 56)), "TEST-ONLY: beside %s" % point_id)
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	return npc


## A passed test told blow by blow (trial_blow_ms apart): the beats until it is all told.
func _told(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> void:
	for beat: int in 12:
		if not map.npc_life.trial_running(npc):
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)


## The log's last lines (the log keeps only MAX_LOG_LINES, so an index taken earlier is no anchor).
func _recent(ui: SharedGameplayUI, count: int = 12) -> Array[String]:
	var lines: Array[String] = ui.log_lines()
	return lines.slice(maxi(0, lines.size() - count))


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


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


func _carries(map: WorldMapController, npc: NpcRuntimeState, definition_id: StringName) -> bool:
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, npc.character_id)
	for item_id: StringName in map.inventory_state().direct_children(carried):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return true
	return false


func _floor_count(map: WorldMapController, definition_id: StringName) -> int:
	var found: int = 0
	for item_id: StringName in map.floor_items.floor_item_ids():
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			found += 1
	return found


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found += 1
	return found


func _session(tree: SceneTree, gender: StringName) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("宝衣", gender)
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


func _capture(session: WorldSessionController) -> GameSaveSnapshot:
	var result: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-10-30T00:00:00Z")
	if result.snapshot == null:
		print("capture rejected: ", result.path, " ", result.detail)
	return result.snapshot


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
