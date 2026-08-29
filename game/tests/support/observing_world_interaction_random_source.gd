class_name ObservingWorldInteractionRandomSource
extends WorldInteractionRandomSource

var _draws: Array[int] = []
var _requested_bounds: Array[int] = []
var _hud: OldPineOutdoorHud
var _player: WorldPlayerRuntimeState
var _expected_source_text: String = ""
var source_text_was_visible_at_draw: bool = false
var player_was_at_east_bridge_at_draw: bool = false


func _init(
	draws: Array[int] = [],
	hud: OldPineOutdoorHud = null,
	player: WorldPlayerRuntimeState = null,
	expected_source_text: String = "",
) -> void:
	_draws = draws.duplicate()
	_hud = hud
	_player = player
	_expected_source_text = expected_source_text


func next_below(exclusive_upper_bound: int) -> int:
	_requested_bounds.append(exclusive_upper_bound)
	if _hud != null:
		var lines: Array[String] = _hud.log_lines()
		source_text_was_visible_at_draw = (
			not lines.is_empty()
			and lines[-1] == _expected_source_text
		)
	if _player != null:
		var location: WorldLocationState = _player.world_location()
		player_was_at_east_bridge_at_draw = (
			location != null
			and location.map_id == OldPineWorldDefinitions.OUTDOOR_MAP_ID
			and location.zone_id == OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID
			and location.combat_location_id
			== OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID
		)
	if _draws.is_empty():
		return -1
	return _draws.pop_front()


func call_count() -> int:
	return _requested_bounds.size()


func requested_bounds() -> Array[int]:
	return _requested_bounds.duplicate()
