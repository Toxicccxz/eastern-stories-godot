class_name WorldMapWinds
extends RefCounted
## Native (第十章 A; DECISIONS「风」): the guiding wind of this map (WindDefinition): ticked by the map
## every physics frame while the world runs and no fight holds it. Each gust tells where the wind
## comes from when that changes (or that it veered, or stopped), rings the bell one carries, and
## brings the gale on one far from the route (pacing's native_hazards). The route that blows is
## the one the player's saved marks name, drawn when they come in by one of the wind's portals.
## Presentation reads `vector()` (the wind's unit vector in the map's px space, ZERO when still)
## and `gusty()` (a veering gust): grass, mist and the HUD's vane show it; they change nothing.

var _map: WorldMapController
var _wind: WindDefinition
var _read: bool = false
var _points: Dictionary[StringName, PackedVector2Array] = {}
var _elapsed_ms: float = 0.0
var _vector: Vector2 = Vector2.ZERO
var _gusty: bool = false
var _told: String = ""
var _bell: String = ""
var _last_at: Vector2 = Vector2.INF
var _blowing: bool = false

var session: WorldSessionController:
	get: return _map.session
var _player: WorldPlayerRuntimeState:
	get: return _map.player_runtime()


func _init(controller: WorldMapController) -> void:
	_map = controller


## The map's wind, or null.
func wind() -> WindDefinition:
	if not _read:
		_read = true
		_wind = GameContent.catalog().wind_for_map(_map.map_id())
	return _wind


## The wind's unit vector now (px space: +x east, +y south), ZERO when still or none blows here.
func vector() -> Vector2:
	return _vector if _blowing else Vector2.ZERO


## Whether the gust blowing now is one that veered (no direction to read in it).
func gusty() -> bool:
	return _blowing and _gusty


## Whether the wind blows where the player stands (one of its zones).
func blowing() -> bool:
	return _blowing


## Coming in by `portal` (the map left): a wind it is a way into draws its route afresh (the town
## has drifted), marking it and clearing the others' marks.
static func entering(portal: PortalDefinition, state: CharacterState, draw: Callable) -> void:
	var into: WindDefinition = GameContent.catalog().wind_for_map(portal.destination_map_id)
	if into == null or not into.enter_portal_ids.has(portal.portal_id):
		return
	var drawn: int = 0 if into.pick == WindDefinition.Pick.FIXED else int(draw.call(into.routes.size()))
	_mark(into, state, into.route_drawn(drawn))


## The route blowing for this player: their mark's, or one drawn now (no mark yet: a Continue
## from before the wind, a test putting them here).
func route() -> WindDefinition.Route:
	if wind() == null or _player == null:
		return null
	var marked: WindDefinition.Route = wind().route_marked(_player.state.marks)
	if marked != null:
		return marked
	var drawn: WindDefinition.Route = wind().route_drawn(0 if wind().pick == WindDefinition.Pick.FIXED else _map.world_interaction_random_source().legacy_random(wind().routes.size()))
	_mark(wind(), _player.state, drawn)
	return drawn


## The route's points on this map (px), from the layout's spawn points.
func points(of: WindDefinition.Route) -> PackedVector2Array:
	if _points.has(of.route_id):
		return _points[of.route_id]
	var laid := PackedVector2Array()
	for point_id: StringName in of.points:
		var marker: WorldSpawnMarker2D = _map.resolve_spawn_marker(point_id)
		if marker == null:
			push_error("wind %s: no spawn point %s on %s" % [wind().wind_id, point_id, _map.map_id()])
			return PackedVector2Array()
		laid.append(marker.global_position)
	_points[of.route_id] = laid
	return laid


## Every physics frame of the running world.
func tick(delta: float) -> void:
	if session == null or _player == null or not _map.gameplay_open():
		return
	if wind() == null:
		# A map without a wind clears the vane another one left (a death, an act's move).
		if _map.hud() != null and _map.hud().player_wind != null and _map.hud().player_wind.visible:
			_map.hud().show_wind("")
		return
	# Another map cleared the vane (the player left this one: a passage, a death, an act's move):
	# coming back, the wind starts afresh.
	if _blowing and _map.hud() != null and _map.hud().player_wind != null and not _map.hud().player_wind.visible:
		_blowing = false
	if session.combat_encounter_coordinator().has_active_encounter():
		return
	var location: WorldLocationState = _player.world_location()
	var here: bool = location != null and wind().zone_ids.has(location.zone_id)
	if here != _blowing:
		_blowing = here
		_elapsed_ms = 0.0
		_told = ""
		_bell = ""
		_last_at = _map.player_body.global_position
		if here:
			_gust(false)
		_show()
	if not here:
		return
	_elapsed_ms += delta * 1000.0
	while _elapsed_ms >= wind().gust_ms:
		_elapsed_ms -= wind().gust_ms
		_gust(true)
		if not _blowing or session.active_map() != _map:
			return


## One gust: where it comes from, the bell, the gale. `may_gale`: whether this gust may bring the
## gale (not the first breath on coming in).
func _gust(may_gale: bool) -> void:
	var blowing_route: WindDefinition.Route = route()
	var laid: PackedVector2Array = PackedVector2Array() if blowing_route == null else points(blowing_route)
	if laid.size() < 2:
		return
	var at: Vector2 = _map.player_body.global_position
	var steady: Vector2 = wind().blowing(laid, at)
	var draw: Callable = _map.world_interaction_random_source().legacy_random
	_gusty = steady != Vector2.ZERO and wind().veer_percent > 0 and int(draw.call(100)) < wind().veer_percent
	_vector = steady
	if _gusty:
		_vector = WindDefinition.veered(steady, float(wind().veer_degrees) * (1.0 if int(draw.call(2)) == 0 else -1.0))
	var lines: Array[ColoredLine] = []
	var told: String = "calm" if steady == Vector2.ZERO else ("veer" if _gusty else WindDefinition.quarter_of(steady))
	if told != _told:
		if told == "calm":
			# TRANSLATORS: 第十章 A (DECISIONS「风」): the wind stops where the player stands (the calm).
			lines.append(ColoredLine.new(tr("风停了。草直直地立着，雾也不动了，四下里一点声音都没有。"), ColoredLine.HIW))
		elif told == "veer":
			# TRANSLATORS: 第十章 A: a gust that veers, no direction to read in it.
			lines.append(ColoredLine.new(tr("一阵乱风打着旋卷过去，辨不出是从哪边来的。")))
		else:
			# TRANSLATORS: 第十章 A: where the wind comes from ({quarter}: 北, 东北 … 西北).
			lines.append(ColoredLine.new(tr("风从{quarter}边吹过来，草都朝一边倒。").format({"quarter": tr(told)})))
		_told = told
	var bell: String = _bell_of(steady, at)
	# Walking, the bell answers every gust (clear into the wind, dull off it); still, it rings once.
	if not bell.is_empty() and (bell != "still" or _bell != "still"):
		match bell:
			"still":
				# TRANSLATORS: 第十章 A: the wind bell in the calm.
				lines.append(ColoredLine.new(tr("怀里的风铃轻轻响了一声，清清楚楚。"), ColoredLine.HIY))
			"clear":
				# TRANSLATORS: 第十章 A: the wind bell rings clear: the way walked went into the wind.
				lines.append(ColoredLine.new(tr("怀里的风铃叮叮地响，声音清亮。"), ColoredLine.HIY))
			"dull":
				# TRANSLATORS: 第十章 A: the wind bell rings dull: the way walked did not go into the wind.
				lines.append(ColoredLine.new(tr("怀里的风铃闷闷地响了两下。")))
	if not bell.is_empty():
		_bell = bell
	_last_at = at
	if not lines.is_empty() and _map.hud() != null:
		_map.hud().append_colored_lines(lines)
	_show()
	if may_gale and steady != Vector2.ZERO and wind().off_route(laid, at) > wind().route_radius:
		_gale()


## The bell's word this gust: "" (not carried, or nothing walked), still, clear or dull.
func _bell_of(steady: Vector2, at: Vector2) -> String:
	if wind().bell_item_id.is_empty() or not session.player_held_item_ids().get(wind().bell_item_id, false):
		return ""
	if steady == Vector2.ZERO:
		return "still"
	if _last_at == Vector2.INF or at.distance_to(_last_at) < 24.0:
		return ""
	return "clear" if wind().went_upwind(steady, at - _last_at) else "dull"


## The gale on one far from the route: its first branch for the player (a native hazard's rule).
func _gale() -> void:
	if wind().gale.is_empty() or not GameContent.catalog().pacing().native_hazards:
		return
	var zone_id: StringName = _player.world_location().zone_id
	var act: ScriptedAct = ScriptedAct.first_for(wind().gale, _player.state.gender, _player.state.affiliation.class_id, _map.acts.facts(zone_id))
	if act != null:
		_map.acts.run(act, null, _map.world_interaction_random_source().legacy_random, zone_id)


## The HUD's vane: where it comes from, still, veering; nothing off the wind's zones.
func _show() -> void:
	var hud: SharedGameplayUI = _map.hud()
	if hud == null:
		return
	if not _blowing:
		hud.show_wind("")
	elif _vector == Vector2.ZERO:
		# TRANSLATORS: 第十章 A: the HUD's wind row in the calm.
		hud.show_wind(tr("风：停了"))
	elif _gusty:
		# TRANSLATORS: 第十章 A: the HUD's wind row in a veering gust.
		hud.show_wind(tr("风：乱风"))
	else:
		# TRANSLATORS: 第十章 A: the HUD's wind row ({quarter} it comes from, {arrow} where it blows).
		hud.show_wind(tr("风：{quarter}风 {arrow}").format({"quarter": tr(WindDefinition.quarter_of(_vector)), "arrow": _arrow(_vector)}))


static func _mark(wind: WindDefinition, state: CharacterState, chosen: WindDefinition.Route) -> void:
	for each: WindDefinition.Route in wind.routes:
		state.marks.erase(each.mark)
	state.marks[chosen.mark] = 1


## An arrow along the wind (where it blows to), of eight.
static func _arrow(wind: Vector2) -> String:
	const ARROWS: Array[String] = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
	var degrees: float = fposmod(rad_to_deg(atan2(wind.x, -wind.y)), 360.0)
	return ARROWS[int(round(degrees / 45.0)) % 8]
