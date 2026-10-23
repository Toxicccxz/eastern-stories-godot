extends RefCounted

## 鬼门关 A (d/death): a dead player is a ghost (damage.c die()) and, once past the death card,
## stands at 鬼门关 before the white gargoyle (DEATH_ROOM). His five lines come five seconds
## apart while the player stays (present(ob)), the last with reincarnate() and the move to the
## Snow temple; walking off cuts them, coming back starts them again (one round at a time, D6),
## and he does not wander off while they run (owner Q2 (a)). North the black gargoyle does the
## same; the 酆都城 gate lets nobody back south; the long road turns on itself until the fifth
## try (road2.c); the little shop's double answers 回家 (inn1.c). A ghost sees ghosts (the
## 阴鬼牙将), cannot eat, is ranked 鬼魂; it may Save, and Continue puts it at 鬼门关 (logind.c,
## D7); killed again it leaves no corpse and pays the penalty again (D5).
## Walks use the move actions (MapPlaces). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const WHITE: StringName = &"death.npc.wgargoyle"
const BLACK: StringName = &"death.npc.bgargoyle"
const GUARD: StringName = &"death.npc.hell_guard"
const DUMPLING: StringName = &"es2:obj/example/dumpling"
const WHITE_LINES: Array[String] = [
	"白无常说道：喂！新来的，你叫什么名字？",
	"白无常用奇异的眼光盯著你，好像要看穿你的一切似的。",
	"白无常「哼」的一声，从袖中掏出一本像帐册的东西翻看著。",
	"白无常阁上册子，说道：咦？阳寿未尽？怎么可能？",
	"白无常搔了搔头，叹道：罢了罢了，你走吧。",
	"一股阴冷的浓雾突然出现，很快地包围了你。",
]
const PEOPLE: Dictionary = {
	&"death.bridge": {GUARD: 4},
	&"death.gate": {WHITE: 1},
	&"death.gateway": {BLACK: 1},
}

var _count: int = 0
var _failures: Array[String] = []


## Every random draw comes up 0: chat_chance always fires and random_move takes the first way.
class Wander extends WorldInteractionRandomSource:
	func next_below(_bound: int) -> int:
		return 0


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = await _new_session(tree)
	await _test_dying(tree, session)
	await _test_white_gargoyle(tree, session)
	await _test_the_way_north(tree, session)
	await _test_long_road(tree, session)
	await _test_little_shop(tree, session)
	session = await _test_continue_as_ghost(tree, session)
	await _test_dying_again(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	# Since the remap the two little shops are each their own map, entered from the 鬼门大道.
	var houses: Dictionary = {"inn1": &"death.inn1_house", "inn2": &"death.inn2_house"}
	for room: String in ["bridge1", "bridge", "gate", "gateway", "road1", "inn1", "inn2", "road2", "road3"]:
		var zone: ZoneDefinition = catalog.zone(StringName("death." + room))
		var map_id: StringName = houses.get(room, DeathWorldDefinitions.MAP_ID)
		_check(zone != null and zone.map_id == map_id and zone.room_ids() == [StringName("es2:d/death/" + room)], "%s: a room of %s" % [room, "its own house's map" if houses.has(room) else "阴间's map"])
	for way: Array in [[&"death.road1.west", &"death.inn1"], [&"death.road1.east", &"death.inn2"], [&"death.inn1.east", &"death.road1"], [&"death.inn2.west", &"death.road1"]]:
		var portal: PortalDefinition = catalog.portal(way[0])
		_check(portal != null and portal.destination_zone_id == way[1] and portal.destination_map_id == catalog.zone(way[1]).map_id, "%s: to %s, onto its map" % way)
	_check(catalog.room(&"es2:d/death/gate").short == "鬼门关", "the gate's name without its terminal colour codes")
	_check(catalog.room(&"es2:d/death/road3").long == "浓雾在这里聚成一堵墙，路到这里就断了。\n", "the road's end: the native line (owner Q3 b)")
	var guard: NpcDefinition = catalog.npc(GUARD)
	_check(guard.is_ghost() and guard.dealings().vendetta_mark == "hell" and guard.hooks().attack_choice == "确定攻击", "阴鬼牙将: ghosts, vendetta_mark hell, attacking one asked first")
	var white: NpcHooks = catalog.npc(WHITE).hooks()
	var afters: Array[float] = []
	for call: NpcHooks.Call in white.calls:
		afters.append(call.after)
	_check(afters == [5.0, 10.0, 15.0, 20.0, 25.0] and white.calls_hold and white.calls[4].act.reincarnates(), "白无常: a line every 5 s, reincarnate() with the last, holding still (Q2)")
	var black: NpcHooks = catalog.npc(BLACK).hooks()
	_check(black.calls.size() == 6 and black.calls_hold and black.calls[0].act.ghost_state == 0 and black.calls[1].act.ghost_state == 1, "黑无常: the same for a ghost, a fight for the living")
	var road: ZoneExitRuleDefinition = catalog.exit_rules_between(&"death.road2", &"death.road3")[0]
	_check(road.counts_tries and road.value == 5 and road.temp == "long_road" and road.point_id == &"death.road2.long_road", "the long road: the fifth try goes through")
	_check(catalog.exit_rules_between(&"death.gateway", &"death.gate")[0].condition == ZoneExitRuleDefinition.Condition.ALWAYS, "no way back south from 酆都城门")


## damage.c die(): a ghost with 1/1 gin, kee and sen; the death card until 继续, then 鬼门关.
func _test_dying(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	await _die(tree, session, false)
	var flow: PlayerLifeFlow = session.player_life_flow()
	_check(flow.phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE and player.life_status == CharacterRuntimeLifeStatus.Value.DEAD and player.state.ghost, "dead, a ghost, the death card shown")
	for _second: int in range(60):
		session._process(1.0)
	_check(flow.phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE and session.active_map_id() == SnowWorldDefinitions.INN_MAP_ID, "the card waits for 继续")
	_check(not OldPineSaveEligibility.inspect(session).allowed(), "no saving on the card")
	session.continue_after_death()
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(not flow.is_active() and session.active_map_id() == DeathWorldDefinitions.MAP_ID and player.world_location().zone_id == DeathWorldDefinitions.GATE_ZONE_ID, "继续: at 鬼门关")
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and player.exists_in_world and player.state.ghost, "standing there, a ghost")
	_check([player.state.vitality.current, player.state.vitality.effective] == [1, 1], "with 1/1 kee")
	_check(OldPineSaveEligibility.inspect(session).allowed(), "a ghost may Save (D7)")
	_check(_people(map) == PEOPLE, "who the rooms put where: %s" % [_people(map)])
	var guard: NpcRuntimeState = _first(map, GUARD)
	var body: WorldCharacterBody2D = map.npcs.runtime_body_for_character(guard.character_id)
	_check(body.visible and map.select_npc(guard.character_id), "a ghost sees the 阴鬼牙将 (char.c visible())")
	_check(guard.definition().display_name.ends_with("阴鬼牙将") and guard.definition().display_name.length() == 5, "named by an earthly branch: %s" % guard.definition().display_name)
	_check(RankWords.query_rank(player.state.gender, player.state.affiliation.class_id, 0, player.state.ghost) == "【 鬼  魂 】", "ranked 鬼魂")
	var made: StringName = map.give_new_item_to_player(DUMPLING) # TEST-ONLY: something to eat
	var context := MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor), session.inventory_state(), session.stack_collection(), session.item_instance_index())
	var eaten: FoodUseResult = HeldFoodUseService.eat(player, context, session.food_collection(), GameContent.catalog().native_item_projections(), made, true)
	_check(eaten.outcome == FoodUseResult.Outcome.GHOST, "a ghost cannot eat (food.c)")


## wgargoyle.c death_stage(): five lines five seconds apart while the player stays; walking off
## cuts them, coming back starts them anew; then the Snow temple, alive.
func _test_white_gargoyle(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var map: WorldMapController = session.active_map() as WorldMapController
	_tick(session, 4)
	_check(not hud.log_lines().has(WHITE_LINES[0]), "nothing for four seconds")
	_tick(session, 1)
	_check(hud.log_lines()[-1] == WHITE_LINES[0], "the first line at five: %s" % [hud.log_lines().slice(-2)])
	_check(await MapPlaces.drive_to_zone(tree, map, &"death.bridge"), "walked off onto the bridge")
	map.npc_life._advance_ambience(0.0)
	_tick(session, 20)
	_check(not hud.log_lines().has(WHITE_LINES[1]) and player.state.ghost, "away from him, no more lines")
	# Q2 (a): while his lines are to come he stays; the draws would walk him off every beat.
	session.configure_npc_ambience_random_source(Wander.new()) # TEST-ONLY
	_check(await MapPlaces.drive_to_zone(tree, map, DeathWorldDefinitions.GATE_ZONE_ID), "back at 鬼门关")
	map.npc_life._advance_ambience(0.0)
	var white: NpcRuntimeState = _first(map, WHITE)
	_tick(session, 24)
	_check(white.world_location().zone_id == DeathWorldDefinitions.GATE_ZONE_ID, "he stays while he talks")
	_check(_said(hud, WHITE_LINES.slice(0, 4)) and not hud.log_lines().has(WHITE_LINES[4]), "started anew: four lines by 24 s")
	_tick(session, 1)
	_check(_said(hud, WHITE_LINES), "the last line and the fog: %s" % [hud.log_lines().slice(-3)])
	await tree.physics_frame
	_check(session.active_map_id() == SnowWorldDefinitions.temple_map_id() and player.world_location().zone_id == SnowWorldDefinitions.TEMPLE_ZONE_ID, "back at the Snow temple (its own map since the remap)")
	_check(not player.state.ghost and player.state.vitality.effective == player.state.vitality.maximum, "reincarnate(): alive, full effective kee")
	_check(session.reincarnations() == 1 and OldPineSaveEligibility.inspect(session).allowed(), "Save again")
	var away: WorldMapController = session.world_map_of(DeathWorldDefinitions.MAP_ID)
	away.npc_life.npc_ambience().cancel_call(white.character_id)
	_check(away.npc_life.random_move(white), "with no lines to come he wanders as before")
	var guard: NpcRuntimeState = _first(away, GUARD)
	_check(not away.npcs.runtime_body_for_character(guard.character_id).visible and not away.player_sees(guard), "alive, the 阴鬼牙将 are unseen again")
	_check(session.essence_magic().drift_target(guard.definition().display_name) == null and session.essence_magic().drift_target("白无常") != null, "游识: the living find no ghost (me->visible(ob)), the gargoyle they do")
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY


## North past the gate: the black gargoyle's lines, no way back south, the road on.
func _test_the_way_north(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	await _die(tree, session, true)
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(player.world_location().zone_id == DeathWorldDefinitions.GATE_ZONE_ID, "dead again: at 鬼门关")
	var white: NpcRuntimeState = _first(map, WHITE)
	if white.world_location().zone_id != &"death.gate":
		map.npcs.bring_beside_player(white) # TEST-ONLY: he wandered next door above
	_check(await MapPlaces.drive_to_zone(tree, map, &"death.gateway"), "north to 酆都城门")
	map.npc_life._advance_ambience(0.0)
	_tick(session, 5)
	_check(hud.log_lines()[-1] == "黑无常说道：喂！新来的，你叫什么名字？", "黑无常 asks too")
	var gateway: Vector2 = MapPlaces.zone_centre(map, &"death.gateway")
	map.runtime_player_body().global_position = Vector2(gateway.x - 32.0, MapPlaces.zone_rect(map, &"death.gateway").end.y - 40.0) # TEST-ONLY: at the square's south edge
	await tree.physics_frame
	await MapPlaces.push(tree, &"move_down", 30)
	_check(player.world_location().zone_id == &"death.gateway" and _said(hud, ["一个空洞的声音在你耳边响起....", "没有回头路了!"]), "no way back south: %s" % [hud.log_lines().slice(-2)])
	_check(await MapPlaces.drive_through(tree, map, [&"death.road1", &"death.road2"]), "through the city gate up the 鬼门大道")
	_tick(session, 30)
	_check(player.state.ghost and session.active_map_id() == DeathWorldDefinitions.MAP_ID, "away from 黑无常, nothing happens")


## road2.c valid_leave(): four tries north put the player back at the road's start, the fifth
## goes on; leaving the road starts the count anew.
func _test_long_road(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var map: WorldMapController = session.active_map() as WorldMapController
	for attempt: int in range(1, 5):
		await _try_north(tree, map)
		_check(player.world_location().zone_id == &"death.road2" and player.temp_marks.get("long_road") == attempt, "try %d: still on the road (%s)" % [attempt, player.world_location().zone_id])
		_check(map.runtime_player_body().global_position.y > MapPlaces.zone_centre(map, &"death.road2").y and hud.log_lines()[-1] == "你走著走著..... 发现四周景色居然都没有变....", "try %d: back where it began" % attempt)
	await _try_north(tree, map)
	_check(player.world_location().zone_id == &"death.road3" and not player.temp_marks.has("long_road"), "the fifth try: the end of the road")
	_check(await MapPlaces.drive_to_zone(tree, map, &"death.road2"), "back south onto the road")
	await _try_north(tree, map)
	_check(player.world_location().zone_id == &"death.road2" and player.temp_marks.get("long_road") == 1, "the count begins anew")
	_check(await MapPlaces.drive_to_zone(tree, map, &"death.road1"), "down to the 鬼门大道")
	_check(not player.temp_marks.has("long_road"), "leaving south forgets it (delete_temp())")


## inn2.c's wall; inn1.c: ask the double about 回家 and wake at the Snow temple.
func _test_little_shop(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(GameContent.catalog().landmark(&"death.inn2.landmark.wall").description.contains("看到你自己时问一下吧"), "the 黑店's wall: ask yourself")
	# West off the 鬼门大道 through its doorway onto the shop's own map (the remap).
	var map: WorldMapController = await MapPlaces.go_to(tree, session, &"death.inn1")
	_check(map != null and map.map_id() == &"death.inn1_house" and player.world_location().zone_id == &"death.inn1", "into the little shop (its own map)")
	if map == null:
		return
	var ask: ActService = map.service(&"death.inn1.ask_home") as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"death.inn1.ask_home")) and ask.in_reach() and ask.verb() == "打听「回家」", "人影 · 打听「回家」")
	ask.interact()
	_check(session.reincarnation_pending() and not OldPineSaveEligibility.inspect(session).allowed(), "the move comes with the session's next frame; Save waits for it")
	_check(_said(hud, ["你走上前去, 低声的向那个长得跟你一样的人询问回家的事.", "那人一句话也不说就往你这边撞过来, 你眼前一阵黑...."]), "do_stuff()'s lines: %s" % [hud.log_lines().slice(-2)])
	_tick(session, 1)
	await tree.physics_frame
	_check(session.active_map_id() == SnowWorldDefinitions.temple_map_id() and player.world_location().zone_id == SnowWorldDefinitions.TEMPLE_ZONE_ID and not player.state.ghost, "back at the Snow temple, alive")


## logind.c: a ghost logs in at DEATH_ROOM (D7): Continue puts it at 鬼门关 and the white
## gargoyle starts again.
func _test_continue_as_ghost(tree: SceneTree, session: WorldSessionController) -> WorldSessionController:
	await _die(tree, session, true)
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_through(tree, map, [&"death.gateway", &"death.road1", &"death.road2"]), "up the long road")
	await _try_north(tree, map)
	_check(session.player_runtime().temp_marks.get("long_road") == 1, "one try counted")
	var restored: WorldSessionController = await _continue(tree, session)
	var player: WorldPlayerRuntimeState = restored.player_runtime()
	_check(not player.temp_marks.has("long_road"), "Continue at the gate leaves the road's count behind")
	var again: WorldMapController = restored.active_map() as WorldMapController
	_check(player.state.ghost and restored.active_map_id() == DeathWorldDefinitions.MAP_ID and player.world_location().zone_id == DeathWorldDefinitions.GATE_ZONE_ID, "Continue: the ghost at 鬼门关")
	if again.npc_life.npc_ambience() != null and _first(again, WHITE).world_location().zone_id != DeathWorldDefinitions.GATE_ZONE_ID:
		again.npcs.bring_beside_player(_first(again, WHITE)) # TEST-ONLY
	again.npc_life._advance_ambience(0.0)
	_tick(restored, 26)
	await tree.physics_frame
	_check(restored.active_map_id() == SnowWorldDefinitions.temple_map_id() and not player.state.ghost, "his lines again, then the temple")
	# A ghost saved away from 阴间 (遁 takes a ghost along, dun.c): Continue puts it at the gate.
	player.state.ghost = true # TEST-ONLY
	var away: WorldSessionController = await _continue(tree, restored)
	_check(away.reincarnation_pending() and not OldPineSaveEligibility.inspect(away).allowed(), "Continued at the temple, a ghost: the way to 阴间 is due")
	_tick(away, 1)
	await tree.physics_frame
	var ghost: WorldPlayerRuntimeState = away.player_runtime()
	_check(away.active_map_id() == DeathWorldDefinitions.MAP_ID and ghost.world_location().zone_id == DeathWorldDefinitions.GATE_ZONE_ID and not away.reincarnation_pending(), "logind.c: the ghost at 鬼门关")
	# Lying unconscious when a gargoyle's last line comes: the move waits until they come to.
	ghost.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY
	away.request_reincarnation()
	away._advance_reincarnation()
	_check(away.reincarnation_pending() and away.active_map_id() == DeathWorldDefinitions.MAP_ID, "unconscious: the move waits")
	ghost.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE) # TEST-ONLY: comes to
	away._advance_reincarnation()
	await tree.physics_frame
	_check(away.active_map_id() == SnowWorldDefinitions.temple_map_id() and not ghost.state.ghost, "awake: to the temple")
	await _test_the_living(tree, away)
	return away


## The living in 阴间 (游识 to a gargoyle met as a ghost): the white gargoyle sends them to the
## temple all the same (reincarnate() asks nothing of ghost), the black one attacks them.
func _test_the_living(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(not player.state.ghost and session.handoff_to(DeathWorldDefinitions.MAP_ID, &"death.gateway", &"death.gateway", &"death.gateway.bgargoyle.1").succeeded(), "TEST-ONLY: alive in 阴间 (as by 游识)")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var black: NpcRuntimeState = _first(map, BLACK)
	_check(map.place_player(black.world_location().zone_id, MapPlaces.spot(map, black.world_location().zone_id, MapPlaces.zone_centre(map, black.world_location().zone_id))), "TEST-ONLY: alive, beside 黑无常")
	await tree.physics_frame
	map.npc_life._advance_ambience(0.0)
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY: survives him
	_tick(session, 5)
	_check(hud.log_lines().has("黑无常说道：喂！阳人来阴间做什么？") and session.combat_encounter_coordinator().has_active_encounter(), "黑无常: 喂！阳人来阴间做什么？ and a fight")
	# 逃跑 until the fight is over (the panel's first action).
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for _round: int in range(600):
		if not coordinator.has_active_encounter():
			break
		var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
		coordinator.submit_player_action(CombatTacticalRequest.new(info.action_id, coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
	_check(not coordinator.has_active_encounter(), "fled from him")
	_tick(session, 25)
	_check(not hud.log_lines().has("黑无常说道：喂！新来的，你叫什么名字？") and not player.state.ghost, "no ghost's lines for the living")


## A ghost killed (by a 阴鬼牙将): no corpse (chard.c), the penalty again with a killer, the
## card, and 鬼门关 once more.
func _test_dying_again(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	await _die(tree, session, true)
	var map: WorldMapController = session.active_map() as WorldMapController
	player.state.progression.combat_experience = 1000 # TEST-ONLY
	var guard: NpcRuntimeState = _first(map, GUARD)
	_check(map.place_player(&"death.bridge", MapPlaces.spot(map, &"death.bridge", MapPlaces.zone_centre(map, &"death.bridge"))), "TEST-ONLY: on the bridge")
	await tree.physics_frame
	map.npc_life._advance_ambience(0.0)
	map.select_npc(guard.character_id)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var corpses: int = map.corpse_states().size()
	var started: CombatSliceInitiationResult = map.attack_selected()
	_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the ghost attacks a 阴鬼牙将: %s %s life %s fighting %s zone %s ghost %s map %s" % [started.outcome, guard.world_location().zone_id, player.life_status, coordinator.has_active_encounter(), player.world_location().zone_id, player.state.ghost, session.active_map_id()])
	for _round: int in range(600):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	var flow: PlayerLifeFlow = session.player_life_flow()
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.DEAD and flow.phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE, "killed")
	_check(map.corpse_states().size() == corpses and flow.corpse_place.is_empty(), "a ghost leaves no corpse, and the card names none")
	_check(flow.death_result.penalized and flow.death_result.combat_experience_lost == 100, "killer_reward() again: exp / 10")
	session.continue_after_death()
	await tree.physics_frame
	_check(player.world_location().zone_id == DeathWorldDefinitions.GATE_ZONE_ID and player.state.ghost and player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "鬼门关 once more")


## Dies where the player stands, without a killer (a mortal wound), and goes on from the card
## when `go_on`.
func _die(tree: SceneTree, session: WorldSessionController, go_on: bool) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	session.player_runtime().state.vitality.effective = -1 # TEST-ONLY: a mortal wound
	map.player_fall_below_zero()
	await tree.physics_frame
	if go_on:
		session.continue_after_death()
		await tree.physics_frame
		(session.active_map() as WorldMapController).npc_life._advance_ambience(0.0)


## Walks north from just below the road's end until the way refuses or lets the player on.
func _try_north(tree: SceneTree, map: WorldMapController) -> void:
	var road: Rect2 = MapPlaces.zone_rect(map, &"death.road2")
	_check(await MapPlaces.drive(tree, map, Vector2(road.get_center().x, road.position.y + 40.0)), "TEST-ONLY: walked up the road")
	await MapPlaces.push(tree, &"move_up", 30)


## `seconds` of the session's time, one at a time.
func _tick(session: WorldSessionController, seconds: int) -> void:
	for _second: int in range(seconds):
		session._process(1.0)


func _new_session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = Work.create_session(tree)
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
	await tree.physics_frame
	return restored


func _first(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _people(map: WorldMapController) -> Dictionary:
	var found: Dictionary = {}
	for npc: NpcRuntimeState in map.resident_npcs():
		var zone: StringName = npc.world_location().zone_id
		if not found.has(zone):
			found[zone] = {}
		var id: StringName = NpcDefinition.unnamed_id(npc.definition().definition_id)
		found[zone][id] = found[zone].get(id, 0) + 1
	return found


## These lines, one after the other, among the last few of the log.
func _said(hud: SharedGameplayUI, lines: Array[String]) -> bool:
	var log: Array[String] = hud.log_lines()
	var at: int = log.rfind(lines[0])
	return at >= 0 and at >= log.size() - 10 and log.slice(at, at + lines.size()) == lines


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("death_realm: " + message)
