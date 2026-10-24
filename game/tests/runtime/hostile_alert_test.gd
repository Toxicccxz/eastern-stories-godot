extends RefCounted

## 进门一起上's alert beat (DECISIONS; pacing hostile_alert_ms 500, ES2 0): the gang's first to
## notice the player shouts (its own ES2 fight line, a hunter's catch_hunt_msg, else a native
## one; a beast only the red ！), the ！ over its head, every one's name red and turned to the
## player; the fight comes when the beat is over, with whoever attacks on sight there then.
## The player who leaves the place within it escapes; the menu holds it; at 0 it is ES2's.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const GATE: StringName = &"city.eastdoor1"
const STREET: StringName = &"city.street9"
const NEXT_GATE: StringName = &"city.eastdoor2"
const LINES: Array[String] = ["守城官兵喝道：还不快放下武器束手就缚？", "守城官兵喝道：大胆刁民！竟敢在天子脚下造反？"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_knob()
	TestAlert.use()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody wanders off
	session.player_runtime().state.vitality = CharacterResourceState.new(10000000, 10000000, 10000000) # TEST-ONLY: the fights are not the point
	session.player_runtime().state.vendetta["authority"] = 1 # TEST-ONLY: the guards' grudge (garrison.c)
	var map: WorldMapController = MapPlaces.enter(session, &"city.nroad2", &"city.nroad2.village_arrival") # TEST-ONLY: at the city
	if _check(map != null and map.map_id() == MapPlaces.map_of(GATE), "TEST-ONLY: on 京师's map"):
		map.set_process(false) # TEST-ONLY: world time by hand
		await _test_beat(tree, session, map)
		await _test_escape(tree, session, map)
		await _test_menu_holds(tree, session, map)
		await _test_latecomer(tree, session, map)
		await _test_hunter(tree, session, map)
		await _test_own_attack(tree, session, map)
		await _test_glare(tree, session, map)
		TestAlert.restore()
		await _test_classic(tree, session, map)
		map.set_process(true)
		TestAlert.use()
		await _test_beast(tree, session)
	TestAlert.restore()
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_knob() -> void:
	var errors: Array[String] = []
	var left_out: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000}, "pacing", errors))
	_check(errors.is_empty() and left_out.hostile_alert_seconds == 0.0, "left out: ES2's call_out(0), at once")
	var broken: Array[String] = []
	PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "hostile_alert_ms": -1}, "p", broken))
	_check(broken.size() == 1 and broken[0].contains("hostile_alert_ms"), "a negative beat is refused: %s" % [broken])
	_check(TestAlert.production_ms() == 500, "pacing.json: half a second")


## In reach of one 守城兵: he shouts his own line, the ！ over him, all three red and turned;
## nobody strikes for the half second, then the three fall on the player together.
func _test_beat(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var guards: Array[NpcRuntimeState] = _guards(map, GATE)
	var noticer: NpcRuntimeState = _westmost(map, guards)
	var said: int = session.shared_ui().log_lines().size()
	await _into_gate(tree, map, noticer)
	map._process(0.0)
	_check(not coordinator.has_active_encounter() and map.hostilities.alert_seconds_left() == 0.5, "noticed: the beat begins, nobody strikes yet")
	_check(_body(map, noticer).alert_mark_shown() and guards.filter(func(npc: NpcRuntimeState) -> bool: return _body(map, npc).alert_mark_shown()).size() == 1, "the ！ over the one who noticed, him alone")
	for npc: NpcRuntimeState in guards:
		var body: WorldCharacterBody2D = _body(map, npc)
		_check(_red(body), "%s's name in the alert red" % npc.character_id)
		_check(body.facing.dot((map.runtime_player_body().global_position - body.global_position).normalized()) > 0.6, "%s turned to the player" % npc.character_id)
	var lines: Array[String] = session.shared_ui().log_lines().slice(said)
	_check(lines.any(func(line: String) -> bool: return LINES.has(line)), "his own fight line (chat_msg_combat): %s" % [lines])
	for npc: NpcRuntimeState in _guards(map, NEXT_GATE):
		_check(not _red(_body(map, npc)) and not _body(map, npc).alert_mark_shown(), "the next gate's 守城兵 take no notice")
	map._process(0.49)
	_check(not coordinator.has_active_encounter(), "still nobody strikes at 0.49 s")
	map._process(0.02)
	var encounter: CombatEncounter = coordinator.active_encounter()
	_check(encounter != null and encounter.participants().size() == 4, "the beat over: all three at once")
	_check(guards.all(func(npc: NpcRuntimeState) -> bool: return not _body(map, npc).alert_mark_shown() and not _red(_body(map, npc))), "the marks come off, all three")
	await _leave(tree, session, map)


## Turned and gone within the beat: out on the street nothing comes; back in, a new beat.
func _test_escape(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var noticer: NpcRuntimeState = _westmost(map, _guards(map, GATE))
	await _into_gate(tree, map, noticer)
	map._process(0.0)
	map._process(0.3)
	await _place(tree, map, STREET, MapPlaces.zone_rect(map, GATE).position + Vector2(-80.0, 40.0))
	map._process(0.0)
	_check(map.hostilities.alert_seconds_left() == 0.0 and not _body(map, noticer).alert_mark_shown(), "out of the gate: the beat is gone, its marks too")
	map._process(1.0)
	_check(not coordinator.has_active_encounter(), "escaped: nobody comes")
	await _into_gate(tree, map, noticer)
	map._process(0.0)
	_check(map.hostilities.alert_seconds_left() == 0.5 and not coordinator.has_active_encounter(), "back in: a new beat")
	map._process(0.6)
	_check(coordinator.has_active_encounter(), "staying: they fall on the player")
	await _leave(tree, session, map)


## The menu holds world time, the beat with it.
func _test_menu_holds(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	await _into_gate(tree, map, _westmost(map, _guards(map, GATE)))
	map._process(0.0)
	session.hold_world_time(&"test") # TEST-ONLY: the menu open
	map._process(2.0)
	_check(not coordinator.has_active_encounter() and map.hostilities.alert_seconds_left() == 0.5, "the menu open: the beat waits")
	session.release_world_time(&"test")
	map._process(0.6)
	_check(coordinator.has_active_encounter(), "closed: the beat runs out")
	await _leave(tree, session, map)


## One of the next gate's 守城兵 comes into this one within the beat (TEST-ONLY): it comes too.
func _test_latecomer(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var comer: NpcRuntimeState = _guards(map, NEXT_GATE)[0]
	var home: WorldLocationState = comer.world_location()
	var home_at: Vector2 = _body(map, comer).global_position
	await _into_gate(tree, map, _westmost(map, _guards(map, GATE)))
	map._process(0.0)
	comer._world_location = map.location_for_zone(GATE) # TEST-ONLY: it walked in
	_body(map, comer).global_position = MapPlaces.zone_centre(map, GATE) + Vector2(60, 60)
	map._process(0.6)
	var encounter: CombatEncounter = coordinator.active_encounter()
	_check(encounter != null and encounter.participants().size() == 5 and encounter.participant_for(comer.character_id) != null, "the one who came in meanwhile falls on the player too")
	await _leave(tree, session, map)
	comer._world_location = home # TEST-ONLY: back at its gate
	_body(map, comer).global_position = home_at


## A 守城兵 who hunts the player (TEST-ONLY) shouts start_hatred()'s catch_hunt_msg in the beat;
## the fight's opening does not say it again.
func _test_hunter(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var guards: Array[NpcRuntimeState] = _guards(map, GATE)
	var hunter: NpcRuntimeState = _westmost(map, guards)
	hunter.set_flag(NpcDefinition.FLAG_HUNTS_PLAYER, true) # TEST-ONLY
	var hunts: Array[String] = []
	for template: String in WorldMapHostilities.CATCH_HUNT:
		hunts.append(template.replace("$N", "京师守城兵").replace("$n", "你"))
	var said: int = session.shared_ui().log_lines().size()
	await _into_gate(tree, map, hunter)
	map._process(0.0)
	map._process(0.6)
	var lines: Array[String] = session.shared_ui().log_lines().slice(said)
	_check(coordinator.has_active_encounter() and lines.filter(func(line: String) -> bool: return hunts.has(line)).size() == 1, "catch_hunt_msg once, in the beat: %s" % [lines])
	_check(hunter.relationship.has_lethal_target(session.player_runtime().character_id) and not session.player_runtime().relationship.has_lethal_target(hunter.character_id), "then start_hatred()'s kill: the player fights back")
	await _leave(tree, session, map)
	hunter.set_flag(NpcDefinition.FLAG_HUNTS_PLAYER, false)


## The player strikes first within the beat (kill.c): the fight is on at once, the gang in
## it, the marks off.
func _test_own_attack(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var guards: Array[NpcRuntimeState] = _guards(map, GATE)
	var target: NpcRuntimeState = _westmost(map, guards)
	await _into_gate(tree, map, target)
	map._process(0.0)
	_check(map.hostilities.alert_seconds_left() > 0.0 and map.select_npc(target.character_id), "in the beat, the one who noticed selected")
	var started: CombatSliceInitiationResult = map.attack_selected()
	_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED and coordinator.active_encounter().participants().size() == 4, "攻击 in the beat: all three at once")
	_check(map.hostilities.alert_seconds_left() == 0.0 and guards.all(func(npc: NpcRuntimeState) -> bool: return not _body(map, npc).alert_mark_shown() and not _red(_body(map, npc))), "the beat is gone, its marks too")
	await _leave(tree, session, map)


## look.c's glare at one of the gang within the beat (观察): it turns to glare, nothing more;
## the beat runs out and the whole gang falls on the player.
func _test_glare(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var noticer: NpcRuntimeState = _westmost(map, _guards(map, GATE))
	var bellicosity: int = noticer.character_state.attributes.bellicosity
	await _into_gate(tree, map, noticer)
	map._process(0.0)
	noticer.character_state.attributes.bellicosity = 1000000 # TEST-ONLY: its glare goes over
	var said: int = session.shared_ui().log_lines().size()
	map.hostilities.look_berserk(noticer)
	noticer.character_state.attributes.bellicosity = bellicosity
	_check(session.shared_ui().log_lines().slice(said).has("京师守城兵突然转过头来瞪你一眼。"), "it glares")
	_check(not coordinator.has_active_encounter() and map.hostilities.alert_seconds_left() > 0.0, "no fight of two: the beat runs on")
	map._process(0.6)
	_check(coordinator.has_active_encounter() and coordinator.active_encounter().participants().size() == 4, "then all three")
	await _leave(tree, session, map)


## At 0 (经典模式) the gang falls on the player the tick it notices them, as before the beat.
func _test_classic(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var noticer: NpcRuntimeState = _westmost(map, _guards(map, GATE))
	var said: int = session.shared_ui().log_lines().size()
	await _into_gate(tree, map, noticer)
	map._process(0.0)
	_check(coordinator.has_active_encounter() and coordinator.active_encounter().participants().size() == 4, "经典: all three at once, no beat")
	var lines: Array[String] = session.shared_ui().log_lines().slice(said)
	_check(not lines.any(func(line: String) -> bool: return LINES.has(line)) and not _body(map, noticer).alert_mark_shown(), "经典: no shout, no ！ (start_vendetta() says nothing)")
	await _leave(tree, session, map)


## The ice cave's 白鳞冰龙 (beasts): the ！ and the log's line, no words.
func _test_beast(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var said: int = session.shared_ui().log_lines().size()
	var cave: WorldMapController = MapPlaces.enter(session, &"village.lakebottom2", &"village.lakebottom2.valley_arrival") # TEST-ONLY: down from the valley
	if not _check(cave != null, "TEST-ONLY: down into the dragons' cave"):
		return
	await tree.process_frame
	await tree.physics_frame
	await tree.process_frame
	var lines: Array[String] = session.shared_ui().log_lines().slice(said)
	_check(not coordinator.has_active_encounter() and lines.has("白鳞冰龙发现了你！"), "a dragon notices the player: %s" % [lines])
	_check(not lines.any(func(line: String) -> bool: return line.contains("道：") or line.contains("大喝一声")), "no words from a beast: %s" % [lines])
	_check(cave.npc_runtimes().any(func(npc: NpcRuntimeState) -> bool: return cave.runtime_body_for_character(npc.character_id) != null and cave.runtime_body_for_character(npc.character_id).alert_mark_shown()), "the ！ over it")
	var waited: float = 0.0
	while waited < 2.0 and not coordinator.has_active_encounter():
		await tree.process_frame
		waited += 1.0 / 60.0
	_check(coordinator.has_active_encounter() and coordinator.active_encounter().participants().size() == 7, "half a second on, all six dragons")
	await _flee(tree, session)


func _guards(map: WorldMapController, zone_id: StringName) -> Array[NpcRuntimeState]:
	var found: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if NpcDefinition.unnamed_id(npc.definition_id) == &"city.npc.guard" and npc.world_location().zone_id == zone_id and npc.exists_in_map:
			found.append(npc)
	return found


func _westmost(map: WorldMapController, npcs: Array[NpcRuntimeState]) -> NpcRuntimeState:
	var best: NpcRuntimeState = null
	for npc: NpcRuntimeState in npcs:
		if best == null or _body(map, npc).global_position.x < _body(map, best).global_position.x:
			best = npc
	return best


func _body(map: WorldMapController, npc: NpcRuntimeState) -> WorldCharacterBody2D:
	return map.runtime_body_for_character(npc.character_id)


func _red(body: WorldCharacterBody2D) -> bool:
	var label: Label = body.get_node_or_null("NameLabel") as Label
	return label != null and label.has_theme_color_override("font_color")


## TEST-ONLY: just inside the gate, in reach of `noticer` (the westmost) only.
func _into_gate(tree: SceneTree, map: WorldMapController, noticer: NpcRuntimeState) -> void:
	var at: Vector2 = _body(map, noticer).global_position
	await _place(tree, map, GATE, Vector2(MapPlaces.zone_rect(map, GATE).position.x + 16.0, at.y))


func _place(tree: SceneTree, map: WorldMapController, zone_id: StringName, at: Vector2) -> void:
	map.runtime_player_body().global_position = MapPlaces.spot(map, zone_id, at, 24.0)
	map.player_runtime().set_world_location(map.location_for_zone(zone_id))
	await tree.physics_frame
	await tree.physics_frame


## Flee, then out to the street and a tick there: the gate's 守城兵 meet the player anew.
func _leave(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	await _flee(tree, session)
	await _place(tree, map, STREET, MapPlaces.zone_rect(map, GATE).position + Vector2(-80.0, 40.0))
	map._process(0.0)


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


func _check(ok: bool, label: String) -> bool:
	_count += 1
	if not ok:
		_failures.append("hostile alert: " + label)
	return ok
