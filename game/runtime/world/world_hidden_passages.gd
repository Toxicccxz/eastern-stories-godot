class_name WorldHiddenPassages
extends RefCounted

## The Session's hidden passages (hidden_passage landmarks): one
## HiddenPassageState each, pushed by the landmark's policy, advanced by world
## time, and the scene passages of both maps kept in step with it. ES2 opens the
## way up only when the room below is loaded (find_object); every native room
## always is, so both open together.
var _session: OldPineWorldSessionController
var _states: Dictionary[StringName, HiddenPassageState] = {}
var _carried_ms: float = 0.0


func _init(session: OldPineWorldSessionController) -> void:
	_session = session
	for landmark: WorldLandmarkDefinition in GameContent.catalog().hidden_passages():
		_states[landmark.landmark_id] = HiddenPassageState.new()


func state(landmark_id: StringName) -> HiddenPassageState:
	return _states.get(landmark_id)


## Continue with the player below a hidden passage: the way back stands open.
func open_for_player_below() -> void:
	for landmark_id: StringName in _states:
		var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(landmark_id)
		if _player_below(landmark):
			_states[landmark_id].open_for_player_below()
			_apply(landmark, true)


## weapon_storage.c do_push(): the push line, then check_trigger().
func push(landmark: WorldLandmarkDefinition) -> HiddenPassagePushResult:
	var result: HiddenPassagePushResult = HiddenPassagePushResult.new()
	var passage: HiddenPassageState = null if landmark == null else _states.get(landmark.landmark_id)
	if passage == null:
		return result
	result.pushed = true
	_session.shared_ui().append_log_lines([landmark.message("push")])
	result.opened = passage.push(landmark.setting("pushes"), 1000 * landmark.setting("open_seconds"))
	if result.opened:
		_apply(landmark, true)
		_session.shared_ui().append_log_lines([landmark.message("open")])
	return result


## weapon_storage.c reset(): delete("left_trigger") when the landmark's room resets.
func reset_room(legacy_room: String) -> void:
	for landmark_id: StringName in _states:
		if GameContent.catalog().landmark(landmark_id).legacy_source_path == legacy_room:
			_states[landmark_id].reset()


## close_passage() once the call_out's time has passed in the world. The close
## line is seen in the landmark's room (message("vision", ..., this_object())).
func advance(delta: float) -> void:
	_carried_ms += maxf(0.0, delta) * 1000.0
	var elapsed: int = int(_carried_ms)
	_carried_ms -= elapsed
	for landmark_id: StringName in _states:
		var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(landmark_id)
		if _states[landmark_id].advance(elapsed, _player_below(landmark)):
			_apply(landmark, false)
			var location: WorldLocationState = _session.player_runtime().world_location()
			if location != null and location.zone_id == landmark.zone_id:
				_session.shared_ui().append_log_lines([landmark.message("close")])


func _apply(landmark: WorldLandmarkDefinition, open: bool) -> void:
	for portal_id: StringName in landmark.portal_ids():
		var portal: PortalDefinition = GameContent.catalog().portal(portal_id)
		var map: WorldResidentMapController = null if portal == null else _session.resident_map(portal.source_map_id)
		if map != null:
			map.set_portal_open(portal_id, open)


## The player stands where the passage's way down leads.
func _player_below(landmark: WorldLandmarkDefinition) -> bool:
	var down: PortalDefinition = GameContent.catalog().portal(landmark.portal_id)
	var location: WorldLocationState = _session.player_runtime().world_location()
	return down != null and location != null and location.zone_id == down.destination_zone_id
