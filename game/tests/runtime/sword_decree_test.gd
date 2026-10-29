extends RefCounted

## 任务系统 (owner, 2026-10-29; DECISIONS「任务系统」): 寻剑令's first half end to end — the
## quest begins with the waiter met, the 目标 row takes it with the 新手链 as 建议, 店小二's
## 官爷, the square's branch (冯策 asked), the deed with its witnesses, the marker over the way
## out, the arrival at 黄石隘口 that ends it, the 历练, the 任务 page's columns and the save.

const WAITER_SPAWN: StringName = &"snow.inn.waiter"
const INN_ENTRY: StringName = &"snow.square.inn_entry"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = await _session(tree)
	await _test_decree(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_decree(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.prologue")
	for pulse: int in 3:
		session.advance_npc_heartbeat(2.0)
	await _settle(tree)
	if not state.seen_npcs.has("snow.npc.waiter"):
		# The player is born beside him; the greeting beat lists him. TEST-ONLY when the frames did not.
		PlayerEssenceMagic.meet(state, _npc_of(session, &"snow.npc.waiter"), false)
	session.record_journal()
	_check(StoryQuestLog.is_started(state, quest) and state.quests.has("main.prologue#started"), "meeting the waiter begins 寻剑令: %s" % [state.quests])
	var log: Array[String] = ui.log_lines()
	_check(log.has("【任务】寻剑令：大内高手在找一把剑。去西南二十四里的黄石隘口，看他们找什么。"), "told once: %s" % [log.slice(maxi(0, log.size() - 5))])
	ui.refresh_exploration()
	_check(ui.player_objective.text == "目标：跟店小二打听广场上的「官爷」。" and ui.player_advice.visible and ui.player_advice.text == "建议：跟店小二打听「楼上」。", "the 目标 row is the quest's, the 新手链 is the 建议: %s / %s" % [ui.player_objective.text, ui.player_advice.text])
	ObjectiveHints.shown = false
	ui.refresh_exploration()
	_check(not ui.player_objective.visible and not ui.player_advice.visible, "目标提示 off: neither row")
	ObjectiveHints.shown = true
	# The marker on the inn's map: the first step's target is the inn itself, so a pillar in the room.
	var inn: WorldMapController = session.active_map() as WorldMapController
	var view: WorldVoxelView = inn.get_node_or_null("MapView") as WorldVoxelView
	if view != null and view._built:
		view._sync_quest_marker()
		_check(view.quest_marker != null and view.quest_marker.get_meta("target_zone", &"") == &"snow.inn.main_floor", "the inn's marker stands in the inn's room: %s" % [null if view.quest_marker == null else view.quest_marker.get_meta("target_zone", &"")])
	# 店小二: 官爷.
	await _stand_at(tree, session, WAITER_SPAWN)
	var map: WorldMapController = session.active_map() as WorldMapController
	var waiter: NpcRuntimeState = _npc_of(session, &"snow.npc.waiter")
	_check(map.select_npc(waiter.character_id) and map.ask_topics_selected().has("官爷"), "店小二 in reach, 官爷 to ask: %s" % [map.ask_topics_selected()])
	var said: Array[String] = map.ask_selected("官爷")
	_check(said.size() == 3 and said[1].contains("外头广场上来了官爷") and said[2].contains("旋芒宝剑"), "the waiter's two lines: %s" % [said])
	_check(state.quests.has("main.prologue/waiter") and StoryQuestLog.objective(state, quests) == "去镇前的广场，看看官爷们在做什么。", "recorded at the ask; on to the square: %s" % [state.quests])
	_check(ui.log_lines().has("【见闻】店小二说外头广场上来了大内的官爷，叫你去瞧瞧。") and ui.log_lines().has("下一步：去镇前的广场，看看官爷们在做什么。"), "told with its next")
	# The square: 冯策 asked about 寻剑 is the official way; the onlooker's way is then closed.
	map = MapPlaces.enter(session, &"snow.square", INN_ENTRY)
	_check(map != null and map.map_id() == &"snow.outdoor", "on the square")
	await _settle(tree)
	var square_view: WorldVoxelView = map.get_node_or_null("MapView") as WorldVoxelView
	if square_view != null and square_view._built:
		square_view._sync_quest_marker()
		_check(square_view.quest_marker != null and square_view.quest_marker.get_meta("target_zone", &"") == &"snow.square", "on the target's map the marker stands in the square itself")
	var feng: NpcRuntimeState = _npc_of(session, &"native.npc.feng_ce")
	var onlooker: NpcRuntimeState = _npc_of(session, &"native.npc.onlooker")
	_check(feng != null and onlooker != null and _npc_of(session, &"native.npc.song_pu") != null and _npc_of(session, &"native.npc.courier") != null and _npc_of(session, &"native.npc.white_officer") != null, "the officials, the courier and the onlooker stand on the square")
	_check(map.place_player(&"snow.square", map.runtime_body_for_character(feng.character_id).global_position + Vector2(0, 60)), "beside 冯策")
	await _settle(tree)
	_check(map.select_npc(feng.character_id), "冯策 in reach")
	var deeds_before: int = state.deeds.size()
	said = map.ask_selected("寻剑")
	_check(said.size() == 3 and said[1].contains("大声点，让众位兄弟都听见了") and said[2].contains("西南二十四里，黄石隘口"), "冯策's order and the courier's answer: %s" % [said])
	_check(state.quests.has("main.prologue/square/official") and not state.quests.has("main.prologue/square/crowd") and StoryQuestLog.objective(state, quests) == "去西南二十四里的黄石隘口，看他们找什么。", "the official way taken: %s" % [state.quests])
	_check(state.deeds.size() == deeds_before + 1 and state.deeds[-1].did == "在广场上当面向大内的总教头问了寻剑的事" and state.deeds[-1].where == &"snow.square" and state.deeds[-1].seen_by.has(&"native.npc.feng_ce") and state.deeds[-1].seen_by.has(&"native.npc.onlooker"), "the deed, seen by those on the square: %s" % [state.deeds[-1].seen_by if state.deeds.size() > deeds_before else []])
	_check(ui.log_lines().any(func(line: String) -> bool: return line.begins_with("【事迹】在广场上当面向大内的总教头问了寻剑的事（在") and line.contains("冯策")), "told as a 【事迹】 line with who saw: %s" % [ui.log_lines().slice(maxi(0, ui.log_lines().size() - 4))])
	map.place_player(&"snow.square", map.runtime_body_for_character(onlooker.character_id).global_position + Vector2(60, 0))
	await _settle(tree)
	map.select_npc(onlooker.character_id)
	said = map.ask_selected("黄石隘口")
	_check(said.size() == 2 and not state.quests.has("main.prologue/square/crowd"), "the onlooker still answers, but the branch is decided: %s" % [said])
	var target: StoryQuestDefinition.Target = StoryQuestLog.target(state, quests)
	_check(target != null and target.map_id == &"canyon.pass" and target.zone_id == &"canyon.canyon1", "the target: 黄石隘口")
	_check(WorldRoute.next_step(GameContent.catalog(), map.map_id(), target.map_id).portal.portal_id == &"snow.sroad4.southwest", "from the square the way is the road southwest")
	if square_view != null and square_view._built:
		square_view._sync_quest_marker()
		_check(square_view.quest_marker != null and square_view.quest_marker.get_meta("way", &"") == &"snow.sroad4.southwest", "the marker moved to the road out of town: %s" % [null if square_view.quest_marker == null else square_view.quest_marker.get_meta("way", &"")])
	# 黄石隘口: arriving does the pass step; the officials are digging there (the stage,
	# WorldStoryPresence) and the scene begins as the player comes in (DECISIONS「剧情演出」).
	var rewards_before: int = _rewards(session).size()
	deeds_before = state.deeds.size()
	map = MapPlaces.enter(session, &"canyon.canyon1", &"canyon.canyon1.chain_arrival")
	_check(map != null and map.map_id() == &"canyon.pass", "at the pass")
	await _settle(tree)
	session.record_journal()
	_check(state.quests.has("main.prologue/pass") and not StoryQuestLog.is_done(state, quest) and StoryQuestLog.objective(state, quests) == "看官队在山壁下挖什么。", "arriving does the pass step; the scene is next: %s" % [state.quests])
	var pass_npcs: Array = map.npc_runtimes().filter(func(npc: NpcRuntimeState) -> bool: return npc.exists_in_map).map(func(npc: NpcRuntimeState) -> String: return String(npc.definition().definition_id))
	_check(pass_npcs.count("native.npc.feng_ce") == 1 and pass_npcs.count("native.npc.white_officer") == 3 and pass_npcs.count("native.npc.bai_daozhang") == 1 and pass_npcs.count("native.npc.black_taoist_pass") == 1, "the officials, 白道长 and the 黑衣道士 stand at the pass: %s" % [pass_npcs])
	var square: WorldMapController = session.world_map_of(&"snow.outdoor")
	var square_officials: Array = square.npc_runtimes().filter(func(npc: NpcRuntimeState) -> bool: return npc.definition().definition_id == &"native.npc.feng_ce")
	_check(square_officials.size() == 1 and square_officials[0].exists_in_map, "the square's 冯策 is still there until the player comes back to that map")
	session.advance_npc_heartbeat(0.5)
	_check(session.scene_held() and map.scene_running() and map.player_body.walk_paused, "the scene holds the player as they come in")
	ui.waits.refresh()
	ui.nearby.refresh()
	_check(ui.waits.texts().any(func(line: String) -> bool: return line.begins_with("白道长：第 0 / 7 句")) and ui.waits.can_hurry(), "the status card: 白道长's seven lines, 继续: %s" % [ui.waits.texts()])
	_check(ui.nearby.groups().is_empty() and not ui.interact(), "nothing in reach is offered while it runs")
	var log_before: int = ui.log_lines().size()
	_check(ui.waits.hurry(), "继续 brings the first line now")
	session.advance_npc_heartbeat(0.0)
	_check(ui.log_lines().slice(log_before).any(func(line: String) -> bool: return line.contains("总教头，挖出来了！")), "the officer's line, in his own voice: %s" % [ui.log_lines().slice(log_before)])
	var focus: Node2D = map.npc_life.scene_focus_body()
	var officer: NpcRuntimeState = _npc_of(session, &"native.npc.white_officer")
	_check(focus != null and focus == map.runtime_body_for_character(_speaker_of(map, &"native.npc.white_officer").character_id), "the camera looks at the officer who spoke")
	for second: int in 30:
		if not map.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
	_check(not map.scene_running() and not session.scene_held() and not map.player_body.walk_paused, "the scene is over: the player may walk again")
	_check(state.marks.get("隘口的道士", 0) == 1, "the scene's mark")
	var strip: StringName = map.floor_item_of(&"native:oldpine/cloth_strip", &"canyon.canyon1")
	_check(not strip.is_empty(), "the strip lies on the ground")
	pass_npcs = map.npc_runtimes().filter(func(npc: NpcRuntimeState) -> bool: return npc.exists_in_map).map(func(npc: NpcRuntimeState) -> String: return String(npc.definition().definition_id))
	_check(pass_npcs.count("native.npc.black_taoist_pass") == 0 and pass_npcs.count("native.npc.white_officer") == 1 and pass_npcs.count("native.npc.feng_ce") == 1, "the taoist fled, two officers after him; 冯策 stays: %s" % [pass_npcs])
	_check(ui.log_lines().has("冯策说道：这不是你该来的地方。") and ui.log_lines().any(func(line: String) -> bool: return line.contains("老松寨的记号")), "冯策's line and 白道长's last: %s" % [ui.log_lines().slice(-6)])
	session.record_journal()
	_check(state.quests.has("main.prologue/scene") and StoryQuestLog.objective(state, quests) == "拾起黑衣道士掉下的布条。", "the scene recorded; the strip is next")
	# The strip: 寻剑令 ends, 伪墓 begins.
	var strip_view: WorldFloorItemView = map.floor_items.floor_item_view(strip)
	var beside: Vector2 = Vector2.INF if strip_view == null else MapPlaces.spot(map, &"canyon.canyon1", strip_view.global_position, 72.0)
	_check(strip_view != null and beside.is_finite() and map.place_player(&"canyon.canyon1", beside), "beside the strip (%s)" % [null if strip_view == null else strip_view.global_position])
	await _settle(tree)
	_check(map.select_floor_item(strip) and map.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN, "picked up")
	session.record_journal()
	_check(state.quests.has("main.prologue/strip") and StoryQuestLog.is_done(state, quest), "the strip ends 寻剑令: %s" % [state.quests])
	var quest_rewards: Array[String] = _rewards(session).slice(rewards_before).filter(func(line: String) -> bool: return line.contains("寻剑令"))
	_check(state.milestones.has("quest/main.prologue") and quest_rewards.size() == 1 and quest_rewards[0].begins_with("【历练】你办成了「寻剑令」：实战经验 +"), "the 历练: %s" % [_rewards(session).slice(rewards_before)])
	_check(state.deeds.size() >= deeds_before + 1 and state.deeds[-1].did == "在黄石隘口看着官队挖出石匣、又被黑衣道士抢走" and state.deeds[-1].where == &"canyon.canyon1", "the end's deed")
	_check(ui.log_lines().has("【任务完成】寻剑令"), "told: %s" % [ui.log_lines().slice(maxi(0, ui.log_lines().size() - 6))])
	var chapter1: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter1")
	_check(StoryQuestLog.is_active(state, chapter1) and StoryQuestLog.tracked(state, quests) == chapter1, "伪墓 begins with the strip in hand, within the first half hour: %s" % [state.quests])
	ui.refresh_exploration()
	_check(ui.player_objective.text == "目标：顺着布条上的记号去老松岭，沿松树上的刀痕找老松寨。", "the 目标 row is 伪墓's: %s" % [ui.player_objective.text])
	var pass_view: WorldVoxelView = map.get_node_or_null("MapView") as WorldVoxelView
	if pass_view != null and pass_view._built:
		pass_view._sync_quest_marker()
		_check(pass_view.quest_marker != null and pass_view.quest_marker.get_meta("way", &"") == &"canyon.canyon1.chain", "the marker points up the chain, towards 老松岭: %s" % [null if pass_view.quest_marker == null else pass_view.quest_marker.get_meta("way", &"")])
	session.record_journal()
	_check(_rewards(session).filter(func(line: String) -> bool: return line.contains("寻剑令")).size() == 1, "not twice")
	# The 任务 page: 主线 with 伪墓 going on and 寻剑令 done; 差事 with the 新手链.
	ui.menu_tab_shown(GameMenu.Tab.JOURNAL)
	var page: String = ui.quest_page.shown_text()
	_check(page.begins_with("主线\n伪墓 · 老松岭\n追到黑衣道士，弄清老松寨和那口墓。") and page.contains("寻剑令 · 雪亭镇 · 已完成") and page.contains("· 布条上刻着老松寨的记号：黑衣道士往老松岭去了。"), "主线 first, 伪墓 going on, 寻剑令 done with its records: " + page.left(300))
	_check(page.contains("差事\n") and page.contains("雪亭镇的头几天 · 雪亭镇") and not page.contains("势力") and not page.contains(QuestPage.NOTHING_YET), "差事 holds the 新手链; empty columns are not shown: " + page)
	_check(ui.character_sheet_text().contains("办成「寻剑令」"), "the 角色 page's 历练 names it")
	# Back on the square's map the officials are gone (the stage, judged as the player comes in).
	map = MapPlaces.enter(session, &"snow.square", INN_ENTRY)
	_check(map != null and map.map_id() == &"snow.outdoor", "back on the square")
	await _settle(tree)
	_check(not square_officials[0].exists_in_map and square_officials[0].has_flag(NpcDefinition.FLAG_GONE), "冯策 and his men left the square")
	# The save keeps the ledger and the deeds.
	var snapshot: GameSaveSnapshot = _capture(session)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	_check(snapshot != null and decoded.snapshot != null and decoded.snapshot.player.character.quests == state.quests and decoded.snapshot.player.character.deeds.size() == state.deeds.size() and decoded.snapshot.player.character.deeds[-1].equals(state.deeds[-1]), "saved and read back: %s" % [decoded.detail])


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("寻剑", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	return session


func _stand_at(tree: SceneTree, session: WorldSessionController, spawn_id: StringName) -> void:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(spawn_id)
	session.handoff_to(spawn.map_id, spawn.zone_id, spawn.zone_id, spawn.spawn_point_ids()[0])
	await _settle(tree)


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


## The first standing NPC of `definition_id` in the player's room on `map`.
func _speaker_of(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	return map.npcs.first_npc_in_zone(definition_id, map.player_runtime().world_location().zone_id, true)


func _npc_of(session: WorldSessionController, definition_id: StringName) -> NpcRuntimeState:
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id:
				return npc
	return null


func _rewards(session: WorldSessionController) -> Array[String]:
	var lines: Array[String] = []
	for line: String in session.shared_ui().log_lines():
		if line.begins_with("【历练】"):
			lines.append(line)
	return lines


func _capture(session: WorldSessionController) -> GameSaveSnapshot:
	var result: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-10-29T00:00:00Z")
	return result.snapshot


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
