class_name WorldRoomResets
extends RefCounted

## std/room.c reset() on world time. MudOS resets each room on its own schedule,
## TIME_TO_RESET / 2 + random(TIME_TO_RESET / 2) seconds after the last one
## (adm/etc/config.ES2 `time to reset : 1800`; pacing.json room_reset_seconds).
## Only rooms whose reset() does something are scheduled: rooms with
## set("objects") (NPC and item spawns) and rooms with a hidden passage
## (weapon_storage.c reset()). Schedules are ES2 room state, not saved: Continue
## starts them afresh, as a rebooted MUD did.
var _rooms: Array[String] = []
var _remaining_ms: Dictionary[String, int] = {}
var _carried_ms: float = 0.0
var _period_seconds: int
var _random: WorldInteractionRandomSource


func _init(rooms: Array[String], period_seconds: int, random: WorldInteractionRandomSource) -> void:
	_rooms = rooms.duplicate()
	_period_seconds = period_seconds
	_random = random
	for room: String in _rooms:
		_remaining_ms[room] = _interval_ms()


## The rooms of every map whose reset() means something, in catalog order.
static func resetting_rooms() -> Array[String]:
	var rooms: Array[String] = []
	var catalog: ContentCatalog = GameContent.catalog()
	for spawn: NpcSpawnDefinition in catalog.spawns():
		if not rooms.has(spawn.legacy_source_room_path):
			rooms.append(spawn.legacy_source_room_path)
	for map: MapDefinition in catalog.maps():
		for spawn: ItemSpawnDefinition in catalog.item_spawns_for_map(map.map_id):
			if not rooms.has(spawn.legacy_source_room_path):
				rooms.append(spawn.legacy_source_room_path)
	for landmark: WorldLandmarkDefinition in catalog.hidden_passages():
		if not rooms.has(landmark.legacy_source_path):
			rooms.append(landmark.legacy_source_path)
	for trap: RoomTrapDefinition in catalog.traps():
		if not rooms.has(trap.legacy_source_path):
			rooms.append(trap.legacy_source_path)
	return rooms


func rooms() -> Array[String]:
	return _rooms.duplicate()


## Milliseconds of world time until `room` resets.
func remaining_ms(room: String) -> int:
	return _remaining_ms.get(room, -1)


## The rooms whose reset comes due in `delta` seconds, each scheduled again.
func advance(delta: float) -> Array[String]:
	var due: Array[String] = []
	if not is_finite(delta) or delta < 0.0:
		return due
	_carried_ms += delta * 1000.0
	var elapsed: int = int(_carried_ms)
	_carried_ms -= elapsed
	for room: String in _rooms:
		_remaining_ms[room] -= elapsed
		if _remaining_ms[room] <= 0:
			due.append(room)
			_remaining_ms[room] = _interval_ms()
	return due


func _interval_ms() -> int:
	var half: int = _period_seconds / 2
	var drawn: int = 0 if _random == null else _random.legacy_random(half)
	return 1000 * (half + clampi(drawn, 0, maxi(half - 1, 0)))
