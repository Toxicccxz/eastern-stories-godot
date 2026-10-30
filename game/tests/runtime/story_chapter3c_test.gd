extends RefCounted

## 逆灵宫 C (owner's plan, 2026-10-29; DECISIONS「逆灵宫 C」): from B's end (StoryFixtures: the
## dungeon seen, the 黑冠 on) — the 北门 into the 后殿 and the 唤首 scene as the player comes in
## (held, hurried, its mark; the shade summoned and gone; 商玦 and 玄冥子 gone; the 黑门 found by
## the scene's mark; the 鬼卒 summoned and attacking), the `ghosts` step once they are down (no
## corpse), then the two endings in two sessions:
## - rescue: the keyed jailers on the stage, the key (TEST-ONLY: given), 霍铮's cell opened and his
##   call (he follows, the mark, the `choice/rescue` option), 石头 too, the 关北 men gone; the
##   backhill's 玄冥子 off the stage; 黄霸's scene at the 土地庙 (the yield, 石头 sent home, the
##   mark, 霍铮 home on the next visit), the chapter done with its deed and milestone;
## - chase: the back door asked and confirmed, the cliff path (`choice/chase`), 玄冥子 on it and
##   attacking, spared → his mood, the mark, the 残卷 dropped; beaten (TEST-ONLY) → 玄冥子倒了,
##   the chapter done; the dungeon after: the prisoners gone, the bodies on the floor.

const MapPlaces := preload("res://tests/support/map_places.gd")
const CROWN: StringName = &"native:niling/black_crown"
const KEY: StringName = &"native:niling/cell_key"
const SCROLL: StringName = &"native:niling/scroll_fragment"
const SCENE_MARK: String = "见过唤首"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var rescue: WorldSessionController = await _session(tree)
	await _test_scene_and_ghosts(tree, rescue)
	await _test_rescue(tree, rescue)
	rescue.free()
	await tree.process_frame
	var chase: WorldSessionController = await _session(tree)
	await _test_scene_and_ghosts(tree, chase, false)
	await _test_chase(tree, chase)
	chase.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


## Into the 后殿 in the crown: the scene plays, the ghouls come, and (TEST-ONLY: sent away for
## beaten) fall; the `ghosts` step and the `choice` next.
func _test_scene_and_ghosts(tree: SceneTree, session: WorldSessionController, verbose: bool = true) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	StoryFixtures.chapter3_dungeon_done(session)
	session.record_journal()
	_check(StoryQuestLog.objective(state, quests).begins_with("牢门开不了"), "at the altar step: %s" % [StoryQuestLog.objective(state, quests)])
	_check(session.handoff_to(&"niling.slope", &"niling.goods_path", &"niling.goods_path", &"niling.goods_path.gate_return").succeeded(), "on the goods road")
	var slope: WorldMapController = session.active_map() as WorldMapController
	await _settle(tree)
	var crown: StringName = slope.give_new_item_to_player(CROWN)
	_check(not crown.is_empty() and session.wear_player_item(crown).succeeded, "the 黑冠 on (TEST-ONLY: given)")
	var gate: WorldMapController = await MapPlaces.go_to(tree, session, &"niling.yard")
	_check(gate != null and gate.map_id() == &"niling.gate" and await MapPlaces.drive(tree, gate, MapPlaces.door_spot(gate, &"niling.front.door", &"niling.yard")) and gate.open_door(&"niling.front.door") and await MapPlaces.take_passage(tree, gate, &"niling.yard.north"), "through the 山门 and the 殿门")
	var hall: WorldMapController = session.active_map() as WorldMapController
	await _settle(tree)
	_check(hall != null and hall.map_id() == &"niling.hall", "in the 前殿")
	var north: WorldDoor = hall.door(&"niling.altar.door")
	_check(north != null and not north.is_open() and await MapPlaces.drive(tree, hall, MapPlaces.door_spot(hall, &"niling.altar.door", &"niling.front")) and hall.open_door(&"niling.altar.door"), "the 北门 shut, opened by hand")
	_check(await MapPlaces.take_passage(tree, hall, &"niling.front.north"), "through it")
	var rear: WorldMapController = session.active_map() as WorldMapController
	await _settle(tree)
	_check(rear != null and rear.map_id() == &"niling.rear" and session.player_runtime().world_location().zone_id == &"niling.altar", "in the 后殿: %s" % [session.active_map_id()])
	if verbose:
		_check(_count_in(session, &"niling.altar", &"native.npc.shang_jue") == 1 and _count_in(session, &"niling.altar", &"native.npc.xuan_mingzi") == 1 and _count_in(session, &"niling.altar", &"native.npc.headless_shade") == 0 and _count_in(session, &"niling.altar", &"native.npc.hell_runner") == 0, "商玦 and 玄冥子 at the altar; the shade and the 鬼卒 not yet")
		var black: WorldDoor = rear.door(&"niling.master.door")
		_check(black != null and not black.is_open() and not rear.can_operate_door(&"niling.master.door"), "the 黑门 shut, worked by no hand")
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(session.scene_held() and rear.scene_running() and rear.player_body.walk_paused, "the 唤首 scene holds the player as they come in")
	_check(state.marks.get(SCENE_MARK, 0) == 1, "marked as seen the moment it began")
	if verbose:
		_check(rear.door(&"niling.master.door").is_open(), "the 黑门 opens with the scene's mark")
		_check(OldPineSaveEligibility.inspect(session).outcome == OldPineSaveEligibilityResult.Outcome.SCENE_RUNNING, "no save while it runs")
	var log_before: int = ui.log_lines().size()
	var seen_shade: bool = false
	for second: int in 40:
		if not rear.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		if not seen_shade and _count_in(session, &"niling.altar", &"native.npc.headless_shade") == 1:
			seen_shade = true
	_check(not rear.scene_running() and not session.scene_held(), "the scene is over")
	var lines: Array[String] = ui.log_lines().slice(log_before)
	if verbose:
		_check(seen_shade and _count_in(session, &"niling.altar", &"native.npc.headless_shade") == 0, "the headless shade came out of the flame and went with it")
		_check(lines.any(func(line: String) -> bool: return line.contains("祭品自己走上坛来")) and lines.any(func(line: String) -> bool: return line.contains("子时见")), "商玦's lines: %s" % [lines.slice(0, 3)])
		_check(_count_in(session, &"niling.altar", &"native.npc.shang_jue") == 0 and _count_in(session, &"niling.altar", &"native.npc.xuan_mingzi") == 0, "商玦 and 玄冥子 gone through the 黑门")
	_check(_count_in(session, &"niling.altar", &"native.npc.hell_runner") == 2, "two 鬼卒 out of the altar's foot")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(session.combat_encounter_coordinator().has_active_encounter(), "they fall on the player, crown or no crown")
	session.record_journal()
	_check(state.quests.has("main.chapter3/altar") and StoryQuestLog.objective(state, quests).begins_with("坛底爬出来的鬼卒"), "the altar step done, the ghouls next: %s" % [StoryQuestLog.objective(state, quests)])
	# TEST-ONLY: out of the fight (fled), then the ghouls leave (the clearing counts them gone).
	await _flee(tree, session)
	for npc: NpcRuntimeState in rear.npc_runtimes():
		if npc.definition().definition_id == &"native.npc.hell_runner" and npc.exists_in_map:
			rear.npcs.leave_for_good(npc)
	session.record_journal()
	_check(state.marks.get("祭坛的鬼卒倒了", 0) == 1 and state.quests.has("main.chapter3/ghosts") and StoryQuestLog.objective(state, quests).begins_with("两件事只来得及做一件"), "the ghouls cleared; the choice: %s" % [StoryQuestLog.objective(state, quests)])
	if verbose:
		var hooks: NpcHooks = GameContent.catalog().npc(&"native.npc.hell_runner").hooks()
		_check(hooks != null and hooks.vanishes and hooks.vanish_line.contains("黑烟"), "a 鬼卒 leaves no corpse (vanishes)")


## The rescue: the key, 霍铮's cell, the followers, the backhill empty, 黄霸's scene, the end.
func _test_rescue(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter3")
	var dungeon: WorldMapController = await MapPlaces.go_to(tree, session, &"niling.corridor")
	_check(dungeon != null and dungeon.map_id() == &"niling.dungeon", "down to the passage")
	await _settle(tree)
	_check(_count_in(session, &"niling.corridor", &"native.npc.niling_jailer") == 0 and _count_in(session, &"niling.corridor", &"native.npc.niling_jailer_keyed") == 2, "the keyless jailers off the stage, the keyed ones on it")
	var keyed: NpcRuntimeState = MapPlaces.npc_at(session, &"niling.corridor.jailer.1")
	var found_keyed: bool = false
	for npc: NpcRuntimeState in dungeon.npc_runtimes():
		if npc.definition().definition_id == &"native.npc.niling_jailer_keyed" and npc.exists_in_map:
			keyed = npc
			found_keyed = true
	_check(found_keyed and _carries(dungeon, keyed, KEY), "a keyed jailer carries the 地牢钥匙")
	# TEST-ONLY: 放过 as he lay drops the key where he stands.
	session.npc_spared(keyed)
	_check(not dungeon.floor_item_of(KEY, &"niling.corridor").is_empty() and state.marks.get("狱卒交了钥匙", 0) == 1, "spared, he drops the key (spared.drop)")
	var key_item: StringName = dungeon.give_new_item_to_player(KEY)
	_check(not key_item.is_empty() and await MapPlaces.drive(tree, dungeon, MapPlaces.door_spot(dungeon, &"niling.cell_huo.door", &"niling.corridor")) and dungeon.open_door(&"niling.cell_huo.door"), "the key in hand (TEST-ONLY): 霍铮's door opens")
	_check(await MapPlaces.drive_to_zone(tree, dungeon, &"niling.cell_huo"), "into his cell")
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	var huo: NpcRuntimeState = MapPlaces.npc_at(session, &"niling.cell_huo.huo_zheng.1")
	_check(huo != null and huo.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) and state.marks.get("救出了霍铮", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("老子跟你走")), "霍铮 follows, the mark: %s" % [ui.log_lines().slice(maxi(0, ui.log_lines().size() - 3))])
	session.record_journal()
	_check(state.quests.has("main.chapter3/choice/rescue") and StoryQuestLog.objective(state, quests) == "带霍铮回野羊山的土地庙。", "the rescue chosen; home next: %s" % [StoryQuestLog.objective(state, quests)])
	_check(await _leg(tree, session, dungeon, &"niling.corridor") and await MapPlaces.drive(tree, dungeon, MapPlaces.door_spot(dungeon, &"niling.cell_shitou.door", &"niling.corridor")) and dungeon.open_door(&"niling.cell_shitou.door") and await MapPlaces.drive_to_zone(tree, dungeon, &"niling.cell_shitou"), "石头's door opened, into his cell")
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	var shitou: NpcRuntimeState = MapPlaces.npc_at(session, &"niling.cell_shitou.shitou.1")
	_check(shitou != null and shitou.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) and state.marks.get("救出了石头", 0) == 1, "石头 follows")
	_check(await _leg(tree, session, dungeon, &"niling.corridor") and await MapPlaces.drive(tree, dungeon, MapPlaces.door_spot(dungeon, &"niling.cell_others.door", &"niling.corridor")) and dungeon.open_door(&"niling.cell_others.door") and await MapPlaces.drive_to_zone(tree, dungeon, &"niling.cell_others"), "the third door opened")
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(state.marks.get("放了关北民夫", 0) == 1 and _count_in(session, &"niling.cell_others", &"native.npc.guanbei_corvee") == 0, "the 关北 men go home on their own")
	# TEST-ONLY: the turn's bandits sent away (they would fall on the player at the rope's foot).
	var mountain: WorldMapController = session.world_map_of(&"goathill.mountain") as WorldMapController
	for definition_id: StringName in [&"goathill.npc.bandit", &"goathill.npc.bandit_leader"]:
		var bandit: NpcRuntimeState = mountain.npcs.first_npc_in_zone(definition_id, &"goathill.mroad4")
		while bandit != null:
			mountain.npcs.leave_for_good(bandit)
			bandit = mountain.npcs.first_npc_in_zone(definition_id, &"goathill.mroad4")
	# Home the long way (the followers come along every way the player takes: the stair, the
	# hall, the yard, the gate, the rope down, the road): 黄霸's scene at the 土地庙.
	# Home the long way, a heart beat after every room (the followers walk after the player
	# room by room; TEST-ONLY the beats are ours): the stair, the hall, the yard, the gate, the
	# goods road, the rope down, the road to the 土地庙 — 黄霸's scene as they come in.
	_check(await _leg(tree, session, dungeon, &"niling.corridor") and _count_in(session, &"niling.corridor", &"native.npc.huo_zheng") == 1 and _count_in(session, &"niling.corridor", &"native.npc.shitou") == 1, "back in the passage, the two behind")
	_check(await _through(tree, session, dungeon, &"niling.corridor.up"), "up the stair")
	var hall: WorldMapController = session.active_map() as WorldMapController
	_check(hall != null and hall.map_id() == &"niling.hall" and _count_in(session, &"niling.alchemy", &"native.npc.huo_zheng") == 1, "霍铮 came up the stair")
	_check(await _leg(tree, session, hall, &"niling.front") and await _through(tree, session, hall, &"niling.front.south"), "through the hall and the 殿门")
	var gate: WorldMapController = session.active_map() as WorldMapController
	_check(gate != null and await _leg(tree, session, gate, &"niling.gatehouse") and await _through(tree, session, gate, &"niling.gatehouse.south"), "out of the gate")
	var winch: WorldMapController = session.active_map() as WorldMapController
	_check(winch != null and winch.map_id() == &"niling.slope" and await _leg(tree, session, winch, &"niling.winch"), "down to the winch")
	_check(_count_in(session, &"niling.winch", &"native.npc.huo_zheng") == 1 and _count_in(session, &"niling.winch", &"native.npc.shitou") == 1, "霍铮 and 石头 came along through the 道观")
	_check(await MapPlaces.drive(tree, winch, MapPlaces.service_spot(winch, &"niling.winch.rope")), "at the rope")
	(winch.service(&"niling.winch.rope") as ActService).interact()
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(session.active_map_id() == &"goathill.mountain", "down the rope")
	mountain = session.active_map() as WorldMapController
	_check(_count_in(session, &"goathill.mroad4", &"native.npc.huo_zheng") == 1 and _count_in(session, &"goathill.mroad4", &"native.npc.shitou") == 1, "and down the rope with the player (follows_every_way)")
	# TEST-ONLY: a step out of the crowd at the rope's foot (the test's route-finder treats the two
	# followers' bodies as walls); they walk after the player into mroad3 as they would.
	_check(mountain.place_player(&"goathill.mroad4", Vector2(600, 1300)), "a step down the turn")
	await _settle(tree)
	_check(await _leg(tree, session, mountain, &"goathill.mroad3"), "along the road to mroad3: at %s" % [session.player_runtime().world_location().zone_id])
	_check(await _through(tree, session, mountain, &"goathill.mroad3.east"), "into the 土地庙: at %s %s" % [session.active_map_id(), session.player_runtime().world_location().zone_id])
	var temple: WorldMapController = session.active_map() as WorldMapController
	_check(temple != null and temple.map_id() == &"goathill.temple_house", "to the 土地庙")
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(_count_in(session, &"goathill.temple1", &"native.npc.huo_zheng") == 1 and _count_in(session, &"goathill.temple1", &"native.npc.shitou") == 1, "霍铮 and 石头 came along (follows_every_way)")
	_check(session.scene_held() and temple.scene_running(), "黄霸's scene begins as they come in")
	_check(state.marks.get("霍铮回了寨", 0) == 1, "its mark the moment it began")
	for second: int in 30:
		if not temple.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not temple.scene_running(), "the scene is over")
	var hwang: NpcRuntimeState = MapPlaces.npc_at(session, &"goathill.temple1.bandit_hwang.1")
	_check(hwang != null and hwang.has_flag(StringName(NpcMood.FLAG_PREFIX + "yielded")) and hwang.definition().hooks().moods["yielded"].title == "野羊山三寨主" and hwang.definition().hooks().moods["yielded"].lasting, "黄霸 yields: 野羊山三寨主 (lasting)")
	_check(state.marks.get("石头回家了", 0) == 1 and _count_in(session, &"goathill.temple1", &"native.npc.shitou") == 0 and _count_in(session, &"goathill.temple1", &"native.npc.huo_zheng") == 0, "石头 sent home, 霍铮 into the back room (the resident spawn stands here from the next visit)")
	session.record_journal()
	_check(state.quests.has("main.chapter3/home") and StoryQuestLog.is_done(state, quest), "home: the chapter is done")
	_check(DeedLog.done(state, "从逆灵宫的地牢里救出了霍铮和石头") and DeedLog.done(state, "查清了逆灵宫纳供的真相") and state.marks.get("逆灵宫一章", 0) == 1, "the deeds and the chapter's mark")
	# Back in: 霍铮 home.
	var road: WorldMapController = MapPlaces.enter(session, &"goathill.mroad3", &"goathill.mroad3.temple1_return")
	_check(road != null, "out")
	temple = MapPlaces.enter(session, &"goathill.temple1", &"goathill.temple1.mroad3_entry")
	await _settle(tree)
	_check(temple != null and _count_in(session, &"goathill.temple1", &"native.npc.huo_zheng") == 1, "and 霍铮 sits in the 土地庙 on the next visit")
	# The backhill after the rescue: 玄冥子 is not there (until quest …/choice/rescue). TEST-ONLY:
	# straight there, now that nobody follows any more.
	var backhill: WorldMapController = MapPlaces.enter(session, &"niling.cliff_path", &"niling.cliff_path.door_arrival")
	_check(backhill != null, "out on the cliff path (TEST-ONLY: straight there)")
	await _settle(tree)
	_check(_count_in(session, &"niling.cliff_path", &"native.npc.xuan_mingzi_cliff") == 0, "玄冥子 went with his master: nobody on the path")
	var snapshot: GameSaveSnapshot = _capture(session)
	_check(snapshot != null, "Save at the chapter's end")


## The chase: the back door asked, the cliff, 玄冥子, the 残卷; the dungeon after.
func _test_chase(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter3")
	var rear: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, rear, &"niling.altar.north"), "through the open 黑门")
	var master: WorldMapController = session.active_map() as WorldMapController
	await _settle(tree)
	_check(master != null and master.map_id() == &"niling.master_house", "in 商玦's room: %s" % [session.active_map_id()])
	_check(master.select_landmark(&"niling.master.landmark.shelf") and master.inspect_selected() and ui.inspection_text.text.contains("逆灵"), "the emptied shelf")
	ui.dismiss_current_panel()
	await _settle(tree)
	var back: ActService = master.service(&"niling.master.back_door") as ActService
	_check(back != null and await MapPlaces.drive(tree, master, MapPlaces.service_spot(master, &"niling.master.back_door")) and back.in_reach() and back.verb() == "追出去", "小门 · 追出去 within reach")
	back.interact()
	await tree.physics_frame
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("只来得及一件"), "asked first: %s" % ui.confirm_prompt.message.text)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	var backhill: WorldMapController = session.active_map() as WorldMapController
	_check(backhill != null and backhill.map_id() == &"niling.backhill" and session.player_runtime().world_location().zone_id == &"niling.cliff_path", "out on the cliff path")
	session.record_journal()
	_check(state.quests.has("main.chapter3/choice/chase") and StoryQuestLog.objective(state, quests) == "追上商玦。", "the chase chosen; the duel next: %s" % [StoryQuestLog.objective(state, quests)])
	_check(_count_in(session, &"niling.cliff_path", &"native.npc.xuan_mingzi_cliff") == 1, "玄冥子 on the path")
	var xuan_body: Node2D = backhill.runtime_body_for_character(MapPlaces.npc_at(session, &"niling.cliff_path.xuan_mingzi.1").character_id)
	if xuan_body != null:
		await MapPlaces.drive(tree, backhill, xuan_body.global_position + Vector2(0, 110))
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(session.combat_encounter_coordinator().has_active_encounter(), "he attacks: the chapter's one real fight")
	# TEST-ONLY: 放过 as he lay — his mood, the mark and the 残卷 on the ground; then gone for the clearing.
	var xuan: NpcRuntimeState = MapPlaces.npc_at(session, &"niling.cliff_path.xuan_mingzi.1")
	session.npc_spared(xuan)
	_check(xuan.has_flag(StringName(NpcMood.FLAG_PREFIX + "owed")) and state.marks.get("放过了玄冥子", 0) == 1 and not backhill.floor_item_of(SCROLL, &"niling.cliff_path").is_empty(), "spared: 欠你一命, the mark, the 残卷 dropped")
	var scrolls_before: int = _floor_count(backhill, SCROLL)
	session.npc_spared(xuan)
	_check(xuan.has_flag(NpcDefinition.FLAG_DROPPED_WHEN_SPARED) and _floor_count(backhill, SCROLL) == scrolls_before and scrolls_before == 1, "spared again: no second 残卷 (one per 玄冥子)")
	await _flee(tree, session)
	backhill.npcs.leave_for_good(xuan)
	session.record_journal()
	_check(state.marks.get("玄冥子倒了", 0) == 1 and state.quests.has("main.chapter3/duel") and StoryQuestLog.is_done(state, quest), "玄冥子 down (the clearing): the chapter is done by the duel")
	_check(DeedLog.done(state, "穿过黑门追到了逆灵宫的后山") and not DeedLog.done(state, "从逆灵宫的地牢里救出了霍铮和石头"), "the chase's deed, not the rescue's")
	_check(await MapPlaces.drive_to_zone(tree, backhill, &"niling.cliff") and backhill.select_landmark(&"niling.cliff.landmark.rope") and backhill.inspect_selected() and ui.inspection_text.text.contains("绳索被割断了"), "the cut rope at the cliff's end")
	ui.dismiss_current_panel()
	await _settle(tree)
	# The dungeon after the chase: the jailers did their work.
	var dungeon: WorldMapController = MapPlaces.enter(session, &"niling.corridor", &"niling.corridor.stairs_arrival")
	_check(dungeon != null, "down to the dungeon (TEST-ONLY: straight there)")
	await _settle(tree)
	_check(_count_in(session, &"niling.cell_huo", &"native.npc.huo_zheng") == 0 and _count_in(session, &"niling.cell_shitou", &"native.npc.shitou") == 0 and _count_in(session, &"niling.cell_others", &"native.npc.guanbei_corvee") == 0, "the prisoners gone")
	_check(not dungeon.floor_item_of(&"native:niling/body_huo", &"niling.cell_huo").is_empty() and not dungeon.floor_item_of(&"native:niling/body_shitou", &"niling.cell_shitou").is_empty(), "two bodies in the cells")
	var snapshot: GameSaveSnapshot = _capture(session)
	_check(snapshot != null, "Save after the chase")


## A walk into `zone_id` with a heart beat after it (the followers walk after the player).
func _leg(tree: SceneTree, session: WorldSessionController, map: WorldMapController, zone_id: StringName) -> bool:
	if not await MapPlaces.drive_to_zone(tree, map, zone_id):
		return false
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	return true


## A passage onto another map with a heart beat after it.
func _through(tree: SceneTree, session: WorldSessionController, map: WorldMapController, portal_id: StringName) -> bool:
	if not await MapPlaces.take_passage(tree, map, portal_id):
		return false
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	return true


## Where every NPC of `definition_id` stands (map, zone, exists), for the probe prints.
func _where(session: WorldSessionController, definition_id: StringName) -> Array:
	var found: Array = []
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id:
				found.append([map.map_id(), npc.world_location().zone_id, npc.exists_in_map, npc.has_flag(NpcDefinition.FLAG_GONE), npc.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER)])
	return found


## How many floor items of `definition_id` lie on `map`.
func _floor_count(map: WorldMapController, definition_id: StringName) -> int:
	var found: int = 0
	for item_id: StringName in map.floor_items.floor_item_ids():
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			found += 1
	return found


## TEST-ONLY: out of the fight by fleeing (as hostile_gang_test), rounds until it is over.
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


## Whether `npc` carries an item of `definition_id` directly.
func _carries(map: WorldMapController, npc: NpcRuntimeState, definition_id: StringName) -> bool:
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, npc.character_id)
	for item_id: StringName in map.inventory_state().direct_children(carried):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return true
	return false


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found += 1
	return found


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
	var result: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-10-30T00:00:00Z")
	if result.snapshot == null:
		print("capture rejected: ", result.path, " ", result.detail)
	return result.snapshot


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
