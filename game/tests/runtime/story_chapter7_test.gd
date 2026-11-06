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
## 浪人's side the fire has nothing to ask. C (DECISIONS「番坊 C」): on the 大秦人's side the tablet in hand brings
## 冯禄 and his four hired 浪人 inside 铁盾会's gate (staged spawns, his scene, 安敦 out of his hut); the 对质
## at the gate — one who learned the 印色 in 关北 holds the 印模 to the paper (假印的差，我们不接: the 浪人 and
## 冯禄 leave, 争地过了), one who did not fights the four with three swordsmen beside them (summoned, 冯禄 leaves
## once they are down). On the 浪人's side 早川's one blow (a story trial), the wait for dark on the boards, the
## 黑影 at the altar by night with the tablet (穆护 in his cell by night; 大秦人被清走: the hall and yard
## empty, 安敦 in a 枷 on the quay, 卢卡 there with one line). Reading the tablet ends the chapter (番坊一章,
## the milestone) and opens the eighth chapter's stub.
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
	for learned: bool in [true, false]:
		var gate: WorldSessionController = await _session(tree, CharacterState.GENDER_MALE if learned else CharacterState.GENDER_FEMALE)
		await _test_gate(tree, gate, learned)
		gate.free()
		await tree.process_frame
	var night: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE)
	await _test_ronin_night(tree, night)
	night.free()
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
	_check(step != null and step.step_id == &"gate" and StoryQuestLog.objective(state, quests).begins_with("回铁盾会") and StoryQuestLog.target(state, quests).zone_id == &"fanfang.shield_yard", "%s: next, 冯禄 at the gate (番坊 C): %s" % [ledger, StoryQuestLog.objective(state, quests)])
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
	# The lane down: the temple's south door onto 鬼笠馆's gate yard, the rule-board, the boards and 早川.
	var temple_yard: WorldMapController = MapPlaces.enter(session, &"fanfang.temple_yard", &"fanfang.temple_yard.slope_arrival")
	await _settle(tree)
	var dojo: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.gate_yard")
	_check(dojo != null and dojo.map_id() == &"fanfang.ronin_hall" and dojo.select_landmark(&"fanfang.gate_yard.landmark.rule"), "ronin: through the south door into 鬼笠馆's gate yard, the rule-board there")
	_check(await MapPlaces.drive_through(tree, dojo, [&"fanfang.dojo"]), "ronin: onto the boards")
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(state.marks.get("早川见过你", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("过我一刀")), "ronin: 早川: 要铜牒？过我一刀")
	var master: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.dojo.ronin_master.1")
	_check(master != null and _count_in(session, &"fanfang.dojo", &"native.npc.ronin") == 5, "ronin: 早川 at the hall's end, five 浪人 on the boards")
	var back: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.temple_yard")
	_check(back != null and back.map_id() == &"fanfang.lama_temple" and session.player_runtime().world_location().zone_id == &"fanfang.temple_yard", "ronin: and back up into the temple yard")


## The 大秦人's side with the tablet in hand: 冯禄 and his four inside 铁盾会's gate, his scene, 安敦 out of his
## hut; the 对质 — by the 印模 (`learned` the 印色) or by swords. Either way 争地过了, the 大秦人 stay; then the
## tablet read, the chapter done, the eighth chapter's stub.
func _test_gate(tree: SceneTree, session: WorldSessionController, learned: bool) -> void:
	var way: String = "the seal" if learned else "the swords"
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter7")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	StoryFixtures.chapter7_sided(session, true, true)
	for key: String in ["main.chapter7/rome"]:
		if not state.quests.has(key):
			state.quests[key] = state.quests.size() + 1
	for mark: String in ["火前说了真话", "铜牒到手"]:
		state.marks[mark] = 1
	if learned:
		state.marks["学过印色"] = 1
		state.marks["看出文书是假的"] = 1
	else:
		state.marks.erase("学过印色")
	session.record_journal()
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(state, quest)
	_check(step != null and step.step_id == &"gate", "%s: the gate step" % way)
	# Into the yard: 冯禄 and his four stand inside the gate (staged), the swordsmen still at their drill.
	var bazaar: WorldMapController = MapPlaces.enter(session, &"fanfang.bazaar_north", &"fanfang.bazaar_north.hall_return")
	await _settle(tree)
	var hall: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.shield_yard")
	if hall != null:
		hall.give_new_item_to_player(&"native:fanfang/bronze_tablet") # TEST-ONLY: the tablet from the fire (_test_hall_and_fire)
	_check(hall != null and _count_in(session, &"fanfang.shield_yard", &"native.npc.feng_lu") == 1 and _count_in(session, &"fanfang.shield_yard", &"native.npc.ronin") == 4 and _count_in(session, &"fanfang.shield_yard", &"native.npc.shield_swordsman") == 6, "%s: 冯禄 and four 浪人 inside the gate, the six at their drill" % way)
	for second: int in 9:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("着市舶司即日清出")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("印不是兵部的印")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("拿出来，对一对")), "%s: 冯禄 reads his order, 安敦 comes out: 印不是兵部的印 … 拿出来，对一对: %s" % [way, ui.log_lines().slice(-6)])
	_check(_count_in(session, &"fanfang.shield_yard", &"native.npc.andun") == 1, "%s: 安敦 in the yard" % way)
	var papers: ActService = hall.service(&"fanfang.shield_yard.papers") as ActService
	_check(papers != null and await MapPlaces.drive(tree, hall, MapPlaces.service_spot(hall, &"fanfang.shield_yard.papers")) and papers.in_reach() and papers.verb() == "对质", "%s: 冯禄的文书 · 对质 at the gate" % way)
	if learned:
		hall.give_new_item_to_player(&"native:canyon/seal_mould") # TEST-ONLY: 赫造基's mould (关北 A) in hand
		_check(session.player_held_item_ids().has(&"native:canyon/seal_mould"), "the seal: the 印模 carried")
		papers.interact()
		await _settle(tree)
		_check(not ui.is_asking() and ui.log_lines().any(func(line: String) -> bool: return line.contains("印色不对")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("假印的差，我们不接")) and state.marks.get("印色对上了", 0) == 1, "the seal: 印色不对 … 假印的差，我们不接: %s" % [ui.log_lines().slice(-8)])
	else:
		papers.interact()
		await _settle(tree)
		_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("拿不出") and ui.confirm_prompt.confirm_button.text == "动手", "the swords: asked first: %s" % ui.confirm_prompt.message.text)
		_full(session.player_runtime())
		ui.confirm_prompt.confirm_button.pressed.emit()
		await _settle(tree)
		for second: int in 4:
			if coordinator.has_active_encounter():
				break
			session.advance_npc_heartbeat(1.0)
			await _settle(tree)
		_check(coordinator.has_active_encounter() and _count_in(session, &"fanfang.shield_yard", &"native.npc.ronin_fighting") == 4 and _count_in(session, &"fanfang.shield_yard", &"native.npc.ronin") == 0 and ui.log_lines().any(func(line: String) -> bool: return line.contains("拿下")), "the swords: 拿下 — the four with swords out fall on the player: %s" % [ui.log_lines().slice(-4)])
		_check(_count_in(session, &"fanfang.shield_yard", &"native.npc.shield_swordsman") == 9, "the swords: three out of the hut beside the player")
		var rounds: int = _fight_out(session)
		await _settle(tree)
		session.record_journal()
		_check(not coordinator.has_active_encounter() and state.marks.get("冯禄的浪人倒了", 0) == 1, "the swords: the four down in %d rounds (冯禄的浪人倒了)" % rounds)
		_check(await MapPlaces.drive(tree, hall, MapPlaces.service_spot(hall, &"fanfang.shield_yard.papers")) and papers.in_reach(), "the swords: back at the gate")
		papers.interact()
		await _settle(tree)
		_check(not ui.is_asking() and ui.log_lines().any(func(line: String) -> bool: return line.contains("回头再议")), "the swords: 冯禄: 兵部的令，本司回头再议: %s" % [ui.log_lines().slice(-4)])
	_check(state.marks.get("争地过了", 0) == 1 and state.marks.get("大秦人留下了", 0) == 1 and _count_in(session, &"fanfang.shield_yard", &"native.npc.feng_lu") == 0 and _count_in(session, &"fanfang.shield_yard", &"native.npc.ronin") == 0 and ui.log_lines().any(func(line: String) -> bool: return line.contains("一齐喊了一声")), "%s: 冯禄 and the 浪人 gone, the 大秦人 stay (争地过了)" % way)
	session.record_journal()
	step = StoryQuestLog.current_step(state, quest)
	_check(step != null and step.step_id == &"read" and StoryQuestLog.objective(state, quests).begins_with("读铜牒"), "%s: next, to read it: %s" % [way, StoryQuestLog.objective(state, quests)])
	papers.interact()
	await _settle(tree)
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("已经退走了")), "%s: nothing more at the gate" % way)
	# The 铜牒 read: the five lines, the chapter done, the eighth chapter's stub.
	await _read_the_tablet(tree, session, hall, way)
	# 安敦 after: the 人情 remembered.
	var andun: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.hall.andun.1")
	_check(andun != null and await MapPlaces.drive(tree, hall, MapPlaces.spot(hall, andun.world_location().zone_id, hall.runtime_body_for_character(andun.character_id).global_position + Vector2(0, 60), 64.0)) and hall.select_npc(andun.character_id) and hall.ask_selected("市舶司").any(func(line: String) -> bool: return line.contains("人情")), "%s: 安敦: 你欠我们的人情，我们记着" % way)
	if learned:
		# The 鬼笠馆 has no words for one who stood with the 大秦人.
		var temple_yard: WorldMapController = MapPlaces.enter(session, &"fanfang.temple_yard", &"fanfang.temple_yard.slope_arrival")
		await _settle(tree)
		var dojo: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.gate_yard")
		_check(dojo != null and await MapPlaces.drive_through(tree, dojo, [&"fanfang.dojo"]), "the seal: onto 鬼笠馆's boards")
		for second: int in 2:
			session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		_check(state.marks.get("早川拒了你", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("没有话说")) and _count_in(session, &"fanfang.dojo", &"native.npc.ronin") == 5, "the seal: 早川: 你站了那边。我们没有话说; the four back on the boards")
		var master: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.dojo.ronin_master.1")
		_check(master != null and dojo.npc_life.story_trials_offered(master).is_empty(), "the seal: no 一刀 offered to the 大秦人's friend")


## The 浪人's side: 早川's one blow (a story trial on the popup, asked first), the wait for dark on the boards,
## the 黑影 at the altar with the tablet by night, and the morning after — the 大秦人 cleared.
func _test_ronin_night(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter7")
	StoryFixtures.chapter7_sided(session, false, false)
	session.record_journal()
	session.day_clock().set_day_seconds(36000) # TEST-ONLY: mid-morning
	var temple_yard: WorldMapController = MapPlaces.enter(session, &"fanfang.temple_yard", &"fanfang.temple_yard.slope_arrival")
	await _settle(tree)
	var dojo: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.gate_yard")
	_check(dojo != null and await MapPlaces.drive_through(tree, dojo, [&"fanfang.dojo"]), "night: onto the boards")
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	var master: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.dojo.ronin_master.1")
	var trials: Array[NpcTrial] = [] if master == null else dojo.npc_life.story_trials_offered(master)
	_check(master != null and trials.size() == 1 and trials[0].label == "过他一刀" and trials[0].confirm.begins_with("早川直义的一刀是真砍") and trials[0].blows.size() == 1, "night: 过他一刀 on the popup, asked first, one blow")
	# The 板地 by day: nothing to wait for before the blow.
	var rest: ActService = dojo.service(&"fanfang.dojo.rest") as ActService
	_check(rest != null and await MapPlaces.drive(tree, dojo, MapPlaces.service_spot(dojo, &"fanfang.dojo.rest")) and rest.in_reach(), "night: the 板地 · 歇")
	rest.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().any(func(line: String) -> bool: return line.contains("不是歇脚的")), "night: before the blow the boards are for drilling")
	_full(session.player_runtime())
	_check(await MapPlaces.drive(tree, dojo, MapPlaces.spot(dojo, &"fanfang.dojo", dojo.runtime_body_for_character(master.character_id).global_position + Vector2(-60, 0), 64.0)), "night: before 早川")
	var result: NpcApprenticeTrial.Result = dojo.npc_life.take_story_trial(master, trials[0])
	await _settle(tree)
	_check(result.outcome == NpcApprenticeTrial.Outcome.PASSED and result.blows == 1 and state.marks.get("过了一刀", 0) == 1 and DeedLog.done(state, "在鬼笠馆接下了早川直义的一刀"), "night: the one blow stood: the mark and the deed; outcome %s" % result.outcome)
	_check(dojo.npc_life.story_trials_offered(master).is_empty(), "night: not offered twice")
	session.record_journal()
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(state, quest)
	_check(step != null and step.step_id == &"theft" and StoryQuestLog.objective(state, quests).contains("天黑") and StoryQuestLog.target(state, quests).zone_id == &"fanfang.fire_hall", "night: next, the fire by night: %s" % StoryQuestLog.objective(state, quests))
	# The wait for dark on the boards (asked first), the clock put forward.
	_check(await MapPlaces.drive(tree, dojo, MapPlaces.service_spot(dojo, &"fanfang.dojo.rest")) and rest.in_reach(), "night: back at the 板地")
	rest.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.confirm_button.text == "歇到天黑", "night: asked first: %s" % ui.confirm_prompt.message.text)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(session.day_phase_id() == &"night" and ui.log_lines().any(func(line: String) -> bool: return line.contains("天黑了")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("火坛前站着")), "night: dark, 早川: 去吧。拜火祠 (%s)" % session.day_phase_id())
	rest.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().any(func(line: String) -> bool: return line.contains("天已经黑了")), "night: already dark: nothing to wait for")
	# The 拜火祠 by night: 穆护 in his cell, the 黑影 behind the altar with the tablet.
	var temple: WorldMapController = MapPlaces.enter(session, &"fanfang.fire_hall", &"fanfang.fire_hall.street_entry")
	await _settle(tree)
	_check(temple != null and _count_in(session, &"fanfang.fire_hall", &"native.npc.fire_priest") == 0 and _count_in(session, &"fanfang.priest_room", &"native.npc.fire_priest") == 1 and _count_in(session, &"fanfang.fire_hall", &"native.npc.shadow_thief") == 1, "night: 穆护 in his cell, a 黑影 at the altar")
	for second: int in 5:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("铜牒到手", 0) == 1 and state.marks.get("大秦人被清走", 0) == 1 and session.player_held_item_ids().has(&"native:fanfang/bronze_tablet") and ui.log_lines().any(func(line: String) -> bool: return line.contains("拿着。走。")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("一声骂")) and _count_in(session, &"fanfang.fire_hall", &"native.npc.shadow_thief") == 0, "night: 拿着。走 — the tablet in hand, the 黑影 gone, the 祭司's curse from his cell: %s" % [ui.log_lines().slice(-5)])
	session.record_journal()
	step = StoryQuestLog.current_step(state, quest)
	_check(step != null and step.step_id == &"read", "night: next, to read it")
	# The morning after: the hall and the yard empty, 安敦 in a 枷 on the quay, 卢卡 there with one line.
	session.day_clock().set_day_seconds(36000)
	var hall: WorldMapController = MapPlaces.enter(session, &"fanfang.shield_yard", &"fanfang.shield_yard.gate_arrival")
	await _settle(tree)
	_check(hall != null and _count_in(session, &"fanfang.shield_yard", &"native.npc.shield_swordsman") == 0 and _count_in(session, &"fanfang.hall", &"native.npc.andun") == 0, "night: 铁盾会 empty")
	bazaar_gone(session)
	var port: WorldMapController = MapPlaces.enter(session, &"fanfang.dock", &"fanfang.dock.bazaar_return")
	await _settle(tree)
	_check(port != null and _count_in(session, &"fanfang.dock", &"native.npc.andun") == 1 and _count_in(session, &"fanfang.dock", &"native.npc.customs_runner") == 2 and _count_in(session, &"fanfang.dock", LUCA) == 1, "night: 安敦 between two runners on the quay, 卢卡 there")
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(state.marks.get("卢卡恨了你", 0) == 1 and state.marks.get("安敦在码头见过你", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("你知道那文书是假的")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("一副枷")), "night: 卢卡: 你知道那文书是假的; 安敦 in a 枷 says nothing: %s" % [ui.log_lines().slice(-4)])
	var luca: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.dock.luca.1")
	_check(luca != null and await MapPlaces.drive(tree, port, MapPlaces.spot(port, &"fanfang.dock", port.runtime_body_for_character(luca.character_id).global_position + Vector2(0, -60), 64.0)) and port.select_npc(luca.character_id) and port.ask_selected("会首").any(func(line: String) -> bool: return line.contains("押走的")), "night: 卢卡: 船上。押走的")
	# The tablet read: the chapter done on this side, the eighth chapter's stub.
	await _read_the_tablet(tree, session, port, "night")


## TEST-ONLY: 卢卡 no longer at the gate once the 大秦人 are cleared.
func bazaar_gone(session: WorldSessionController) -> void:
	var bazaar: WorldMapController = MapPlaces.enter(session, &"fanfang.bazaar_north", &"fanfang.bazaar_north.hall_return")
	_check(bazaar != null and _count_in(session, &"fanfang.bazaar_north", LUCA) == 0, "night: 卢卡 gone from the gate")


## The 铜牒 read from the 背包: the five lines of the 封法 (HIW), 读过铜牒, the chapter's milestone and deed
## (by the side), 番坊一章; the eighth chapter opens with its one step at the lakeside.
func _read_the_tablet(tree: SceneTree, session: WorldSessionController, map: WorldMapController, way: String) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var tablet: StringName = _carried(session, &"native:fanfang/bronze_tablet")
	_check(not tablet.is_empty() and map.act_with_item(tablet), "%s: 读铜牒" % way)
	await _settle(tree)
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("头在湖底冰下")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("须有人留下")) and state.marks.get("读过铜牒", 0) == 1, "%s: the five lines, 读过铜牒: %s" % [way, ui.log_lines().slice(-7)])
	session.record_journal()
	_check(state.quests.has("main.chapter7#done") and state.marks.get("番坊一章", 0) == 1 and DeedLog.done(state, "从拜火祠取回了三百年前老兵刻下封法的铜牒"), "%s: the chapter done: 番坊一章, the deed" % way)
	var eighth: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter8")
	_check(eighth != null and eighth.requires == [&"main.chapter7"] and eighth.steps.size() == 6 and StoryQuestLog.current_step(state, eighth) != null and StoryQuestLog.objective(state, quests).contains("湖底") and StoryQuestLog.target(state, quests) != null and StoryQuestLog.target(state, quests).zone_id == &"village.lakeside", "%s: the eighth chapter open (第八章 A): 下湖底，看清封物: %s" % [way, StoryQuestLog.objective(state, quests)])
	_check(not session.player_held_item_ids().is_empty() and session.player_held_item_ids().has(&"native:fanfang/bronze_tablet"), "%s: the tablet kept" % way)


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


## TEST-ONLY: the fight runs on without the player's hand until it is over (story_chapter6_test).
func _fight_out(session: WorldSessionController) -> int:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 1500:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.shared_ui().dismiss_current_panel()
	return rounds


func _full(player: WorldPlayerRuntimeState) -> void:
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: nobody dies here
	player.state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY


## The instance id of a definition the player carries directly, or "".
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
