extends RefCounted

## Hours of world time on Snow and Old Pine (about three; ES_SOAK_HOURS=<n> runs
## longer): the player stays five minutes in every room in turn, knocks a trainee out,
## kills an NPC every half hour and sells a floor item, while rooms reset and NPCs
## wander, heal and come to. Each stay ends with a Save, restored and compared every
## ten minutes; every hour play goes on in the restored world, as after Continue. Nothing
## may stall: fights end, nobody stays busy, out cold, mid-walk, dead past its room's
## reset or away from home past it, no fight aborts and no error is logged.
## TEST-ONLY: the player is strong enough to win every fight and is placed in each room
## instead of walking there (the windowed walkthrough walks them).
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const STAY_SECONDS: int = 300
## Every stay ends with a Save; every second one is restored and compared.
const RESTORE_EVERY_STAYS: int = 2
## Longer than a reset period and its slack, so an overdue reset shows before the
## schedules start afresh with the restored world.
const SWAP_EVERY_STAYS: int = 12
const KILL_EVERY_STAYS: int = 6
## room.c: TIME_TO_RESET / 2 + random(TIME_TO_RESET / 2), at most the period.
const RESET_SECONDS: int = 1800
## A respawn or homecoming is due one reset period after it began; checks run at the
## end of each five-minute stay, so one stay late.
const RESET_SLACK_SECONDS: int = 2 * STAY_SECONDS
## damage.c revive: random(100 - con) + 30 seconds, at most 129.
const OUT_COLD_SECONDS: int = 135
## busy 1 or 2 wears off within two 2-second beats.
const BUSY_SECONDS: int = 6
const WALK_SECONDS: int = 60
const FIGHT_SECONDS: int = 600
## Where the player arrives on each map before being placed in a room.
const ENTRIES: Dictionary[StringName, Array] = {
	&"snow.inn": [&"snow.inn.main_floor", &"snow.inn.main_floor.player_birth"],
	&"snow.outdoor": [&"snow.square", &"snow.square.inn_entry"],
	&"snow.inn_upstairs": [&"snow.inn_2f", &"snow.inn_2f.stairs_arrival"],
	&"snow.cellar": [&"snow.secret_storage", &"snow.secret_storage.stairs_arrival"],
	&"oldpine.outdoor": [&"oldpine.outdoor.central_clearing", &"oldpine.outdoor.central_clearing.player_start"],
}
const OLD_PINE_ROOMS: Array[StringName] = [&"oldpine.outdoor.north_approach", &"oldpine.outdoor.slope"]
## Killed in turn, one every KILL_EVERY_STAYS stays (spawn point, its map).
const VICTIMS: Array[Array] = [
	[&"snow.eroad2.dog.1", &"snow.outdoor"], [&"snow.sroad2.farmer.1", &"snow.outdoor"],
	[&"snow.school2.trainee.1", &"snow.outdoor"], [&"snow.mstreet2.scavenger.1", &"snow.outdoor"],
	[&"snow.herbshop.woodcutter.1", &"snow.outdoor"], [&"snow.inn_2f.rat.1", &"snow.inn_upstairs"],
]
const SWORD_POINT: StringName = &"snow.weapon_storage.bamboo_sword.1"


## Script errors and push_error() (a room reset that could not lay its item, say).
class LoggedErrors extends Logger:
	var _mutex: Mutex = Mutex.new()
	var lines: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		if error_type != ERROR_TYPE_SCRIPT and error_type != ERROR_TYPE_ERROR:
			return
		_mutex.lock()
		lines.append("%s:%d %s" % [file, line, rationale if not rationale.is_empty() else code])
		_mutex.unlock()


var assertions: int = 0
var failures: Array[String] = []
var _tree: SceneTree
var _session: OldPineWorldSessionController
var _now: int = 0
## World seconds when the room schedules last started afresh (New Game, Continue).
var _schedules_since: int = 0
var _out_cold: Dictionary[StringName, int] = {}
var _busy: Dictionary[StringName, int] = {}
var _walking: Dictionary[StringName, int] = {}
var _fight_seconds: int = 0
var _fights: int = 0
var _dead_since: Dictionary[StringName, int] = {}
var _away_since: Dictionary[StringName, int] = {}
var _respawns: int = 0
var _homecomings: int = 0
var _knockouts: int = 0
var _wakings: int = 0
var _sword_gone_at: int = -1
var _sword_back: bool = false
var _stopped: bool = false
var _restore_msec: int = 0


func run_all(tree: SceneTree) -> Dictionary:
	_tree = tree
	var errors := LoggedErrors.new()
	OS.add_logger(errors)
	await _soak()
	OS.remove_logger(errors)
	check(errors.lines.is_empty(), "no error logged in %d world seconds: %s" % [_now, errors.lines.slice(0, 5)])
	check(CombatEncounterCoordinator.take_aborted_total() == 0, "no fight aborted")
	if is_instance_valid(_session):
		_session.free()
	await tree.process_frame
	print("SOAK %d world s, %d fights, %d knock-outs (%d woke), %d respawns, %d homecomings, sword back %s; %d ms in Save/restore" % [_now, _fights, _knockouts, _wakings, _respawns, _homecomings, _sword_back, _restore_msec])
	return {"assertions": assertions, "failures": failures}


func check(ok: bool, label: String) -> bool:
	assertions += 1
	if not ok:
		failures.append("world soak: " + label)
	return ok


## The heart beat's tick draws, seeded so a failing soak can be rerun.
class SeededTicks extends RecoveryCadenceRandomSource:
	var _random: RandomNumberGenerator = RandomNumberGenerator.new()

	func _init(value: int) -> void:
		_random.seed = value

	func draw_reset_tick() -> int:
		return 5 + _random.randi_range(0, 9)


func _soak() -> void:
	_session = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	_session.configure_source_entry("雪工", CharacterState.GENDER_FEMALE)
	_session.deterministic_combat_seed = true
	_session.deterministic_npc_seed = true
	_session.deterministic_world_interaction_seed = true
	_session.configure_recovery_random_source(SeededTicks.new(1))
	_session.configure_npc_random_sources(SeededTicks.new(2), GodotCombatRandomSource.new(3, true))
	_tree.root.add_child(_session)
	await _tree.process_frame
	_session.set_process(false)
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	# TEST-ONLY: strong enough to win every fight here. The max kee survives Continue
	# (race/human.c at login: 100 + max_force / 4).
	player.state.progression.combat_experience = 1000000
	player.state.recovery.inner_force.maximum = 39600
	player.state.vitality = CharacterResourceState.new(10000, 10000, 10000)
	var rooms: Array[StringName] = []
	for zone: ZoneDefinition in GameContent.catalog().zones():
		if String(zone.zone_id).begins_with("snow."):
			rooms.append(zone.zone_id)
	rooms.append_array(OLD_PINE_ROOMS)
	# The 竹剑 goes first, so its shelf has time to reset within the soak.
	rooms.erase(&"snow.weapon_storage")
	rooms.push_front(&"snow.weapon_storage")
	var hours: float = float(OS.get_environment("ES_SOAK_HOURS")) if OS.has_environment("ES_SOAK_HOURS") else 0.0
	var stays: int = rooms.size() if hours <= 0.0 else ceili(hours * 3600.0 / STAY_SECONDS)
	for stay: int in stays:
		var room: StringName = rooms[stay % rooms.size()]
		if not await _enter(room):
			check(false, "could not place the player in %s" % room)
			return
		await _act(stay, room)
		await _pass(STAY_SECONDS)
		if _stopped:
			return
		if not await _settle_for_save():
			return
		var snapshot: GameSaveSnapshot = Work.capture(_session)
		if not check(snapshot != null, "Save captures after the stay in %s" % room):
			return
		var swap: bool = (stay + 1) % SWAP_EVERY_STAYS == 0
		if swap or stay % RESTORE_EVERY_STAYS == RESTORE_EVERY_STAYS - 1:
			var started: int = Time.get_ticks_msec()
			if not await _restore(snapshot, swap, room):
				return
			_restore_msec += Time.get_ticks_msec() - started
	check(_fights >= stays / KILL_EVERY_STAYS, "the fights happened: %d" % _fights)
	check(_knockouts >= 1 and _wakings >= _knockouts, "every knocked-out NPC came to: %d of %d" % [_wakings, _knockouts])
	check(_respawns >= 1 and _homecomings >= 1 and _sword_back, "rooms reset: %d respawns, %d homecomings, sword back %s" % [_respawns, _homecomings, _sword_back])


## One stay's own action: the 竹剑 taken and sold, a knock-out, or a kill.
func _act(stay: int, room: StringName) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	if room == &"snow.weapon_storage" and _sword_gone_at < 0:
		var sword: StringName = ItemSpawnDefinition.item_instance_id(_session.item_id_allocator().scope, SWORD_POINT)
		var view: WorldFloorItemView = map.floor_item_view(sword)
		if not check(view != null and _place(map, room, view.global_position + Vector2(0, 30)), "beside the 竹剑 on its shelf"):
			return
		await _tree.physics_frame
		check(map.select_floor_item(sword) and map.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN, "the 竹剑 taken")
		# Sold at once: room.c reset() lays it again only once it is gone (DECISIONS 4D).
		var counter: HockshopService = map.service(&"snow.hockshop.counter") as HockshopService
		if not check(_carries_sword() and _place(map, &"snow.hockshop", map.physical_zone(&"snow.hockshop").global_rect().get_center()), "at the Hockshop counter with the 竹剑"):
			return
		await _tree.physics_frame
		_session.shared_ui().open_current_context()
		counter.select_item(sword)
		counter.request_value()
		counter.request_confirmation()
		counter.confirm_sale()
		_session.shared_ui().dismiss_current_panel()
		if check(counter.last_sell != null and counter.last_sell.outcome == HockshopSellResult.Outcome.SOLD, "the 竹剑 sold"):
			_sword_gone_at = _now
	elif room == &"snow.school2":
		var trainee: NpcRuntimeState = _npc(map, &"snow.school2.trainee.6")
		check(trainee != null, "a trainee at school2's sixth marker")
		if trainee != null and trainee.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			check(_beside(map, trainee), "beside the trainee")
			map.select_npc(trainee.character_id)
			if check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the trainee spars"):
				# TEST-ONLY: the blow that knocks it out (kee < 0).
				trainee.character_state.vitality.current = -1
				_knockouts += 1
	if stay % KILL_EVERY_STAYS == KILL_EVERY_STAYS - 1 and not _session.combat_encounter_coordinator().has_active_encounter():
		var victim: Array = VICTIMS[(stay / KILL_EVERY_STAYS) % VICTIMS.size()]
		if not await _enter_map(victim[1]):
			return
		map = _session.active_map() as WorldMapController
		var npc: NpcRuntimeState = _npc(map, victim[0])
		check(npc != null, "someone at %s" % victim[0])
		# A victim still dead from an earlier stay waits for its room's reset.
		if npc != null and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			check(_beside(map, npc), "beside %s" % victim[0])
			await _tree.physics_frame
			map.select_npc(npc.character_id)
			check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED or _session.combat_encounter_coordinator().has_active_encounter(), "attack %s" % victim[0])


## World time in one-second steps, as frames pass it, with a physics frame every ten
## seconds for presence (aggression). Watches every stall.
func _pass(seconds: int) -> void:
	var coordinator: CombatEncounterCoordinator = _session.combat_encounter_coordinator()
	for second: int in seconds:
		var fighting: bool = coordinator.has_active_encounter()
		_session._process(1.0)
		_now += 1
		if fighting:
			_fight_seconds += 1
			if not check(_fight_seconds < FIGHT_SECONDS, "a fight outlived %d s at %s" % [FIGHT_SECONDS, _where()]):
				_stopped = true
				return
		elif _fight_seconds > 0:
			_fights += 1
			_fight_seconds = 0
		_watch(not coordinator.has_active_encounter())
		_track_resets()
		if _stopped:
			return
		if second % 10 == 9:
			await _tree.physics_frame


func _watch(world_flows: bool) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if world_flows:
		_count(_busy, player.character_id, player.busy.is_busy(), BUSY_SECONDS, "the player stays busy")
	for npc: NpcRuntimeState in map.npc_runtimes():
		var id: StringName = npc.character_id
		var out_cold: bool = npc.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS
		if _out_cold.has(id) and not out_cold and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			_wakings += 1
		if world_flows:
			_count(_out_cold, id, out_cold, OUT_COLD_SECONDS, "%s stays out cold" % npc.spawn_point_id)
			_count(_busy, id, npc.busy.is_busy() and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, BUSY_SECONDS, "%s stays busy" % npc.spawn_point_id)
			_count(_walking, id, map.npc_walker().is_walking(id), WALK_SECONDS, "%s never ends its walk" % npc.spawn_point_id)


func _count(counters: Dictionary[StringName, int], id: StringName, active: bool, limit: int, label: String) -> void:
	if not active:
		counters.erase(id)
		return
	counters[id] = counters.get(id, 0) + 1
	if counters[id] == limit:
		check(false, "%s (%d s at %s)" % [label, limit, _where()])
		_stopped = true


## Fights end, the player lives and is idle: Save is allowed (else a stall).
func _settle_for_save() -> bool:
	for second: int in 300:
		if OldPineSaveEligibility.inspect(_session).allowed():
			_check_resets()
			return true
		await _pass(1)
		if _stopped:
			return false
	return check(false, "Save stayed closed at %s: %d" % [_where(), OldPineSaveEligibility.inspect(_session).outcome])


## Since when each spawn point's NPC has been dead, or away from home, every second on
## every map (a wanderer may come home at a reset and leave again before a check).
func _track_resets() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for map: WorldMapController in _session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			var point: StringName = npc.spawn_point_id
			var dead: bool = npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD
			if dead and not _dead_since.has(point):
				_dead_since[point] = _now
			elif not dead and _dead_since.has(point):
				_dead_since.erase(point)
				_respawns += 1
			var away: bool = not dead and npc.world_location().zone_id != catalog.spawn(npc.spawn_id).zone_id
			if away and not _away_since.has(point):
				_away_since[point] = _now
			elif not away and _away_since.has(point):
				_away_since.erase(point)
				_homecomings += 1


## Dead NPCs come back and wanderers go home within a reset period (counted from
## Continue, which starts the schedules afresh); so does the 竹剑.
func _check_resets() -> void:
	for point: StringName in _dead_since:
		check(_overdue(_dead_since[point]) == false, "%s never came back (dead since %d s)" % [point, _dead_since[point]])
	for point: StringName in _away_since:
		check(_overdue(_away_since[point]) == false, "%s never went home (away since %d s)" % [point, _away_since[point]])
	if _sword_gone_at >= 0 and not _sword_back:
		var sword: StringName = ItemSpawnDefinition.item_instance_id(_session.item_id_allocator().scope, SWORD_POINT)
		_sword_back = _session.inventory_state().is_registered(sword) and not _carries_sword()
		check(_sword_back or not _overdue(_sword_gone_at), "the 竹剑 never came back to the shelf")


func _overdue(since: int) -> bool:
	return _now > maxi(since, _schedules_since) + RESET_SECONDS + RESET_SLACK_SECONDS


## Save → restore must be exact; a swap goes on in the restored world (Continue).
func _restore(snapshot: GameSaveSnapshot, swap: bool, room: StringName) -> bool:
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	if not check(encoded.succeeded() and decoded.succeeded(), "the save after %s encodes and decodes" % room):
		return false
	if swap:
		_session.free()
		await _tree.process_frame
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, _tree.root)
	if not check(restored.succeeded(), "restore after %s: %s" % [room, restored.path]):
		if is_instance_valid(restored.candidate):
			restored.candidate.free()
		return false
	var fresh: OldPineWorldSessionController = restored.candidate
	check(fresh.activate_restore_candidate(), "activate the restore after %s" % room)
	fresh.set_process(false)
	var again: GameSaveSnapshot = Work.capture(fresh)
	check(again != null and GameSaveJsonCodec.encode(again).text == encoded.text, "the restore after %s is exact" % room)
	if not swap:
		fresh.free()
		return true
	_session = fresh
	_schedules_since = _now
	# Transient walks and beats start afresh with the new world.
	_walking.clear()
	await _tree.process_frame
	return true


# --- Placement ---------------------------------------------------------------------

func _enter(room: StringName) -> bool:
	var zone: ZoneDefinition = GameContent.catalog().zone(room)
	if zone == null or not await _enter_map(zone.map_id):
		return false
	var map: WorldMapController = _session.active_map() as WorldMapController
	var rect: Rect2 = map.physical_zone(room).global_rect()
	for ring: int in 6:
		for offset: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)]:
			var spot: Vector2 = rect.get_center() + offset * 24.0 * ring
			if MapPlacementValidator.is_valid_character_position(map, room, spot) and _clear_of_npcs(map, spot):
				var placed: bool = _place(map, room, spot)
				for frame: int in 3:
					await _tree.physics_frame
				return placed
	return false


func _enter_map(map_id: StringName) -> bool:
	if _session.active_map_id() == map_id:
		return true
	var entry: Array = ENTRIES[map_id]
	var handoff: OldPineMapHandoffResult = _session.handoff_to(map_id, entry[0], entry[0], entry[1])
	await _tree.physics_frame
	return check(handoff.succeeded(), "handoff to %s: %d" % [map_id, handoff.outcome])


func _beside(map: WorldMapController, npc: NpcRuntimeState) -> bool:
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var zone_id: StringName = npc.world_location().zone_id
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if body != null and MapPlacementValidator.is_valid_character_position(map, zone_id, body.global_position + offset):
			return _place(map, zone_id, body.global_position + offset)
	return false


func _place(map: WorldMapController, zone_id: StringName, at: Vector2) -> bool:
	map.runtime_player_body().global_position = at
	return _session.player_runtime().set_world_location(map.location_for_zone(zone_id))


func _clear_of_npcs(map: WorldMapController, spot: Vector2) -> bool:
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
		if body != null and npc.exists_in_map and body.global_position.distance_to(spot) < 48.0:
			return false
	return true


func _npc(map: WorldMapController, point: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == point:
			return npc
	return null


func _carries_sword() -> bool:
	var sword: StringName = ItemSpawnDefinition.item_instance_id(_session.item_id_allocator().scope, SWORD_POINT)
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	return _session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)).has(sword)


func _where() -> String:
	return "%s, %d s" % [_session.player_runtime().world_location().zone_id, _now]
