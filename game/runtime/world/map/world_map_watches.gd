class_name WorldMapWatches
extends RefCounted
## Native (第九章 B; DECISIONS「禁军夜巡」): the night watch of this map — every NPC with an
## NpcWatch walks its route and looks for the player (NpcWatch's rules: a cone, walls, lights,
## cover, a beat to slip away; pacing's `stealth` off, ES2's presence). Ticked by the map every
## physics frame while the world runs. A player seen the beat through is caught: the watch's
## lines, its mark, the clock to dawn, put out at the release point (another map: a handoff).
## Presentation reads what it shows from the bodies: a ？ over a watcher that is looking, ！ when
## it has them (set_alert_mark), and the cone (meta `watch_cone`: radius px, degrees, alarmed).

const SAMPLE: float = 8.0
## Terrain that stops an eye (TileSet custom data `terrain`); a piece of furniture (`blocked`)
## does not, unless its look says `cover`.
const SIGHT_STOPS: Array[String] = ["wall", "wall_wood", "boundary", "shutter", "shop_front", "cliff", "forest", "rock"]
const ALERT: String = "！"
const LOOKING: String = "？"

var _map: WorldMapController
var _states: Dictionary[StringName, Watching] = {}
var _lights: Array[Light] = []
var _covers: Array[Rect2] = []
var _layers: Array[TileMapLayer] = []
var _read_pieces: bool = false
var _catching: bool = false

class Watching:
	extends RefCounted
	var index: int = 0
	var step: int = 1
	var rest: float = 0.0
	var noticed: float = 0.0
	var active: bool = false

class Light:
	extends RefCounted
	var at: Vector2
	var radius: float

	func _init(p_at: Vector2, p_radius: float) -> void:
		at = p_at
		radius = p_radius


var session: WorldSessionController:
	get: return _map.session
var _player: WorldPlayerRuntimeState:
	get: return _map.player_runtime()


func _init(controller: WorldMapController) -> void:
	_map = controller


## Every physics frame of the running world.
func tick(delta: float) -> void:
	if session == null or _player == null or _catching or not _map.gameplay_open():
		return
	if session.combat_encounter_coordinator().has_active_encounter():
		return
	_read_furniture()
	for npc: NpcRuntimeState in _map.npcs.residents:
		var watch: NpcWatch = npc.definition().dealings().watch
		if watch == null:
			continue
		var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
		var state: Watching = _states.get(npc.character_id)
		if state == null:
			state = Watching.new()
			_states[npc.character_id] = state
		var on: bool = (
			body != null and npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
			and not npc.relationship.is_fighting() and _holds(watch.when, true)
		)
		if not on:
			if state.active and body != null:
				_quiet(body, state)
			if body != null and body.has_meta("watch_cone"):
				body.remove_meta("watch_cone")
			state.active = false
			continue
		state.active = true
		_walk(npc, body, watch, state, delta)
		var stealth: bool = GameContent.catalog().pacing().stealth
		body.set_meta("watch_cone", {"radius": watch.radius, "degrees": watch.cone_degrees if stealth else 360, "alarmed": state.noticed > 0.0})
		if _holds(watch.unless, false) or not sees(npc, body, watch):
			if state.noticed > 0.0:
				_quiet(body, state)
			continue
		state.noticed += delta * 1000.0
		body.face_toward(_map.player_body.global_position)
		if not stealth or state.noticed >= watch.notice_ms:
			body.set_alert_mark(true, ALERT)
			_catch(npc, watch)
			return
		body.set_alert_mark(true, LOOKING)


## Whether the watcher sees the player now (its cone and reach, the light on the player, walls
## and cover between them); with pacing's stealth off any player within its radius.
func sees(npc: NpcRuntimeState, body: WorldCharacterBody2D, watch: NpcWatch) -> bool:
	var stealth: bool = GameContent.catalog().pacing().stealth
	var from: Vector2 = body.global_position
	var to: Vector2 = _map.player_body.global_position
	var reach: float = float(watch.lit_radius) if stealth and lit(to, npc) else float(watch.radius)
	if not watch.sees_direction(from, body.facing, to, reach, stealth):
		return false
	return not stealth or clear_line(from, to)


## Whether `point` stands in a light: a lamp of the map's (a layout piece whose look carries
## `light`) or a watcher's own lantern (`lantern` round any keeping its watch now).
func lit(point: Vector2, besides: NpcRuntimeState = null) -> bool:
	_read_furniture()
	for light: Light in _lights:
		if light.at.distance_to(point) <= light.radius:
			return true
	for npc: NpcRuntimeState in _map.npcs.residents:
		var watch: NpcWatch = npc.definition().dealings().watch
		var state: Watching = _states.get(npc.character_id)
		if watch == null or watch.lantern <= 0 or npc == besides or state == null or not state.active:
			continue
		var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
		if body != null and body.global_position.distance_to(point) <= watch.lantern:
			return true
	return false


## Whether nothing that stops an eye lies between `from` and `to`: a wall's tile or a piece whose
## look says `cover` (a rockery, a cypress; a bench or a vat does not).
func clear_line(from: Vector2, to: Vector2) -> bool:
	_read_furniture()
	var length: float = from.distance_to(to)
	var steps: int = maxi(1, ceili(length / SAMPLE))
	for i: int in range(1, steps):
		var point: Vector2 = from.lerp(to, float(i) / float(steps))
		if _stops_sight(point):
			return false
		for cover: Rect2 in _covers:
			if cover.has_point(point):
				return false
	return true


## The watcher's walk: from marker to marker of its route and back, resting at each.
func _walk(npc: NpcRuntimeState, body: WorldCharacterBody2D, watch: NpcWatch, state: Watching, delta: float) -> void:
	var walker: WorldNpcWalker = _map.npc_life.npc_walker()
	if walker.is_walking(npc.character_id) or watch.route.size() < 2:
		return
	if state.rest > 0.0:
		state.rest -= delta
		return
	var next: int = state.index + state.step
	if next < 0 or next >= watch.route.size():
		state.step = -state.step
		next = state.index + state.step
	var marker: WorldSpawnMarker2D = _map.resolve_spawn_marker(watch.route[next])
	if marker == null:
		return
	var from: WorldPhysicalZoneArea2D = _zone_at(body.global_position)
	var to: WorldPhysicalZoneArea2D = _zone_at(marker.global_position)
	if from == null or to == null:
		return
	if walker.walk_to(npc.character_id, body, from, to, marker.global_position):
		state.index = next
		state.rest = watch.pause_ms / 1000.0
		if to.zone_id != npc.world_location().zone_id:
			npc.set_world_location(_map.location_for_zone(to.zone_id))


## Caught (NpcWatch's caught): its say, the lines (the second time's if it was not the first),
## the mark, the clock to the next of until_phase, out at the release point.
func _catch(npc: NpcRuntimeState, watch: NpcWatch) -> void:
	_catching = true
	var state: CharacterState = _player.state
	var again: bool = not watch.again_mark.is_empty() and state.marks.has(watch.mark)
	var lines: Array[ColoredLine] = []
	if not watch.say.is_empty():
		# TRANSLATORS: say.c: a watcher ({name}) catches the player in the night ({text}).
		lines.append(ColoredLine.new(tr("{name}喝道：{text}").format({"name": tr(npc.definition().display_name), "text": tr(watch.say)}), ColoredLine.HIR))
	for line: String in (watch.again_lines if again else watch.lines):
		lines.append(ColoredLine.new(tr(line)))
	state.marks[watch.again_mark if again else watch.mark] = 1
	_map.hud().append_colored_lines(lines)
	for body_state: StringName in _states.keys():
		var other: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(body_state)
		if other != null:
			_quiet(other, _states[body_state])
	if not watch.until_phase.is_empty():
		session.wait_until_phase(watch.until_phase)
	var out: ZoneDefinition = GameContent.catalog().zone(watch.release_zone_id)
	if out != null and session.handoff_to(out.map_id, out.zone_id, out.combat_location_id, watch.release_point_id).succeeded():
		var arrived: WorldMapController = session.active_map() as WorldMapController
		if arrived != null and arrived.hud() != null:
			arrived.hud().describe_arrival()
	_catching = false


func _quiet(body: WorldCharacterBody2D, state: Watching) -> void:
	state.noticed = 0.0
	body.set_alert_mark(false)
	if body.has_meta("watch_cone"):
		var cone: Dictionary = body.get_meta("watch_cone")
		cone["alarmed"] = false
		body.set_meta("watch_cone", cone)


func _holds(condition: JournalEntryDefinition, otherwise: bool) -> bool:
	if condition == null:
		return otherwise
	var location: WorldLocationState = _player.world_location()
	return JournalLog.holds(condition, _player.state, _player.temp_marks, session.player_held_item_ids(), &"" if location == null else location.zone_id, session.player_worn_item_ids(), session.day_phase_id())


func _zone_at(point: Vector2) -> WorldPhysicalZoneArea2D:
	for zone: WorldPhysicalZoneArea2D in _map.physical_zones():
		if zone.contains_center(point):
			return zone
	return null


func _stops_sight(point: Vector2) -> bool:
	for layer: TileMapLayer in _layers:
		var data: TileData = layer.get_cell_tile_data(layer.local_to_map(layer.to_local(point)))
		if data != null and str(data.get_custom_data("terrain")) in SIGHT_STOPS:
			return true
	return false


## The map's lamps and cover, read once from its Furnishings (the layout's looks).
func _read_furniture() -> void:
	if _read_pieces:
		return
	_read_pieces = true
	for node: Node in _map.find_children("*", "TileMapLayer", true, false):
		if (node as TileMapLayer).collision_enabled:
			_layers.append(node as TileMapLayer)
	var furnishings: Node = _map.get_node_or_null("Furnishings")
	if furnishings == null:
		return
	for piece: Node in furnishings.get_children():
		if not piece is Node2D or not piece.has_meta("look"):
			continue
		var look: Dictionary = piece.get_meta("look")
		var at: Vector2 = (piece as Node2D).global_position
		if float(look.get("light", 0.0)) > 0.0:
			_lights.append(Light.new(at, float(look["light"])))
		if look.get("cover", false):
			var size: Vector2 = piece.get_meta("footprint", Vector2(32, 32))
			_covers.append(Rect2(at - size / 2.0, size))
