extends RefCounted

## 第七章「番坊」 so far (番坊 A and B, DECISIONS「番坊 A」「番坊 B」「火前问话」): 关北's last step asked of 卢卡
## in the 马市 ends that chapter while he still stands by the pen — he keeps his 马市 lines there and
## greets no one (his 番坊 lines wait for the gate). Once 关北 is done the chapter opens with the way —
## out of 忘情谷 south down the 海崖道 (the portal marks 到了番坊) — on both of 关北's ledgers (the raid,
## the night); its next objective is 铁盾会's gate in the bazaar, where 卢卡 now stands and greets the
## player once. 卢卡 is gone from the 马市. The 市舶司's 兵部文书 reads false to one who learned the 印色
## in 关北 A. B: through the gate 安敦 meets the player in his hut (见了安敦), tells of the 铜牒 when
## asked (the step heard), and the side is taken — 站大秦人 (asked first, as 借兵 was) — then in the
## 拜火祠 the 火前问话: three questions on the player's own deeds answered from the ledger; a lie makes
## the fire refuse for the day (火不肯: 等到明天 puts the clock to dawn), the truth three times puts the
## 铜牒 in hand (铜牒到手, 火前说了真话) and the chapter's next objective is to read it (番坊 C). On the
## 浪人's side (番坊 C's 早川; TEST-ONLY the mark) the fire has nothing to ask.
const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const LUCA: StringName = &"native.npc.luca"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	for raid: bool in [true, false]:
		var session: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE if raid else CharacterState.GENDER_MALE)
		await _test_way_down(tree, session, raid)
		session.free()
		await tree.process_frame
	for raid: bool in [true, false]:
		var session: WorldSessionController = await _session(tree, CharacterState.GENDER_MALE)
		await _test_hall_and_fire(tree, session, raid)
		session.free()
		await tree.process_frame
	var ronin: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE)
	await _test_ronin_side(tree, ronin)
	ronin.free()
	await tree.process_frame
	var boxed: WorldSessionController = await _session(tree, CharacterState.GENDER_MALE)
	await _test_fire_in_the_box(tree, boxed)
	boxed.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_way_down(tree: SceneTree, session: WorldSessionController, raid: bool) -> void:
	var ledger: String = "the raid" if raid else "the night"
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter7")
	StoryFixtures.chapter6_site_done(session, raid)
	session.record_journal()
	# 关北's last step in the 马市: 卢卡's ghost and his 会首 end the chapter while he stands by the pen.
	var market: WorldMapController = MapPlaces.enter(session, &"guanbei.market", &"guanbei.market.street_arrival")
	_check(market != null, "%s: in the 马市" % ledger)
	await _settle(tree)
	var seller: NpcRuntimeState = MapPlaces.npc_at(session, &"guanbei.market.luca.1")
	var body: Node2D = null if seller == null else market.runtime_body_for_character(seller.character_id)
	_check(body != null and market.place_player(&"guanbei.market", body.global_position + Vector2(0, 56)) and market.select_npc(seller.character_id), "%s: beside 卢卡 by the pen" % ledger)
	await _settle(tree)
	market.ask_selected("鬼")
	_check(market.ask_selected("会首").any(func(line: String) -> bool: return line.contains("他在番坊")), "%s: 会首安敦, in 番坊" % ledger)
	session.record_journal()
	_check(state.marks.get("关北一章", 0) == 1, "%s: 关北 is done" % ledger)
	_check(market.ask_selected("番坊").any(func(line: String) -> bool: return line.contains("出忘情谷")) and market.ask_selected("会首").any(func(line: String) -> bool: return line.contains("他在番坊")) and market.ask_selected("路费").any(func(line: String) -> bool: return line.contains("二十两")), "%s: still by the pen, 卢卡 keeps his 马市 lines (the way there, the fare)" % ledger)
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(not state.marks.has("卢卡在番坊见到你") and not ui.log_lines().any(func(line: String) -> bool: return line.contains("路，不近")), "%s: and greets no one in the 马市" % ledger)
	_check(StoryQuestLog.is_active(state, quest) and StoryQuestLog.objective(state, quests).begins_with("去番坊找大秦人的会首安敦"), "%s: the seventh chapter open: %s" % [ledger, StoryQuestLog.objective(state, quests)])
	var target: StoryQuestDefinition.Target = StoryQuestLog.target(state, quests)
	_check(target != null and target.zone_id == &"village.valley1", "%s: its marker on the path outside 忘情谷" % ledger)
	_check(not StoryQuestLog.objective(state, quests).contains("村东"), "%s: the objective names no wrong side (owner Q1: the sea lies south-west)" % ledger)
	# Once the player has left, 卢卡 has left the 马市 too.
	var away: WorldMapController = MapPlaces.enter(session, &"village.valley1", &"village.valley1.cave_return")
	_check(away != null, "%s: away from the 马市" % ledger)
	await _settle(tree)
	market = MapPlaces.enter(session, &"guanbei.market", &"guanbei.market.street_arrival")
	await _settle(tree)
	_check(market != null and _count_in(session, &"guanbei.market", LUCA) == 0, "%s: back in the 马市, 卢卡 is gone" % ledger)
	# Down from the valley.
	var valley: WorldMapController = MapPlaces.enter(session, &"village.valley1", &"village.valley1.cave_return")
	_check(valley != null and valley.map_id() == &"village.main", "%s: on the path outside 忘情谷" % ledger)
	await _settle(tree)
	var road: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.cliff_top")
	_check(road != null and road.map_id() == &"fanfang.cliff_road" and state.marks.get("到了番坊", 0) == 1, "%s: south out of the woods onto the 海崖口" % ledger)
	session.record_journal()
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(state, quest)
	_check(step != null and step.step_id == &"hall" and StoryQuestLog.objective(state, quests).contains("两面大盾"), "%s: the way done; next 铁盾会's gate: %s" % [ledger, StoryQuestLog.objective(state, quests)])
	var hall: StoryQuestDefinition.Target = StoryQuestLog.target(state, quests)
	_check(hall != null and hall.zone_id == &"fanfang.bazaar_north", "%s: the marker moves to the lane's end" % ledger)
	# Through the port to the bazaar: 卢卡 at the gate greets the player once.
	_check(await MapPlaces.drive_through(tree, road, [&"fanfang.cliff_path", &"fanfang.cliff_foot"]), "%s: down the cliff road" % ledger)
	var port: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.dock")
	_check(port != null and port.map_id() == &"fanfang.port", "%s: down the steps to the port" % ledger)
	var bazaar: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.bazaar_west")
	_check(bazaar != null and bazaar.map_id() == &"fanfang.bazaar", "%s: through the port into the bazaar" % ledger)
	_check(_count_in(session, &"fanfang.bazaar_north", LUCA) == 1, "%s: 卢卡 at 铁盾会's gate" % ledger)
	_check(await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east", &"fanfang.bazaar_north"]), "%s: up the lane to him" % ledger)
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(state.marks.get("卢卡在番坊见到你", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("会首在里头")), "%s: 卢卡: 你来了……会首在里头" % ledger)
	var greeted: int = ui.log_lines().filter(func(line: String) -> bool: return line.contains("路，不近")).size()
	var dock: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.dock")
	_check(dock != null, "%s: back out to the dock" % ledger)
	bazaar = await MapPlaces.go_to(tree, session, &"fanfang.bazaar_west")
	_check(bazaar != null and await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east", &"fanfang.bazaar_north"]), "%s: and up the lane again" % ledger)
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(ui.log_lines().filter(func(line: String) -> bool: return line.contains("路，不近")).size() == greeted, "%s: he greets the player only the once" % ledger)
	var luca: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.bazaar_north.luca.1")
	_check(luca != null and await MapPlaces.drive(tree, bazaar, MapPlaces.spot(bazaar, &"fanfang.bazaar_north", bazaar.runtime_body_for_character(luca.character_id).global_position + Vector2(0, 60), 64.0)) and bazaar.select_npc(luca.character_id), "%s: beside 卢卡" % ledger)
	_check(bazaar.ask_selected("安敦").any(func(line: String) -> bool: return line.contains("会首在里头")), "%s: 安敦 is inside" % ledger)
	_check(bazaar.ask_selected("路费").any(func(line: String) -> bool: return line.contains("到了")), "%s: no more talk of the fare: he is here" % ledger)
	_check(bazaar.ask_selected("会首").any(func(line: String) -> bool: return line.contains("会首在里头")) and not bazaar.ask_selected("会首").any(func(line: String) -> bool: return line.contains("你去，说卢卡让你去")), "%s: 会首 is inside, no more sending the player to 番坊" % ledger)
	# The 兵部文书 in the 市舶司: 关北 A taught the 印色, so the seal reads false.
	_check(await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east", &"fanfang.bazaar_west"]), "%s: back down to the street's west end" % ledger)
	var office: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.office")
	_check(office != null and office.map_id() == &"fanfang.customs", "%s: into the 市舶司" % ledger)
	var papers: ActService = office.service(&"fanfang.office.papers") as ActService
	_check(papers != null and await MapPlaces.drive(tree, office, MapPlaces.service_spot(office, &"fanfang.office.papers")) and papers.in_reach(), "%s: at the desk" % ledger)
	papers.interact()
	await _settle(tree)
	_check(state.marks.get("看出文书是假的", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("印是假的")), "%s: the 兵部文书's seal is false" % ledger)


## 番坊 B on a ledger (`raid`: the 工地 raided, else sneaked; 旧案 kept and the 宝衣 left with 瑷伦 on both):
## 安敦's hut, the tablet's tale, the side taken, and the 火前问话 — a lie, the wait for dawn, the truth.
func _test_hall_and_fire(tree: SceneTree, session: WorldSessionController, raid: bool) -> void:
	var ledger: String = "the raid" if raid else "the night"
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter7")
	StoryFixtures.chapter6_done(session, raid)
	state.marks["到了番坊"] = 1 # TEST-ONLY: the 海崖道 walked (_test_way_down)
	session.record_journal()
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(state, quest)
	_check(step != null and step.step_id == &"hall", "%s: at 铁盾会's gate step" % ledger)
	var bazaar: WorldMapController = MapPlaces.enter(session, &"fanfang.bazaar_north", &"fanfang.bazaar_north.hall_return")
	_check(bazaar != null and bazaar.map_id() == &"fanfang.bazaar", "%s: before the gate" % ledger)
	await _settle(tree)
	var hall: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.shield_yard")
	_check(hall != null and hall.map_id() == &"fanfang.shield_hall" and not state.marks.has("见了安敦"), "%s: into the yard; 安敦 waits in his hut" % ledger)
	_check(await MapPlaces.drive_through(tree, hall, [&"fanfang.hall"]), "%s: into the 会首's hut" % ledger)
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(state.marks.get("见了安敦", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("卢卡的人")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("问我「铜牒」")), "%s: 安敦 stands up for 卢卡's friend and tells of his forebears" % ledger)
	session.record_journal()
	step = StoryQuestLog.current_step(state, quest)
	_check(step != null and step.step_id == &"tablet_tale" and StoryQuestLog.objective(state, quests).contains("「铜牒」"), "%s: next, the 铜牒: %s" % [ledger, StoryQuestLog.objective(state, quests)])
	var andun: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.hall.andun.1")
	_check(andun != null and await MapPlaces.drive(tree, hall, MapPlaces.spot(hall, &"fanfang.hall", hall.runtime_body_for_character(andun.character_id).global_position + Vector2(0, 60), 64.0)) and hall.select_npc(andun.character_id), "%s: beside 安敦" % ledger)
	_check(hall.ask_selected("铜牒").any(func(line: String) -> bool: return line.contains("火前不说谎")) and state.marks.get("安敦说了铜牒", 0) == 1, "%s: the tablet is in the 拜火祠, the rule 火前不说谎" % ledger)
	session.record_journal()
	step = StoryQuestLog.current_step(state, quest)
	_check(step != null and step.step_id == &"side" and StoryQuestLog.objective(state, quests).contains("站大秦人") and StoryQuestLog.objective(state, quests).contains("站浪人"), "%s: the side to take: %s" % [ledger, StoryQuestLog.objective(state, quests)])
	# The fire has nothing to ask of one who has not taken a side.
	var temple: WorldMapController = await _into_temple(tree, session, hall)
	var questions: ActService = null if temple == null else temple.service(&"fanfang.fire_hall.questions") as ActService
	_check(questions != null and await MapPlaces.drive(tree, temple, MapPlaces.service_spot(temple, &"fanfang.fire_hall.questions")) and questions.in_reach(), "%s: at the fire" % ledger)
	questions.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().any(func(line: String) -> bool: return line.contains("先站定")) and not state.marks.has("铜牒到手"), "%s: 穆护: 火前只问站定了的人" % ledger)
	# Back to 安敦: 站大秦人, asked first (as 借兵 was); ask_selected answers in the test.
	hall = await _back_to_hall(tree, session, temple)
	andun = MapPlaces.npc_at(session, &"fanfang.hall.andun.1")
	_check(hall != null and andun != null and await MapPlaces.drive(tree, hall, MapPlaces.spot(hall, &"fanfang.hall", hall.runtime_body_for_character(andun.character_id).global_position + Vector2(0, 60), 64.0)) and hall.select_npc(andun.character_id), "%s: beside 安敦 again" % ledger)
	_check(hall.ask_selected("站大秦人").any(func(line: String) -> bool: return line.contains("三句真话")) and state.marks.get("站了大秦人", 0) == 1, "%s: 站大秦人: 三句真话，牒是你的" % ledger)
	_check(hall.ask_selected("站大秦人").any(func(line: String) -> bool: return line.contains("火前说真话")), "%s: asked again: 去祠里，火前说真话" % ledger)
	session.record_journal()
	step = StoryQuestLog.current_step(state, quest)
	_check(step != null and step.step_id == &"rome" and StoryQuestLog.objective(state, quests).contains("拜火祠") and StoryQuestLog.target(state, quests) != null and StoryQuestLog.target(state, quests).zone_id == &"fanfang.fire_hall", "%s: the 拜火祠 next: %s" % [ledger, StoryQuestLog.objective(state, quests)])
	# The 火前问话: a lie first — the fire refuses for the day.
	temple = await _into_temple(tree, session, hall)
	questions = null if temple == null else temple.service(&"fanfang.fire_hall.questions") as ActService
	_check(questions != null and await MapPlaces.drive(tree, temple, MapPlaces.service_spot(temple, &"fanfang.fire_hall.questions")) and questions.in_reach() and questions.verb() == "问话", "%s: 火前 · 问话" % ledger)
	questions.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("南危水") and ui.confirm_prompt.choice_buttons.size() >= 2 and ui.confirm_prompt.choice_buttons[0].text == "守了口。" and ui.confirm_prompt.choice_buttons[1].text == "告了。" and ui.log_lines().any(func(line: String) -> bool: return line.contains("三句")), "%s: the first question, 水烟阁, two answers: %s" % [ledger, ui.confirm_prompt.message.text])
	ui.confirm_prompt.choice_buttons[1].pressed.emit() # 告了 — a lie on these ledgers (旧案 kept)
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("关北") and ui.log_lines().any(func(line: String) -> bool: return line.contains("你答道：告了")), "%s: the second question, 关北; the answer in 消息" % ledger)
	ui.confirm_prompt.choice_buttons[0 if raid else 1].pressed.emit() # the truth
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("宝衣") and ui.confirm_prompt.choice_buttons[2].text == "给了安妮儿。", "%s: the third question, 晚月庄, three answers" % ledger)
	ui.confirm_prompt.choice_buttons[1].pressed.emit() # 留给瑷伦 — the truth
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().any(func(line: String) -> bool: return line.contains("今天火不肯")) and session.player_runtime().temp_marks.get("火不肯", 0) == 1 and not state.marks.has("铜牒到手") and not session.player_held_item_ids().has(&"native:fanfang/bronze_tablet"), "%s: one lie: the fire flares, 今天火不肯, no tablet" % ledger)
	# At dawn itself nothing can be waited for (the clock would not move): the refusal stays.
	var noon: int = session.day_clock().day_seconds()
	session.day_clock().set_day_seconds(600) # TEST-ONLY: back to this day's dawn (微曦 is the day's first 240 minutes)
	_check(session.day_phase_id() == &"dawn", "%s: TEST-ONLY the clock set to dawn (%s)" % [ledger, session.day_phase_id()])
	questions.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().any(func(line: String) -> bool: return line.contains("天刚亮")) and session.player_runtime().temp_marks.get("火不肯", 0) == 1, "%s: a lie at dawn: 明天再来, the refusal kept" % ledger)
	session.day_clock().set_day_seconds(noon)
	# The same day: only the wait for dawn is offered (asked first), the clock put forward.
	var before: StringName = session.day_phase_id()
	questions.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.begins_with("火今天不肯") and ui.confirm_prompt.confirm_button.text == "等到明天", "%s: asked first: %s" % [ledger, ui.confirm_prompt.message.text])
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(session.day_phase_id() == &"dawn" and before != &"dawn" and session.player_runtime().temp_marks.get("火不肯", 0) == 0 and ui.log_lines().any(func(line: String) -> bool: return line.contains("火静了")), "%s: dawn, the fire quiet again (%s → %s)" % [ledger, before, session.day_phase_id()])
	# The truth three times: the tablet.
	questions.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("南危水"), "%s: asked again" % ledger)
	ui.confirm_prompt.choice_buttons[0].pressed.emit()
	await _settle(tree)
	ui.confirm_prompt.choice_buttons[0 if raid else 1].pressed.emit()
	await _settle(tree)
	ui.confirm_prompt.choice_buttons[1].pressed.emit()
	await _settle(tree)
	_check(not ui.is_asking() and state.marks.get("铜牒到手", 0) == 1 and state.marks.get("火前说了真话", 0) == 1 and session.player_held_item_ids().has(&"native:fanfang/bronze_tablet") and ui.log_lines().any(func(line: String) -> bool: return line.contains("它认你")), "%s: three truths: 火静了。它认你 — the 铜牒 in hand" % ledger)
	session.record_journal()
	step = StoryQuestLog.current_step(state, quest)
	_check(step != null and step.step_id == &"read" and StoryQuestLog.objective(state, quests).begins_with("读铜牒"), "%s: next, to read it (番坊 C): %s" % [ledger, StoryQuestLog.objective(state, quests)])
	questions.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().any(func(line: String) -> bool: return line.contains("火前没有你的事了")), "%s: nothing more at the fire" % ledger)
	# Save and Continue with the tablet and the chapter where it stands.
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "%s: a save in the 拜火祠" % ledger)
	if snapshot != null:
		var walker: RefCounted = Work.new()
		await walker.round_trip(tree, session, snapshot, "番坊 B in the 拜火祠 (%s)" % ledger)
		_check(walker._failures.is_empty(), "%s: Save/Continue restores exactly: %s" % [ledger, str(walker._failures)])


## With the feel on (the dialogue box, DECISIONS「对话框」) the questions' answers show in the box, as 打听's
## topics do, and the box asks the next question in turn; 走开 (取消) leaves the fire with nothing done.
func _test_fire_in_the_box(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.chapter7_sided(session, true)
	session.record_journal()
	var temple: WorldMapController = MapPlaces.enter(session, &"fanfang.fire_hall", &"fanfang.fire_hall.street_entry")
	_check(temple != null and temple.map_id() == &"fanfang.fire_temple", "boxed: in the 拜火祠")
	await _settle(tree)
	var questions: ActService = temple.service(&"fanfang.fire_hall.questions") as ActService
	_check(questions != null and await MapPlaces.drive(tree, temple, MapPlaces.service_spot(temple, &"fanfang.fire_hall.questions")) and questions.in_reach(), "boxed: at the fire")
	TestFeel.use()
	questions.interact()
	await _settle(tree)
	for page: int in 12:
		if ui.dialogue_box.is_open() and not ui.dialogue_box.hosting():
			ui.dialogue_box.advance()
			await _settle(tree)
	_check(ui.dialogue_box.is_open() and ui.dialogue_box.hosted() == ui.confirm_prompt and ui.is_asking() and ui.confirm_prompt.choice_buttons[0].visible and not ui.confirm_prompt.confirm_button.visible and ui.confirm_prompt.cancel_button.text == "走开", "boxed: the first question's answers in the dialogue box, 走开 to leave")
	ui.confirm_prompt.cancel_button.pressed.emit()
	await _settle(tree)
	_check(not ui.dialogue_box.is_open() and not ui.is_asking() and not state.marks.has("铜牒到手") and session.player_runtime().temp_marks.get("火不肯", 0) == 0, "boxed: walked away: the box shut, nothing written")
	questions.interact()
	await _settle(tree)
	for page: int in 12:
		if ui.dialogue_box.is_open() and not ui.dialogue_box.hosting():
			ui.dialogue_box.advance()
			await _settle(tree)
	_check(ui.dialogue_box.hosted() == ui.confirm_prompt, "boxed: asked again")
	ui.confirm_prompt.choice_buttons[0].pressed.emit()
	await _settle(tree)
	_check(ui.dialogue_box.hosted() == ui.confirm_prompt and ui.confirm_prompt.message.text.contains("关北"), "boxed: the second question follows in the box")
	ui.confirm_prompt.choice_buttons[0].pressed.emit()
	await _settle(tree)
	ui.confirm_prompt.choice_buttons[1].pressed.emit()
	await _settle(tree)
	for page: int in 12:
		if ui.dialogue_box.is_open() and not ui.dialogue_box.hosting():
			ui.dialogue_box.advance()
			await _settle(tree)
	TestFeel.restore()
	_check(state.marks.get("铜牒到手", 0) == 1 and session.player_held_item_ids().has(&"native:fanfang/bronze_tablet"), "boxed: three truths, the tablet in hand")


## On the 浪人's side (TEST-ONLY the mark: 早川 is 番坊 C's) the fire has nothing to ask, 安敦 has no words.
func _test_ronin_side(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter7")
	StoryFixtures.chapter7_sided(session, false)
	session.record_journal()
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(state, quest)
	_check(step != null and step.step_id == &"ronin" and StoryQuestLog.objective(state, quests).contains("鬼笠馆"), "ronin: the 浪人's step: %s" % StoryQuestLog.objective(state, quests))
	var temple: WorldMapController = MapPlaces.enter(session, &"fanfang.fire_hall", &"fanfang.fire_hall.street_entry")
	_check(temple != null and temple.map_id() == &"fanfang.fire_temple", "ronin: in the 拜火祠")
	await _settle(tree)
	var questions: ActService = temple.service(&"fanfang.fire_hall.questions") as ActService
	_check(questions != null and await MapPlaces.drive(tree, temple, MapPlaces.service_spot(temple, &"fanfang.fire_hall.questions")) and questions.in_reach(), "ronin: at the fire")
	questions.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().any(func(line: String) -> bool: return line.contains("不走火前")) and not state.marks.has("铜牒到手"), "ronin: 穆护: 他们拿东西，不走火前")
	var hall: WorldMapController = MapPlaces.enter(session, &"fanfang.shield_yard", &"fanfang.shield_yard.gate_arrival")
	await _settle(tree)
	_check(hall != null and await MapPlaces.drive_through(tree, hall, [&"fanfang.hall"]), "ronin: into the 会首's hut")
	var andun: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.hall.andun.1")
	_check(hall != null and andun != null and await MapPlaces.drive(tree, hall, MapPlaces.spot(hall, &"fanfang.hall", hall.runtime_body_for_character(andun.character_id).global_position + Vector2(0, 60), 64.0)) and hall.select_npc(andun.character_id), "ronin: beside 安敦")
	_check(hall.ask_selected("站大秦人").any(func(line: String) -> bool: return line.contains("没有话说")) and not state.marks.has("站了大秦人"), "ronin: 安敦: 你去了鬼笠馆。……没有话说")


## From 铁盾会's hut out and east along the street into the 拜火祠.
func _into_temple(tree: SceneTree, session: WorldSessionController, hall: WorldMapController) -> WorldMapController:
	if hall == null or not await MapPlaces.drive_through(tree, hall, [&"fanfang.shield_yard"]):
		return null
	var bazaar: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.bazaar_north")
	if bazaar == null or not await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east"]):
		return null
	var temple: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.fire_hall")
	if temple != null:
		await _settle(tree)
	return temple


## From the 拜火祠 back up the lane into 铁盾会's hut.
func _back_to_hall(tree: SceneTree, session: WorldSessionController, temple: WorldMapController) -> WorldMapController:
	if temple == null:
		return null
	var bazaar: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.bazaar_east")
	if bazaar == null or not await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_north"]):
		return null
	var hall: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.shield_yard")
	if hall == null or not await MapPlaces.drive_through(tree, hall, [&"fanfang.hall"]):
		return null
	await _settle(tree)
	return hall


func _session(tree: SceneTree, gender: StringName) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("番坊", gender)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	return session


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found += 1
	return found


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
