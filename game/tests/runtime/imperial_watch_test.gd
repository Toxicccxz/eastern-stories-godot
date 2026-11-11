extends RefCounted

## 第九章 B 禁军夜巡 (owner's plan, 2026-11-06「按你的推荐来」Q2 轻潜行; DECISIONS「第九章 B」「禁军夜巡」):
## - data: the three night guards' watches (routes on their maps' markers, a 90° cone, lanterns, the
##   night only, a 腰牌 at the belt spares one; caught: the mark, 冯策's lines, dawn, out at the 午门);
##   NpcWatch's cone on its own; pacing's stealth on.
## - the night's way in (from the eighth chapter's ledger): the 地下密室's stone refused till the bed is
##   looked at (看过床底的石板), then down; the tunnel's black cord; up the well (从冷宫井上来: the quest's
##   sneak), 钟嬷嬷's three lines and her 窗闩; the 御花园 at night with its guard on stage: a rock between
##   them hides the player, the cone's back hides them, the lantern's light reaches further; in front of
##   it, a ？ while it looks, caught when the beat is through — the mark, 冯策's line, dawn, out at the
##   午门; caught again, the second time's line; the 腰牌 at the belt, it does not look; stealth off, any side.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const TOKEN: StringName = &"native:imperial/guard_token"
const GARDEN_GUARD: StringName = &"native.npc.night_guard_garden"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	# The day at the game's length (TestDay): wait_until_phase() turns the hours it waits into
	# real seconds by it, and with the day standing still an evening's wait would be years of
	# recovery, resets and catch-up. The sessions here do not process, so no frame moves it.
	TestDay.use()
	_test_data()
	var session: WorldSessionController = await _session(tree)
	await _test_night(tree, session)
	session.free()
	await tree.process_frame
	TestDay.restore()
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for id: StringName in [&"native.npc.night_guard_lanes", &"native.npc.night_guard_gate", GARDEN_GUARD]:
		var npc: NpcDefinition = catalog.npc(id)
		var watch: NpcWatch = null if npc == null else npc.dealings().watch
		_check(watch != null and watch.route.size() >= 2 and watch.cone_degrees == 90 and watch.lit_radius > watch.radius and watch.lantern > 0 and watch.when != null and watch.unless != null and watch.mark == "被禁军拿过" and watch.again_mark == "被禁军拿过两回" and watch.release_zone_id == &"city.wumen" and watch.until_phase == [&"dawn"], "%s keeps a night watch" % id)
	var cone: NpcWatch = catalog.npc(GARDEN_GUARD).dealings().watch
	_check(cone.sees_direction(Vector2.ZERO, Vector2.DOWN, Vector2(0, 100), 150.0, true), "the cone: straight ahead within reach")
	_check(not cone.sees_direction(Vector2.ZERO, Vector2.DOWN, Vector2(0, 200), 150.0, true), "the cone: not beyond its reach")
	_check(not cone.sees_direction(Vector2.ZERO, Vector2.DOWN, Vector2(100, 10), 150.0, true), "the cone: not at its side (90°)")
	_check(not cone.sees_direction(Vector2.ZERO, Vector2.DOWN, Vector2(0, -100), 150.0, true), "the cone: not behind")
	_check(cone.sees_direction(Vector2.ZERO, Vector2.DOWN, Vector2(0, -100), 150.0, false), "stealth off: behind too (in range, seen)")
	var pacing: PacingDefinition = catalog.pacing()
	_check(pacing.stealth and not PacingDefinition.new(1000).stealth, "the game's night watch is a stealth; left out, ES2's presence")


func _test_night(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter9")
	StoryFixtures.chapter8_done(session, false)
	session.record_journal()
	# The 地下密室: the stone under the bed.
	var cellar: WorldMapController = MapPlaces.enter(session, &"city.midao1", &"city.midao1.stairs_arrival") # TEST-ONLY: down the 祭坛's stair
	await _settle(tree)
	_check(session.wait_until_phase([&"night"]) and session.day_phase_id() == &"night", "night falls (%s)" % session.day_phase_id())
	var before: int = ui.log_lines().size()
	_check(not await MapPlaces.take_passage(tree, cellar, &"city.midao1.down", 200) and ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("什么也没有")), "the stone is nothing to one who has not looked")
	var bed: WorldLandmarkDefinition = GameContent.catalog().landmark(&"city.midao1.landmark.bed")
	_check(bed != null and bed.teaches == ["看过床底的石板"], "the bed: looking at it finds the stone")
	state.marks["看过床底的石板"] = 1 # TEST-ONLY: as the 床's look teaches (landmark_test covers teaches)
	_check(await MapPlaces.take_passage(tree, cellar, &"city.midao1.down") and session.active_map().map_id() == &"imperial.well_tunnel", "down under the stone into the tunnel")
	await _settle(tree)
	var tunnel: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_to_zone(tree, tunnel, &"imperial.well_bottom"), "south along the tunnel to the well's bottom")
	_check(await MapPlaces.take_passage(tree, tunnel, &"imperial.well_bottom.up") and session.active_map().map_id() == &"imperial.cold_palace" and state.marks.get("从冷宫井上来", 0) == 1, "up the iron rungs into the 冷宫 (从冷宫井上来)")
	await _settle(tree)
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"sneak") and StoryQuestLog.current_step(state, quest).step_id == &"audience", "the way taken by the well, the 养心殿 next")
	var cold: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_to_zone(tree, cold, &"imperial.cold_room"), "into 钟嬷嬷's room")
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("钟嬷嬷见过你", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("你不是他们的人")), "钟嬷嬷: 你不是他们的人")
	var zhong: NpcRuntimeState = _first(session, &"imperial.cold_room", &"native.npc.zhong_momo")
	_check(zhong != null and cold.select_npc(zhong.character_id) and cold.ask_selected("养心殿").any(func(line: String) -> bool: return line.contains("窗闩")) and state.marks.get("钟嬷嬷说了窗闩", 0) == 1, "钟嬷嬷: the 西暖阁's window latch")
	# The 御花园 by night.
	var garden: WorldMapController = MapPlaces.enter(session, &"imperial.garden", &"imperial.garden.lanes_arrival") # TEST-ONLY: into the garden
	await _settle(tree)
	var guard: NpcRuntimeState = _first(session, &"imperial.garden", GARDEN_GUARD)
	_check(guard != null, "the garden's night guard is on his round")
	if guard == null:
		return
	var body: WorldCharacterBody2D = garden.npcs.runtime_body_for_character(guard.character_id)
	var watch: NpcWatch = guard.definition().dealings().watch
	var player: WorldCharacterBody2D = garden.runtime_player_body()
	garden.npc_life.npc_walker().cancel(guard.character_id) # TEST-ONLY: he stands still for the looking
	body.facing = Vector2.DOWN
	var rock: Rect2 = _cover_of(garden)
	_check(rock.size != Vector2.ZERO, "the garden has rocks to hide behind")
	var at: Vector2 = body.global_position
	player.global_position = at + Vector2(0, 90) # TEST-ONLY: in front of him
	await _settle(tree)
	_check(garden.watches.sees(guard, body, watch), "in front of him, in reach: seen")
	player.global_position = at + Vector2(0, -90) # TEST-ONLY: behind him
	await _settle(tree)
	_check(not garden.watches.sees(guard, body, watch), "behind him: not seen")
	_check(garden.watches.lit(at + Vector2(0, 30), null), "his own lantern lights the ground before him")
	var behind: Vector2 = rock.get_center() + Vector2(0, rock.size.y / 2.0 + 24.0)
	var front: Vector2 = rock.get_center() - Vector2(0, rock.size.y / 2.0 + 24.0)
	_check(not garden.watches.clear_line(front, behind), "a rock between them stops the eye")
	_check(garden.watches.clear_line(front, front + Vector2(0, -40)), "open ground does not")
	# Caught.
	_check(not session.player_held_item_ids().get(TOKEN, false), "no 腰牌 at the belt")
	player.global_position = at + Vector2(0, 80) # TEST-ONLY
	await _settle(tree)
	garden.watches.tick(0.5)
	_check(body.alert_mark_shown() and session.active_map() == garden and state.marks.get("被禁军拿过", 0) == 0, "a ？ while he looks, not yet caught")
	garden.watches.tick(1.0)
	await _settle(tree)
	_check(state.marks.get("被禁军拿过", 0) == 1 and session.day_phase_id() == &"dawn" and session.active_map().map_id() == &"city.main" and session.player_runtime().world_location().zone_id == &"city.wumen", "caught: the mark, dawn, out at the 午门 (%s, %s)" % [session.day_phase_id(), session.player_runtime().world_location().zone_id])
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("什么人")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("别让我看见第二回")), "什么人！ and 冯策's word")
	# Again, the next night.
	_check(session.wait_until_phase([&"night"]), "the next night")
	garden = MapPlaces.enter(session, &"imperial.garden", &"imperial.garden.lanes_arrival") # TEST-ONLY
	await _settle(tree)
	guard = _first(session, &"imperial.garden", GARDEN_GUARD)
	_check(guard != null, "on his round again")
	if guard == null:
		return
	body = garden.npcs.runtime_body_for_character(guard.character_id)
	garden.npc_life.npc_walker().cancel(guard.character_id)
	body.facing = Vector2.DOWN
	player = garden.runtime_player_body()
	player.global_position = body.global_position + Vector2(0, 80) # TEST-ONLY
	await _settle(tree)
	garden.watches.tick(2.0)
	await _settle(tree)
	_check(state.marks.get("被禁军拿过两回", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("下回我就不认得你了")), "caught again: the second time's word")
	# The 腰牌 spares one; with stealth off it sees on every side.
	_check(session.wait_until_phase([&"night"]), "a third night")
	garden = MapPlaces.enter(session, &"imperial.garden", &"imperial.garden.lanes_arrival") # TEST-ONLY
	await _settle(tree)
	_check(not garden.give_new_item_to_player(TOKEN).is_empty(), "the 腰牌 (TEST-ONLY: given, as the 殿试 gives it)")
	guard = _first(session, &"imperial.garden", GARDEN_GUARD)
	if guard == null:
		_check(false, "on his round a third time")
		return
	body = garden.npcs.runtime_body_for_character(guard.character_id)
	garden.npc_life.npc_walker().cancel(guard.character_id)
	body.facing = Vector2.DOWN
	player = garden.runtime_player_body()
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	pacing.with_stealth(false) # TEST-ONLY: the knob off
	player.global_position = body.global_position + Vector2(0, -90) # TEST-ONLY: behind him
	await _settle(tree)
	_check(garden.watches.sees(guard, body, guard.definition().dealings().watch), "stealth off: behind him, in range, seen (the 腰牌 aside: sees() is the eye alone)")
	pacing.with_stealth(true)
	await _settle(tree)
	var before_marks: int = state.marks.size()
	player.global_position = body.global_position + Vector2(0, 80) # TEST-ONLY: in front, the 腰牌 at the belt
	await _settle(tree)
	garden.watches.tick(2.0)
	await _settle(tree)
	_check(session.active_map() == garden and not body.alert_mark_shown() and state.marks.size() == before_marks, "the 腰牌: he does not look twice")


func _cover_of(map: WorldMapController) -> Rect2:
	var furnishings: Node = map.get_node_or_null("Furnishings")
	if furnishings == null:
		return Rect2()
	for piece: Node in furnishings.get_children():
		var look: Dictionary = piece.get_meta("look", {})
		if look.get("kind", "") == "rockery" and look.get("cover", false):
			var size: Vector2 = piece.get_meta("footprint", Vector2.ZERO)
			return Rect2((piece as Node2D).global_position - size / 2.0, size)
	return Rect2()


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in session.world_map_of(MapPlaces.map_of(zone_id)).resident_npcs():
		if npc.exists_in_map and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("番坊", CharacterState.GENDER_MALE)
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
