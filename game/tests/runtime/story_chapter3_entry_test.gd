extends RefCounted

## 主线 C (owner, 2026-10-29; DECISIONS「第三章入口」「刘安禄放过后开口」「黄霸改寨主」): 逆灵宫's
## entrance from 旧案's end (StoryFixtures, the secret kept) — 刘安禄 revealed and spared tells of
## 霍铮 and the tribute (a 门房 spared for nothing stays a 门房), 黄霸 in the 土地庙 tells of it
## too, the escort and the cart wait under the crack at the turn from the chapter's start, the
## crack can be looked at, the cart cannot be taken, the quest stops at 「逆灵宫就在裂口上头」,
## and it all saves.

const CART: StringName = &"native:goathill/tribute_cart"
const TURN: StringName = &"goathill.mroad4"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = await _session(tree)
	await _test_entrance(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_entrance(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter3")
	StoryFixtures.chapter2_done(session, true)
	session.record_journal()
	_check(StoryQuestLog.is_done(state, GameContent.catalog().story_quest(&"main.chapter2")) and StoryQuestLog.is_active(state, quest) and StoryQuestLog.objective(state, quests).begins_with("黑衣道士往野羊山北麓去了。"), "逆灵宫 begins as 旧案 ends: %s" % [StoryQuestLog.objective(state, quests)])
	# 刘安禄: 放过 before the reveal changes nothing; revealed (TEST-ONLY: his mood put on, not asked
	# for — the reveal itself is 前两小时 D's suite) and spared, he is 血手刘三 without the hatred.
	var town: WorldMapController = MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry")
	_check(town != null, "in 雪亭镇")
	await _settle(tree)
	var liu: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.school1.guard.1")
	_check(liu != null and liu.mood() == null, "刘安禄 at the 武馆's gate, the 门房")
	session.npc_spared(liu)
	_check(liu.mood() == null and not state.marks.has("放过了刘安禄") and liu.short_name() == "门房 刘安禄", "spared as the 门房: nothing changes (%s)" % [liu.short_name()])
	liu.put_in_mood(liu.definition().hooks().moods["revealed"])
	_check(liu.has_flag(NpcDefinition.FLAG_AGGRESSIVE) and liu.has_flag(NpcDefinition.FLAG_HUNTS_PLAYER), "revealed: 血手刘三 hunts the player")
	session.npc_spared(liu)
	_check(liu.mood() != null and liu.mood().name == "spared" and not liu.has_flag(NpcDefinition.FLAG_AGGRESSIVE) and not liu.has_flag(NpcDefinition.FLAG_HUNTS_PLAYER) and state.marks.get("放过了刘安禄", 0) == 1, "spared: his own mood, no hatred, the mark")
	_check(liu.short_name().contains("血手刘三") and liu.short_name().contains("野羊山寨二寨主") and liu.character_state.applies.get("attack", 0) == 70, "still who he is, as strong as he was: %s" % [liu.short_name()])
	_check(town.place_player(&"snow.school1", town.runtime_body_for_character(liu.character_id).global_position + Vector2(0, 60)), "beside 刘安禄")
	await _settle(tree)
	_check(town.select_npc(liu.character_id) and town.ask_topics_selected().has("大寨主"), "大寨主 to ask")
	var said: Array[String] = town.ask_selected("大寨主")
	_check(said.size() >= 4 and said.any(func(line: String) -> bool: return line.contains("霍铮")) and said.any(func(line: String) -> bool: return line.contains("裂口")) and state.marks.get("刘安禄说了大寨主", 0) == 1, "he tells of 霍铮, 逆灵宫, the tribute and the crack: %s" % [said])
	session.record_journal()
	_check(state.quests.has("main.chapter3/lead/liu") and StoryQuestLog.objective(state, quests) == "去野羊山的山路转角，看黄霸的纳供车。", "recorded; the turn is next")
	_check(town.select_npc(liu.character_id) and town.ask_selected("刘老三").any(func(line: String) -> bool: return line.contains("老子认了")) and not session.combat_encounter_coordinator().has_active_encounter(), "刘老三 asked again is no longer a fight")
	# 黄霸 in the 土地庙: the other way to the same news (the step is past; his mark still falls).
	var temple: WorldMapController = MapPlaces.enter(session, &"goathill.temple1", &"goathill.temple1.mroad3_entry")
	_check(temple != null, "in the 土地庙")
	await _settle(tree)
	var hwang: NpcRuntimeState = MapPlaces.npc_at(session, &"goathill.temple1.bandit_hwang.1")
	_check(hwang != null and hwang.short_name().contains("野羊山三寨主（代寨主）"), "黄霸, acting chief: %s" % ["" if hwang == null else hwang.short_name()])
	_check(temple.place_player(&"goathill.temple1", temple.runtime_body_for_character(hwang.character_id).global_position + Vector2(0, 60)), "beside 黄霸")
	await _settle(tree)
	_check(temple.select_npc(hwang.character_id), "黄霸 in reach")
	said = temple.ask_selected("纳供")
	_check(said.size() >= 5 and said.any(func(line: String) -> bool: return line.contains("逆灵宫")) and said.any(func(line: String) -> bool: return line.contains("山路转角")) and state.marks.get("黄霸说了纳供", 0) == 1, "黄霸 tells of the tribute and the cart at the turn: %s" % [said])
	_check(temple.select_npc(hwang.character_id) and temple.ask_selected("纳供").any(func(line: String) -> bool: return line.contains("不说第二遍")), "and not twice")
	# The turn: the escort and the cart stand there since the chapter began (the stage, on entry).
	var mountain: WorldMapController = MapPlaces.enter(session, &"goathill.mroad3", &"goathill.mroad3.temple1_return")
	_check(mountain != null and mountain.map_id() == &"goathill.mountain", "back on the mountain road")
	await _settle(tree)
	var escorts: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in mountain.npcs.resident_npcs():
		if npc.definition().definition_id == &"native.npc.tribute_taoist" and npc.world_location().zone_id == TURN and npc.exists_in_map:
			escorts.append(npc)
	_check(escorts.size() == 2, "two 押车道士 at the turn: %d" % escorts.size())
	var cart: StringName = mountain.floor_item_of(CART, TURN)
	_check(not cart.is_empty(), "the 纳供车 under the crack")
	# TEST-ONLY: the four bandits on the ledge would open their fight as the player comes to the
	# turn (goathill_test's); they go, this suite being about the tribute, not them.
	for definition_id: StringName in [&"goathill.npc.bandit", &"goathill.npc.bandit_leader"]:
		var bandit: NpcRuntimeState = mountain.npcs.first_npc_in_zone(definition_id, TURN)
		while bandit != null:
			mountain.npcs.leave_for_good(bandit)
			bandit = mountain.npcs.first_npc_in_zone(definition_id, TURN)
	_check(mountain.place_player(TURN, Vector2(640, 1224)), "onto the turn")
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
	var joined: Array[String] = []
	if session.combat_encounter_coordinator().has_active_encounter():
		for participant: CombatParticipant in session.combat_encounter_coordinator().active_encounter().participants():
			var npc: NpcRuntimeState = mountain.find_resident_npc(participant.participant_id)
			joined.append("player" if npc == null else String(npc.definition().definition_id))
	_check(joined.is_empty(), "the escort does not attack: %s" % [joined])
	session.record_journal()
	_check(state.quests.has("main.chapter3/cart") and StoryQuestLog.objective(state, quests).begins_with("逆灵宫就在裂口上头。找到失踪的大寨主霍铮。"), "the cart seen; the gate is the step here (逆灵宫 A goes on from it): %s" % [StoryQuestLog.objective(state, quests)])
	_check(mountain.select_floor_item(cart) and mountain.take_selected_floor_item() == FloorItemPickup.Outcome.NO_GET and not mountain.floor_item_of(CART, TURN).is_empty(), "the cart cannot be taken")
	_check(mountain.select_landmark(&"goathill.mroad4.landmark.crack") and mountain.inspect_selected() and state.marks.get("看过裂口", 0) == 1, "the crack looked at")
	_check(mountain.select_npc(escorts[0].character_id) and mountain.ask_selected("逆灵宫").any(func(line: String) -> bool: return line.contains("听谁说的")), "the escort gives nothing away")
	session.record_journal()
	_check(not StoryQuestLog.is_done(state, quest) and not state.quests.has("main.chapter3/gate"), "逆灵宫 stays open: the gate is not passed here (story_chapter3_test climbs it)")
	# The 任务 page and the save.
	ui.menu_tab_shown(GameMenu.Tab.JOURNAL)
	var page: String = ui.quest_page.shown_text()
	_check(page.contains("逆灵宫 · 野羊山") and page.contains("逆灵宫就在裂口上头。找到失踪的大寨主霍铮。") and page.contains("· 两个黑衣道士守着一辆盖着油布的车。"), "the 任务 page: " + page.left(400))
	var snapshot: GameSaveSnapshot = _capture(session)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	_check(snapshot != null and decoded.snapshot != null and decoded.snapshot.player.character.quests == state.quests and decoded.snapshot.player.character.marks.get("放过了刘安禄", 0) == 1, "saved and read back: %s" % [decoded.detail])


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("逆灵宫", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	return session


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _capture(session: WorldSessionController) -> GameSaveSnapshot:
	var result: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-10-29T00:00:00Z")
	return result.snapshot


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
