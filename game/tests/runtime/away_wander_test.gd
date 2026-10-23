extends RefCounted

## 别的地图时间补算 B (owner, 2026-10-23; DECISIONS): coming back to a map, its wanderers and
## constables are where their chat's moves took them while the player was away (random_move()
## by its own rule, patrol() along the beat), the same each time; ES2's knob (0) leaves them
## where they stood. 邻图来客 (owner Q1): standing in a shop's street, a wanderer of the shop
## next door may come out through its door.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _wanderers_move(tree)
	await _es2_stays(tree)
	await _neighbour_comes_in(tree)
	return _result()


## Away ten minutes from every map: wanderers moved, each within its range (home and next
## door), none onto the player's map; constables on their beat; world after world the same.
func _wanderers_move(tree: SceneTree) -> void:
	var runs: Array[Dictionary] = []
	for run: int in 2:
		var session: WorldSessionController = Work.create_session(tree)
		# No frame of real time (the time owed draws the catch-up's seed).
		session.set_process(false)
		await tree.process_frame
		var before: Dictionary[StringName, StringName] = _zones(session)
		session.away_times().advance(600.0)
		for map: WorldMapController in session.world_maps():
			session.catch_up_map(map)
		var after: Dictionary[StringName, StringName] = _zones(session)
		var moved: int = 0
		var out_of_range: Array[String] = []
		var catalog: ContentCatalog = GameContent.catalog()
		for id: StringName in after:
			var npc: NpcRuntimeState = _npc(session, id)
			if after[id] == before.get(id, after[id]):
				continue
			moved += 1
			var spawn: NpcSpawnDefinition = catalog.spawn(npc.spawn_id)
			var patrol: NpcPatrol = npc.definition().dealings().patrol
			var in_range: bool = (
				patrol.route.has(after[id]) if patrol != null
				else spawn != null and (after[id] == spawn.zone_id or catalog.zones_adjacent(spawn.zone_id, after[id]))
			)
			if not in_range:
				out_of_range.append("%s:%s" % [id, after[id]])
		print("away wander: %d of %d NPCs moved in ten minutes" % [moved, after.size()])
		_check(moved >= 10, "wanderers and constables moved while the player was away (%d)" % moved)
		_check(out_of_range.is_empty(), "each stays within its range: %s" % [out_of_range])
		var on_player_map: int = 0
		for npc: NpcRuntimeState in session.world_map_of(session.active_map_id()).npc_runtimes():
			var was: ZoneDefinition = catalog.zone(before.get(npc.character_id, &""))
			if was != null and was.map_id != session.active_map_id():
				on_player_map += 1
		_check(on_player_map == 0, "nobody was moved onto the player's map unseen")
		var placed: Array[String] = []
		for map: WorldMapController in session.world_maps():
			for npc: NpcRuntimeState in map.npc_runtimes():
				var body: Node2D = map.npcs.runtime_body_for_character(npc.character_id)
				if body != null and npc.exists_in_map:
					placed.append("%s@%s" % [npc.character_id, body.global_position.round()])
					if not map.point_in_zone(body.global_position, npc.world_location().zone_id):
						_check(false, "%s's body stands in its zone" % npc.character_id)
		runs.append({"zones": after, "bodies": placed})
		session.free()
		await tree.process_frame
	_check(runs.size() == 2 and runs[0] == runs[1], "the same absence puts everyone in the same place, world after world")


## ES2 (away_wander_moves 0, no pulse): a healed NPC's heart beat stops where no player is.
func _es2_stays(tree: SceneTree) -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	GameContent.catalog().set_pacing(_pacing(pacing, 0, 0))
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	var before: Dictionary[StringName, StringName] = _zones(session)
	session.away_times().advance(600.0)
	for map: WorldMapController in session.world_maps():
		session.catch_up_map(map)
	_check(_zones(session) == before, "with ES2's knob nobody away moved")
	session.free()
	await tree.process_frame
	GameContent.catalog().set_pacing(pacing)


## Standing on the square outside 饮风客栈 for twenty minutes: a 旅客 comes out through the
## inn's door (go.c's 走了过来。), onto the square beside it; without the pulse (ES2) never.
func _neighbour_comes_in(tree: SceneTree) -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	for pulse: int in [30, 0]:
		GameContent.catalog().set_pacing(_pacing(pacing, pacing.away_wander_moves, pulse))
		var session: WorldSessionController = Work.create_session(tree)
		await tree.process_frame
		session.set_process(false)
		var zone: ZoneDefinition = GameContent.catalog().zone(&"snow.square")
		_check(session.handoff_to(&"snow.outdoor", &"snow.square", zone.combat_location_id, &"snow.square.inn_entry").succeeded(), "the player stands on the square")
		var came: bool = false
		var told: bool = false
		for _second: int in 1200:
			var seen: int = session.shared_ui().log_lines().size()
			session.advance_npc_heartbeat(1.0)
			for line: String in session.shared_ui().log_lines().slice(maxi(seen - 1, 0)):
				told = told or line.contains("旅客走了过来")
			for npc: NpcRuntimeState in session.world_map_of(&"snow.outdoor").npc_runtimes():
				came = came or String(npc.character_id).begins_with("snow.inn.main_floor.inn.traveller")
			if came:
				break
		if pulse > 0:
			_check(came and told, "a 旅客 came out of the inn through its door while the player stood outside (%s, %s)" % [came, told])
		else:
			_check(not came, "without the pulse (ES2) nobody comes out of the inn")
		session.free()
		await tree.process_frame
	GameContent.catalog().set_pacing(pacing)


func _pacing(pacing: PacingDefinition, moves: int, pulse: int) -> PacingDefinition:
	return PacingDefinition.new(
		roundi(pacing.combat_round_seconds * 1000.0), pacing.room_reset_seconds, pacing.player_exp_gain,
		pacing.player_recovery_gain, pacing.quest_time_percent, pacing.npc_thirst, pacing.player_wake_seconds,
	).with_responsiveness(roundi(pacing.reaction_seconds(10.0) * 1000.0), roundi(pacing.trial_blow_seconds * 1000.0), roundi(pacing.heart_beat_seconds * 1000.0), roundi(pacing.dim_fade_seconds * 1000.0)).with_away_catch_up_limit(pacing.away_catch_up_limit_seconds, moves, pulse)


## Each NPC standing in the world, by ID: its zone.
func _zones(session: WorldSessionController) -> Dictionary[StringName, StringName]:
	var zones: Dictionary[StringName, StringName] = {}
	for npc: NpcRuntimeState in session.world_npcs():
		if npc.exists_in_map and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
			zones[npc.character_id] = npc.world_location().zone_id
	return zones


func _npc(session: WorldSessionController, character_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in session.world_npcs():
		if npc.character_id == character_id:
			return npc
	return null


func _result() -> Dictionary[String, Variant]:
	return {"assertions": _count, "failures": _failures}


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
