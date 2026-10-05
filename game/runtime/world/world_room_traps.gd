class_name WorldRoomTraps
extends RefCounted

## The Session's room traps (traps[] in world.json, RoomTrapDefinition): shut when
## the player leaves the trap's room its way, open again on the room's reset or
## when an item the trap listens for is played there. Not saved, as doors are not:
## a new world and a Continue both start with every trap open.
var _session: OldPineWorldSessionController
var _shut: Dictionary[StringName, bool] = {}


func _init(session: OldPineWorldSessionController) -> void:
	_session = session


func is_shut(trap_id: StringName) -> bool:
	return _shut.get(trap_id, false)


## keep2.c valid_leave(): leaving `from_zone_id` for `to_zone_id` while the way
## out stands open shuts it with its shout (heard in the room left) and calls in
## the summoned guards. Called before the player's location changes.
func player_leaving(from_zone_id: StringName, to_zone_id: StringName) -> void:
	for trap: RoomTrapDefinition in GameContent.catalog().traps():
		if trap.from_zone_id != from_zone_id or trap.to_zone_id != to_zone_id or is_shut(trap.trap_id):
			continue
		var map: WorldMapController = _map_of(trap)
		if map == null:
			continue
		_session.shared_ui().append_colored_lines([
			ColoredLine.new(TranslationServer.translate(trap.message("shout")), ColoredLine.HIY),
			ColoredLine.new(TranslationServer.translate(trap.message("shut")), ColoredLine.PLAIN),
		])
		_shut[trap.trap_id] = true
		map.set_door_open(trap.door_id, false)
		if not trap.summon_spawn_id.is_empty():
			map.summon(trap.summon_spawn_id)


## keep2.c reset(): the way out is there again, without a word.
func reset_room(legacy_room: String) -> void:
	for trap: RoomTrapDefinition in GameContent.catalog().traps():
		if trap.legacy_source_path == legacy_room and is_shut(trap.trap_id):
			_open(trap)


## keep2.c pipe_notify(), called by an item played in `zone_id` that makes
## `sound` (bamboo_pipe.c do_play()): the trap there says so and opens, shut or
## not. False when no trap hears it.
func hear(sound: StringName, zone_id: StringName) -> bool:
	var heard: bool = false
	for trap: RoomTrapDefinition in GameContent.catalog().traps():
		if sound.is_empty() or trap.opens_on != sound or trap.from_zone_id != zone_id:
			continue
		_session.shared_ui().append_log_lines([TranslationServer.translate(trap.message("open"))])
		_open(trap)
		heard = true
	return heard


func _open(trap: RoomTrapDefinition) -> void:
	_shut.erase(trap.trap_id)
	var map: WorldMapController = _map_of(trap)
	if map != null:
		map.set_door_open(trap.door_id, true)


func _map_of(trap: RoomTrapDefinition) -> WorldMapController:
	var door: DoorDefinition = GameContent.catalog().door(trap.door_id)
	return null if door == null else _session.world_map_of(door.map_id)
