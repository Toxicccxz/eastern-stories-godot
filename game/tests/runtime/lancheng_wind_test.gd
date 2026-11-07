extends RefCounted

## 第十章 A 风 (owner's plan build/plans/第十章_计划.md, 2026-11-07「继续做」: Q1–Q3 默认; DECISIONS「第十章 A」「风」),
## from the eighth chapter's ledger with the ninth's marks written as A–E write them (TEST-ONLY):
## - WindDefinition: the wind blows from a point ahead along the route toward the player (walking into it
##   leads to the calm), still within calm_radius of the last point; how far one stands off the route; a
##   way walked into the wind; the quarter it comes from; the catalog's wind on lancheng.wilds.
## - The mirror's upper way: closed (迷香) until the ninth chapter is done, then up into the 幻影道; coming in
##   draws one route and marks it (the others' marks cleared); the 风 row on the HUD.
## - Each gust: where it comes from (only when that changes), still in the calm (风停了), the bell clear
##   walking into it and dull walking away, the gale on one far off the route (内力 holds it off, else 气;
##   nothing with native_hazards off: 经典).
## - The 石匣 opens to the wind there (the bell inside), not elsewhere, once.
## - 伏地 in the hollow the wind blows out of: asked first, 到了岚城 and the tenth's 风 step done; in another
##   hollow: 风还没停.
## - The 卜风坛's diviners stand there once the ninth is done and let one in a 黑冠 be; 萧辟尘 speaks of
##   岚城 and of the bell, 於兰天武 of 旋芒.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const BELL: StringName = &"native:lancheng/wind_bell"
const BOX: StringName = &"native:oldpine/stone_box"
const CROWN: StringName = &"native:niling/black_crown"
const ROUTE_MARKS: Array[String] = ["风眼在西", "风眼在北", "风眼在东"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_rules()
	for kind: String in ["way", "gusts", "hollows", "people"]:
		var session: WorldSessionController = await _session(tree)
		match kind:
			"way": await _test_way(tree, session)
			"gusts": await _test_gusts(tree, session)
			"hollows": await _test_hollows(tree, session)
			"people": await _test_people(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_rules() -> void:
	var wind := WindDefinition.new()
	wind.calm_radius = 100.0
	wind.upwind_degrees = 50
	var line := PackedVector2Array([Vector2(0, 0), Vector2(0, -1000)])
	var at_start: Vector2 = wind.blowing(line, Vector2(0, 0))
	_check(at_start.is_equal_approx(Vector2(0, 1)) and WindDefinition.quarter_of(at_start) == "北", "on the route it blows from the calm's way (from the north here): %s" % at_start)
	var aside: Vector2 = wind.blowing(line, Vector2(300, -400))
	_check(aside.x > 0.5 and aside.y > 0.0, "off to the east it blows from the route ahead, back toward it: %s" % aside)
	_check(is_equal_approx(wind.off_route(line, Vector2(300, -400)), 300.0), "300 px off the route")
	_check(wind.blowing(line, Vector2(0, -950)) == Vector2.ZERO and wind.calm_at(line, Vector2(30, -960)) and not wind.calm_at(line, Vector2(0, -800)), "still within calm_radius of the last point, not before")
	_check(wind.went_upwind(Vector2(0, 1), Vector2(0, -60)) and wind.went_upwind(Vector2(0, 1), Vector2(30, -60)), "walking north into a north wind (and a little aside) goes into it")
	_check(not wind.went_upwind(Vector2(0, 1), Vector2(60, 0)) and not wind.went_upwind(Vector2(0, 1), Vector2(0, 60)) and not wind.went_upwind(Vector2(0, 1), Vector2(0, -10)), "across it, with it, or hardly moved: not")
	_check(WindDefinition.quarter_of(Vector2(1, 0)) == "西" and WindDefinition.quarter_of(Vector2(-1, -1).normalized()) == "东南" and WindDefinition.quarter_of(Vector2.ZERO) == "", "the quarters: 西, 东南, none")
	_check(WindDefinition.veered(Vector2(0, 1), 90.0).is_equal_approx(Vector2(-1, 0)), "a gust veered by 90°")
	var catalog: ContentCatalog = GameContent.catalog()
	var blowing: WindDefinition = catalog.wind_for_map(&"lancheng.wilds")
	_check(blowing != null and blowing.routes.size() == 3 and blowing.enter_portal_ids == [&"canyon.fantasy1.up"] and blowing.bell_item_id == BELL and not blowing.gale.is_empty(), "the 寻风地带's wind: three routes, drawn by the upper way, the bell, the gale")
	_check(blowing != null and blowing.routes.map(func(route: WindDefinition.Route) -> String: return route.mark) == ROUTE_MARKS, "each route's mark names its hollow")
	_check(catalog.wind_for_map(&"canyon.bamboo") == null, "no wind in the mirror's chamber")
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.chapter10")
	_check(quest != null and quest.steps.size() == 1 and quest.steps[0].target != null and quest.steps[0].target.zone_id == &"lancheng.stone_field", "第十章 风: the 石林雾野 its target")


func _ninth_done(session: WorldSessionController) -> void:
	StoryFixtures.chapter8_done(session, false, true, false)
	var state: CharacterState = session.player_runtime().state
	for mark: String in ["中了武状元", "宫门放行", "候了殿试", "殿试过", "进了皇城", "见了福安", "见了皇帝", "翻过樟木匣", "对出了原令", "见过卫沧澜", "宋朴传了话", "私了了庾子建"]:
		state.marks[mark] = 1 # TEST-ONLY: as 第九章 A–D write them (the deal)
	session.record_journal()


func _test_way(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.chapter8_done(session, false, true, false)
	session.record_journal()
	var chamber: WorldMapController = MapPlaces.enter(session, &"canyon.fantasy1", &"canyon.fantasy1.mirror_arrival") # TEST-ONLY: in the mirror
	await _settle(tree)
	var before: int = ui.log_lines().size()
	_check(not await MapPlaces.take_passage(tree, chamber, &"canyon.fantasy1.up", 240) and ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("迷香")), "before the ninth is done the upper way turns one back (迷香)")
	_check(not ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("整修中")), "never ES2's 整修中")
	_ninth_done(session)
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter10")
	_check(StoryQuestLog.is_done(state, GameContent.catalog().story_quest(&"main.chapter9")) and StoryQuestLog.current_step(state, quest) != null and StoryQuestLog.current_step(state, quest).step_id == &"wind", "the ninth done: the tenth's 风 next")
	chamber = MapPlaces.enter(session, &"canyon.fantasy1", &"canyon.fantasy1.mirror_arrival") # TEST-ONLY
	await _settle(tree)
	_check(await MapPlaces.take_passage(tree, chamber, &"canyon.fantasy1.up") and session.active_map().map_id() == &"lancheng.wilds", "up the 幻影道 into the 寻风地带")
	await _settle(tree)
	var marked: Array[String] = ROUTE_MARKS.filter(func(mark: String) -> bool: return state.marks.get(mark, 0) != 0)
	_check(marked.size() == 1, "coming in drew one route: %s" % [marked])
	var wilds: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_to_zone(tree, wilds, &"lancheng.windgate"), "out onto the 风口")
	await _settle(tree)
	_check(wilds.winds.blowing() and ui.player_wind.visible and ui.player_wind.text.begins_with("风："), "the 风 row on the HUD: %s" % ui.player_wind.text)
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("边吹过来")), "the first gust tells where it comes from")
	# Down and up again: the town has drifted (the draw is the world's; marks stay one).
	_check(await MapPlaces.drive_to_zone(tree, wilds, &"lancheng.huanying") and await MapPlaces.take_passage(tree, wilds, &"lancheng.huanying.down") and session.active_map().map_id() == &"canyon.bamboo", "back down into the mirror")
	await _settle(tree)
	_check(not ui.player_wind.visible, "no 风 row in the mirror's chamber")
	chamber = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, chamber, &"canyon.fantasy1.up"), "up once more")
	await _settle(tree)
	_check(ROUTE_MARKS.filter(func(mark: String) -> bool: return state.marks.get(mark, 0) != 0).size() == 1, "still exactly one route marked")


func _test_gusts(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	_ninth_done(session)
	_only_route(state, "风眼在北")
	var wilds: WorldMapController = MapPlaces.enter(session, &"lancheng.stone_field", &"lancheng.wind.fork") # TEST-ONLY: where the trails part
	await _settle(tree)
	var player: WorldCharacterBody2D = wilds.runtime_player_body()
	var wind: WindDefinition = wilds.winds.wind()
	wind.veer_percent = 0 # TEST-ONLY: steady gusts (restored below)
	var missing: Array[StringName] = []
	for route: WindDefinition.Route in wind.routes:
		for point_id: StringName in route.points:
			if not _point(wilds, point_id).is_finite():
				missing.append(point_id)
	_check(missing.is_empty(), "every route point stands on the map: missing %s" % [missing])
	var north: Vector2 = _point(wilds, &"lancheng.wind.north_calm")
	var fork: Vector2 = _point(wilds, &"lancheng.wind.fork")
	wilds.winds.tick(0.1)
	wilds.winds.tick(wind.gust_ms / 1000.0)
	var blowing: Vector2 = wilds.winds.vector()
	_check(blowing != Vector2.ZERO and blowing.dot((fork - north).normalized()) > 0.5, "at the fork it blows from the north hollow's way: %s" % blowing)
	_check(ui.player_wind.text.contains("风") and not ui.player_wind.text.contains("停"), "the 风 row names it: %s" % ui.player_wind.text)
	var told: int = ui.log_lines().filter(func(line: String) -> bool: return line.contains("边吹过来")).size()
	wilds.winds.tick(wind.gust_ms / 1000.0)
	_check(ui.log_lines().filter(func(line: String) -> bool: return line.contains("边吹过来")).size() == told, "the same wind is not told twice")
	# The bell: into the wind clear, away from it dull.
	_check(not wilds.give_new_item_to_player(BELL).is_empty(), "the bell (TEST-ONLY: given, as the 石匣 gives it)")
	player.global_position = fork
	wilds.winds.tick(wind.gust_ms / 1000.0)
	player.global_position = fork.move_toward(_point(wilds, &"lancheng.wind.north1"), 80.0) # TEST-ONLY: a few steps into the wind
	wilds.winds.tick(wind.gust_ms / 1000.0)
	_check(ui.log_lines()[-1].contains("清亮") or ui.log_lines().slice(-3).any(func(line: String) -> bool: return line.contains("清亮")), "walking into it the bell rings clear")
	player.global_position = player.global_position + Vector2(0, 90) # TEST-ONLY: back down, with the wind
	wilds.winds.tick(wind.gust_ms / 1000.0)
	_check(ui.log_lines().slice(-3).any(func(line: String) -> bool: return line.contains("闷闷")), "walking away the bell rings dull")
	player.global_position = player.global_position + Vector2(0, 60) # TEST-ONLY: on down the same way
	wilds.winds.tick(wind.gust_ms / 1000.0)
	_check(ui.log_lines().slice(-2).any(func(line: String) -> bool: return line.contains("闷闷")), "walking on away, the bell answers again")
	# The calm.
	player.global_position = north # TEST-ONLY: in the north hollow
	await _settle(tree)
	wilds.winds.tick(wind.gust_ms / 1000.0)
	_check(wilds.winds.vector() == Vector2.ZERO and ui.log_lines().slice(-3).any(func(line: String) -> bool: return line.contains("风停了")) and ui.player_wind.text.contains("停了"), "in the hollow the wind blows out of: 风停了")
	_check(ui.log_lines().slice(-3).any(func(line: String) -> bool: return line.contains("响了一声")), "the bell rings once in the calm")
	# The gale, far off the route.
	player.global_position = _point(wilds, &"lancheng.wind.east2") # TEST-ONLY: on the east trail, the north route blowing
	await _settle(tree)
	_check(wind.off_route(wilds.winds.points(wind.route_marked(state.marks)), player.global_position) > wind.route_radius, "the east trail is far off the north route")
	state.recovery.inner_force = CharacterInternalResourceState.new(100, 100) # TEST-ONLY
	wilds.winds.tick(wind.gust_ms / 1000.0)
	_check(state.recovery.inner_force.current == 92 and ui.log_lines().slice(-3).any(func(line: String) -> bool: return line.contains("运起内力")), "the gale: 内力 holds it off (100 → 92)")
	state.recovery.inner_force = CharacterInternalResourceState.new(0, 100) # TEST-ONLY
	var kee: int = state.vitality.current
	wilds.winds.tick(wind.gust_ms / 1000.0)
	_check(state.vitality.current == kee - 8 and ui.log_lines().slice(-3).any(func(line: String) -> bool: return line.contains("风大不能行")), "without 内力 it throws one down (气 −8)")
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	pacing.with_native_hazards(false) # TEST-ONLY: 经典
	kee = state.vitality.current
	wilds.winds.tick(wind.gust_ms / 1000.0)
	_check(state.vitality.current == kee, "经典: no gale")
	pacing.with_native_hazards(true)
	wind.veer_percent = 15


func _test_hollows(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	_ninth_done(session)
	# The 石匣: shut outside, open to the wind here.
	var camp: WorldMapController = MapPlaces.enter(session, &"canyon.stone_forest3", &"canyon.stone_forest3.mirror_return") # TEST-ONLY: before the mirror
	await _settle(tree)
	var box_id: StringName = camp.give_new_item_to_player(BOX)
	_check(not box_id.is_empty() and camp.floor_items.act_with_item(box_id), "the 石匣 has its 对着风")
	await _settle(tree)
	_check(not session.player_held_item_ids().get(BELL, false) and ui.log_lines().slice(-2).any(func(line: String) -> bool: return line.contains("一动不动")), "outside the 寻风地带 it stays shut")
	_only_route(state, "风眼在东")
	var wilds: WorldMapController = MapPlaces.enter(session, &"lancheng.windgate", &"lancheng.wind.gate") # TEST-ONLY
	await _settle(tree)
	box_id = _carried(wilds, BOX)
	_check(not box_id.is_empty() and wilds.floor_items.act_with_item(box_id), "on the 风口: 对着风")
	await _settle(tree)
	_check(session.player_held_item_ids().get(BELL, false) and state.marks.get("石匣开了", 0) == 1, "the lid springs open: the bell")
	wilds.floor_items.act_with_item(box_id)
	await _settle(tree)
	_check(ui.log_lines().slice(-2).any(func(line: String) -> bool: return line.contains("里面空了")) and _count_of(wilds, BELL) == 1, "once: the box is empty after")
	# 伏地 where the wind does not stop.
	var wrong: ActService = wilds.service(&"lancheng.calm_west.lie_down") as ActService
	_check(wrong != null and await MapPlaces.drive(tree, wilds, MapPlaces.service_spot(wilds, &"lancheng.calm_west.lie_down")) and wrong.in_reach(), "in the west hollow")
	wrong.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().slice(-2).any(func(line: String) -> bool: return line.contains("不是风停的地方")) and state.marks.get("到了岚城", 0) == 0, "伏地 there: 风还没停")
	# And where it does.
	var right: ActService = wilds.service(&"lancheng.calm_east.lie_down") as ActService
	_check(right != null and await MapPlaces.drive(tree, wilds, MapPlaces.service_spot(wilds, &"lancheng.calm_east.lie_down")) and right.in_reach(), "across to the east hollow")
	right.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("伏下身子"), "伏地 asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(state.marks.get("到了岚城", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("白石的城")), "风停处即是城: 到了岚城")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, GameContent.catalog().story_quest(&"main.chapter10")) == null, "the tenth's 风 step done")


func _test_people(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.chapter8_done(session, false, true, false)
	session.record_journal()
	var wilds: WorldMapController = MapPlaces.enter(session, &"lancheng.diviner_altar", &"lancheng.diviner_altar.head.1") # TEST-ONLY
	await _settle(tree)
	_check(_first(session, &"lancheng.diviner_altar", &"native.npc.niling_wind_diviner_head") == null, "no diviners before the ninth is done")
	_ninth_done(session)
	var hall: WorldMapController = MapPlaces.enter(session, &"waterfog.guildhall", &"waterfog.guildhall.master.1") # TEST-ONLY: 萧辟尘's hall
	await _settle(tree)
	var xiao: NpcRuntimeState = _first(session, &"waterfog.guildhall", &"common.npc.fighter.master")
	_check(xiao != null and hall.select_npc(xiao.character_id) and _said(hall.ask_selected("岚城"), "往外吹"), "萧辟尘: the wind blows out of the town")
	_check(xiao != null and _said(hall.ask_selected("风铃"), "我的"), "萧辟尘: the bell he lost")
	_check(xiao != null and not hall.give_new_item_to_player(BELL).is_empty() and _said(hall.ask_selected("岚城"), "风认人"), "萧辟尘, the bell shown: 铃在，风认人")
	wilds = MapPlaces.enter(session, &"lancheng.diviner_altar", &"lancheng.diviner_altar.head.1") # TEST-ONLY
	await _settle(tree)
	var head: NpcRuntimeState = _first(session, &"lancheng.diviner_altar", &"native.npc.niling_wind_diviner_head")
	_check(head != null, "the diviners at the 卜风坛 once the ninth is done")
	_check(head != null and head.definition().loadout_entries().any(func(entry: NpcLoadoutEntry) -> bool: return entry != null and entry.item_definition_id == &"native:lancheng/diviner_slip"), "the head carries the 卜风签")
	_check(head != null and head.definition().dealings().ignores_when != null, "a 黑冠 is let be")
	_check(state.marks.get("卜风坛的道士倒了", 0) == 0, "nobody felled yet")


func _only_route(state: CharacterState, mark: String) -> void:
	for each: String in ROUTE_MARKS:
		state.marks.erase(each)
	state.marks[mark] = 1 # TEST-ONLY: as coming in by the upper way draws it


func _point(map: WorldMapController, point_id: StringName) -> Vector2:
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(point_id)
	return Vector2.INF if marker == null else marker.global_position


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _carried(map: WorldMapController, definition_id: StringName) -> StringName:
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, map.session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


func _count_of(map: WorldMapController, definition_id: StringName) -> int:
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, map.session.player_runtime().character_id)
	var count: int = 0
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			count += 1
	return count


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
