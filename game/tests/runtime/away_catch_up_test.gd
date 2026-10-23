extends RefCounted

## 别的地图时间补算 (owner, 2026-10-23; DECISIONS): a map the player was away from catches up
## its NPCs' heart beat when the player comes back (or a reset or an NPC comes to it), as if
## it had run all along: the catch-up gives what the beat gives, on draws of its own, the
## same each time and across a Continue; past pacing.json away_catch_up_limit_seconds the
## rest is settled.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SEED: int = 42

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _catch_up_is_the_beat(tree)
	await _away_and_back(tree)
	await _limit_settles(tree)
	await _continue_owes_the_same(tree)
	await _poison_away(tree)
	await _in_and_out(tree)
	await _every_map_in_time(tree)
	return _result()


## NpcHeartbeat.catch_up() over 10 minutes gives what advance() gives frame by frame: the
## heal_up() ticks, a poison's, busy wearing off, a revive and the healing while it lay there.
func _catch_up_is_the_beat(tree: SceneTree) -> void:
	var live_world: WorldSessionController = Work.create_session(tree)
	var away_world: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	live_world.set_process(false)
	away_world.set_process(false)
	var live: Array[NpcRuntimeState] = _hurt_pair(live_world)
	var away: Array[NpcRuntimeState] = _hurt_pair(away_world)
	_check(live.size() == 2 and away.size() == 2, "the start map has two NPCs to hurt")
	if live.size() == 2 and away.size() == 2:
		for index: int in 2:
			var beat: NpcHeartbeat = NpcHeartbeat.new(GodotRecoveryCadenceRandomSource.new(SEED + index, true))
			var woke: bool = false
			for _frame: int in 6000:
				woke = not beat.advance(0.1, [live[index]]).is_empty() or woke
			var caught: NpcHeartbeat.CatchUp = NpcHeartbeat.new(GodotRecoveryCadenceRandomSource.new(SEED + index, true)).catch_up(away[index], 600.0)
			_check(_body(live[index]) == _body(away[index]), "catch-up gives what the beat gives (%s): %s vs %s" % [live[index].character_id, _body(live[index]), _body(away[index])])
			_check(caught.woke == woke and caught.left == 0.0, "it wakes as the beat would, and stays standing")
		_check(away[1].life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "the one lying unconscious woke")
		_check(away[0].character_state.conditions.size() == 0 and not away[0].busy.is_busy(), "the poison ran out and busy wore off")
	live_world.free()
	away_world.free()
	await tree.process_frame


## The player leaves a map with a hurt NPC and one lying unconscious; its time stands owed,
## and coming back catches it up: healed some, awake. Again and the same; coming and going at
## once changes nothing; the catch-up draws from no session stream.
func _away_and_back(tree: SceneTree) -> void:
	var results: Array[Array] = []
	for run: int in 2:
		var session: WorldSessionController = Work.create_session(tree)
		await tree.process_frame
		session.set_process(false)
		var home: StringName = session.active_map_id()
		var hurt: Array[NpcRuntimeState] = _hurt_pair(session)
		var out: PortalDefinition = _portal(home, func(p: PortalDefinition) -> bool: return p.destination_map_id != home)
		_check(hurt.size() == 2 and out != null and _go(session, out), "the player leaves the hurt NPCs' map")
		if hurt.size() != 2 or session.active_map_id() == home:
			session.free()
			return
		var before: Array = [_body(hurt[0]), _body(hurt[1])]
		# The clock alone: the street's own beat could bring someone in by the door, which
		# catches the map up before they come (tested below with a reset).
		session.away_times().advance(120.0)
		_check(session.away_times().owed_ms(home) == 120_000, "two minutes of world time are owed to the map left")
		_check([_body(hurt[0]), _body(hurt[1])] == before, "nobody looks: the map waits, as it was")
		var rng: Array[int] = Work.rng_state(session)
		session.catch_up_map(session.world_map_of(home))
		_check(Work.rng_state(session) == rng, "the catch-up draws from no session stream")
		_check(session.away_times().owed_ms(home) == 0, "caught up, it owes nothing")
		# A room reset there catches it up first: what it finds is as it is now.
		session.away_times().advance(5.0)
		var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(hurt[0].spawn_id)
		var room: String = "" if spawn == null else spawn.legacy_source_room_path
		_check(not room.is_empty(), "the hurt NPC's room is known")
		if not room.is_empty():
			session.reset_room(room)
			_check(session.away_times().owed_ms(home) == 0, "a room reset on the map catches it up first")
		var back: PortalDefinition = _portal(out.destination_map_id, func(p: PortalDefinition) -> bool: return p.destination_map_id == home)
		_check(back != null and _go(session, back), "the player comes back")
		var after: Array = [_body(hurt[0]), _body(hurt[1])]
		_check(hurt[0].character_state.vitality.current > before[0][1], "the hurt one healed while the player was away")
		_check(hurt[1].life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "the one lying there woke (revive's 30 s came)")
		# Out and in again at once: no time, no change.
		_check(_go(session, out) and _go(session, back), "out and in again")
		_check([_body(hurt[0]), _body(hurt[1])] == after, "coming and going at once changes nothing")
		results.append(after)
		session.free()
		await tree.process_frame
	_check(results.size() == 2 and results[0] == results[1], "the same absence comes to the same, world after world")


## Past the limit the rest is settled: whole, the poison gone; with no limit (ES2) the slow
## repair of the effective value (one a tick) is still under way.
func _limit_settles(tree: SceneTree) -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	for limit: int in [60, 0]:
		var record: PacingDefinition = PacingDefinition.new(
			roundi(pacing.combat_round_seconds * 1000.0), pacing.room_reset_seconds, pacing.player_exp_gain,
			pacing.player_recovery_gain, pacing.quest_time_percent, pacing.npc_thirst, pacing.player_wake_seconds,
		).with_responsiveness(0, 0, roundi(pacing.heart_beat_seconds * 1000.0), 0).with_away_catch_up_limit(limit)
		GameContent.catalog().set_pacing(record)
		var session: WorldSessionController = Work.create_session(tree)
		await tree.process_frame
		session.set_process(false)
		var home: StringName = session.active_map_id()
		var hurt: Array[NpcRuntimeState] = _hurt_pair(session)
		var out: PortalDefinition = _portal(home, func(p: PortalDefinition) -> bool: return p.destination_map_id != home)
		if hurt.size() == 2 and out != null and _go(session, out):
			session.away_times().advance(300.0)
			session.catch_up_map(session.world_map_of(home))
			var kee: CharacterResourceState = hurt[0].character_state.vitality
			if limit > 0:
				_check(kee.current == kee.maximum and kee.effective == kee.maximum and hurt[0].character_state.conditions.size() == 0, "past the limit the rest is settled: whole, the poison over")
				_check(hurt[1].life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "past the limit the one lying there is up")
			else:
				_check(kee.effective < kee.maximum, "with no limit (ES2) five minutes repair the effective value one a tick")
		else:
			_check(false, "the limit run leaves the start map")
		session.free()
		await tree.process_frame
	GameContent.catalog().set_pacing(pacing)


## Save while a map is owed time: the save keeps what it is owed, Continue owes it the same,
## and coming back to it gives what it gives without the save.
func _continue_owes_the_same(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	var home: StringName = session.active_map_id()
	var hurt: Array[NpcRuntimeState] = _hurt_pair(session)
	var out: PortalDefinition = _portal(home, func(p: PortalDefinition) -> bool: return p.destination_map_id != home)
	if hurt.size() != 2 or out == null or not _go(session, out):
		_check(false, "the save run leaves the start map")
		session.free()
		return
	var ids: Array[StringName] = [hurt[0].character_id, hurt[1].character_id]
	session.away_times().advance(90.0)
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null and snapshot.away_ms.get(home, 0) == 90_000 and not snapshot.away_ms.has(out.destination_map_id), "the save keeps what the map left is owed, nothing for the player's")
	var text: String = "" if snapshot == null else GameSaveJsonCodec.encode(snapshot).text
	var back: PortalDefinition = _portal(out.destination_map_id, func(p: PortalDefinition) -> bool: return p.destination_map_id == home)
	_check(back != null and _go(session, back), "without the save the player comes back")
	var unsaved: Array = [_body(hurt[0]), _body(hurt[1])]
	session.free()
	await tree.process_frame
	if snapshot == null:
		return
	var read: GameSaveResult = GameSaveJsonCodec.decode(text)
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(read.snapshot, tree.root)
	if restored.succeeded():
		# No frame of the restored world's own time before the checks.
		restored.candidate.set_process(false)
	_check(read.succeeded() and restored.succeeded() and restored.candidate.activate_restore_candidate(), "Continue builds the world")
	if not restored.succeeded():
		return
	var world: WorldSessionController = restored.candidate
	await tree.process_frame
	_check(world.away_times().owed_ms(home) == 90_000, "Continue owes the map the same")
	_check(GameSaveJsonCodec.encode(Work.capture(world)).text == text, "the restored world saves the same")
	_check(_go(world, back), "after Continue the player comes back")
	_check([_body(_npc(world, ids[0])), _body(_npc(world, ids[1]))] == unsaved, "it comes to what it came to without the save")
	world.free()
	await tree.process_frame
	# A save naming the player's own map, or no map, is refused.
	for bad: StringName in [out.destination_map_id, &"no.such_map"]:
		var wrong: GameSaveSnapshot = read.snapshot.duplicate_snapshot()
		var owed: Dictionary[StringName, int] = {bad: 1000}
		var refused: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(wrong.with_away_ms(owed), tree.root)
		_check(not refused.succeeded(), "Continue refuses away_ms for %s" % bad)
		if refused.candidate != null:
			refused.candidate.free()
	await tree.process_frame


## A condition runs while the player is away (owner Q3: as in ES2): 蒙汗药 past one's
## tolerance lays them low where they stand (slumber_drug.c unconcious()), and they wake
## later and heal on, as on the player's own map.
func _poison_away(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	var home: StringName = session.active_map_id()
	var pair: Array[NpcRuntimeState] = _hurt_pair(session)
	var out: PortalDefinition = _portal(home, func(p: PortalDefinition) -> bool: return p.destination_map_id != home)
	if pair.size() != 2 or out == null:
		_check(false, "the poison run has two NPCs and a way out")
		session.free()
		return
	# Both stand, drugged far past their tolerance (pair[0] still busy three beats).
	pair[1].set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	pair[1].character_state.vitality.current = pair[1].character_state.vitality.effective
	for npc: NpcRuntimeState in pair:
		npc.character_state.conditions.clear()
		npc.character_state.conditions.add_or_replace_duration(ConditionIds.SLUMBER_DRUG, 1000)
	_check(_go(session, out), "the player leaves the drugged")
	# The first heal_up() tick comes within 15 beats (and pair[0]'s three busy ones).
	session.away_times().advance(40.0)
	session.catch_up_map(session.world_map_of(home))
	for npc: NpcRuntimeState in pair:
		_check(npc.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and npc.revive_in_ms > 0, "the drug laid %s low while the player was away" % npc.character_id)
	session.away_times().advance(600.0)
	session.catch_up_map(session.world_map_of(home))
	for npc: NpcRuntimeState in pair:
		_check(npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and npc.character_state.conditions.size() == 0, "%s woke, the drug spent" % npc.character_id)
	session.free()
	await tree.process_frame


## Out and in a hundred times, a little time each: nothing comes of it that time would not
## bring (no NPC, corpse, item or experience more); room resets keep their own time.
func _in_and_out(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	var home: StringName = session.active_map_id()
	var out: PortalDefinition = _portal(home, func(p: PortalDefinition) -> bool: return p.destination_map_id != home)
	var back: PortalDefinition = null if out == null else _portal(out.destination_map_id, func(p: PortalDefinition) -> bool: return p.destination_map_id == home)
	if back == null:
		_check(false, "the in-and-out run has a way out and back")
		session.free()
		return
	var before: Array = _world_tally(session)
	var resets: Array[int] = []
	for room: String in session.room_resets().rooms():
		resets.append(session.room_resets().remaining_ms(room))
	var ok: bool = true
	for _round: int in 100:
		ok = _go(session, out) and ok
		session.away_times().advance(0.5)
		ok = _go(session, back) and ok
	_check(ok, "a hundred times out and in")
	_check(_world_tally(session) == before, "nothing comes of it: %s vs %s" % [before, _world_tally(session)])
	var after: Array[int] = []
	for room: String in session.room_resets().rooms():
		after.append(session.room_resets().remaining_ms(room))
	_check(after == resets, "no room reset comes sooner for it")
	session.free()
	await tree.process_frame


func _world_tally(session: WorldSessionController) -> Array:
	var npcs: int = 0
	var standing: int = 0
	var corpses: int = 0
	var dropped: int = 0
	for map: WorldMapController in session.world_maps():
		corpses += map.corpse_states().size()
		dropped += map.dropped_item_ids().size()
		for npc: NpcRuntimeState in map.npc_runtimes():
			npcs += 1
			if npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
				standing += 1
	var player: CharacterState = session.player_runtime().state
	return [npcs, standing, corpses, dropped, player.progression.combat_experience, session.inventory_state().registered_item_ids().size()]


## Every map's NPCs hurt and an hour owed: each map catches up in time for a door's fade.
func _every_map_in_time(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	var hurt: int = 0
	for map: WorldMapController in session.world_maps():
		if map == session.active_map():
			continue
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and npc.character_state.vitality.maximum > 2:
				npc.character_state.vitality.effective = npc.character_state.vitality.maximum / 2
				npc.character_state.vitality.current = 1
				hurt += 1
	session.advance_npc_heartbeat(3600.0)
	var slowest: int = 0
	var slowest_map: StringName = &""
	var total: int = 0
	var maps: int = 0
	for map: WorldMapController in session.world_maps():
		if map == session.active_map():
			continue
		var started: int = Time.get_ticks_usec()
		session.catch_up_map(map)
		var spent: int = Time.get_ticks_usec() - started
		total += spent
		maps += 1
		if spent > slowest:
			slowest = spent
			slowest_map = map.map_id()
	print("away catch-up: %d maps, %d NPCs hurt, an hour each: %.1f ms in all, %.2f ms a map, slowest %.1f ms (%s)" % [maps, hurt, total / 1000.0, total / 1000.0 / maxi(maps, 1), slowest / 1000.0, slowest_map])
	_check(maps > 100 and hurt > 100, "the whole world's maps and NPCs are measured")
	_check(slowest < 80_000, "the slowest map catches up within a door's fade (80 ms)")
	session.free()
	await tree.process_frame


## Two NPCs of the start map: one hurt and wounded, poisoned and busy; one lying unconscious
## half a minute from its revive.
func _hurt_pair(session: WorldSessionController) -> Array[NpcRuntimeState]:
	var found: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in session.world_map_of(session.active_map_id()).npc_runtimes():
		if npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and npc.character_state.vitality.maximum >= 100 and npc.definition().raising() == null:
			found.append(npc)
		if found.size() == 2:
			break
	if found.size() < 2:
		return [] as Array[NpcRuntimeState]
	var kee: CharacterResourceState = found[0].character_state.vitality
	kee.effective = kee.maximum - 40
	kee.current = kee.maximum / 4
	found[0].character_state.conditions.add_or_replace_duration(ConditionIds.SNAKE_POISON, 3)
	found[0].busy.start_busy(3)
	var lying: CharacterResourceState = found[1].character_state.vitality
	lying.current = 0
	found[1].set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	found[1].set_revive_in_ms(30_000)
	return found


func _body(npc: NpcRuntimeState) -> Array:
	if npc == null:
		return []
	var state: CharacterState = npc.character_state
	return [
		state.vitality.effective, state.vitality.current, state.essence.current, state.spirit.current,
		state.recovery.water, state.recovery.food, state.recovery.inner_force.current,
		state.conditions.size(), npc.busy.busy_value, npc.life_status, npc.revive_in_ms,
	]


func _npc(session: WorldSessionController, character_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in session.world_npcs():
		if npc.character_id == character_id:
			return npc
	return null


func _portal(map_id: StringName, wanted: Callable) -> PortalDefinition:
	for portal: PortalDefinition in GameContent.catalog().portals_for_map(map_id):
		if wanted.call(portal):
			return portal
	return null


func _go(session: WorldSessionController, portal: PortalDefinition) -> bool:
	var zone: ZoneDefinition = GameContent.catalog().zone(portal.destination_zone_id)
	return zone != null and session.handoff_to(
		portal.destination_map_id, portal.destination_zone_id, zone.combat_location_id, portal.destination_spawn_point_id,
	).succeeded() and session.active_map_id() == portal.destination_map_id


func _result() -> Dictionary[String, Variant]:
	return {"assertions": _count, "failures": _failures}


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
