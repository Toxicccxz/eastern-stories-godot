extends RefCounted

## Busy is saved, not waited on (owner, 2026-10-17). The project review found an NPC left
## busy on a map the player left: inactive maps froze, so it stayed busy there and Save
## refused until the player went back. Now busy is saved with its character on every map
## (the player's too) and Continue restores it exactly, with no draw; the map left owes its
## time (别的地图时间补算) and back on it the busy has worn off.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	var home_map: StringName = session.active_map_id()
	var here: NpcRuntimeState = _first_npc(session, home_map)
	_check(here != null, "the start map has an NPC")
	if here == null:
		session.free()
		return _result()
	var npc_id: StringName = here.character_id
	# On the map the player stands in.
	here.busy.start_busy(5, 7)
	session.player_runtime().busy.start_busy(2)
	_check(OldPineSaveEligibility.inspect(session).allowed(), "Save does not wait on a busy NPC or player on the current map")
	# Left behind on a map that waits until someone comes (the clock alone: the street's own
	# beat could bring someone in by the door, which catches the map up).
	var away: PortalDefinition = _portal(home_map, func(p: PortalDefinition) -> bool: return p.destination_map_id != home_map)
	_check(away != null and _go(session, away), "the player leaves the busy NPC's map")
	session.away_times().advance(6.0)
	_check(session.npc_world_time_allowed(), "world time runs on the map the player went to")
	_check(here.busy.busy_value == 5 and here.busy.interrupt_threshold == 7, "the map left behind waits, its time owed: its NPC is still busy")
	_check(OldPineSaveEligibility.inspect(session).allowed(), "Save does not wait on a busy NPC on a map left behind")
	var player_busy: Array[int] = [session.player_runtime().busy.busy_value, session.player_runtime().busy.interrupt_threshold]
	var rng: Array[int] = Work.rng_state(session)
	var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-09-11T00:00:00Z")
	_check(captured.snapshot != null, "busy characters are captured")
	_check(here.busy.busy_value == 5 and Work.rng_state(session) == rng, "Save leaves the busy as it was and draws nothing")
	var back_map: StringName = away.destination_map_id
	session.free()
	await tree.process_frame
	if captured.snapshot == null:
		return _result()
	var text: String = GameSaveJsonCodec.encode(captured.snapshot).text
	var read: GameSaveResult = GameSaveJsonCodec.decode(text)
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(read.snapshot, tree.root)
	if restored.succeeded():
		# No frame of the restored world's own time (the map left owes it) before the checks.
		restored.candidate.set_process(false)
	_check(read.succeeded() and restored.succeeded() and restored.candidate.activate_restore_candidate(), "Continue builds the busy world")
	if not restored.succeeded():
		return _result()
	var world: WorldSessionController = restored.candidate
	await tree.process_frame
	var back: NpcRuntimeState = _npc(world, npc_id)
	_check(back != null and back.busy.busy_value == 5 and back.busy.interrupt_threshold == 7, "the map left's NPC comes back busy, its interrupt value too")
	_check(world.away_times().owed_ms(home_map) == 6000, "Continue owes the map left its six seconds")
	_check([world.player_runtime().busy.busy_value, world.player_runtime().busy.interrupt_threshold] == player_busy, "the player's busy comes back")
	_check(Work.rng_state(world) == rng, "Continue draws nothing")
	_check(GameSaveJsonCodec.encode(Work.capture(world)).text == text, "the restored world saves the same")
	var home: PortalDefinition = _portal(back_map, func(p: PortalDefinition) -> bool: return p.destination_map_id == home_map)
	_check(home != null and _go(world, home), "the player goes back to the NPC's map")
	# Six seconds are three beats: five busy beats less three. Then it wears off on the beat.
	_check(back != null and back.busy.busy_value == 2, "coming back catches the map up: three of its busy beats are spent")
	for _beat: int in 120:
		world.advance_npc_heartbeat(1.0)
		if back == null or back.busy.busy_value == 0:
			break
	# continue_action() runs only while busy, so the interrupt value stays (action.c), harmless
	# until the next start_busy() replaces it; it is saved as it is.
	_check(back != null and back.busy.busy_value == 0 and back.busy.interrupt_threshold == 7, "back on its map the busy wears off on the heart beat")
	_check(OldPineSaveEligibility.inspect(world).allowed(), "a spent busy with its interrupt value allows Save")
	world.free()
	await tree.process_frame
	return _result()


func _first_npc(session: WorldSessionController, map_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in session.world_map_of(map_id).npc_runtimes():
		if npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			return npc
	return null


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
