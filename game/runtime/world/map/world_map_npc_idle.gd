class_name WorldMapNpcIdle
extends RefCounted
## Native (NPC 活起来; DECISIONS「街上的人会动」): what the people of the map the player is on do
## while nothing else moves them — each by its NpcLifeBook entry: strolls about its own room
## (wander, work), looks along the way and back (post), or stays put (still). One the player
## comes near (pacing's npc_idle stop_reach_px), or has selected, finishes its few steps and turns
## to them. One that attacks on sight or takes a toll never strolls: it looks about at its spot.
## Only the body's place inside its zone changes, never its zone: rooms, room moves
## (random_move), reach rules and every ES2 random stream stay as they are; its own stream
## draws the strolls. Ticked on NPC heart_beat time (world time: still in a fight and
## while the world is held), only on the active map.
## Night (D; DECISIONS「夜里冷清」): the street's idle folk (entries with `night` "home") go indoors
## while the day's phase is one of npc_idle's night_phases — one in sight walks to the map's nearest
## way out (a passage, a door) and is gone there, one out of sight is simply gone — and come out
## at dawn (out of the nearest way out and back to their spot, if the spot is in sight). As the
## player comes onto a map (judge_night()) it is so at once. Busy or with the player, one waits.
## Their absence is the NPC's own (withdraw(), saved as any absent one); nothing else is kept.

## One at work faces a piece of furniture (the anvil, the counter, a table) this near the edge
## of its body (pixels), else keeps the way it came.
const WORK_FACES_PX: float = 40.0

## How far a post's look turns from its own facing (radians, either way; a body faces in
## eighths).
const POST_LOOK: float = PI / 4.0

## Body meta: true while the person attends to the player (its gesture stops).
const ATTENDING: StringName = &"npc_attending"

var _map: WorldMapController
## {home: Vector2, zone: StringName, facing: Vector2, wait: float, turned: bool, met: bool}
## by character ID: where the person stands in its room and the way it faces there (its first
## place and facing in that room), the seconds to its next stroll or look, whether a post
## looks away now, and whether it has turned to the player. Not saved: a save keeps the body
## where it stands.
var _people: Dictionary[StringName, Dictionary] = {}
var random: RandomNumberGenerator = RandomNumberGenerator.new()
## NpcLifeBook's entry by NPC definition ID (null: none), looked up once: the loop runs every tick.
var _entries: Dictionary[StringName, NpcLifeBook.Entry] = {}
## Night (D): who is on the way indoors, by character ID: true walking to a way out, false with
## no way to walk (gone once out of sight). Not saved: a save takes the walk's end.
var _leaving: Dictionary[StringName, bool] = {}


func _init(map: WorldMapController) -> void:
	_map = map
	random.seed = 0x6e70636c


func advance(delta: float) -> void:
	var tuning: NpcIdleTuning = GameContent.catalog().pacing().npc_idle
	if not tuning.enabled or not is_finite(delta) or delta <= 0.0:
		return
	var session: WorldSessionController = _map.session
	if session == null or session.active_map() != _map or _map.player_body == null:
		return
	var walker: WorldNpcWalker = _map.npc_life.npc_walker()
	var selected: StringName = _map.selection.selected_character_id()
	# A room's stroll ground is made one step a tick (a grid or its cells: a few ms each).
	var prepared: bool = false
	var night: bool = _night_now(tuning)
	for npc: NpcRuntimeState in _map.npcs.residents:
		var entry: NpcLifeBook.Entry = _entry(npc.definition().definition_id)
		var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
		if entry == null or body == null:
			continue
		if tuning.night_home and entry.night_home and _night_spawn(npc) != null and _night_step(npc, body, night, selected, tuning, walker):
			continue
		if not npc.exists_in_map:
			continue
		var zone_id: StringName = npc.world_location().zone_id
		var person: Dictionary = _people.get(npc.character_id, {})
		# A room move (its rules) or another walk is under way: its own spot is where it ends.
		if walker.is_walking(npc.character_id) and not walker.is_strolling(npc.character_id):
			_people.erase(npc.character_id)
			continue
		if person.is_empty() or person["zone"] != zone_id:
			person = {
				"home": _home(npc, body, zone_id), "zone": zone_id, "facing": body.facing,
				"wait": tuning.pause_seconds(random.randf()), "turned": false, "met": false,
			}
			_people[npc.character_id] = person
		if not _free(npc):
			if walker.is_strolling(npc.character_id):
				walker.cancel(npc.character_id)
			continue
		var near: bool = (
			npc.character_id == selected
			or body.global_position.distance_to(_map.player_body.global_position) <= float(tuning.stop_reach_px)
		)
		# The voxel person puts its work down while it attends to the player.
		body.set_meta(ATTENDING, near)
		if near:
			# One under way finishes its few steps (they end on open ground) before it turns: stopped
			# half-way it could stand across a narrow way (a plank bridge) the player is on.
			if not walker.is_strolling(npc.character_id):
				body.face_toward(_map.player_body.global_position)
			person["met"] = true
			# Back at its work once the player goes: it turns to the furniture again.
			person["settled"] = false
			person["wait"] = tuning.pause_seconds(random.randf())
			continue
		if person["met"]:
			# The player went on: one that stays put faces its own way again.
			person["met"] = false
			if (not entry.moves() or _keeps_watch(npc)) and entry.gesture == "":
				_face(body, person["facing"])
				person["turned"] = false
		if walker.is_strolling(npc.character_id):
			person["settled"] = false
			continue
		if not person.get("settled", false):
			# At its work again: it turns to what it works at.
			person["settled"] = true
			if entry.gesture != "":
				var at: Vector2 = _work_point(body.global_position, _map.physical_zone(zone_id))
				if at.is_finite():
					body.face_toward(at)
		person["wait"] = float(person["wait"]) - delta
		if float(person["wait"]) > 0.0:
			continue
		person["wait"] = tuning.pause_seconds(random.randf())
		# One that attacks on sight (or takes a toll) keeps its spot and looks about: strolling would
		# carry its notice where ES2's room put none (a new player's road past 疯狗, 老松林's
		# bandits the owner keeps avoidable).
		var mode: NpcLifeBook.Mode = NpcLifeBook.Mode.POST if entry.moves() and _keeps_watch(npc) else entry.mode
		if entry.moves() and mode != NpcLifeBook.Mode.POST and not walker.ground_ready(_map.physical_zone(zone_id)):
			if not prepared:
				walker.prepare_ground(_map.physical_zone(zone_id))
				prepared = true
			person["wait"] = 0.0
			continue
		match mode:
			NpcLifeBook.Mode.POST:
				var turned: bool = not bool(person["turned"])
				person["turned"] = turned
				var facing: Vector2 = person["facing"]
				_face(body, facing.rotated(POST_LOOK * (1.0 if random.randf() < 0.5 else -1.0)) if turned else facing)
			NpcLifeBook.Mode.WANDER, NpcLifeBook.Mode.WORK:
				# A short reach (a smith by the forge) takes short steps.
				var reach: float = float(entry.reach(tuning.home_radius_px))
				walker.stroll(
					npc.character_id, body, _map.physical_zone(zone_id), person["home"],
					reach, minf(float(tuning.stroll_min_px), reach*0.5),
					float(tuning.stroll_max_px), float(tuning.speed_px), random.randf,
				)


## Night (D): as the player comes onto the map (a handoff, Continue, the first map), the street's
## idle folk are where the hour puts them, at once: indoors by night, on their spots by day.
func judge_night() -> void:
	_leaving.clear()
	var tuning: NpcIdleTuning = GameContent.catalog().pacing().npc_idle
	if not tuning.enabled or not tuning.night_home or _map.session == null:
		return
	var night: bool = _night_now(tuning)
	for npc: NpcRuntimeState in _map.npcs.residents.duplicate():
		var entry: NpcLifeBook.Entry = _entry(npc.definition().definition_id)
		var spawn: NpcSpawnDefinition = _night_spawn(npc)
		if entry == null or not entry.night_home or spawn == null or not _up(npc):
			continue
		if night and npc.exists_in_map and _free(npc):
			_go_in(npc)
		elif not night and not npc.exists_in_map:
			_map.npcs.appear(npc, spawn)
			_people.erase(npc.character_id)


## Whether the day's phase now is one of the night's.
func _night_now(tuning: NpcIdleTuning) -> bool:
	return tuning.night_home and _map.session != null and tuning.night_phases.has(_map.session.day_phase_id())


## The spawn of one who may go indoors at night: an ordinary one (not the story's, a summoned,
## drawn or absent-at-first one, whose comings and goings are their own), else null.
static func _night_spawn(npc: NpcRuntimeState) -> NpcSpawnDefinition:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(npc.spawn_id)
	if spawn == null or spawn.staged or spawn.summoned or spawn.starts_absent or spawn.drawn:
		return null
	return spawn


## Alive, awake and not gone for good.
static func _up(npc: NpcRuntimeState) -> bool:
	return npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not npc.has_flag(NpcDefinition.FLAG_GONE)


## One tick of the night for one of the street's idle folk: true when it took the tick (the rest
## of the loop leaves it be), false when the day's ways go on (busy, or with the player).
func _night_step(npc: NpcRuntimeState, body: WorldCharacterBody2D, night: bool, selected: StringName, tuning: NpcIdleTuning, walker: WorldNpcWalker) -> bool:
	var id: StringName = npc.character_id
	if not night:
		_leaving.erase(id)
		if npc.exists_in_map or not _up(npc):
			return false
		_come_out(npc, walker)
		return true
	if not npc.exists_in_map:
		return true
	if _leaving.has(id):
		if bool(_leaving[id]) and walker.is_walking(id):
			return true
		if bool(_leaving[id]) or not _map.in_view(body.global_position):
			_go_in(npc)
		return true
	if not _free(npc) or id == selected or body.global_position.distance_to(_map.player_body.global_position) <= float(tuning.stop_reach_px):
		return false
	if walker.is_strolling(id):
		# Its few steps first.
		return true
	if not _map.in_view(body.global_position):
		_go_in(npc)
		return true
	_leaving[id] = false
	for spot: Vector2 in _ways_out(body.global_position):
		if walker.walk_across(id, body, spot):
			_leaving[id] = true
			break
	return true


## Indoors for the night: off the map until dawn.
func _go_in(npc: NpcRuntimeState) -> void:
	var walker: WorldNpcWalker = _map.npc_life.npc_walker()
	walker.cancel(npc.character_id)
	_leaving.erase(npc.character_id)
	_people.erase(npc.character_id)
	var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
	if body != null:
		body.set_meta(ATTENDING, false)
	_map.npcs.withdraw(npc)


## Out again at dawn: on its spot, or (its spot in sight) out of the nearest way out and back to it.
func _come_out(npc: NpcRuntimeState, walker: WorldNpcWalker) -> void:
	var spawn: NpcSpawnDefinition = _night_spawn(npc)
	var marker: WorldSpawnMarker2D = _map.resolve_spawn_marker(npc.spawn_point_id)
	if spawn == null or marker == null:
		return
	var seen: bool = _map.in_view(marker.global_position)
	if not _map.npcs.appear(npc, spawn):
		return
	_people.erase(npc.character_id)
	var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
	if not seen or body == null:
		return
	for spot: Vector2 in _ways_out(marker.global_position):
		body.global_position = spot
		if walker.walk_across(npc.character_id, body, marker.global_position):
			return
	body.global_position = marker.global_position


## The map's ways out (its passages, its doors), nearest to `point` first, at most three.
func _ways_out(point: Vector2) -> Array[Vector2]:
	var ways: Array[Vector2] = []
	for passage: WorldPassageArea2D in _map.static_nodes().passages:
		ways.append(passage.global_rect().get_center())
	for door: WorldDoor in _map.static_nodes().doors:
		var wall: CollisionShape2D = door.wall_shape()
		if wall != null:
			ways.append(wall.global_position)
	ways.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(point) < b.distance_squared_to(point))
	return ways.slice(0, 3)


## The nearest point of the furniture of `zone` (the map's Furnishings standing in it and on the
## stage now: position and footprint) within WORK_FACES_PX of a body at `point` (17 px its half
## width), else Vector2.INF.
func _work_point(point: Vector2, zone: WorldPhysicalZoneArea2D) -> Vector2:
	var furnishings: Node = _map.find_child("Furnishings", false, false)
	var best: Vector2 = Vector2.INF
	if furnishings == null:
		return best
	for piece: Node in furnishings.get_children():
		if not (piece is Node2D) or not piece.has_meta("footprint") or bool(piece.get_meta("staged_off", false)):
			continue
		if zone != null and not zone.global_rect().has_point((piece as Node2D).global_position):
			continue
		var size: Vector2 = piece.get_meta("footprint")
		var centre: Vector2 = (piece as Node2D).global_position
		var near: Vector2 = point.clamp(centre - size/2.0, centre + size/2.0)
		var gap: float = near.distance_to(point) - 17.0
		if gap <= WORK_FACES_PX and (not best.is_finite() or near.distance_to(point) < best.distance_to(point)):
			best = near
	return best


func _entry(definition_id: StringName) -> NpcLifeBook.Entry:
	if not _entries.has(definition_id):
		_entries[definition_id] = NpcLifeBook.entry(NpcDefinition.unnamed_id(definition_id))
	return _entries[definition_id]


## Forgets everyone (the map is left, or reset): a post or one that stays put faces its own
## way again, and each starts again from its own spot.
func clear() -> void:
	_leaving.clear()
	for character_id: StringName in _people:
		var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(character_id)
		if body != null:
			_face(body, _people[character_id]["facing"])
	_people.clear()


## Where a person strolls about: its spawn marker while in the room it was put in (the spot
## does not drift from visit to visit), else where it came into this room.
func _home(npc: NpcRuntimeState, body: WorldCharacterBody2D, zone_id: StringName) -> Vector2:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(npc.spawn_id)
	var marker: WorldSpawnMarker2D = _map.resolve_spawn_marker(npc.spawn_point_id)
	if spawn != null and spawn.zone_id == zone_id and marker != null:
		return marker.global_position
	return body.global_position


## Whether nothing else has the person now: standing and awake, not fighting or busy, not on
## a patrol, a watch, a scene, a way out or the player's heels, not raised or summoned.
func _free(npc: NpcRuntimeState) -> bool:
	var life: WorldMapNpcLife = _map.npc_life
	var dealings: NpcDealings = npc.definition().dealings()
	return (
		npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and not npc.relationship.is_fighting() and not npc.busy.is_busy()
		and dealings.patrol == null and dealings.watch == null
		and npc.definition().raising() == null and _map.npcs.summoner_of(npc.character_id).is_empty()
		and not life.follows_every_way(npc) and not life.departures.has(npc.character_id)
		and life.scene_npc_id != npc.character_id and life.scene_focus_id != npc.character_id
		and not (_map.player_runtime() != null and _map.player_runtime().led_by == npc.character_id)
	)


## Whether the person attacks on sight or takes a toll (its own room's aggression): it does not
## stroll.
static func _keeps_watch(npc: NpcRuntimeState) -> bool:
	var attitude: int = npc.definition().attitude
	return (
		attitude == NpcDefinition.Attitude.AGGRESSIVE or attitude == NpcDefinition.Attitude.KILLER
		or npc.definition().dealings().takes_toll()
	)


static func _face(body: WorldCharacterBody2D, facing: Vector2) -> void:
	if facing != Vector2.ZERO:
		body.face_toward(body.global_position + facing)
