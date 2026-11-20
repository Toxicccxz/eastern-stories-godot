extends RefCounted

## 全项目审查 补充 D (DECISIONS「尸体和走散的同伴」「走散的同伴回来」): one who follows the player every
## way (小娟, chuenyu.npc.xiaojuan2: NpcHooks.follows_every_way) comes along only from the room the
## player left, awake and not fighting; a death, 遁, an arrest and the night watch move the player
## without her. After the return to life, the court's release and the night watch's she comes to
## the player with a line (owner 2026-11-19); after 遁, being led into court, or lying knocked down
## she stays, and the player is told: a line when a map change leaves her behind, a line on the 任务
## page, a mark on the 沙盘, the quest arrow pointing to her; the same after Save and Continue, read
## from the world (no field of its own). The corpse with the player's things is told the same way.

const MapPlaces := preload("res://tests/support/map_places.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const XIAOJUAN: StringName = &"chuenyu.npc.xiaojuan2"
const CHUNYU: StringName = &"chuenyu.npc.chuenyu"
const PRISON: StringName = &"chuenyu.prison"
const DUNGEON: StringName = &"chuenyu.dungeon"
const STAYED: String = "小娟没有跟上来，还在黑松山 · 刑房。"
const CAME: String = "小娟找了过来，又跟在你身边。"
const WAITS: String = "小娟还在黑松山 · 刑房等你。"
const CORPSE_LINE: String = "你的尸体和留在上面的东西还在：黑松山 · 刑房"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	TestDeath.use()
	var session: WorldSessionController = await _session(tree)
	await _death(tree, session)
	await _dun(tree, session)
	session = await _continue(tree, session)
	_after_continue(session)
	await _arrest(tree, session)
	await _night_watch(tree, session)
	await _knocked_down(tree, session)
	session.free()
	await tree.process_frame
	TestDeath.restore()
	return {"assertions": _count, "failures": _failures.duplicate()}


## Dead beside her: no line on the way to 阴间 (she stays in the 刑房); back at the 城隍庙 she comes to the
## player with a line; the hint names the corpse and 精气神 at 1; the corpse on the 任务 page and the 沙盘.
func _death(tree: SceneTree, session: WorldSessionController) -> void:
	var juan: NpcRuntimeState = await _with_her(tree, session)
	if juan == null:
		return
	var ui: SharedGameplayUI = session.shared_ui()
	# Something in the bag (what is worn stays on the player: DECISIONS「减轻死亡」).
	_check(not (session.active_map() as WorldMapController).give_new_item_to_player(&"es2:obj/longsword").is_empty(), "TEST-ONLY: a sword in the bag")
	var before: int = ui.log_lines().size()
	session.player_runtime().state.vitality.effective = -1
	(session.active_map() as WorldMapController).player_fall_below_zero()
	await tree.physics_frame
	var flow: PlayerLifeFlow = session.player_life_flow()
	_check(flow.phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE, "dead")
	session.continue_after_death()
	await tree.physics_frame
	_check(session.active_map_id() == DeathWorldDefinitions.MAP_ID, "a ghost at 鬼门关")
	_check(juan.world_location().zone_id == DUNGEON, "she stays in the 刑房 meanwhile")
	_check(not ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("没有跟上来")), "nothing said on the way to 阴间")
	session.request_reincarnation()
	session._process(0.1)
	await tree.physics_frame
	_check(not session.player_runtime().state.ghost and session.active_map_id() == SnowWorldDefinitions.temple_map_id(), "back to life at the 城隍庙")
	_check(_beside_player(session, juan), "she came to the 城隍庙, beside the player, still following")
	_check(ui.log_lines().slice(before).has(CAME), "told: %s" % [ui.log_lines().slice(before)])
	var notice: String = ui.life_overlay._revived_notice(flow)
	_check(notice.contains(CORPSE_LINE), "the hint names where the corpse lies: %s" % notice)
	_check(not notice.contains("小娟"), "she is no longer apart: %s" % notice)
	_check(notice.contains("精、气、神都只剩 1") and notice.contains("歇到回满"), "and that 歇到回满 brings 精气神 back: %s" % notice)
	_check(_page_lines(session).has(CORPSE_LINE), "the 任务 page names the corpse")
	_check(WorldLeftBehind.marks(session).any(func(mark: MapAtlas.Mark) -> bool: return mark.kind == MapAtlas.CORPSE and mark.map_id == PRISON and mark.zone_id == DUNGEON), "the corpse's mark on the 沙盘")
	var corpses: Array[WorldLeftBehind.Place] = WorldLeftBehind.corpses(session)
	_check(corpses.size() == 1 and corpses[0].map_id == PRISON and corpses[0].zone_id == DUNGEON, "one corpse holds the things, in the 刑房")


## 遁's move (dun.c me->move(), WorldSessionController._move_player_to_temple()) from beside her: one
## line, she stays where she was, and is told apart.
func _dun(tree: SceneTree, session: WorldSessionController) -> void:
	var juan: NpcRuntimeState = await _with_her(tree, session)
	if juan == null:
		return
	var ui: SharedGameplayUI = session.shared_ui()
	var before: int = ui.log_lines().size()
	_check(session._move_player_to_temple(), "遁: to the 城隍庙")
	await tree.physics_frame
	_check(juan.world_location().zone_id == DUNGEON and session.world_map_of(PRISON).npcs.find_resident_npc(juan.character_id) != null, "she stays in the 刑房")
	_check(ui.log_lines().slice(before).has(STAYED), "told once: %s" % [ui.log_lines().slice(before)])
	_told_apart(session, "after 遁")


## After Save and Continue (after 遁) the same is read from the corpse records and her place: no field
## of its own.
func _after_continue(session: WorldSessionController) -> void:
	_check(WorldLeftBehind.corpses(session).size() == 1 and _page_lines(session).has(CORPSE_LINE), "Continue: the corpse is still told")
	_told_apart(session, "after Continue")


## Led to the court (yamen_po.c catchyou()'s end, WorldMapPatrols._deliver()): she is not taken along,
## and is told apart; let go by the judge (settle_lawsuit()), she comes to the player.
func _arrest(tree: SceneTree, session: WorldSessionController) -> void:
	var juan: NpcRuntimeState = await _with_her(tree, session)
	if juan == null:
		return
	var constable: NpcRuntimeState = null
	var his_map: WorldMapController = null
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			var patrol: NpcPatrol = npc.definition().dealings().patrol
			if constable == null and patrol != null and patrol.arrest != null and not patrol.arrest.court_zone_id.is_empty():
				constable = npc
				his_map = map
	_check(constable != null, "a constable who takes thieves to court")
	if constable == null:
		return
	var arrest: NpcArrest = constable.definition().dealings().patrol.arrest
	var ui: SharedGameplayUI = session.shared_ui()
	var before: int = ui.log_lines().size()
	his_map.patrols._deliver(constable, arrest)
	await tree.physics_frame
	_check(session.player_runtime().world_location().zone_id == arrest.court_zone_id and session.player_runtime().awaiting_sentence, "in the court, awaiting the sentence")
	_check(juan.world_location().zone_id == DUNGEON, "she stays in the 刑房")
	_check(ui.log_lines().slice(before).has(STAYED), "told once: %s" % [ui.log_lines().slice(before)])
	_told_apart(session, "led into court")
	var court_map: WorldMapController = session.active_map() as WorldMapController
	var judge: NpcRuntimeState = null
	for npc: NpcRuntimeState in court_map.npc_runtimes():
		if npc.definition().dealings().sentence != null and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			judge = npc
	_check(judge != null, "a judge in the court")
	if judge == null:
		session.player_runtime().awaiting_sentence = false
		return
	before = ui.log_lines().size()
	court_map.patrols.pass_sentence(judge)
	await tree.physics_frame
	_wake(session)
	_check(not session.player_runtime().awaiting_sentence and _beside_player(session, juan), "let go: she is beside the player")
	_check(ui.log_lines().slice(before).has(CAME) and not ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("没有跟上来")), "told she came, not that she stayed: %s" % [ui.log_lines().slice(before)])


## Put out by the night watch (WorldMapWatches._catch(), 第九章 B): she comes to the player.
func _night_watch(tree: SceneTree, session: WorldSessionController) -> void:
	var juan: NpcRuntimeState = await _with_her(tree, session)
	if juan == null:
		return
	var watcher: NpcRuntimeState = null
	var his_map: WorldMapController = null
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if watcher == null and npc.definition().dealings().watch != null:
				watcher = npc
				his_map = map
	_check(watcher != null, "a night watch")
	if watcher == null:
		return
	var watch: NpcWatch = watcher.definition().dealings().watch
	var ui: SharedGameplayUI = session.shared_ui()
	var before: int = ui.log_lines().size()
	his_map.watches._catch(watcher, watch)
	await tree.physics_frame
	_check(session.player_runtime().world_location().zone_id == watch.release_zone_id, "put out at %s" % watch.release_zone_id)
	_check(_beside_player(session, juan), "she is beside the player")
	_check(ui.log_lines().slice(before).has(CAME) and not ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("没有跟上来")), "told she came: %s" % [ui.log_lines().slice(before)])


## Knocked down beside the player, who walks out: she lies where she fell; the 任务 page says so and
## the arrow points to her; up again, she follows; a return to life does not bring one still down.
func _knocked_down(tree: SceneTree, session: WorldSessionController) -> void:
	var juan: NpcRuntimeState = await _with_her(tree, session)
	if juan == null:
		return
	juan.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	var prison: WorldMapController = session.world_map_of(PRISON)
	_check(await MapPlaces.take_same_map_passage(tree, prison, &"chuenyu.dungeon.west") and session.player_runtime().world_location().zone_id != DUNGEON, "the player walks out of the 刑房")
	_check(juan.world_location().zone_id == DUNGEON, "she lies where she fell")
	var lines: Array[String] = _page_lines(session)
	_check(lines.has("小娟倒在黑松山 · 刑房，没能跟上你。"), "the 任务 page: %s" % [lines])
	var goal: MapAtlas.Goal = MapAtlas.goal(GameContent.catalog(), session.player_runtime().state, WorldLeftBehind.follower_goal(session))
	_check(goal != null and goal.map_id == PRISON and goal.zone_id == DUNGEON and goal.npc_ids == [XIAOJUAN], "the arrow points to her")
	_check(session.bring_followers_back().is_empty() and juan.world_location().zone_id == DUNGEON, "one knocked down is not brought")
	juan.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	_check(await MapPlaces.take_same_map_passage(tree, prison, &"chuenyu.tunnel3.east") and session.player_runtime().world_location().zone_id == DUNGEON, "back in the 刑房")
	_check(WorldLeftBehind.followers_apart(session).is_empty(), "with her again: nothing apart")
	var back: MapAtlas.Goal = MapAtlas.goal(GameContent.catalog(), session.player_runtime().state, WorldLeftBehind.follower_goal(session))
	_check(back == null or back.npc_ids != [XIAOJUAN], "the arrow goes back to the quest")


## She is told apart: the 任务 page, the 沙盘's mark, the arrow.
func _told_apart(session: WorldSessionController, label: String) -> void:
	var lines: Array[String] = _page_lines(session)
	_check(lines.has(WAITS), "%s: the 任务 page: %s" % [label, lines])
	var marks: Array[MapAtlas.Mark] = WorldLeftBehind.marks(session)
	_check(marks.any(func(mark: MapAtlas.Mark) -> bool: return mark.kind == MapAtlas.FOLLOWER and mark.map_id == PRISON and mark.zone_id == DUNGEON and mark.who == "小娟"), "%s: her mark on the 沙盘" % label)
	var goal: MapAtlas.Goal = MapAtlas.goal(GameContent.catalog(), session.player_runtime().state, WorldLeftBehind.follower_goal(session))
	_check(goal != null and goal.map_id == PRISON and goal.zone_id == DUNGEON, "%s: the arrow points to her" % label)


func _beside_player(session: WorldSessionController, juan: NpcRuntimeState) -> bool:
	return (
		juan.world_location().map_id == session.active_map_id() and juan.world_location().zone_id == session.player_runtime().world_location().zone_id
		and juan.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) and WorldLeftBehind.followers_apart(session).is_empty()
	)


## TEST-ONLY: up again whatever the sentence's boards did.
func _wake(session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	player.state.vitality = CharacterResourceState.new(100, 100, 100)
	session.player_life_flow().finish()


## The lines the 任务 page shows above its columns.
func _page_lines(session: WorldSessionController) -> Array[String]:
	var ui: SharedGameplayUI = session.shared_ui()
	ui.menu_tab_shown(GameMenu.Tab.JOURNAL)
	var lines: Array[String] = []
	lines.assign(ui.quest_page.shown_text().split("\n"))
	return lines


## TEST-ONLY: the player in the 刑房 beside 小娟, who follows them (xiaojuan2.c's twenty seconds
## are chuenyu_prison_test's); 淳于怀太 out of the way.
func _with_her(tree: SceneTree, session: WorldSessionController) -> NpcRuntimeState:
	var prison: WorldMapController = session.world_map_of(PRISON)
	var chunyu: NpcRuntimeState = _npc(prison, CHUNYU)
	if chunyu != null and chunyu.exists_in_map:
		prison.npcs.vanish(chunyu)
	var juan: NpcRuntimeState = _find_her(session)
	if juan != null and juan.world_location().map_id != PRISON:
		# Back to her room (she came to the player): TEST-ONLY.
		var from: WorldMapController = session.world_map_of(juan.world_location().map_id)
		session._move_npc(juan, from, prison, prison.location_for_zone(DUNGEON), MapPlaces.spot(prison, DUNGEON, MapPlaces.zone_centre(prison, DUNGEON)))
	if session.active_map_id() != PRISON or session.player_runtime().world_location().zone_id != DUNGEON:
		_check(session.handoff_to_point(PRISON, DUNGEON, GameContent.catalog().zone(DUNGEON).combat_location_id, MapPlaces.spot(prison, DUNGEON, MapPlaces.zone_centre(prison, DUNGEON))).succeeded(), "TEST-ONLY: in the 刑房")
	await tree.physics_frame
	juan = _find_her(session)
	_check(juan != null and juan.world_location().zone_id == DUNGEON, "小娟 in the 刑房")
	if juan == null:
		return null
	juan.set_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER, true)
	_check(WorldLeftBehind.followers_apart(session).is_empty(), "beside her: nobody apart")
	return juan


func _find_her(session: WorldSessionController) -> NpcRuntimeState:
	for map: WorldMapController in session.world_maps():
		var found: NpcRuntimeState = _npc(map, XIAOJUAN)
		if found != null:
			return found
	return null


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	return session


## Save, and Continue from it in a fresh session (the old one freed first: two would share physics).
func _continue(tree: SceneTree, session: WorldSessionController) -> WorldSessionController:
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "Save")
	if snapshot == null:
		return session
	session.free()
	await tree.process_frame
	var preparation: OldPineWorldRestoreResult = OldPineWorldRestoreComposition.prepare(snapshot)
	_check(preparation.outcome == OldPineWorldRestoreResult.Outcome.SUCCESS, "Continue prepared: %s %s" % [preparation.path, preparation.detail])
	var restored: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	_check(restored.configure_restore(preparation.preparation), "Continue configured")
	tree.root.add_child(restored)
	_check(restored.activate_restore_candidate(), "Continue")
	restored.set_process(false)
	restored.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY
	await tree.process_frame
	await tree.physics_frame
	return restored


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	if map == null:
		return null
	for npc: NpcRuntimeState in map.resident_npcs():
		if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
