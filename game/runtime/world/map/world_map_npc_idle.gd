class_name WorldMapNpcIdle
extends RefCounted
## Native (NPC 活起来; DECISIONS「街上的人会动」): what the people of the map the player is on do
## while nothing else moves them — each by its NpcLifeBook entry: strolls about its own room
## (wander, work), looks along the way and back (post), or stays put (still). One the player
## comes near (pacing's npc_idle stop_reach_px), or has selected, stops and turns to them.
## Only the body's place inside its zone changes, never its zone: rooms, room moves
## (random_move), reach rules and every ES2 random stream stay as they are; its own stream
## draws the strolls. Ticked on NPC heart_beat time (world time: still in a fight and
## while the world is held), only on the active map.

## How far a post's look turns from its own facing (radians, either way; a body faces in
## eighths).
const POST_LOOK: float = PI / 4.0

var _map: WorldMapController
## {home: Vector2, zone: StringName, facing: Vector2, wait: float, turned: bool, met: bool}
## by character ID: where the person stands in its room and the way it faces there (its first
## place and facing in that room), the seconds to its next stroll or look, whether a post
## looks away now, and whether it has turned to the player. Not saved: a save keeps the body
## where it stands.
var _people: Dictionary[StringName, Dictionary] = {}
var random: RandomNumberGenerator = RandomNumberGenerator.new()


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
	for npc: NpcRuntimeState in _map.npcs.residents:
		var entry: NpcLifeBook.Entry = NpcLifeBook.entry(NpcDefinition.unnamed_id(npc.definition().definition_id))
		var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
		if entry == null or body == null:
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
		if near:
			if walker.is_strolling(npc.character_id):
				walker.cancel(npc.character_id)
			body.face_toward(_map.player_body.global_position)
			person["met"] = true
			person["wait"] = tuning.pause_seconds(random.randf())
			continue
		if person["met"]:
			# The player went on: one that stays put faces its own way again.
			person["met"] = false
			if not entry.moves():
				_face(body, person["facing"])
				person["turned"] = false
		if walker.is_strolling(npc.character_id):
			continue
		person["wait"] = float(person["wait"]) - delta
		if float(person["wait"]) > 0.0:
			continue
		person["wait"] = tuning.pause_seconds(random.randf())
		match entry.mode:
			NpcLifeBook.Mode.POST:
				var turned: bool = not bool(person["turned"])
				person["turned"] = turned
				var facing: Vector2 = person["facing"]
				_face(body, facing.rotated(POST_LOOK * (1.0 if random.randf() < 0.5 else -1.0)) if turned else facing)
			NpcLifeBook.Mode.WANDER, NpcLifeBook.Mode.WORK:
				walker.stroll(
					npc.character_id, body, _map.physical_zone(zone_id), person["home"],
					float(entry.reach(tuning.home_radius_px)), float(tuning.stroll_min_px),
					float(tuning.stroll_max_px), float(tuning.speed_px), random.randf,
				)


## Forgets everyone (the map is left, or reset): a post or one that stays put faces its own
## way again, and each starts again from its own spot.
func clear() -> void:
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


static func _face(body: WorldCharacterBody2D, facing: Vector2) -> void:
	if facing != Vector2.ZERO:
		body.face_toward(body.global_position + facing)
