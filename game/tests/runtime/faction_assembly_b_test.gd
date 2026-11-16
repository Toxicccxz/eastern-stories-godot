extends RefCounted

## 势力线第一批 大会 B (计划 build/plans/势力线第一批_计划.md §7「怎么算」与大会 B, §8, §10 第 11 行, §11 Q3; DECISIONS
## 「大会 B」「台上的选择」): 入席 at the 擎天柱 (asked once), the things of the morning (only those that happen:
## 神教 at 山烟寺's 轿子, 余孽 at 葬剑亭, 颜违's men at 封山's road or 兵部 at 骆云舟's tea; one handled, the others'
## 派 cannot come), the nine coming up (an absent one's seat empty, its vote not counted), 参选 (侮天鬼灭了 and five
## 派 that came 听你的; else greyed, saying why), the count (five to change the 盟主: you, 颜违, or the chair stays —
## 卫沧澜 back in it, or empty), the 盟主's three answers, 旋芒, the second epilogue; after it the 正厅's chair, the
## 山门's notice, 颜违's title, yours. Every way through ends the day and the quest.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const StoryFixtures := preload("res://tests/support/story_fixtures.gd")
const QUEST: StringName = &"faction.assembly"
const ACT: StringName = &"waterfog.terrace_top.assembly"
const XUANMANG: StringName = &"native:lancheng/xuanmang"
const LIN: StringName = &"common.npc.taoist.taolord"
## The four things of the morning kept from happening (the 东方神教 split, the 余孽 settled, 庾子建 in prison).
const QUIET: Array[String] = ["站了安妮儿", "余孽交了官府", "余孽有了去处", "庾子建下狱"]
const SELF_MARKS: Array[String] = ["封山听你的", "天邪听你的", "茅山听你的", "晚月庄听你的", "步玄听你的"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_rules()
	_test_epilogues()
	for test: Callable in [_test_yan, _test_self, _test_wei, _test_empty_and_walk_away, _test_blockade]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest.step(&"day") != null and quest.step(&"day").condition.key == "大会散了", "the quest ends with the day: 大会散了")
	var service: ServiceDefinition = catalog.service(ACT)
	_check(service != null and service.act != null and service.act.verb == "入席" and service.act.acts.size() == 1, "虹台大会 · 入席: one branch")
	var act: ScriptedAct = service.act.acts[0]
	_check(not act.ask.is_empty() and act.ask_lacks == ["入了虹台的席"], "入席 asked once")
	var kinds: Array = act.steps.map(func(step: ScriptedAct.Step) -> ScriptedAct.Kind: return step.kind)
	_check(kinds.count(ScriptedAct.Kind.CHOOSE) == 6 and kinds.count(ScriptedAct.Kind.RESTAGE) == 2 and kinds.has(ScriptedAct.Kind.TITLE) and kinds.has(ScriptedAct.Kind.EPILOGUE), "the day: six choices (the morning, 参选, three answers, 旋芒), the nine come and go, the title, the epilogue")
	var asked: Array = act.steps.filter(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.CHOOSE)
	_check(asked.all(func(step: ScriptedAct.Step) -> bool: return step.options.all(func(option: ScriptedAct.Option) -> bool: return not option.confirm.is_empty())), "every option asked first (the one confirm prompt)")
	var assembly: EpilogueDefinition = catalog.epilogue(&"assembly")
	_check(assembly != null and assembly.cards.map(func(card: EpilogueDefinition.Card) -> StringName: return card.card_id) == [&"terrace", &"snow", &"waterfog", &"yard", &"north_slope"] and assembly.final == null, "the second epilogue: five cards, the world goes on")
	var yan: NpcDefinition = catalog.npc(&"native.npc.yan_wei_chair")
	_check(yan != null and yan.title == "武林盟主", "颜违 in the chair: 武林盟主")
	_check(catalog.npc(&"waterfog.npc.elder7").hooks().moods.has("elder"), "颜违 back to 七长老 when another sits the chair")


## The morning's things, the counts, 参选's gate (the named conditions, no session).
func _test_rules() -> void:
	var state := _fresh(["终章", "入了虹台的席"])
	_check(_holds(state, "assembly.day.ambush") and _holds(state, "assembly.day.fire") and _holds(state, "assembly.day.tea") and not _holds(state, "assembly.day.blockade"), "nothing settled: 神教, 余孽, 兵部")
	state = _fresh(["终章", "入了虹台的席", "站了安妮儿", "余孽有了去处", "庾子建下狱"])
	_check(not _holds(state, "assembly.day.ambush") and not _holds(state, "assembly.day.fire") and not _holds(state, "assembly.day.tea"), "站了安妮儿, the 余孽 settled, 庾子建 in prison: a quiet morning")
	state = _fresh(["终章", "入了虹台的席", "站了潘军禅"])
	_check(_holds(state, "assembly.day.blockade") and not _holds(state, "assembly.day.tea"), "站了潘军禅: 颜违's men at 封山's road, not 兵部 at the tea")
	state = _fresh(["终章", "入了虹台的席", "站了潘军禅", "跟了北宗"])
	_check(not _holds(state, "assembly.day.blockade") and _holds(state, "assembly.day.tea"), "北宗 votes 颜违: he does not bar its road")
	state = _fresh(["终章", "入了虹台的席", "站了朱鸿雪"])
	_check(_holds(state, "assembly.day.ambush"), "站了朱鸿雪: the 杀手 on the road")
	# the count: five for 颜违, absent ones not counted
	state = _fresh(["终章", "入了虹台的席"])
	_check(_holds(state, "assembly.day.yan_wins"), "all came, nothing done: five for 颜违")
	state.marks["茅山没上虹台"] = 1 # TEST-ONLY: the fire not handled
	_check(not _holds(state, "assembly.day.yan_wins") and not _holds(state, "assembly.day.maoshan.here") and not _holds(state, "assembly.day.maoshan.yan"), "茅山 not up: four, not counted")
	state = _fresh(["终章", "入了虹台的席", "振远改投旧盟主"])
	_check(not _holds(state, "assembly.day.yan_wins"), "振远 turned: four")
	state = _fresh(["终章", "入了虹台的席", "振远改投旧盟主", "天邪听你的", "封山听你的", "听你的投颜违"])
	_check(_holds(state, "assembly.day.yan_wins") and _holds(state, "assembly.day.celestial.yan") and _holds(state, "assembly.day.fonxan.yan"), "振远 turned, 天邪 and 封山 sent to 颜违 by you: five again")
	state = _fresh(["终章", "入了虹台的席", "振远改投旧盟主", "天邪听你的", "封山听你的", "听你的投旧盟主"])
	_check(not _holds(state, "assembly.day.yan_wins") and _holds(state, "assembly.day.celestial.old") and _holds(state, "assembly.day.fonxan.old"), "sent to the old 盟主: three")
	# 参选
	state = _fresh(["终章", "入了虹台的席", "侮天鬼灭了"] + SELF_MARKS.slice(0, 4))
	_check(not _holds(state, "assembly.day.can_stand"), "four 听你的: not enough to stand")
	state.marks["步玄听你的"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.day.can_stand") and not _holds(state, "assembly.day.self_wins"), "five: can stand, not yet stood")
	state.marks["站出来参选"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.day.self_wins") and not _holds(state, "assembly.day.yan_wins"), "stood: five for you")
	state.marks["步玄没上虹台"] = 1 # TEST-ONLY: 兵部's tea not handled
	_check(not _holds(state, "assembly.day.self_wins") and not _holds(state, "assembly.day.can_stand"), "步玄 not up: four, short")
	state = _fresh(["终章", "入了虹台的席", "再封了侮天鬼"] + SELF_MARKS)
	_check(not _holds(state, "assembly.day.can_stand"), "侮天鬼 sealed, not slain: no 盟主 from you")
	# 绝尘 only when asked down
	state = _fresh(["终章", "入了虹台的席", "九派到了"])
	_check(not _holds(state, "assembly.day.juechen.seated") and _holds(state, "assembly.day.huazi.seated"), "绝尘 does not come unless asked down")


## The second epilogue's lines by the day's outcome; the 终章's 水烟阁 card no longer tells it.
func _test_epilogues() -> void:
	var assembly: EpilogueDefinition = GameContent.catalog().epilogue(&"assembly")
	var told: String = _told(assembly, ["当了武林盟主", "盟主答：旧案查到底", "盟主答：逆灵宫交茅山", "盟主答：容神教", "扑灭了葬剑亭的火", "山烟寺没上虹台", "旋芒还给了岚城"])
	_check(told.contains("推你做了武林盟主") and told.contains("重新翻了出来") and told.contains("把肯下山的领了回去") and told.contains("照旧在棺材铺后面") and told.contains("扑灭了") and told.contains("玄智和尚没能上山") and told.contains("又转了起来"), "you the 盟主: your three answers, the morning, 旋芒 back")
	told = _told(assembly, ["颜违做了盟主", "站了安妮儿", "旋芒供在葬剑亭"])
	_check(told.contains("颜违做了武林盟主") and told.contains("坐着颜违") and told.contains("一个也没走脱") and told.contains("安妮儿闭了西厢的门") and told.contains("供在了葬剑亭"), "颜违: 到此为止, 剿, 逐")
	told = _told(assembly, ["卫沧澜坐回了椅子", "余孽交了官府", "余孽有了去处"])
	_check(told.contains("卫沧澜走到石椅前") and told.contains("坐着卫沧澜") and told.contains("官兵封了山门") and not told.contains("把肯下山的领了回去"), "卫沧澜 back: the 余孽 already settled stays so")
	told = _told(assembly, ["盟主的椅子还空着", "告发了南危水"])
	_check(told.contains("那把石椅还空着") and told.contains("颜违照旧代理") and told.contains("续灯的火一直没灭") and told.contains("朱鸿雪照旧派她的差事"), "nobody: the chair empty, nothing changes")
	var ending: EpilogueDefinition = GameContent.catalog().epilogue(&"ending")
	for marks: Array in [["南危水留在了冰里"], ["卫沧澜出了尚书府"], ["替南危水保密"], ["告发了南危水"]]:
		_check(not _told(ending, marks).contains("这一年正月十七"), "the 终章's 水烟阁 card tells the time before the day (%s)" % [marks])


## Nothing in the morning, nothing done: 颜违 has five and sits the chair.
func _test_yan(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.assembly_invited(session, "slay", QUIET)
	state.marks.erase("卫沧澜出了尚书府") # TEST-ONLY: he did not come out
	var ui: SharedGameplayUI = session.shared_ui()
	var act: ActService = await _at_terrace(tree, session)
	act.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("就不能再去各派游说") and ui.confirm_prompt.confirm_button.text == "入席", "入席 asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(state.marks.has("入了虹台的席") and not state.marks.has("三件事了了"), "a quiet morning: nothing to choose")
	_check(ui.is_asking() and _choice(ui, "坐着听唱票") != null and _choice(ui, "我也算一个") != null and _choice(ui, "我也算一个").disabled and _choice(ui, "听我的") == null, "参选: nobody 听你的: greyed, only to sit")
	_check(_choice(ui, "我也算一个").text.contains("一派也没来"), "greyed, saying why: %s" % _choice(ui, "我也算一个").text)
	_check(_people(session) == 9 and _on_stage(session, &"native.npc.assembly_xuanzhi") and not _on_stage(session, &"native.npc.assembly_juechenzi") and not _on_stage(session, &"native.npc.assembly_wei_canglan"), "the nine came up (绝尘 not): eight heads and 颜违")
	_check(not _flag_off(session, "zhenyuan") and _flag_off(session, "juechen"), "their flags on the seats; 绝尘's seat bare")
	_check(await _answer(tree, ui, "坐着听唱票"), "sat")
	_check(state.marks.has("颜违做了盟主") and state.marks.has("唱了票") and state.marks.has("大会散了") and not state.marks.has("当了武林盟主"), "five for 颜违: he is 盟主")
	_check(_said(ui, "颜违，五票") and _said(ui, "振远镖局——颜违") and _said(ui, "绝尘派——没有来"), "the count said aloud")
	_check(ui.epilogue.active(), "the second epilogue told")
	var titles: Array[String] = await _read_all(tree, ui.epilogue)
	_check(titles.size() == 5 and "\n".join(titles).contains("颜违做了武林盟主"), "five cards: %s" % [titles.size()])
	await _until_finished(tree, ui.epilogue)
	session.record_journal()
	_check(StoryQuestLog.is_done(state, GameContent.catalog().story_quest(QUEST)), "the quest done")
	_check(_people(session) == 0, "the 虹台 empty again")
	var hall: WorldMapController = MapPlaces.enter(session, &"waterfog.guildhall", &"waterfog.guildhall.master.1")
	await _settle(tree)
	_check(_on(session, &"waterfog.guildhall", &"native.npc.yan_wei_chair"), "颜违 in the 正厅's chair")
	_check(hall.service(&"waterfog.guildhall.chair") == null or (hall.service(&"waterfog.guildhall.chair") as ActService).context_title().is_empty(), "the chair not yours to sit")
	_check(_on(session, &"waterfog.forehall", &"waterfog.npc.elder7") or session.world_map_of(&"waterfog.upstairs") == null, "the 前厅's 颜违 still there until you come")
	MapPlaces.enter(session, &"waterfog.west_2f", &"waterfog.west_2f.stairs_arrival")
	await _settle(tree)
	var upstairs: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_to_zone(tree, upstairs, &"waterfog.forehall"), "up to the 前厅")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(_said(ui, "本座这就下去坐") and not _on(session, &"waterfog.forehall", &"waterfog.npc.elder7"), "颜违 leaves the 前厅 for the chair")
	var yard: WorldMapController = MapPlaces.enter(session, &"waterfog.frontyard", &"waterfog.frontyard.gate_return")
	await _settle(tree)
	var notice: ActService = yard.service(&"waterfog.frontyard.notice") as ActService
	_check(notice != null and await MapPlaces.drive(tree, yard, MapPlaces.service_spot(yard, &"waterfog.frontyard.notice")), "the 山门's notice")
	notice.interact()
	await _settle(tree)
	_check(_said(ui, "颜违为武林盟主"), "it says 颜违")
	_check(_heard(state, &"cloud.npc.b_header", "虹台", "照旧走镖") and _heard(state, &"cloud.npc.b_header", "改投", "入了席"), "陈剑秋 after the day")


## Five 听你的, 侮天鬼 slain: the fire handled (山烟寺 lost), you stand and win, the three answers, 旋芒 back to 岚城.
func _test_self(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.assembly_invited(session, "slay", ["庾子建下狱"] + SELF_MARKS)
	for mark: String in ["余孽有了去处", "站了安妮儿", "站了潘军禅"]:
		state.marks.erase(mark) # TEST-ONLY: the 神教 and the 余孽 loose
	var ui: SharedGameplayUI = session.shared_ui()
	var act: ActService = await _at_terrace(tree, session)
	(session.active_map() as WorldMapController).give_new_item_to_player(XUANMANG)
	act.interact()
	await _settle(tree)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(ui.is_asking() and _choice(ui, "山道上") != null and _choice(ui, "葬剑亭") != null and _choice(ui, "山下茶棚") == null and _choice(ui, "官道上") == null, "the morning: 神教 and 余孽, only what happens")
	_check(await _answer(tree, ui, "葬剑亭"), "the fire handled")
	_check(state.marks.has("扑灭了葬剑亭的火") and state.marks.has("山烟寺没上虹台") and not state.marks.has("茅山没上虹台"), "山烟寺 cannot come")
	_check(not _on_stage(session, &"native.npc.assembly_xuanzhi") and _on_stage(session, &"native.npc.assembly_lin_ji") and _flag_off(session, "sanyen"), "玄智 not on the 虹台, his seat bare")
	_check(_choice(ui, "我也算一个") != null and not _choice(ui, "我也算一个").disabled and _choice(ui, "听我的那几派，投旧盟主") != null, "参选 open: five came 听你的")
	_check(await _answer(tree, ui, "我也算一个"), "stood")
	_check(state.marks.has("当了武林盟主") and _said(ui, "你，五票"), "five for you: 盟主")
	_check(session.player_runtime().shown_title() == "武林盟主", "your title: 武林盟主 (%s)" % session.player_runtime().shown_title())
	state.family = FamilyState.new(&"family.fonxan", 14) # TEST-ONLY: a 封山 member, as the recruit leaves them
	state.affiliation.has_family_rank = true
	state.affiliation.family_title = "大弟子"
	_check(session.player_runtime().shown_title() == "武林盟主", "over a family's title too")
	session.player_runtime().family_rank_changed()
	_check(session.player_runtime().shown_title().contains("大弟子"), "until the family's rank is raised again")
	session.player_runtime().take_title("武林盟主")
	_check(await _answer(tree, ui, "查到底") and await _answer(tree, ui, "交茅山看管") and await _answer(tree, ui, "容"), "the three answers")
	_check(state.marks.has("盟主答：旧案查到底") and state.marks.has("盟主答：逆灵宫交茅山") and state.marks.has("盟主答：容神教"), "their marks")
	_check(await _answer(tree, ui, "还给岚城") and state.marks.has("旋芒还给了岚城") and not session.player_held_item_ids().has(XUANMANG), "旋芒 back to the wind")
	_check(state.marks.has("大会散了") and ui.epilogue.active(), "the day done, the epilogue")
	await _read_all(tree, ui.epilogue)
	await _until_finished(tree, ui.epilogue)
	var hall: WorldMapController = MapPlaces.enter(session, &"waterfog.guildhall", &"waterfog.guildhall.master.1")
	await _settle(tree)
	var chair: ActService = hall.service(&"waterfog.guildhall.chair") as ActService
	_check(chair != null and await MapPlaces.drive(tree, hall, MapPlaces.service_spot(hall, &"waterfog.guildhall.chair")) and not chair.context_title().is_empty(), "the 正厅's chair yours to sit")
	chair.interact()
	await _settle(tree)
	_check(_said(ui, "你在太师椅上坐了一会儿") and not _on(session, &"waterfog.guildhall", &"native.npc.yan_wei_chair"), "sat in it; nobody else there")
	var lancheng: WorldMapController = MapPlaces.enter(session, &"lancheng.deck", &"lancheng.deck.stair_arrival")
	await _settle(tree)
	var whirl: ActService = lancheng.service(&"lancheng.whirl.self") as ActService
	if whirl != null and await MapPlaces.drive(tree, lancheng, MapPlaces.service_spot(lancheng, &"lancheng.whirl.self")):
		whirl.interact()
		await _settle(tree)
	_check(_said(ui, "又转着旋芒"), "岚城's whirl has it again")


## 卫沧澜 back, nobody to five: he sits the chair again.
func _test_wei(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.assembly_invited(session, "slay", QUIET + ["卫沧澜出了尚书府"])
	var ui: SharedGameplayUI = session.shared_ui()
	var act: ActService = await _at_terrace(tree, session)
	act.interact()
	await _settle(tree)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(_on_stage(session, &"native.npc.assembly_wei_canglan"), "卫沧澜 on the 虹台")
	_check(await _answer(tree, ui, "坐着听唱票"), "sat")
	_check(state.marks.has("卫沧澜坐回了椅子") and _said(ui, "颜违，四票") and _said(ui, "天邪派——卫盟主"), "four for 颜违: the chair stays, 卫沧澜 in it")
	await _read_all(tree, ui.epilogue)
	await _until_finished(tree, ui.epilogue)
	MapPlaces.enter(session, &"waterfog.guildhall", &"waterfog.guildhall.master.1")
	await _settle(tree)
	var chaired: Array = _all_on(session, &"waterfog.guildhall", &"native.npc.wei_canglan")
	_check(chaired.size() == 1 and chaired[0].spawn_point_id == &"waterfog.guildhall.chair.2", "卫沧澜 in the 太师椅, off his stool")


## Three things in the morning; walking away and back (no second 入席 question); 侮天鬼 sealed: 参选 greyed;
## nobody to five, 卫沧澜 not back: the chair stays empty. The 卧底's 余孽 still to settle after.
func _test_empty_and_walk_away(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.assembly_invited(session, "seal_elon", ["林忌说了余孽"])
	for mark: String in ["卫沧澜出了尚书府", "庾子建下狱", "余孽有了去处", "站了安妮儿", "站了潘军禅"]:
		state.marks.erase(mark) # TEST-ONLY: 庾子建 in office, the 余孽 and the 神教 loose
	var ui: SharedGameplayUI = session.shared_ui()
	var act: ActService = await _at_terrace(tree, session)
	act.interact()
	await _settle(tree)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(ui.is_asking() and _choice(ui, "山道上") != null and _choice(ui, "葬剑亭") != null and _choice(ui, "山下茶棚") != null and _choice(ui, "官道上") == null, "three things in the morning")
	ui.confirm_prompt.cancel_button.pressed.emit() # 走开
	await _settle(tree)
	_check(not ui.is_asking() and state.marks.has("入了虹台的席") and not state.marks.has("三件事了了"), "walked away: seated, nothing chosen")
	_check(not GameContent.catalog().npc(&"cloud.npc.b_header").talk().confirm_applies("改投", state.marks), "no more 游说 once seated")
	for mark: String in ["站了安妮儿", "余孽交了官府", "余孽有了去处"]:
		state.marks[mark] = 1 # TEST-ONLY: the 神教 and the 余孽 settled while the day waits
	_check(_heard(state, &"waterfog.npc.elder7", "椅子", "还没完") and not state.marks.has("站了颜违"), "天邪's split waits for the day to end")
	for mark: String in ["站了安妮儿", "余孽交了官府", "余孽有了去处"]:
		state.marks.erase(mark) # TEST-ONLY: back as they were, for the 卧底's 余孽 after the day
	act.interact()
	await _settle(tree)
	_check(ui.is_asking() and _choice(ui, "山道上") != null and _choice(ui, "葬剑亭") != null, "back to the 擎天柱: the same morning (as it stood at 入席), 入席 not asked twice")
	ui.confirm_prompt.choice_buttons[_index(ui, "山下茶棚")].pressed.emit()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.confirm_button.visible and ui.confirm_prompt.message.text.contains("骆云舟"), "the tea asked first")
	ui.confirm_prompt.cancel_button.pressed.emit()
	await _settle(tree)
	_check(ui.is_asking() and _choice(ui, "山道上") != null and not state.marks.has("请回了骆云舟"), "取消: back to the three")
	_check(await _answer(tree, ui, "山下茶棚"), "the tea handled")
	_check(state.marks.has("山烟寺没上虹台") and state.marks.has("茅山没上虹台") and not state.marks.has("步玄没上虹台"), "山烟寺 and 茅山 cannot come")
	_check(_said(ui, "茅山的旗座空着") and _said(ui, "山烟寺的旗座空着"), "their seats said empty")
	_check(_choice(ui, "我也算一个") != null and _choice(ui, "我也算一个").disabled and _choice(ui, "我也算一个").text.contains("要灭了侮天鬼"), "侮天鬼 sealed: greyed, saying so")
	_check(await _answer(tree, ui, "坐着听唱票"), "sat")
	_check(state.marks.has("盟主的椅子还空着") and _said(ui, "颜违，三票") and _said(ui, "山烟寺——没有来"), "three for 颜违: the chair stays empty")
	await _read_all(tree, ui.epilogue)
	await _until_finished(tree, ui.epilogue)
	session.record_journal()
	_check(StoryQuestLog.is_done(state, GameContent.catalog().story_quest(QUEST)), "the quest done")
	_check(_heard(state, LIN, "剿", "程不平") and state.marks.has("余孽交了官府"), "the 卧底's 余孽 still to settle after the day")


## 站了潘军禅: 颜违's men bar 封山's road; left alone, 封山 cannot come.
func _test_blockade(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.assembly_invited(session, "slay", ["站了潘军禅", "站了安妮儿"])
	state.marks.erase("余孽有了去处") # TEST-ONLY
	var ui: SharedGameplayUI = session.shared_ui()
	var act: ActService = await _at_terrace(tree, session)
	act.interact()
	await _settle(tree)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(_choice(ui, "官道上") != null and _choice(ui, "葬剑亭") != null and _choice(ui, "山下茶棚") == null and _choice(ui, "山道上") == null, "颜违's men instead of 兵部's tea")
	_check(await _answer(tree, ui, "葬剑亭"), "the fire handled")
	_check(state.marks.has("封山没上虹台") and not _on_stage(session, &"native.npc.assembly_liu_chunfeng") and _flag_off(session, "fonxan"), "封山 not up")
	_check(await _answer(tree, ui, "坐着听唱票") and state.marks.has("大会散了"), "the day ends")
	await _read_all(tree, ui.epilogue)
	await _until_finished(tree, ui.epilogue)


func _at_terrace(tree: SceneTree, session: WorldSessionController) -> ActService:
	session.record_journal()
	var map: WorldMapController = MapPlaces.enter(session, &"waterfog.terrace_stair", &"waterfog.terrace_stair.tomb_arrival")
	await _settle(tree)
	var act: ActService = map.service(ACT) as ActService
	_check(act != null and await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, ACT)) and act.in_reach() and act.verb() == "入席", "at the 擎天柱: 虹台大会 · 入席")
	return act


## Picks the option that begins with `prefix` and says yes to its question; whether it could.
func _answer(tree: SceneTree, ui: SharedGameplayUI, prefix: String) -> bool:
	await _settle(tree)
	var index: int = _index(ui, prefix)
	if not ui.is_asking() or index < 0 or ui.confirm_prompt.choice_buttons[index].disabled:
		return false
	ui.confirm_prompt.choice_buttons[index].pressed.emit()
	await _settle(tree)
	if ui.is_asking() and ui.confirm_prompt.confirm_button.visible:
		ui.confirm_prompt.confirm_button.pressed.emit()
		await _settle(tree)
	return true


func _index(ui: SharedGameplayUI, prefix: String) -> int:
	for index: int in ui.confirm_prompt.choice_buttons.size():
		var button: Button = ui.confirm_prompt.choice_buttons[index]
		if button.visible and button.text.begins_with(prefix):
			return index
	return -1


func _choice(ui: SharedGameplayUI, prefix: String) -> Button:
	var index: int = _index(ui, prefix)
	return null if index < 0 or not ui.is_asking() else ui.confirm_prompt.choice_buttons[index]


## Whether a seat's flag for `sect` is off the stage (the bare seat shown).
func _flag_off(session: WorldSessionController, sect: String) -> bool:
	var map: WorldMapController = session.world_map_of(&"waterfog.terrace")
	var furnishings: Node = null if map == null else map.get_node_or_null("Furnishings")
	if furnishings == null:
		return false
	for node: Node in furnishings.get_children():
		var look: Dictionary = node.get_meta("look", {})
		if look.get("kind", "") == "flag_seat" and look.has("present") and JSON.stringify(look["present"]).contains("assembly.day.%s.seated" % sect):
			return bool(node.get_meta("staged_off", false))
	return false


func _people(session: WorldSessionController) -> int:
	var map: WorldMapController = session.world_map_of(&"waterfog.terrace")
	if map == null:
		return 0
	return map.resident_npcs().filter(func(npc: NpcRuntimeState) -> bool: return npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE) and npc.world_location().zone_id == &"waterfog.terrace_top").size()


func _on_stage(session: WorldSessionController, definition_id: StringName) -> bool:
	return _on(session, &"waterfog.terrace_top", definition_id)


func _on(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> bool:
	return not _all_on(session, zone_id, definition_id).is_empty()


func _all_on(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> Array:
	var map: WorldMapController = session.world_map_of(MapPlaces.map_of(zone_id))
	if map == null:
		return []
	return map.resident_npcs().filter(func(npc: NpcRuntimeState) -> bool: return npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE) and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id)


func _said(ui: SharedGameplayUI, part: String) -> bool:
	return ui.log_lines().any(func(line: String) -> bool: return line.contains(part))


func _told(epilogue: EpilogueDefinition, marks: Array) -> String:
	var state := _fresh(marks)
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	var test: Callable = func(condition: JournalEntryDefinition) -> bool: return JournalLog.holds(condition, state, temps, held)
	var lines: Array[String] = []
	for shown: Array in epilogue.shown(test):
		lines.append_array(shown[1])
	return "\n".join(lines)


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


## Every card's title and lines as shown, going on through them.
func _read_all(tree: SceneTree, overlay: EpilogueOverlay) -> Array[String]:
	var seen: Array[String] = []
	for frame: int in 30:
		if overlay.card_index() >= 0:
			break
		await tree.process_frame
	while overlay.active() and overlay.card_index() >= 0:
		seen.append(overlay.shown_title() + "\n" + overlay.shown_lines())
		var at: int = overlay.card_index()
		overlay.advance()
		if overlay.card_index() == at:
			break
	return seen


func _until_finished(tree: SceneTree, overlay: EpilogueOverlay) -> void:
	for frame: int in 240:
		if not overlay.active() and not overlay.visible:
			break
		await tree.process_frame


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("虹台", CharacterState.GENDER_MALE)
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
